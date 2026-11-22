import 'dart:math';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/backend_api.dart';
import '../../core/media/media_upload_policy.dart';
import '../shorts/shorts_screen.dart';
import '../posts/post_detail_screen.dart';
import 'feed_media_url.dart';
import 'feed_request_policy.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.api, required this.onSignOut});
  final BackendApi api;
  final Future<void> Function() onSignOut;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  final Set<String> _busy = {};
  bool _loading = false, _hasMore = true, _publishing = false;
  String _feedMode = 'for_you';
  int _loadGeneration = 0;
  int _activeLoads = 0;
  String? _cursor, _error, _rankingMode;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && !_loading && _hasMore && _scroll.position.extentAfter < 650) {
      _load();
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final value = payload['data'];
    return value is Map ? Map<String, dynamic>.from(value) : payload;
  }

  Future<void> _load({bool reset = false}) async {
    if (!FeedRequestPolicy.shouldStart(
      loading: _loading,
      hasMore: _hasMore,
      reset: reset,
    )) {
      return;
    }
    final generation = reset
        ? FeedRequestPolicy.nextGeneration(_loadGeneration)
        : _loadGeneration;
    _loadGeneration = generation;
    final requestedFeed = _feedMode;
    final pageCursor = reset ? null : _cursor;
    setState(() {
      _activeLoads++;
      _loading = true;
      _error = null;
      if (reset) {
        _posts.clear();
        _cursor = null;
        _rankingMode = null;
        _hasMore = true;
      }
    });
    try {
      final payload = await widget.api.getHomeFeed(
        limit: 20,
        cursor: pageCursor,
        feed: requestedFeed,
        followingOnly: requestedFeed == 'following',
      );
      final data = _data(payload);
      final raw = data['posts'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final summaries = await Future.wait(rows.map((post) async {
        final id = (post['id'] ?? '').toString();
        final origin = (post['origin'] ?? 'local').toString().toLowerCase();
        final isRemote = origin.isNotEmpty && origin != 'local';
        // Remote object URIs and AT URIs are not native UUID post IDs.
        // Never send them to native interaction-summary endpoints.
        if (id.isEmpty || isRemote) return <String, dynamic>{};
        try {
          return _data(await widget.api.getPostInteractionSummary(id));
        } catch (_) {
          return <String, dynamic>{};
        }
      }));
      for (var i = 0; i < rows.length; i++) {
        final summary = summaries[i];
        rows[i]['is_liked'] = summary['is_liked'] == true;
        rows[i]['is_reposted'] = summary['is_reposted'] == true;
        rows[i]['is_bookmarked'] = summary['is_bookmarked'] == true;
        rows[i]['likes_count'] = summary['likes'] ?? rows[i]['likes_count'];
        rows[i]['replies_count'] = summary['replies'] ?? rows[i]['replies_count'];
        rows[i]['reposts_count'] = summary['reposts'] ?? rows[i]['reposts_count'];
      }
      if (!mounted ||
          !FeedRequestPolicy.isCurrent(
            requestGeneration: generation,
            currentGeneration: _loadGeneration,
          ) ||
          requestedFeed != _feedMode) {
        return;
      }
      setState(() {
        final ids = _posts.map((p) => (p['id'] ?? '').toString()).toSet();
        _posts.addAll(
          rows.where((p) => !ids.contains((p['id'] ?? '').toString())),
        );
        _cursor = (data['next_cursor'] ?? '').toString();
        final rankingMode = (data['ranking_mode'] ?? '').toString();
        _rankingMode = rankingMode == 'algorithm' || rankingMode == 'chronological'
            ? rankingMode
            : null;
        _hasMore = data['has_more'] == true && (_cursor?.isNotEmpty ?? false);
      });
    } catch (e) {
      if (mounted &&
          FeedRequestPolicy.isCurrent(
            requestGeneration: generation,
            currentGeneration: _loadGeneration,
          )) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeLoads--;
          _loading = _activeLoads > 0;
        });
      }
    }
  }

  Future<void> _action(Map<String, dynamic> post, String kind) async {
    final id = (post['id'] ?? '').toString();
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      if (kind == 'like') {
        if (post['is_liked'] == true) { await widget.api.removePostReaction(id); }
        else { await widget.api.reactToPost(id); }
      } else if (kind == 'repost') {
        if (post['is_reposted'] == true) { await widget.api.removePostRepost(id); }
        else { await widget.api.repostPost(id); }
      } else if (kind == 'bookmark') {
        if (post['is_bookmarked'] == true) { await widget.api.removePostBookmark(id); }
        else { await widget.api.bookmarkPost(id); }
      }
      final summary = _data(await widget.api.getPostInteractionSummary(id));
      if (!mounted) return;
      setState(() {
        post['is_liked'] = summary['is_liked'] == true;
        post['is_reposted'] = summary['is_reposted'] == true;
        post['is_bookmarked'] = summary['is_bookmarked'] == true;
        post['likes_count'] = summary['likes'] ?? post['likes_count'];
        post['replies_count'] = summary['replies'] ?? post['replies_count'];
        post['reposts_count'] = summary['reposts'] ?? post['reposts_count'];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _quotePost(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString();
    if (id.isEmpty || _busy.contains(id)) return;
    final quote = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _QuotePostComposer(post: post),
    );
    if (!mounted || quote == null || quote.trim().isEmpty) return;

    setState(() => _busy.add(id));
    try {
      await widget.api.repostPost(id, quote: quote.trim());
      final summary = _data(await widget.api.getPostInteractionSummary(id));
      if (!mounted) return;
      setState(() {
        post['is_reposted'] = summary['is_reposted'] == true;
        post['reposts_count'] = summary['reposts'] ?? post['reposts_count'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your quote was published.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish quote: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _replies(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString();
    final controller = TextEditingController();
    var loading = true, sending = false;
    String? error;
    List<Map<String, dynamic>> replies = [];
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> load() async {
          setSheet(() { loading = true; error = null; });
          try {
            final data = _data(await widget.api.listPostReplies(id));
            final list = data['items'];
            replies = list is List ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
          } catch (e) { error = e.toString(); }
          setSheet(() => loading = false);
        }
        Future<void> send() async {
          final value = controller.text.trim();
          if (value.isEmpty || sending) return;
          setSheet(() => sending = true);
          try {
            await widget.api.createPostReply(id, value);
            controller.clear();
            await load();
          } catch (e) { setSheet(() => error = e.toString()); }
          setSheet(() => sending = false);
        }
        if (loading && replies.isEmpty && error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => load());
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Replies', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null && replies.isEmpty
                  ? Center(child: Text(error!))
                  : replies.isEmpty
                    ? const Center(child: Text('No replies yet. Start the conversation.'))
                    : ListView.builder(
                        itemCount: replies.length,
                        itemBuilder: (_, i) {
                          final row = replies[i];
                          final profile = row['user_profiles'];
                          final name = profile is Map ? (profile['display_name'] ?? profile['username'] ?? 'Testagram user') : 'Testagram user';
                          return ListTile(title: Text(name.toString()), subtitle: Text((row['content'] ?? '').toString()));
                        })),
              if (error != null && replies.isNotEmpty) Text(error!),
              Row(children: [
                Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Write a reply'))),
                IconButton.filled(onPressed: sending ? null : send, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
              ]),
            ]),
          ),
        );
      }),
    );
    controller.dispose();
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return 'post-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
  }

  Future<void> _composePost() async {
    final draft = await showModalBottomSheet<_PostDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _PostComposerSheet(),
    );
    if (!mounted || draft == null || _publishing) return;

    final uploadedKeys = <String>[];
    final attachedKeys = <String>{};
    var postId = '';
    setState(() => _publishing = true);
    try {
      final created = _data(await widget.api.createPost(
        content: draft.content,
        visibility: draft.visibility,
        idempotencyKey: _newIdempotencyKey(),
      ));
      postId = (created['id'] ?? '').toString();
      if (postId.isEmpty) {
        throw const BackendApiException('The server did not confirm the new post ID.');
      }

      for (final media in draft.media) {
        final asset = media.contentType.startsWith('video/')
            ? await widget.api.uploadPublicVideo(
                name: media.name,
                contentType: media.contentType,
                bytes: media.bytes,
              )
            : await widget.api.uploadPublicImage(
                name: media.name,
                contentType: media.contentType,
                bytes: media.bytes,
              );
        final key = (asset['key'] ?? '').toString();
        if (key.isEmpty) {
          throw const BackendApiException('The server did not confirm an uploaded image key.');
        }
        uploadedKeys.add(key);
        await widget.api.attachPostMedia(postId, key);
        attachedKeys.add(key);
      }

      if (!mounted) return;
      await _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(draft.media.isEmpty
              ? 'Your post was published.'
              : draft.media.any((media) => media.contentType.startsWith('video/'))
                  ? 'Your post and video were published.'
                  : 'Your post and ${attachedKeys.length} photo(s) were published.')),
        );
      }
    } catch (error) {
      for (final key in uploadedKeys.where((key) => !attachedKeys.contains(key))) {
        try {
          await widget.api.deleteMedia(key);
        } catch (_) {
          // The Backend's media janitor remains responsible for expired/orphaned assets.
        }
      }
      if (mounted) {
        final message = postId.isEmpty
            ? 'Post was not confirmed: $error'
            : 'Post published, but some photos could not be attached. The text post is safe: $error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        if (postId.isNotEmpty) await _load(reset: true);
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Icon(Icons.forum_rounded, color: Theme.of(context).colorScheme.primary, size: 25),
          const SizedBox(width: 9),
          const Text('T social'),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh timeline',
        ),
        IconButton(
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Sign out',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(onPressed: _publishing ? null : _composePost, tooltip: 'Compose post', child: _publishing ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit)),
    body: Column(children: [
      SizedBox(
        height: 54,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final lane in const [
                ('for_you', 'For you'),
                ('following', 'Following'),
                ('latest', 'Latest'),
                ('media', 'Media'),
                ('discover', 'Discover'),
              ])
                SizedBox(
                  width: 92,
                  child: _FeedTab(
                    label: lane.$2,
                    selected: _feedMode == lane.$1,
                    onTap: () => _selectFeed(lane.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
      _FeedOrderingStatus(
        feedMode: _feedMode,
        rankingMode: _rankingMode,
        loading: _loading,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: InkWell(
          onTap: _publishing ? null : _composePost,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text("What's happening?", style: TextStyle(fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Post',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(child: LayoutBuilder(
        builder: (context, constraints) {
          final timeline = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _loading && _posts.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
          : _error != null && _posts.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 100), Center(child: Text(_error!)), Center(child: TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')))])
            : _posts.isEmpty
              ? ListView(children: const [SizedBox(height: 120), Center(child: Icon(Icons.dynamic_feed_outlined, size: 48)), SizedBox(height: 12), Center(child: Text('No posts are available yet.'))])
              : ListView.separated(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _posts.length + (_loading || _hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == _posts.length) {
                      return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: _loading ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: const Text('Load more'))),
                      );
                    }
                    final post = _posts[index];
                    final id = (post['id'] ?? '').toString();
                    final rawContentTypes = post['media_content_types'];
                    final isVideoPost = post['is_video'] == true ||
                        (rawContentTypes is List && rawContentTypes.any(
                          (type) => type.toString().toLowerCase().startsWith('video/'),
                        ));
                    return _PostCard(
                      post: post,
                      busy: _busy.contains(id),
                      onOpen: id.isEmpty ? null : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PostDetailScreen(api: widget.api, postId: id),
                        ),
                      ),
                      onOpenVideo: id.isEmpty || !isVideoPost
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ShortsScreen(
                                    api: widget.api,
                                    initialPost: Map<String, dynamic>.from(post),
                                  ),
                                ),
                              ),
                      onLike: () => _action(post, 'like'),
                      onRepost: () => _action(post, 'repost'),
                      onQuote: () => _quotePost(post),
                      onBookmark: () => _action(post, 'bookmark'),
                      onReplies: () => _replies(post),
                    );
                  },
                ),
          );
          if (constraints.maxWidth < 1040) return timeline;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: timeline,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 292,
                child: _ConversationSidebar(posts: _posts),
              ),
            ],
          );
        },
      )),
    ]),
  );

  void _selectFeed(String feedMode) {
    const allowed = {'for_you', 'following', 'latest', 'media', 'discover'};
    if (!allowed.contains(feedMode) || _feedMode == feedMode) return;
    setState(() => _feedMode = feedMode);
    _load(reset: true);
  }
}

class _FeedOrderingStatus extends StatelessWidget {
  const _FeedOrderingStatus({
    required this.feedMode,
    required this.rankingMode,
    required this.loading,
  });

  final String feedMode;
  final String? rankingMode;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    final String detail;
    if (feedMode == 'latest') {
      label = 'Latest';
      detail = 'Posts in chronological order';
      icon = Icons.schedule_rounded;
    } else if (rankingMode == 'algorithm') {
      label = 'Ranked for you';
      detail = 'Ordering supplied by Testagram recommendations';
      icon = Icons.auto_awesome_rounded;
    } else if (rankingMode == 'chronological') {
      label = 'Chronological';
      detail = feedMode == 'following'
          ? 'Recent posts from accounts you follow'
          : 'Recommendations unavailable; showing recent posts';
      icon = Icons.schedule_rounded;
    } else {
      label = loading ? 'Updating timeline' : 'Ordering unavailable';
      detail = 'The Backend has not reported the ordering mode';
      icon = loading ? Icons.sync_rounded : Icons.info_outline_rounded;
    }

    return Semantics(
      label: '$label. $detail',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConversationSidebar extends StatelessWidget {
  const _ConversationSidebar({required this.posts});

  final List<Map<String, dynamic>> posts;

  @override
  Widget build(BuildContext context) {
    final topics = <String, int>{};
    final matcher = RegExp(r'#[A-Za-z0-9_]{2,30}');
    for (final post in posts) {
      final content = (post['content'] ?? '').toString();
      for (final match in matcher.allMatches(content)) {
        final topic = match.group(0)!.toLowerCase();
        topics[topic] = (topics[topic] ?? 0) + 1;
      }
    }
    final ranked = topics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("What's happening", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Topics appearing in your timeline', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            if (ranked.isEmpty)
              Text('Hashtags from posts will appear here as conversations grow.', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final topic in ranked.take(6)) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trending in your feed', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(topic.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text('${topic.value} ${topic.value == 1 ? 'post' : 'posts'}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _PostDraft {
  const _PostDraft({
    required this.content,
    required this.visibility,
    required this.media,
  });

  final String content;
  final String visibility;
  final List<_PostMediaDraft> media;
}

class _PostComposerSheet extends StatefulWidget {
  const _PostComposerSheet();

  @override
  State<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<_PostComposerSheet> {
  final _controller = TextEditingController();
  final _media = <_PostMediaDraft>[];
  String _visibility = 'public';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_media.any((media) => media.contentType.startsWith('video/'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A post can contain either one video or up to four photos.')),
      );
      return;
    }
    if (_media.length >= 4) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!mounted || picked == null) return;
      final extension = picked.name.toLowerCase().split('.').last;
      const types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'gif': 'image/gif',
        'avif': 'image/avif',
      };
      final contentType = types[extension];
      if (contentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPEG, PNG, WebP, GIF or AVIF image.')),
        );
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > MediaUploadPolicy.imageMaxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each image must be 20 MiB or smaller.')),
        );
        return;
      }
      setState(() => _media.add(_PostMediaDraft(
        name: picked.name,
        contentType: contentType,
        bytes: bytes,
      )));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select image: $error')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_media.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A post can contain either one video or up to four photos.')),
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (!mounted || picked == null) return;
      final extension = MediaUploadPolicy.normalizeExtension(picked.name, isVideo: true);
      final contentType = MediaUploadPolicy.contentType(extension);
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      MediaUploadPolicy.validateSize(bytes.length, isVideo: true);
      setState(() => _media.add(_PostMediaDraft(
        name: picked.name,
        contentType: contentType,
        bytes: bytes,
      )));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select video: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.text.runes.length;
    final hasVideo = _media.any((media) => media.contentType.startsWith('video/'));
    final canPublish = count > 0 &&
        count <= 5000 &&
        _media.length <= 4 &&
        (!hasVideo || _media.length == 1) &&
        (_visibility == 'public' || _media.isEmpty);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18, 8, 18, MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text('Create a post', style: Theme.of(context).textTheme.titleLarge)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 9,
              maxLength: 5000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'What is happening? Use #hashtags and @mentions.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < _media.length; index++)
                    SizedBox(
                      width: 104,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _media[index].contentType.startsWith('video/')
                                ? Container(
                                    width: 104,
                                    height: 104,
                                    color: Colors.black87,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 38),
                                  )
                                : Image.memory(
                                    _media[index].bytes,
                                    width: 104,
                                    height: 104,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: IconButton.filledTonal(
                              tooltip: _media[index].contentType.startsWith('video/') ? 'Remove video' : 'Remove image',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _media.removeAt(index)),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _media.length >= 4 || hasVideo ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('Add photo (${_media.where((media) => media.contentType.startsWith('image/')).length}/4)'),
                ),
                TextButton.icon(
                  onPressed: _media.isNotEmpty ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text('Add video (${hasVideo ? 1 : 0}/1)'),
                ),
              ],
            ),
            if (_media.isNotEmpty && _visibility != 'public') ...[
              const SizedBox(height: 8),
              const Text(
                'Media attachments are currently available on public posts only. Remove media to publish to followers or privately.',
                style: TextStyle(color: Colors.orange),
              ),
            ],
            const SizedBox(height: 8),
            Text('Who can see this post?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('Everyone'), icon: Icon(Icons.public)),
                ButtonSegment(value: 'followers', label: Text('Followers'), icon: Icon(Icons.people_outline)),
                ButtonSegment(value: 'private', label: Text('Only me'), icon: Icon(Icons.lock_outline)),
              ],
              selected: {_visibility},
              onSelectionChanged: (value) => setState(() => _visibility = value.first),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text('$count / 5000', style: Theme.of(context).textTheme.bodySmall)),
              FilledButton.icon(
                onPressed: canPublish ? () => Navigator.pop(context, _PostDraft(
                  content: _controller.text.trim(),
                  visibility: _visibility,
                  media: List<_PostMediaDraft>.from(_media),
                )) : null,
                icon: const Icon(Icons.send),
                label: const Text('Publish'),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Public posts can be delivered to federated servers when federation is enabled for your account.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostMediaDraft {
  const _PostMediaDraft({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final Uint8List bytes;
}

class _QuotePostComposer extends StatefulWidget {
  const _QuotePostComposer({required this.post});

  final Map<String, dynamic> post;

  @override
  State<_QuotePostComposer> createState() => _QuotePostComposerState();
}

class _QuotePostComposerState extends State<_QuotePostComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keyboard insets can exceed the test viewport (and occasionally
    // transient webview viewport bounds). Cap them and allow compact layouts
    // to scroll instead of overflowing the modal sheet.
    final keyboardInset =
        media.viewInsets.bottom.clamp(0.0, media.size.height * 0.6);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 8, 18, keyboardInset + 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Quote post', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                (widget.post['content'] ?? '').toString(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 7,
                maxLength: 5000,
                decoration: const InputDecoration(
                  hintText: 'Add your perspective…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_controller.text.trim()),
                  icon: const Icon(Icons.repeat_rounded),
                  label: const Text('Publish quote'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.busy,
    required this.onLike,
    required this.onRepost,
    required this.onQuote,
    required this.onBookmark,
    required this.onReplies,
    this.onOpen,
    this.onOpenVideo,
  });

  final Map<String, dynamic> post;
  final bool busy;
  final VoidCallback onLike, onRepost, onQuote, onBookmark, onReplies;
  final VoidCallback? onOpen, onOpenVideo;

  String _timeLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final author = post['author'];
    final origin = (post['origin'] ?? 'local').toString().toLowerCase();
    final isRemote = origin.isNotEmpty && origin != 'local';
    final sourceLabel = switch (origin) {
      'activitypub' => 'Fediverse',
      'atproto' || 'bluesky' => 'Bluesky',
      'local' => null,
      _ => 'Federated',
    };
    final rawCapabilities = post['capabilities'];
    final capabilities = rawCapabilities is Map ? rawCapabilities : const <String, dynamic>{};
    final canLike = !isRemote || capabilities['like'] == true;
    final canReply = !isRemote || capabilities['reply'] == true;
    final canRepost = !isRemote || capabilities['repost'] == true;
    final canQuote = !isRemote || capabilities['quote'] == true;
    final name = author is Map
        ? (author['display_name'] ?? author['username'] ?? 'Testagram user').toString()
        : 'Testagram user';
    final username = author is Map ? (author['username'] ?? '').toString() : '';
    final avatarUrl = author is Map ? (FeedMediaUrl.normalize(author['avatar_url']) ?? '') : '';
    final body = (post['content'] ?? '').toString();
    final created = _timeLabel((post['created_at'] ?? '').toString());
    final rawMedia = post['media_urls'];
    final mediaUrls = rawMedia is List
        ? rawMedia.map(FeedMediaUrl.normalize).whereType<String>().take(4).toList()
        : <String>[];
    final rawContentTypes = post['media_content_types'];
    final contentTypes = rawContentTypes is List
        ? rawContentTypes.map((value) => value.toString().toLowerCase()).toList()
        : <String>[];
    final isVideoPost = post['is_video'] == true || contentTypes.any((type) => type.startsWith('video/'));
    final rawMediaAuthHeaders = post['media_auth_headers'];
    final mediaAuthHeaders = <String, String>{};
    if (rawMediaAuthHeaders is Map) {
      for (final entry in rawMediaAuthHeaders.entries) {
        final url = FeedMediaUrl.normalize(entry.key);
        final authorization = entry.value.toString();
        if (url != null && url.startsWith('https://') && authorization.startsWith('Bearer v1.')) {
          mediaAuthHeaders[url] = authorization;
        }
      }
    }
    Map<String, String>? headersForMedia(String url) {
      final authorization = mediaAuthHeaders[url];
      return authorization == null ? null : {'Authorization': authorization};
    }
    if (mediaUrls.isEmpty) {
      final legacyUrl = FeedMediaUrl.normalize(post['media_url']);
      if (legacyUrl != null && !mediaUrls.contains(legacyUrl)) mediaUrls.add(legacyUrl);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
              backgroundImage: avatarUrl.startsWith('http') ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.startsWith('http')
                  ? null
                  : Text(
                      name.isEmpty ? 'T' : name[0].toUpperCase(),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2), overflow: TextOverflow.ellipsis)),
                      if (author is Map && (author['is_verified'] == true || author['verified'] == true))
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Tooltip(
                            message: 'Verified account',
                            child: Icon(Icons.verified_rounded, size: 15, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Flexible(child: Text('@$username', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor), overflow: TextOverflow.ellipsis)),
                      ],
                      if (created.isNotEmpty) Text(' · $created', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                      if (sourceLabel != null) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: switch (origin) {
                            'activitypub' => 'Remote content delivered through ActivityPub / Fediverse',
                            'atproto' || 'bluesky' => 'Remote content delivered through AT Protocol / Bluesky',
                            _ => 'Remote content delivered through a federated network',
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded, size: 13, color: Theme.of(context).colorScheme.secondary),
                              const SizedBox(width: 3),
                              Text(
                                'via $sourceLabel',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'Post actions',
                        icon: Icon(Icons.more_horiz_rounded, size: 19, color: Theme.of(context).hintColor),
                        onSelected: (action) {
                          if (action == 'quote') onQuote();
                          if (action == 'open') onOpen?.call();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'quote',
                            enabled: canQuote,
                            child: const ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.format_quote_rounded),
                              title: Text('Quote post'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'open',
                            enabled: onOpen != null,
                            child: const ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.open_in_new_rounded),
                              title: Text('Open post'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    InkWell(
                      onTap: onOpen,
                      child: Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.42)),
                    ),
                  ],
                  if (isVideoPost && mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    InkWell(
                      onTap: onOpenVideo ?? onOpen,
                      borderRadius: BorderRadius.circular(18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            color: Colors.black,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 58),
                                SizedBox(height: 7),
                                Text('Watch in Shorts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    if (mediaUrls.length == 1)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(mediaUrls.first, width: double.infinity, height: 250, fit: BoxFit.cover, headers: headersForMedia(mediaUrls.first), errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tileWidth = (constraints.maxWidth - 6) / 2;
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: mediaUrls.map((url) => SizedBox(
                              width: tileWidth,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  url,
                                  height: 146,
                                  fit: BoxFit.cover,
                                  headers: headersForMedia(url),
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            )).toList(),
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (canReply)
                        _Action(icon: Icons.mode_comment_outlined, label: (post['replies_count'] ?? 0).toString(), onTap: onReplies),
                      if (canRepost)
                        _Action(icon: post['is_reposted'] == true ? Icons.repeat_on_rounded : Icons.repeat_rounded, label: (post['reposts_count'] ?? 0).toString(), active: post['is_reposted'] == true, onTap: busy ? null : onRepost),
                      if (canLike)
                        _Action(icon: post['is_liked'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: (post['likes_count'] ?? 0).toString(), active: post['is_liked'] == true, onTap: busy ? null : onLike),
                      if (!isRemote)
                        _Action(icon: post['is_bookmarked'] == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: '', active: post['is_bookmarked'] == true, onTap: busy ? null : onBookmark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}
class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            )),
          ],
        ],
      ),
    ),
  );
}
