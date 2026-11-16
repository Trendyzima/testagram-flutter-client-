import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class RemoteAuthorSubscriptionsPanel extends StatefulWidget {
  const RemoteAuthorSubscriptionsPanel({super.key, required this.api});

  final BackendApi api;

  @override
  State<RemoteAuthorSubscriptionsPanel> createState() =>
      _RemoteAuthorSubscriptionsPanelState();
}

class _RemoteAuthorSubscriptionsPanelState
    extends State<RemoteAuthorSubscriptionsPanel> {
  final _identity = TextEditingController();
  final _handle = TextEditingController();
  String _protocol = 'activitypub';
  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _identity.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await widget.api.listRemoteAuthorSubscriptions();
      final data = response['data'];
      if (data is! Map || data['subscriptions'] is! List) {
        throw const BackendApiException(
          'Testagram returned an invalid remote subscriptions list.',
        );
      }
      final rows = (data['subscriptions'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) setState(() => _subscriptions = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await widget.api.subscribeRemoteAuthor(
        protocol: _protocol,
        identity: _identity.text,
        handle: _handle.text,
      );
      final data = response['data'];
      final status = data is Map
          ? (data['verification_status'] ?? 'pending').toString()
          : 'pending';
      _identity.clear();
      _handle.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'verified'
                ? 'Remote author verified and added.'
                : 'Subscription saved. Remote identity verification is pending.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> subscription) async {
    final id = (subscription['id'] ?? '').toString();
    if (id.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.unsubscribeRemoteAuthor(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remote author subscription removed.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActivityPub = _protocol == 'activitypub';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_outlined,
                    color: theme.colorScheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Follow remote authors',
                      style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Refresh remote subscriptions',
                  onPressed: _loading || _saving ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Follow public authors on Mastodon-compatible servers or Bluesky. They stay external identities, separate from your Testagram account.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _protocol,
              decoration: const InputDecoration(
                labelText: 'Network',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'activitypub',
                  child: Text('Mastodon / ActivityPub'),
                ),
                DropdownMenuItem(
                  value: 'bluesky',
                  child: Text('Bluesky / AT Protocol'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _protocol = value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _identity,
              enabled: !_saving,
              autocorrect: false,
              keyboardType: isActivityPub
                  ? TextInputType.url
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: isActivityPub ? 'Actor profile URL' : 'Bluesky DID',
                hintText: isActivityPub
                    ? 'https://mastodon.social/users/alice'
                    : 'did:plc:…',
                border: const OutlineInputBorder(),
              ),
            ),
            if (!isActivityPub) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _handle,
                enabled: !_saving,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Display handle (optional)',
                  hintText: 'alice.bsky.social',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _subscribe,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add remote author'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 18),
            Text('Your remote subscriptions',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading && _subscriptions.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ))
            else if (_subscriptions.isEmpty)
              const Text('No remote authors followed yet.')
            else
              ..._subscriptions.map((subscription) {
                final handle = (subscription['handle'] ?? '').toString();
                final identity = (subscription['identity'] ?? '').toString();
                final protocol = (subscription['protocol'] ?? '').toString();
                final verification =
                    (subscription['verification_status'] ?? 'pending').toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(protocol == 'bluesky'
                      ? Icons.cloud_outlined
                      : Icons.public_rounded),
                  title: Text(handle.isEmpty ? identity : handle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '$protocol · $verification\n$identity',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Unfollow remote author',
                    onPressed: _saving ? null : () => _remove(subscription),
                    icon: const Icon(Icons.person_remove_alt_1_rounded),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
