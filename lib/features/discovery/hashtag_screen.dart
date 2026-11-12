import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../posts/post_detail_screen.dart';

class HashtagScreen extends StatefulWidget {
  const HashtagScreen({super.key, required this.api, required this.tag});

  final BackendApi api;
  final String tag;

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _isFollowing = false;
  bool _followBusy = false;
  int _generation = 0;
  String? _cursor;
  String? _error;

  String get _tag => widget.tag.replaceFirst(RegExp(r'^#'), '');

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final raw = payload['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : payload;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && !_loading && _hasMore &&
        _scroll.position.extentAfter < 600) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final generation = reset ? ++_generation : _generation;
    final pageCursor = reset ? null : _cursor;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _posts.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final data = _data(await widget.api.getHashtagTimeline(
        _tag,
        limit: 20,
        cursor: pageCursor,
      ));
      final raw = data['posts'];
      final rows = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted || generation != _generation) return;
      setState(() {
        _isFollowing = data['is_following'] == true;
        final existing = _posts.map((post) => (post['id'] ?? '').toString()).toSet();
        _posts.addAll(rows.where((post) => !existing.contains((post['id'] ?? '').toString())));
        _cursor = (data['next_cursor'] ?? '').toString();
        _hasMore = data['has_more'] == true && (_cursor?.isNotEmpty ?? false);
      });
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

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    setState(() => _followBusy = true);
    try {
      final response = _data(_isFollowing
          ? await widget.api.unfollowHashtag(_tag)
          : await widget.api.followHashtag(_tag));
      if (!mounted) return;
      setState(() => _isFollowing = response['is_following'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing
            ? 'Following #$_tag. Your Explore topics will reflect this interest.'
            : 'Unfollowed #$_tag.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update hashtag follow: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Widget _postCard(Map<String, dynamic> post) {
    final author = post['author'];
    final name = author is Map
        ? (author['display_name'] ?? author['username'] ?? 'Testagram user').toString()
        : 'Testagram user';
    final username = author is Map ? (author['username'] ?? '').toString() : '';
    final avatar = author is Map ? (author['avatar_url'] ?? '').toString() : '';
    final id = (post['id'] ?? '').toString();
    final content = (post['content'] ?? '').toString();
    final rawMedia = post['media_urls'];
    final mediaUrls = rawMedia is List
        ? rawMedia.map((value) => value.toString()).where((value) => value.startsWith('http')).take(4).toList()
        : <String>[];

    return InkWell(
      onTap: id.isEmpty ? null : () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(api: widget.api, postId: id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: avatar.startsWith('https://') || avatar.startsWith('http://')
                  ? NetworkImage(avatar)
                  : null,
              child: avatar.startsWith('https://') || avatar.startsWith('http://')
                  ? null
                  : Text(name.isEmpty ? 'T' : name[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (username.isNotEmpty)
                    Text('@$username', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(content, style: const TextStyle(height: 1.4)),
                  if (mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (mediaUrls.length == 1)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          mediaUrls.first,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: mediaUrls.map((url) => SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 96) / 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        )).toList(),
                      ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${post['likes_count'] ?? 0} likes  ·  ${post['replies_count'] ?? 0} replies',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('#$_tag'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _followBusy ? null : _toggleFollow,
            icon: Icon(_isFollowing ? Icons.check : Icons.add),
            label: Text(_followBusy ? 'Saving' : _isFollowing ? 'Following' : 'Follow'),
          ),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _loading && _posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : _error != null && _posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text(_error!)),
                    Center(
                      child: TextButton(
                        onPressed: () => _load(reset: true),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                )
              : _posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        const Center(child: Icon(Icons.tag, size: 48)),
                        const SizedBox(height: 12),
                        Center(child: Text('No public posts for #$_tag yet.')),
                      ],
                    )
                  : ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _posts.length + (_loading || _hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == _posts.length) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : TextButton(
                                      onPressed: _load,
                                      child: const Text('Load more'),
                                    ),
                            ),
                          );
                        }
                        return _postCard(_posts[index]);
                      },
                    ),
    ),
  );
}
