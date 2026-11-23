import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../../core/widgets/testagram_app_bar.dart';
import '../../core/widgets/testagram_state_view.dart';
import 'conversation_screen.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response) {
    final data = _data(response);
    final raw = data['items'];
    return raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.listConversations();
      if (mounted) setState(() => _items = _rows(result));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _conversationTitle(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    final members = item['members'];
    if (members is List) {
      final names = members.whereType<Map>().map((m) =>
        (m['display_name'] ?? m['username'] ?? '').toString()
      ).where((v) => v.isNotEmpty).toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return item['kind'] == 'group' ? 'Group conversation' : 'Direct message';
  }

  Future<void> _startDirectMessage() async {
    var enteredUsername = '';
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a conversation'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => enteredUsername = value,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Testagram username',
            prefixText: '@',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, enteredUsername), child: const Text('Continue')),
        ],
      ),
    );
    final handle = (username ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (handle.isEmpty || !mounted) return;
    setState(() => _creating = true);
    try {
      final resolved = _data(await widget.api.resolveProfileUsername(handle));
      final userId = (resolved['id'] ?? resolved['user_id'] ?? '').toString();
      if (userId.isEmpty) throw const BackendApiException('That account could not be found.');
      final created = _data(await widget.api.createConversation([userId]));
      final conversationId = (created['conversation_id'] ?? '').toString();
      if (conversationId.isEmpty) throw const BackendApiException('The Backend did not return a conversation ID.');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(api: widget.api, conversationId: conversationId, title: handle),
      ));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TestagramAppBar(
      title: 'Messages',
      actions: [
        IconButton(tooltip: 'New message', onPressed: _creating ? null : _startDirectMessage, icon: const Icon(Icons.edit_outlined)),
        IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading && _items.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              TestagramStateView(
                icon: Icons.forum_outlined,
                title: 'Loading conversations',
                message: 'Checking your private inbox.',
                loading: true,
              ),
            ],
          )
        : _error != null && _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                TestagramStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Inbox could not load',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ],
            )
          : _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  TestagramStateView(
                    icon: Icons.forum_outlined,
                    title: 'Your inbox starts here',
                    message: 'Start a private conversation with a Testagram account.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final unread = int.tryParse((item['unread_count'] ?? 0).toString()) ?? 0;
                  final latest = item['latest_message'];
                  final encrypted = latest is Map && latest['ciphertext'] != null;
                  return ListTile(
                    leading: CircleAvatar(child: Icon(item['kind'] == 'group' ? Icons.groups_outlined : Icons.person_outline)),
                    title: Text(_conversationTitle(item), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(encrypted ? 'Encrypted message' : 'Open conversation', maxLines: 1),
                    trailing: unread > 0 ? CircleAvatar(radius: 12, child: Text('$unread', style: const TextStyle(fontSize: 11))) : const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ConversationScreen(
                          api: widget.api,
                          conversationId: (item['id'] ?? '').toString(),
                          title: _conversationTitle(item),
                        ),
                      ));
                      if (mounted) _load();
                    },
                  );
                },
              ),
    ),
  );
}
