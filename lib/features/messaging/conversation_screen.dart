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
  String _myUserId = '';
  final Set<String> _busyMessageActions = {};

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
      final profileResponse = _data(await widget.api.getMyProfile());
      final myId = (profileResponse['id'] ?? profileResponse['user_id'] ?? '').toString();
      final response = _data(await widget.api.listMessages(_id));
      final raw = response['items'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() { _myUserId = myId; _messages = rows.reversed.toList(); });
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

  Future<void> _messageAction(Map<String, dynamic> message, String action) async {
    final id = (message['id'] ?? '').toString();
    if (id.isEmpty || !_busyMessageActions.add(id)) return;
    setState(() {});
    try {
      if (action == 'react') {
        await widget.api.reactToMessage(messageId: id, reaction: '❤️');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reaction added.')));
      } else if (action == 'delete') {
        if ((message['sender_id'] ?? '').toString() != _myUserId || _myUserId.isEmpty) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this message?'),
            content: const Text('This removes the message from the conversation for everyone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed != true) return;
        await widget.api.deleteMessage(id);
        if (mounted) setState(() => _messages.removeWhere((item) => (item['id'] ?? '').toString() == id));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message action failed: $error')));
    } finally {
      _busyMessageActions.remove(id);
      if (mounted) setState(() {});
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
              Expanded(child: Text('Message content stays hidden until Testagram has a verified device-key, recipient-verification and decryption lifecycle. Plaintext legacy records are not displayed.')),
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
                              const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.visibility_off_outlined, size: 16),
                                SizedBox(width: 7),
                                Text('Message unavailable'),
                              ]),
                              const SizedBox(height: 4),
                              Text((message['created_at'] ?? '').toString(), style: Theme.of(context).textTheme.bodySmall),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                TextButton.icon(
                                  onPressed: _busyMessageActions.contains((message['id'] ?? '').toString()) ? null : () => _messageAction(message, 'react'),
                                  icon: const Icon(Icons.favorite_border_rounded, size: 16),
                                  label: const Text('React'),
                                ),
                                if (_myUserId.isNotEmpty && (message['sender_id'] ?? '').toString() == _myUserId)
                                  PopupMenuButton<String>(
                                    enabled: !_busyMessageActions.contains((message['id'] ?? '').toString()),
                                    onSelected: (action) => _messageAction(message, action),
                                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete for everyone'))],
                                  ),
                              ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
        ),
        const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Secure sending is locked. Secure message composition is paused until Testagram key registration, device recovery and recipient-key verification are available in this client.'),
              SizedBox(height: 8),
              TextField(
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
