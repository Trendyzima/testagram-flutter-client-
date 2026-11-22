import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import 'call_room_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Map<String, dynamic>> _calls = [];
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
      final conversationsResponse = await widget.api.callCapability(
        'testagram.conversations.list',
        input: {'limit': 100},
      );
      final raw = conversationsResponse['items'];
      final conversations = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final calls = <Map<String, dynamic>>[];
      for (final conversation in conversations) {
        final id = (conversation['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final response = await widget.api.callCapability(
          'testagram.calls.list',
          input: {'conversation_id': id},
        );
        final rows = response['items'];
        if (rows is List) {
          for (final row in rows.whereType<Map>()) {
            calls.add({
              ...Map<String, dynamic>.from(row),
              'conversation_title': (conversation['title'] ?? '').toString(),
              'conversation_id': id,
            });
          }
        }
      }
      calls.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      if (!mounted) return;
      setState(() { _calls = calls; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Audio & video calls'),
      actions: [
        IconButton(
          tooltip: 'Refresh call history',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: _loading && _calls.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : _error != null && _calls.isEmpty
        ? _state(_error!, action: 'Retry', onPressed: _load)
        : _calls.isEmpty
          ? _state(
              'Your voice and video call history will appear here. Start a call from a private conversation once secure media transport is available.',
              action: 'Refresh',
              onPressed: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _calls.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final call = _calls[index];
                  final kind = (call['kind'] ?? 'video').toString();
                  final status = (call['status'] ?? 'unknown').toString();
                  final date = DateTime.tryParse((call['created_at'] ?? '').toString());
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(kind == 'voice' ? Icons.call_rounded : Icons.videocam_rounded),
                    ),
                    title: Text(kind == 'voice' ? 'Voice call' : kind == 'video' ? 'Video call' : 'Screen share'),
                    subtitle: Text([
                      if ((call['conversation_title'] ?? '').toString().isNotEmpty) call['conversation_title'],
                      status[0].toUpperCase() + status.substring(1),
                      if (date != null) date.toLocal().toString().substring(0, 16),
                      'Media encryption not active in this client',
                    ].join(' · ')),
                    trailing: const Icon(Icons.lock_outline_rounded),
                    onTap: () {
                      final conversationId = (call['conversation_id'] ?? '').toString();
                      if (conversationId.isEmpty) return;
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => CallRoomScreen(
                          api: widget.api,
                          conversationId: conversationId,
                          conversationTitle: (call['conversation_title'] ?? 'Conversation').toString(),
                        ),
                      ));
                    },
                  );
                },
              ),
            ),
  );

  Widget _state(String message, {required String action, required VoidCallback onPressed}) =>
    Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.video_call_outlined, size: 42),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onPressed, child: Text(action)),
      ]),
    ));
}
