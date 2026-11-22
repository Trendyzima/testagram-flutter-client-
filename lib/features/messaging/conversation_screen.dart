import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.api, required this.conversation});
  final BackendApi api;
  final Map<String, dynamic> conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  String get _id => (widget.conversation['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_id.isEmpty) {
      setState(() { _loading = false; _error = 'This conversation has an invalid identifier.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.callCapability(
        'testagram.messages.list',
        input: {'conversation_id': _id, 'limit': 100},
      );
      final raw = response['items'];
      final messages = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList().reversed.toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _messages = messages; _loading = false; });
      if (messages.isNotEmpty) {
        final latest = messages.last;
        final messageId = (latest['id'] ?? '').toString();
        if (messageId.isNotEmpty) {
          try {
            await widget.api.callCapability(
              'testagram.messages.mark_read',
              input: {'message_id': messageId},
            );
          } catch (_) {
            // Read receipts are best-effort; never block opening the conversation.
          }
        }
      }
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.conversation['title'] ?? '').toString().trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? 'Private conversation' : title),
        actions: [
          IconButton(
            tooltip: 'Call options',
            onPressed: () => _showCallNotice(context),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading && _messages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _messages.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ))
              : _messages.isEmpty
                ? const Center(child: Text('This conversation has no messages yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final sender = message['sender'];
                      final senderName = sender is Map
                          ? (sender['display_name'] ?? sender['username'] ?? 'Testagram member').toString()
                          : 'Testagram member';
                      final own = message['sender_id'] == null;
                      final created = DateTime.tryParse((message['created_at'] ?? '').toString());
                      return Align(
                        alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(senderName, style: Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 6),
                              const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.lock_outline_rounded, size: 16),
                                SizedBox(width: 7),
                                Flexible(child: Text('Encrypted message')),
                              ]),
                              if (created != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  TimeOfDay.fromDateTime(created.toLocal()).format(context),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: const Row(children: [
              Icon(Icons.enhanced_encryption_outlined),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Secure sending is locked until device key generation, key verification and encrypted payload handling are connected.',
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showCallNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Secure calls'),
        content: const Text(
          'Call session records and signaling authorization exist on the Backend. Native WebRTC media, peer signaling and device permission handling are not yet integrated in this client, so calls cannot be started safely yet.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}
