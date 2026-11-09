import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({super.key, required this.api});
  final BackendApi api;
  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true, _sending = false;
  String? _error;

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final raw = payload['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : payload;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = _data(await widget.api.getThreads(limit: 20));
      final raw = data['items'];
      if (mounted) setState(() => _items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : []);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose() async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a thread'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'What is happening?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Publish')),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.createThread(body);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggle(String id, String kind) async {
    try {
      if (kind == 'like') await widget.api.toggleThreadLike(id);
      if (kind == 'repost') await widget.api.toggleThreadRepost(id);
      if (kind == 'bookmark') await widget.api.toggleThreadBookmark(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Threads'), actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      IconButton(onPressed: _sending ? null : _compose, icon: const Icon(Icons.edit)),
    ]),
    floatingActionButton: FloatingActionButton(onPressed: _sending ? null : _compose, child: const Icon(Icons.add)),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
          ? ListView(children: [const SizedBox(height: 100), Center(child: Text(_error!)), Center(child: TextButton(onPressed: _load, child: const Text('Retry')))])
          : _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No public threads yet. Start one.'))])
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final profile = item['profiles'];
                  final name = profile is Map ? (profile['display_name'] ?? profile['username'] ?? 'Testagram user').toString() : 'Testagram user';
                  final id = (item['id'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text((item['created_at'] ?? '').toString().split('T').first, style: Theme.of(context).textTheme.bodySmall),
                      ]),
                      const SizedBox(height: 10),
                      Text((item['body'] ?? '').toString()),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        TextButton.icon(onPressed: () => _toggle(id, 'like'), icon: const Icon(Icons.favorite_border), label: Text((item['likes_count'] ?? 0).toString())),
                        TextButton.icon(onPressed: () => _toggle(id, 'repost'), icon: const Icon(Icons.repeat), label: Text((item['reposts_count'] ?? 0).toString())),
                        TextButton.icon(onPressed: () => _toggle(id, 'bookmark'), icon: const Icon(Icons.bookmark_border), label: const Text('Save')),
                      ]),
                    ]),
                  );
                },
              ),
    ),
  );
}
