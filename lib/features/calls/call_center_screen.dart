import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../messaging/conversation_screen.dart';
import 'call_room_screen.dart';

class CallCenterScreen extends StatefulWidget {
  const CallCenterScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<CallCenterScreen> createState() => _CallCenterScreenState();
}

class _CallCenterScreenState extends State<CallCenterScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = _data(await widget.api.listConversations());
      final raw = response['items'];
      final rows = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      if (mounted) setState(() => _conversations = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    final members = item['members'];
    if (members is List) {
      final names = members.whereType<Map>().map((m) => (m['display_name'] ?? m['username'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return 'Conversation';
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calls'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading && _conversations.isEmpty
        ? ListView(children: const [SizedBox(height: 180), Center(child: CircularProgressIndicator())])
        : _error != null && _conversations.isEmpty
          ? ListView(children: [const SizedBox(height: 100), Center(child: Text(_error!, textAlign: TextAlign.center)), Center(child: TextButton(onPressed: _load, child: const Text('Retry')))])
          : _conversations.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 100), Center(child: Icon(Icons.call_outlined, size: 48)), Center(child: Text('Calls will appear alongside your conversations.'))])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _conversations[index];
                  final id = (item['id'] ?? '').toString();
                  final title = _title(item);
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.call_outlined)),
                    title: Text(title),
                    subtitle: const Text('Voice and video calling'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => CallRoomScreen(api: widget.api, conversationId: id, conversationTitle: title),
                    )),
                  );
                },
              ),
    ),
  );
}
