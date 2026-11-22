import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../calls/call_room_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.api,
    this.conversation,
    this.conversationId,
    this.title,
  });
  final BackendApi api;
  final Map<String, dynamic>? conversation;
  final String? conversationId;
  final String? title;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  String get _id => (widget.conversationId ?? widget.conversation?['id'] ?? '').toString();
  String get _title {
    final value = (widget.title ?? widget.conversation?['title'] ?? '').toString().trim();
    return value.isEmpty ? 'Private conversation' : value;
  }

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      if (_id.isEmpty) throw const BackendApiException('This conversation has an invalid identifier.');
      final response = _data(await widget.api.listMessages(_id));
      final raw = response['items'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _messages = rows.reversed.toList());
      if (rows.isNotEmpty) {
        final latestId = (rows.first['id'] ?? '').toString();
        if (latestId.isNotEmpty) {
          try { await widget.api.markMessageRead(latestId); } catch (_) { /* Read receipts are best-effort. */ }
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_title),
      actions: [
        IconButton(
          tooltip: 'Voice or video call',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CallRoomScreen(
              api: widget.api,
              conversationId: _id,
              conversationTitle: _title,
            ),
          )),
          icon: const Icon(Icons.video_call_outlined),
        ),
        IconButton(tooltip: 'Refresh messages', onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.lock_outline, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Messages are stored as encrypted payloads. This client does not yet have the verified key-management and decryption lifecycle enabled.')),
            ]),
          ),
        ),
        Expanded(
          child: _loading && _messages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _messages.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ])))
              : _messages.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final encrypted = message['e2ee_enabled'] == true || (message['ciphertext'] ?? '').toString().isNotEmpty;
                      final sender = message['sender'];
                      final senderName = sender is Map
                          ? (sender['display_name'] ?? sender['username'] ?? 'Member').toString()
                          : 'Member';
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(senderName, style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 6),
                              Text(encrypted ? 'Encrypted message — decryption is unavailable on this client.' : (message['body'] ?? '').toString()),
                              const SizedBox(height: 4),
                              Text((message['created_at'] ?? '').toString(), style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Secure message composition is paused until Testagram key registration, device recovery and recipient-key verification are available in this client.'),
              const SizedBox(height: 8),
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'Secure messaging is not enabled yet',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ]),
          ),
        ),
      ],
    ),
  );
}
