import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.api, required this.onSignOut});
  final BackendApi api;
  final Future<void> Function() onSignOut;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await widget.api.getHomeFeed();
      final envelope = payload['data'];
      final data = envelope is Map ? Map<String, dynamic>.from(envelope) : payload;
      final raw = data['posts'] ?? data['items'] ?? [];
      final rows = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _posts = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose() async {
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a post'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: 5000,
          decoration: const InputDecoration(hintText: 'What is happening?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Publish')),
        ],
      ),
    );
    controller.dispose();
    if (content == null || content.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await widget.api.createPost(
        content: content,
        idempotencyKey: 'flutter-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Testagram', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(onPressed: _load, tooltip: 'Refresh feed', icon: const Icon(Icons.refresh)),
            IconButton(onPressed: widget.onSignOut, tooltip: 'Sign out', icon: const Icon(Icons.logout)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _posting ? null : _compose,
          child: _posting ? const CircularProgressIndicator() : const Icon(Icons.edit),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading && _posts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _posts.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 120),
                      Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)),
                      Center(child: TextButton(onPressed: _load, child: const Text('Try again'))),
                    ])
                  : _posts.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 130),
                          Icon(Icons.dynamic_feed_outlined, size: 48, color: Colors.white54),
                          SizedBox(height: 12),
                          Center(child: Text('Your feed is ready for its first post.')),
                        ])
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF26332B)),
                          itemBuilder: (context, index) => _PostCard(post: _posts[index]),
                        ),
        ),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final author = post['author'] is Map ? Map<String, dynamic>.from(post['author'] as Map) : <String, dynamic>{};
    final name = (author['display_name'] ?? author['name'] ?? author['handle'] ?? 'Testagram user').toString();
    final body = (post['body'] ?? post['content'] ?? '').toString();
    final created = (post['created_at'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: const Color(0xFF174A2D), child: Text(name.isEmpty ? 'T' : name[0].toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                if (created.isNotEmpty) Text('  ·  ${created.length > 10 ? created.substring(0, 10) : created}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
              const SizedBox(height: 7),
              Text(body, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              Row(children: [
                _Count(icon: Icons.favorite_border, value: post['likes_count']),
                const SizedBox(width: 28),
                _Count(icon: Icons.mode_comment_outlined, value: post['replies_count'] ?? post['comments_count']),
                const SizedBox(width: 28),
                _Count(icon: Icons.repeat, value: post['reposts_count']),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value});
  final IconData icon;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: Colors.white60),
        const SizedBox(width: 5),
        Text('${value ?? 0}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ]);
}
