import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class CallRoomScreen extends StatefulWidget {
  const CallRoomScreen({
    super.key,
    required this.api,
    required this.conversationId,
    required this.conversationTitle,
  });
  final BackendApi api;
  final String conversationId;
  final String conversationTitle;

  @override
  State<CallRoomScreen> createState() => _CallRoomScreenState();
}

class _CallRoomScreenState extends State<CallRoomScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  Future<void> _loadHistory() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.listConversationCalls(widget.conversationId);
      final rawData = response['data'];
      final data = rawData is Map ? Map<String, dynamic>.from(rawData) : response;
      final raw = data['items'];
      final items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _history = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Voice & video'),
      actions: [IconButton(onPressed: _loadHistory, tooltip: 'Refresh call history', icon: const Icon(Icons.refresh))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.video_call_outlined, size: 64),
        const SizedBox(height: 16),
        Text(widget.conversationTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
          'Testagram has Backend call-session and scoped signaling-ticket contracts. Live audio/video is not enabled in this Flutter build because a verified WebRTC media transport, permission flow and end-to-end media encryption lifecycle are not yet integrated.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              ListTile(leading: Icon(Icons.mic_none), title: Text('Voice calls'), subtitle: Text('Awaiting secure media transport')),
              Divider(),
              ListTile(leading: Icon(Icons.videocam_outlined), title: Text('Video calls'), subtitle: Text('Awaiting camera and media integration')),
              Divider(),
              ListTile(leading: Icon(Icons.screen_share_outlined), title: Text('Screen sharing'), subtitle: Text('Not enabled')),
              Divider(),
              ListTile(leading: Icon(Icons.enhanced_encryption_outlined), title: Text('Encrypted signaling'), subtitle: Text('Backend-issued, room-scoped tickets')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.call),
          label: const Text('Start call — not enabled yet'),
        ),
        const SizedBox(height: 24),
        Text('Call history', style: Theme.of(context).textTheme.titleLarge),
        if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        if (_error != null) Text(_error!, textAlign: TextAlign.center),
        if (!_loading && _error == null && _history.isEmpty) const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No calls in this conversation yet.'),
        ),
        for (final call in _history)
          ListTile(
            leading: Icon(call['kind'] == 'voice' ? Icons.call : Icons.videocam_outlined),
            title: Text('${(call['kind'] ?? 'video').toString().toUpperCase()} call'),
            subtitle: Text('Status: ${(call['status'] ?? 'unknown').toString()} · ${(call['created_at'] ?? '').toString()}'),
          ),
      ],
    ),
  );
}
