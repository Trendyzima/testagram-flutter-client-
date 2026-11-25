import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class AudioSpacesScreen extends StatefulWidget {
  const AudioSpacesScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<AudioSpacesScreen> createState() => _AudioSpacesScreenState();
}

class _AudioSpacesScreenState extends State<AudioSpacesScreen> {
  List<Map<String, dynamic>> _spaces = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  Future<void> _load({bool silent = false}) async {
    if (mounted) setState(() { if (!silent) _loading = true; _error = null; });
    try {
      final response = _payload(await widget.api.listLiveAudioSpaces());
      final raw = response['items'];
      final items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() { _spaces = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _createSpace() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final audience = TextEditingController(text: '1000');
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start an Audio Space'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 120,
            decoration: const InputDecoration(labelText: 'Space title')),
          TextField(controller: description, maxLength: 2000, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description (optional)')),
          TextField(controller: audience, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Audience limit (2–10,000)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'title': title.text.trim(),
            'description': description.text.trim(),
            'max_audience': int.tryParse(audience.text.trim()) ?? 1000,
          }), child: const Text('Create Space')),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    audience.dispose();
    if (input == null) return;
    try {
      setState(() => _creating = true);
      await widget.api.createAudioSpace(
        title: (input['title'] ?? '').toString(),
        description: (input['description'] ?? '').toString(),
        maxAudience: input['max_audience'] as int,
      );
      if (mounted) _toast('Your Space was created. Live audio transport is not enabled yet.');
      await _load(silent: true);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openSpace(Map<String, dynamic> space) async {
    final id = (space['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final details = _payload(await widget.api.getAudioSpace(id));
      final membership = _payload(await widget.api.getMyAudioSpaceStatus(id));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final role = (membership['role'] ?? '').toString();
          final requestStatus = (membership['speaker_request_status'] ?? 'none').toString();
          final joined = membership['joined'] == true;
          final isHost = role == 'host';
          final host = details['host'] is Map ? details['host'] as Map : const {};
          return AlertDialog(
            title: Text((details['title'] ?? space['title'] ?? 'Audio Space').toString()),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((details['description'] ?? '').toString()),
                const SizedBox(height: 8),
                Text('Host: @' + (host['username'] ?? 'member').toString()),
                Text('Listeners: ' + (details['listener_count'] ?? space['listener_count'] ?? 0).toString() +
                    ' / ' + (details['max_audience'] ?? space['max_audience'] ?? 1000).toString()),
                if (joined) Text('Your role: ' + role),
                if (requestStatus != 'none') Text('Speaker request: ' + requestStatus),
                const SizedBox(height: 12),
                const Text(
                  'Room lifecycle and speaker controls are connected to the Backend. Live multi-party audio transport is not enabled in this client yet.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
              if (!joined)
                FilledButton(onPressed: () async {
                  try {
                    await widget.api.joinAudioSpace(id);
                    if (mounted) _toast('You joined the Space.');
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _load(silent: true);
                  } catch (error) { if (mounted) _toast(error.toString()); }
                }, child: const Text('Join')),
              if (joined && !isHost)
                OutlinedButton(onPressed: () async {
                  try {
                    await widget.api.leaveAudioSpace(id);
                    if (mounted) _toast('You left the Space.');
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _load(silent: true);
                  } catch (error) { if (mounted) _toast(error.toString()); }
                }, child: const Text('Leave')),
              if (joined && !isHost && requestStatus != 'pending' && requestStatus != 'approved')
                OutlinedButton(onPressed: () async {
                  try {
                    await widget.api.requestAudioSpaceSpeaker(id);
                    if (mounted) _toast('Speaker request sent.');
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) { if (mounted) _toast(error.toString()); }
                }, child: const Text('Request to speak')),
              if (isHost)
                OutlinedButton(onPressed: () async {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _manageSpeakerRequests(id);
                }, child: const Text('Speaker requests')),
              if (isHost)
                OutlinedButton(onPressed: () async {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _editSpace(id, (details['title'] ?? '').toString(), (details['description'] ?? '').toString());
                }, child: const Text('Edit details')),
              if (joined && !isHost)
                OutlinedButton(onPressed: () async {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _sendSuperchat(id);
                }, child: const Text('Super Chat')),
              if (isHost)
                FilledButton.tonal(onPressed: () async {
                  try {
                    await widget.api.endAudioSpace(id);
                    if (mounted) _toast('Audio Space ended.');
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _load(silent: true);
                  } catch (error) { if (mounted) _toast(error.toString()); }
                }, child: const Text('End Space')),
            ],
          );
        },
      );
    } catch (error) {
      if (mounted) _toast(error.toString());
    }
  }

  Future<void> _editSpace(String spaceId, String currentTitle, String currentDescription) async {
    final title = TextEditingController(text: currentTitle);
    final description = TextEditingController(text: currentDescription);
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Audio Space'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 120,
            decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: description, maxLength: 2000, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'title': title.text.trim(), 'description': description.text.trim(),
          }), child: const Text('Save')),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    if (input == null) return;
    try {
      await widget.api.updateAudioSpace(
        spaceId: spaceId,
        title: input['title'] ?? '',
        description: input['description'] ?? '',
      );
      if (mounted) {
        _toast('Audio Space details updated.');
        await _load(silent: true);
      }
    } catch (error) {
      if (mounted) _toast(error.toString());
    }
  }

  Future<void> _sendSuperchat(String spaceId) async {
    final amount = TextEditingController(text: '100');
    final message = TextEditingController();
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send a Super Chat'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount in your wallet currency')),
          TextField(controller: message, maxLength: 280, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'amount': amount.text.trim(), 'message': message.text.trim(),
          }), child: const Text('Continue')),
        ],
      ),
    );
    amount.dispose();
    message.dispose();
    if (input == null) return;
    final value = double.tryParse(input['amount'] ?? '');
    if (value == null || value <= 0 || (input['message'] ?? '').isEmpty) {
      if (mounted) _toast('Enter a positive amount and a message.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Super Chat'),
        content: Text('Send ' + (input['amount'] ?? '') + ' from your wallet with this message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final key = 'space-' + spaceId + '-' + DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      await widget.api.sendAudioSpaceSuperchat(
        spaceId: spaceId,
        message: input['message'] ?? '',
        amount: input['amount'] ?? '',
        idempotencyKey: key,
      );
      if (mounted) _toast('Super Chat sent.');
    } catch (error) {
      if (mounted) _toast(error.toString());
    }
  }

  Future<void> _manageSpeakerRequests(String spaceId) async {
    try {
      final response = _payload(await widget.api.listAudioSpaceSpeakerRequests(spaceId));
      final raw = response['items'];
      final requests = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Speaker requests'),
          content: SizedBox(
            width: 420,
            child: requests.isEmpty
                ? const Text('There are no pending speaker requests.')
                : ListView(shrinkWrap: true, children: requests.map((request) {
                    final profile = request['profiles'] is Map ? request['profiles'] as Map : const {};
                    final userId = (request['user_id'] ?? '').toString();
                    return ListTile(
                      title: Text('@' + (profile['username'] ?? 'member').toString()),
                      subtitle: Text((profile['display_name'] ?? '').toString()),
                      trailing: Wrap(spacing: 4, children: [
                        IconButton(
                          tooltip: 'Approve speaker',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () async {
                            try {
                              await widget.api.decideAudioSpaceSpeaker(
                                spaceId: spaceId, userId: userId, approve: true,
                              );
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              await _manageSpeakerRequests(spaceId);
                            } catch (error) { if (mounted) _toast(error.toString()); }
                          },
                        ),
                        IconButton(
                          tooltip: 'Deny speaker',
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () async {
                            try {
                              await widget.api.decideAudioSpaceSpeaker(
                                spaceId: spaceId, userId: userId, approve: false,
                              );
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              await _manageSpeakerRequests(spaceId);
                            } catch (error) { if (mounted) _toast(error.toString()); }
                          },
                        ),
                      ]),
                    );
                  }).toList()),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))],
        ),
      );
    } catch (error) {
      if (mounted) _toast(error.toString());
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Audio Spaces'),
      actions: [
        IconButton(
          tooltip: 'Refresh live Spaces',
          onPressed: _loading ? null : () => _load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Start an Audio Space',
          onPressed: _creating ? null : _createSpace,
          icon: _creating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_rounded),
        ),
      ],
    ),
    body: Column(children: [
      Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Space discovery, membership, speaker requests and host controls are connected. Live multi-party audio is not enabled until the dedicated group media transport is deployed.',
            )),
          ]),
        ),
      ),
      Expanded(
        child: _loading && _spaces.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _spaces.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: () => _load(), child: const Text('Retry')),
                    ]),
                  ))
                : _spaces.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(children: const [
                          SizedBox(height: 120),
                          Icon(Icons.graphic_eq_rounded, size: 48),
                          SizedBox(height: 12),
                          Center(child: Text('No open Audio Spaces right now.')),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _spaces.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final space = _spaces[index];
                            final host = space['host'] is Map ? space['host'] as Map : const {};
                            return Card(child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.graphic_eq_rounded)),
                              title: Text((space['title'] ?? 'Live Audio Space').toString()),
                              subtitle: Text([
                                '@' + (host['username'] ?? 'Testagram member').toString(),
                                (space['listener_count'] ?? 0).toString() + ' listening',
                                if ((space['description'] ?? '').toString().isNotEmpty)
                                  (space['description'] ?? '').toString(),
                              ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _openSpace(space),
                            ));
                          },
                        ),
                      ),
      ),
    ]),
  );
}
