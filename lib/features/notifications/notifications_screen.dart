import 'package:flutter/material.dart';

import '../../core/backend_api.dart';
import '../messages/platform_inbox_policy.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final BackendApi api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false, _hasMore = true;
  int _loadGeneration = 0;
  int _activeLoads = 0;
  String? _cursor, _error;
  final Set<String> _marking = {};
  String _filter = 'all';

  List<Map<String, dynamic>> get _visibleItems =>
      _items.where((item) => PlatformInboxPolicy.matchesFilter(item, _filter)).toList();
  int get _unreadCount => PlatformInboxPolicy.unreadCount(_items);

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

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final raw = payload['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : payload;
  }

  void _onScroll() {
    if (_scroll.hasClients && !_loading && _hasMore && _scroll.position.extentAfter < 500) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final generation = reset ? ++_loadGeneration : _loadGeneration;
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
      final data = _data(await widget.api.listNotifications(
        limit: 30,
        cursor: pageCursor,
      ));
      final raw = data['items'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted && generation == _loadGeneration) {
        setState(() {
          final ids = _items.map((e) => (e['id'] ?? '').toString()).toSet();
          _items.addAll(rows.where((e) => !ids.contains((e['id'] ?? '').toString())));
          _cursor = (data['next_cursor'] ?? '').toString();
          _hasMore = _cursor!.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
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

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty || item['read_at'] != null || _marking.contains(id)) return;
    setState(() => _marking.add(id));
    try {
      await widget.api.markNotificationRead(id);
      if (mounted) setState(() => item['read_at'] = DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _marking.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Notifications · $_unreadCount unread'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Filter notifications',
          initialValue: _filter,
          onSelected: (value) => setState(() => _filter = value),
          itemBuilder: (_) => PlatformInboxPolicy.filters.map((value) => PopupMenuItem(
            value: value,
            child: Text(value == 'all' ? 'All notifications' : value[0].toUpperCase() + value.substring(1)),
          )).toList(),
        ),
        IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _loading && _items.isEmpty
        ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
        : _error != null && _items.isEmpty
          ? ListView(children: [const SizedBox(height: 100), Center(child: Text(_error!)), Center(child: TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')))])
          : _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Icon(Icons.notifications_none, size: 48)), SizedBox(height: 12), Center(child: Text('You are all caught up.'))])
            : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _visibleItems.length + (_loading || _hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _visibleItems.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: _loading ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: const Text('Load more'))),
                    );
                  }
                  final item = _visibleItems[index];
                  final actor = item['actor'];
                  final actorName = actor is Map ? (actor['display_name'] ?? actor['username'] ?? 'Someone') : 'Testagram';
                  final kind = (item['kind'] ?? 'activity').toString().replaceAll('_', ' ');
                  final unread = item['read_at'] == null;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unread ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: Icon(unread ? Icons.notifications_active_outlined : Icons.notifications_none),
                    ),
                    title: Text('$actorName $kind'),
                    subtitle: Text((item['created_at'] ?? '').toString()),
                    trailing: unread
                      ? _marking.contains((item['id'] ?? '').toString())
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.circle, size: 9)
                      : null,
                    onTap: () => _markRead(item),
                  );
                },
              ),
    ),
  );
}
