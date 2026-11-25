import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import 'conversation_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.callCapability(
        'testagram.conversations.list',
        input: {'limit': 100},
      );
      final raw = response['items'];
      final items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  String _conversationName(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    final members = item['members'];
    if (members is List) {
      final names = members.whereType<Map>().map((m) {
        final name = (m['display_name'] ?? m['username'] ?? '').toString().trim();
        return name;
      }).where((name) => name.isNotEmpty).toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return item['kind'] == 'direct' ? 'Direct message' : 'Group conversation';
  }

  String _activityLabel(Map<String, dynamic> item) {
    final latest = item['latest_message'];
    final latestCreatedAt = latest is Map ? latest['created_at'] : null;
    final raw = (latestCreatedAt ?? item['updated_at'] ?? '').toString();
    final timestamp = DateTime.tryParse(raw);
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Updated $hour:$minute';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Messages'),
      actions: [
        IconButton(
          tooltip: 'Refresh messages',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: _loading && _items.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : _error != null && _items.isEmpty
        ? _state(_error!, action: 'Retry', onPressed: _load)
        : _items.isEmpty
          ? _state(
              'Your private conversations will appear here. Messages are stored as encrypted payloads; message content is not previewed in the inbox.',
              action: 'Refresh',
              onPressed: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final unread = (item['unread_count'] as num?)?.toInt() ?? 0;
                  final kind = item['kind'] == 'group' ? 'Group' : 'Direct';
                  final activity = _activityLabel(item);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                    leading: CircleAvatar(
                      child: Icon(item['kind'] == 'group'
                        ? Icons.groups_2_outlined
                        : Icons.person_outline_rounded),
                    ),
                    title: Text(_conversationName(item), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      'Open conversation · $kind${activity.isEmpty ? '' : ' · $activity'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unread > 0
                      ? CircleAvatar(
                          radius: 12,
                          child: Text(unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(fontSize: 10)),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ConversationScreen(
                        api: widget.api,
                        conversation: item,
                      ),
                    )).then((_) => _load()),
                  );
                },
              ),
            ),
  );

  Widget _state(String message, {required String action, required VoidCallback onPressed}) =>
    Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 38),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
        ]),
      ),
    );
}
