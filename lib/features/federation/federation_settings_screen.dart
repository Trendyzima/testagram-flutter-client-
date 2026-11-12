import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class FederationSettingsScreen extends StatefulWidget {
  const FederationSettingsScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<FederationSettingsScreen> createState() => _FederationSettingsScreenState();
}

class _FederationSettingsScreenState extends State<FederationSettingsScreen> {
  bool? _enabled;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getMyFederationPreference();
      final data = response['data'];
      if (data is! Map || data['enabled'] is! bool) {
        throw const BackendApiException(
          'Testagram returned an invalid federation preference.',
        );
      }
      if (mounted) setState(() => _enabled = data['enabled'] as bool);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(bool next) async {
    if (_saving || _enabled == null || next == _enabled) return;
    final previous = _enabled!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response =
          await widget.api.updateMyFederationPreference(enabled: next);
      final data = response['data'];
      if (data is! Map || data['enabled'] is! bool) {
        throw const BackendApiException(
          'Testagram did not confirm the updated federation preference.',
        );
      }
      if (mounted) {
        setState(() => _enabled = data['enabled'] as bool);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next
                ? 'Fediverse discovery preference enabled.'
                : 'Fediverse discovery preference disabled.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _enabled = previous;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fediverse'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _enabled == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.hub_rounded,
                          size: 36,
                          color: Color(0xFF18A957),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Connect with the Fediverse',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The Fediverse connects independent social platforms, including Mastodon. When Testagram federation is available for your account, people on other compatible servers can discover and follow your public profile.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile.adaptive(
                    value: _enabled ?? false,
                    onChanged: _enabled == null || _saving ? null : _update,
                    title: const Text('Allow Fediverse discovery'),
                    subtitle: Text(
                      _enabled == true
                          ? 'Your account has opted in to federation.'
                          : 'Your account is not opted in to federation.',
                    ),
                    secondary: const Icon(Icons.public_rounded),
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Saving your preference…'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _loading || _saving ? null : _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Before enabling',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const _FederationInfo(
                  icon: Icons.visibility_outlined,
                  text:
                      'Your account must be public and discoverable by username. Backend checks this before accepting the preference.',
                ),
                const _FederationInfo(
                  icon: Icons.lock_outline_rounded,
                  text:
                      'Your existing Testagram Appwrite session remains your only login. Federation does not create a separate Mastodon password.',
                ),
                const _FederationInfo(
                  icon: Icons.shield_outlined,
                  text:
                      'This setting is an opt-in preference, not a promise that public federation is already active. Testagram keeps federation gated until interoperability and security checks pass.',
                ),
                const _FederationInfo(
                  icon: Icons.article_outlined,
                  text:
                      'Only eligible public content can be federated. Private or deleted posts must remain unavailable to remote servers.',
                ),
              ],
            ),
    );
  }
}

class _FederationInfo extends StatelessWidget {
  const _FederationInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
