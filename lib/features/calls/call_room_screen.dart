import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class CallRoomScreen extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Voice & video')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.video_call_outlined, size: 64),
        const SizedBox(height: 16),
        Text(conversationTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
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
      ],
    ),
  );
}
