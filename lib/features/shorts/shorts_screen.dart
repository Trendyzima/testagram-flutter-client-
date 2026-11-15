import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../core/backend_api.dart';
import '../posts/post_detail_screen.dart';
import 'shorts_feed_policy.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final List<ShortsFeedItem> _items = [];
  final Map<int, VideoPlayerController> _players = {};
  final Map<int, String> _playerErrors = {};
  final Set<String> _viewedPostIds = {};
  final Set<String> _busyActions = {};

  int _activeIndex = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _followingOnly = false;
  bool _muted = true;
  bool _appResumed = true;
  String? _cursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed) {
      unawaited(_syncPlayers());
    } else {
      for (final player in _players.values) {
        unawaited(player.pause());
      }
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final value = payload['data'];
    return value is Map ? Map<String, dynamic>.from(value) : payload;
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    final generation = reset ? ++_generation : _generation;

    if (reset) {
      await _disposePlayers();
      _items.clear();
      _playerErrors.clear();
      _viewedPostIds.clear();
      _cursor = null;
      _activeIndex = 0;
      _hasMore = true;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final payload = await widget.api.getHomeFeed(
        limit: 50,
        cursor: reset ? null : _cursor,
        followingOnly: _followingOnly,
        videoOnly: true,
      );
      final data = _data(payload);
      final raw = data['posts'];
      final rows = raw is List ? raw : const <dynamic>[];
      final videos = ShortsFeedPolicy.parsePosts(rows);
      final summaries = await Future.wait(videos.map((item) async {
        try {
          return _data(await widget.api.getPostInteractionSummary(item.postId));
        } catch (_) {
          return <String, dynamic>{};
        }
      }));

      if (!mounted || generation != _generation) return;
      setState(() {
        final existing = _items.map((item) => item.postId).toSet();
        for (var index = 0; index < videos.length; index++) {
          final item = videos[index];
          if (!existing.add(item.postId)) continue;
          final summary = summaries[index];
          item.post['is_liked'] = summary['is_liked'] == true;
          item.post['is_reposted'] = summary['is_reposted'] == true;
          item.post['is_bookmarked'] = summary['is_bookmarked'] == true;
          item.post['likes_count'] = summary['likes'] ?? item.post['likes_count'];
          item.post['replies_count'] = summary['replies'] ?? item.post['replies_count'];
          item.post['reposts_count'] = summary['reposts'] ?? item.post['reposts_count'];
          _items.add(item);
        }
        _cursor = (data['next_cursor'] ?? '').toString();
        _hasMore = data['has_more'] == true && (_cursor?.isNotEmpty ?? false);
      });

      if (reset && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      if (_items.isNotEmpty) {
        _recordView(_items[_activeIndex]);
        await _syncPlayers();
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _disposePlayers() async {
    final players = _players.values.toList();
    _players.clear();
    for (final player in players) {
      await player.dispose();
    }
  }

  Future<void> _ensurePlayer(int index) async {
    if (!mounted || index < 0 || index >= _items.length ||
        _players.containsKey(index) || _playerErrors.containsKey(index)) {
      return;
    }

    final item = _items[index];
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(item.mediaUrl),
      httpHeaders: item.mediaHeaders,
    );
    _players[index] = controller;

    try {
      await controller.initialize().timeout(const Duration(seconds: 25));
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted) return;
      if (index == _activeIndex && _appResumed) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (identical(_players[index], controller)) {
        _players.remove(index);
      }
      _playerErrors[index] = error.toString();
      await controller.dispose();
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncPlayers() async {
    if (!mounted || _items.isEmpty) return;
    final keep = <int>{_activeIndex, _activeIndex + 1};

    for (final entry in _players.entries.toList()) {
      if (!keep.contains(entry.key)) {
        _players.remove(entry.key);
        await entry.value.dispose();
      } else if (entry.key != _activeIndex || !_appResumed) {
        await entry.value.pause();
      } else {
        await entry.value.setVolume(_muted ? 0 : 1);
        if (entry.value.value.isInitialized) await entry.value.play();
      }
    }

    await _ensurePlayer(_activeIndex);
    await _ensurePlayer(_activeIndex + 1);
  }

  void _onPageChanged(int index) {
    if (index >= _items.length) {
      if (_hasMore) unawaited(_load());
      return;
    }
    setState(() => _activeIndex = index);
    _recordView(_items[index]);
    unawaited(_syncPlayers());
    if (_hasMore && index >= _items.length - 3) {
      unawaited(_load());
    }
  }

  void _recordView(ShortsFeedItem item) {
    if (item.postId.isEmpty || !_viewedPostIds.add(item.postId)) return;
    unawaited(widget.api.recordPostView(item.postId).catchError((_) => <String, dynamic>{}));
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    for (final player in _players.values) {
      if (player.value.isInitialized) {
        await player.setVolume(_muted ? 0 : 1);
      }
    }
  }

  Future<void> _togglePlayback(int index) async {
    final player = _players[index];
    if (player == null || !player.value.isInitialized) return;
    if (player.value.isPlaying) {
      await player.pause();
    } else if (_appResumed && index == _activeIndex) {
      await player.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _retryPlayer(int index) async {
    setState(() => _playerErrors.remove(index));
    await _ensurePlayer(index);
  }

  Future<void> _runAction(
    ShortsFeedItem item,
    String action,
    Future<void> Function() request,
  ) async {
    final key = '${item.postId}:$action';
    if (item.postId.isEmpty || !_busyActions.add(key)) return;
    setState(() {});
    try {
      await request();
      final summary = _data(await widget.api.getPostInteractionSummary(item.postId));
      if (!mounted) return;
      setState(() {
        item.post['is_liked'] = summary['is_liked'] == true;
        item.post['is_reposted'] = summary['is_reposted'] == true;
        item.post['is_bookmarked'] = summary['is_bookmarked'] == true;
        item.post['likes_count'] = summary['likes'] ?? item.post['likes_count'];
        item.post['replies_count'] = summary['replies'] ?? item.post['replies_count'];
        item.post['reposts_count'] = summary['reposts'] ?? item.post['reposts_count'];
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      _busyActions.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleLike(ShortsFeedItem item) => _runAction(
        item,
        'like',
        () async {
          if (item.post['is_liked'] == true) {
            await widget.api.removePostReaction(item.postId);
          } else {
            await widget.api.reactToPost(item.postId);
          }
        },
      );

  Future<void> _toggleRepost(ShortsFeedItem item) => _runAction(
        item,
        'repost',
        () async {
          if (item.post['is_reposted'] == true) {
            await widget.api.removePostRepost(item.postId);
          } else {
            await widget.api.repostPost(item.postId);
          }
        },
      );

  Future<void> _toggleBookmark(ShortsFeedItem item) => _runAction(
        item,
        'bookmark',
        () async {
          if (item.post['is_bookmarked'] == true) {
            await widget.api.removePostBookmark(item.postId);
          } else {
            await widget.api.bookmarkPost(item.postId);
          }
        },
      );

  Future<void> _toggleFollow(ShortsFeedItem item) async {
    final author = item.post['author'];
    final userId = (item.post['user_id'] ??
            (author is Map ? author['id'] : null) ??
            '')
        .toString();
    if (userId.isEmpty) return;
    await _runAction(item, 'follow', () async {
      if (item.isFollowing) {
        await widget.api.unfollowUser(userId);
      } else {
        await widget.api.followUser(userId);
      }
      item.post['is_following'] = !item.isFollowing;
    });
  }

  void _openPost(ShortsFeedItem item) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PostDetailScreen(api: widget.api, postId: item.postId),
    ));
  }

  Widget _emptyState() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            const Text('Could not load videos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _load(reset: true), child: const Text('Try again')),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 54),
          const SizedBox(height: 12),
          const Text('No short videos yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          const Text(
            'Publish a public MP4 or WebM clip to start the feed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          if (_hasMore) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Load more')),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPage(int index) {
    final item = _items[index];
    final player = _players[index];
    final playerError = _playerErrors[index];
    final initialized = player?.value.isInitialized == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _togglePlayback(index),
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: playerError != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white70, size: 42),
                      const SizedBox(height: 8),
                      const Text('This video could not be played.', style: TextStyle(color: Colors.white)),
                      TextButton(onPressed: () => _retryPlayer(index), child: const Text('Retry')),
                    ],
                  )
                : initialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: player!.value.size.width,
                          height: player.value.size.height,
                          child: VideoPlayer(player),
                        ),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        if (initialized && !player!.value.isPlaying)
          const Center(
            child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 76),
          ),
        Positioned(
          top: 8,
          left: 14,
          right: 14,
          child: Row(
            children: [
              const Text('SHORTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
              const Spacer(),
              _FeedChoice(
                label: 'For you',
                selected: !_followingOnly,
                onTap: () => _selectFeed(false),
              ),
              const SizedBox(width: 8),
              _FeedChoice(
                label: 'Following',
                selected: _followingOnly,
                onTap: () => _selectFeed(true),
              ),
              IconButton(
                tooltip: 'Refresh videos',
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 92,
          bottom: 28,
          child: _VideoCaption(
            item: item,
            onFollow: item.isFollowing ? null : () => _toggleFollow(item),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShortAction(
                icon: Icons.favorite_rounded,
                active: item.post['is_liked'] == true,
                count: item.likes,
                tooltip: 'Like',
                busy: _busyActions.contains('${item.postId}:like'),
                onTap: () => _toggleLike(item),
              ),
              const SizedBox(height: 14),
              _ShortAction(
                icon: Icons.mode_comment_rounded,
                count: item.replies,
                tooltip: 'Comments',
                onTap: () => _openPost(item),
              ),
              const SizedBox(height: 14),
              _ShortAction(
                icon: Icons.repeat_rounded,
                active: item.post['is_reposted'] == true,
                count: item.reposts,
                tooltip: 'Repost',
                busy: _busyActions.contains('${item.postId}:repost'),
                onTap: () => _toggleRepost(item),
              ),
              const SizedBox(height: 14),
              _ShortAction(
                icon: Icons.bookmark_rounded,
                active: item.post['is_bookmarked'] == true,
                tooltip: 'Save',
                busy: _busyActions.contains('${item.postId}:bookmark'),
                onTap: () => _toggleBookmark(item),
              ),
              const SizedBox(height: 14),
              _ShortAction(
                icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                tooltip: _muted ? 'Unmute' : 'Mute',
                onTap: _toggleMute,
              ),
            ],
          ),
        ),
        if (initialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              player!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 5),
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
      ],
    );
  }

  void _selectFeed(bool following) {
    if (_followingOnly == following || _loading) return;
    setState(() => _followingOnly = following);
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _items.isEmpty
            ? _emptyState()
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _items.length + (_hasMore ? 1 : 0),
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return _buildVideoPage(index);
                },
              ),
    );
  }
}

class _FeedChoice extends StatelessWidget {
  const _FeedChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: .2) : Colors.black26,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.white70 : Colors.white24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      );
}

class _VideoCaption extends StatelessWidget {
  const _VideoCaption({required this.item, this.onFollow});

  final ShortsFeedItem item;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (item.avatarUrl.isNotEmpty)
                CircleAvatar(radius: 15, backgroundImage: NetworkImage(item.avatarUrl))
              else
                const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 17)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '@${item.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              if (onFollow != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onFollow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('Follow', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.caption,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.25),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.music_note_rounded, color: Colors.white70, size: 14),
              SizedBox(width: 4),
              Text('Original sound', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      );
}

class _ShortAction extends StatelessWidget {
  const _ShortAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.count,
    this.active = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int? count;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tooltip,
            onPressed: busy ? null : onTap,
            icon: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(icon, color: active ? Colors.pinkAccent : Colors.white, size: 30),
          ),
          if (count != null)
            Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
        ],
      );
}
