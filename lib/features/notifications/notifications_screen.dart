import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final BackendApi api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final raw = payload['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : payload;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = _data(await widget.api.listNotifications());
      final raw = response['items'];
      if (mounted) setState(() => _items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : []);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty || item['read_at'] != null) return;
    try {
      await widget.api.markNotificationRead(id);
      if (mounted) setState(() => item['read_at'] = DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
          ? ListView(children: [const SizedBox(height: 100), Center(child: Text(_error!)), Center(child: TextButton(onPressed: _load, child: const Text('Retry')))])
          : _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Icon(Icons.notifications_none, size: 48)), SizedBox(height: 12), Center(child: Text('You are all caught up.'))])
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final actor = item['actor'];
                  final actorName = actor is Map ? (actor['display_name'] ?? actor['username'] ?? 'Someone') : 'Testagram';
                  final kind = (item['kind'] ?? 'activity').toString().replaceAll('_', ' ');
                  final unread = item['read_at'] == null;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unread ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: Icon(unread ? Icons.notifications_active_outlined : Icons.notifications_none),
                    ),
                    title: Text(actorName.toString() + ' ' + kind),
                    subtitle: Text((item['created_at'] ?? '').toString()),
                    trailing: unread ? const Icon(Icons.circle, size: 9) : null,
                    onTap: () => _markRead(item),
                  );
                },
              ),
    ),
  );
}
