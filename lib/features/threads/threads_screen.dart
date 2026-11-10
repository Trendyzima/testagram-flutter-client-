import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({super.key, required this.api});
  final BackendApi api;
  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false, _sending = false, _hasMore = true;
  int _loadGeneration = 0;
  int _activeLoads = 0;
  final Set<String> _busyActions = {};
  String? _cursor;
  String _tab = 'for-you';
  String? _error;

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
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && !_loading && _hasMore && _scroll.position.extentAfter < 500) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    final requestedTab = _tab;
    final pageCursor = reset ? null : _cursor;
    setState(() {
      _activeLoads++;
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final data = _data(await widget.api.getThreads(
        limit: 20,
        cursor: pageCursor,
        tab: requestedTab,
      ));
      final raw = data['items'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted && generation == _loadGeneration && requestedTab == _tab) {
        setState(() {
          final ids = _items.map((e) => (e['id'] ?? '').toString()).toSet();
          _items.addAll(rows.where((e) => !ids.contains((e['id'] ?? '').toString())));
          _cursor = (data['next_cursor'] ?? '').toString();
          _hasMore = data['has_more'] == true && _cursor!.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration && requestedTab == _tab) {
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
      await _load(reset: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggle(String id, String kind) async {
    if (id.isEmpty || _busyActions.contains(id)) return;
    setState(() => _busyActions.add(id));
    try {
      if (kind == 'like') await widget.api.toggleThreadLike(id);
      if (kind == 'repost') await widget.api.toggleThreadRepost(id);
      if (kind == 'bookmark') await widget.api.toggleThreadBookmark(id);
      if (mounted) await _load(reset: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyActions.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Threads'), actions: [
      IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
      IconButton(onPressed: _sending ? null : _compose, icon: const Icon(Icons.edit)),
    ]),
    floatingActionButton: FloatingActionButton(onPressed: _sending ? null : _compose, child: const Icon(Icons.add)),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'for-you', label: Text('For you')),
            ButtonSegment(value: 'following', label: Text('Following')),
            ButtonSegment(value: 'saved', label: Text('Saved')),
          ],
          selected: {_tab},
          onSelectionChanged: (value) { setState(() => _tab = value.first); _load(reset: true); },
        ),
      ),
      Expanded(child: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _loading && _items.isEmpty
        ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
        : _error != null && _items.isEmpty
          ? ListView(children: [const SizedBox(height: 100), Center(child: Text(_error!)), Center(child: TextButton(onPressed: _load, child: const Text('Retry')))])
          : _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No public threads yet. Start one.'))])
            : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _items.length) return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: _loading ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: const Text('Load more'))),
                  );
                  final item = _items[index];
                  final profile = item['profiles'];
                  final name = profile is Map
                      ? (profile['display_name'] ?? profile['username'] ?? 'Testagram user').toString()
                      : 'Testagram user';
                  final username = profile is Map ? (profile['username'] ?? '').toString() : '';
                  final avatarUrl = profile is Map ? (profile['avatar_url'] ?? '').toString() : '';
                  final id = (item['id'] ?? '').toString();
                  final actionBusy = _busyActions.contains(id);
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(
                          backgroundImage: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
                          child: avatarUrl.isEmpty ? const Icon(Icons.person_outline) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (username.isNotEmpty)
                              Text('@$username', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        )),
                        Text((item['created_at'] ?? '').toString().split('T').first,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                      const SizedBox(height: 10),
                      Text((item['body'] ?? '').toString()),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        TextButton.icon(onPressed: actionBusy ? null : () => _toggle(id, 'like'), icon: const Icon(Icons.favorite_border), label: Text((item['likes_count'] ?? 0).toString())),
                        TextButton.icon(onPressed: actionBusy ? null : () => _toggle(id, 'repost'), icon: const Icon(Icons.repeat), label: Text((item['reposts_count'] ?? 0).toString())),
                        TextButton.icon(onPressed: actionBusy ? null : () => _toggle(id, 'bookmark'), icon: const Icon(Icons.bookmark_border), label: const Text('Save')),
                      ]),
                    ]),
                  );
                },
              ),
    )),
    ]),
  );
}
