import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../posts/post_detail_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  String? _cursor;
  bool _loading = true;
  bool _hasMore = false;
  String? _error;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _posts = [];
        _cursor = null;
        _hasMore = false;
      }
    });
    final previousCursor = reset ? null : _cursor;
    try {
      final response = await widget.api.getBookmarkedPosts(
        limit: 20,
        cursor: reset ? null : _cursor,
      );
      final raw = response['data'];
      final data = raw is Map ? Map<String, dynamic>.from(raw) : response;
      final rows = data['posts'];
      final page = rows is List
          ? rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      final seen = _posts.map((post) => (post['id'] ?? '').toString()).toSet();
      setState(() {
        _posts.addAll(page.where((post) {
          final id = (post['id'] ?? '').toString();
          return id.isNotEmpty && seen.add(id);
        }));
        _cursor = (data['next_cursor'] ?? '').toString();
        _hasMore = data['has_more'] == true &&
            _cursor!.isNotEmpty && _cursor != previousCursor;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _remove(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString();
    if (id.isEmpty || !_removing.add(id)) return;
    setState(() {});
    try {
      await widget.api.removePostBookmark(id);
      if (mounted) setState(() => _posts.removeWhere((item) => item['id'] == id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove saved post: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _error != null && _posts.isEmpty
            ? ListView(children: [
                const SizedBox(height: 90),
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                Center(child: Text(_error!)),
                Center(child: TextButton(
                  onPressed: () => _load(reset: true),
                  child: const Text('Try again'),
                )),
              ])
            : _posts.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 100),
                        Icon(Icons.bookmark_border_rounded, size: 48),
                        SizedBox(height: 12),
                        Center(child: Text('Your saved posts will appear here.')),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _posts.length + (_hasMore || _loading || _error != null ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= _posts.length) {
                            if (_error != null) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: TextButton(
                                  onPressed: _loading ? null : () => _load(),
                                  child: const Text('Could not load more saved posts. Retry'),
                                )),
                              );
                            }
                            if (_hasMore && !_loading) {
                              WidgetsBinding.instance.addPostFrameCallback((_) => _load());
                            }
                            return const Padding(
                              padding: EdgeInsets.all(18),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final post = _posts[index];
                          final author = post['author'] is Map
                              ? Map<String, dynamic>.from(post['author'] as Map)
                              : <String, dynamic>{};
                          final name = (author['display_name'] ?? author['username'] ?? 'Testagram member').toString();
                          final username = (author['username'] ?? '').toString();
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundImage: (author['avatar_url'] ?? '').toString().startsWith('http')
                                  ? NetworkImage(author['avatar_url'].toString())
                                  : null,
                              child: (author['avatar_url'] ?? '').toString().startsWith('http')
                                  ? null : const Icon(Icons.person_outline_rounded),
                            ),
                            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (username.isNotEmpty) Text('@$username'),
                                const SizedBox(height: 5),
                                Text((post['content'] ?? '').toString(), maxLines: 4, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove bookmark',
                              onPressed: _removing.contains((post['id'] ?? '').toString())
                                  ? null : () => _remove(post),
                              icon: _removing.contains((post['id'] ?? '').toString())
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.bookmark_remove_outlined),
                            ),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => PostDetailScreen(
                                api: widget.api,
                                postId: (post['id'] ?? '').toString(),
                              ),
                            )),
                          );
                        },
                      ),
      ),
    );
  }
}
