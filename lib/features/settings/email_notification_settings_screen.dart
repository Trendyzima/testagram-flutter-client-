import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../../core/widgets/testagram_app_bar.dart';

class EmailNotificationSettingsScreen extends StatefulWidget {
  const EmailNotificationSettingsScreen({
    super.key,
    required this.api,
    this.skipInitialPrompt = false,
  });

  final BackendApi api;
  final bool skipInitialPrompt;

  @override
  State<EmailNotificationSettingsScreen> createState() =>
      _EmailNotificationSettingsScreenState();
}

class _EmailNotificationSettingsScreenState
    extends State<EmailNotificationSettingsScreen> {
  bool _newFollowers = false;
  bool _newPosts = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = _data(await widget.api.getMyEmailNotificationPreferences());
      if (!mounted) return;
      setState(() {
        _newFollowers = data['new_follower_email_enabled'] == true;
        _newPosts = data['new_post_email_enabled'] == true;
        _loading = false;
        _error = null;
      });
      if (data['consent_prompt_required'] == true && !widget.skipInitialPrompt) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showConsentPrompt();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _showConsentPrompt() async {
    final allowSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose your email updates'),
        content: const Text(
          'Would you like Testagram to email you when someone follows you '
          'or when people you follow share a new post? These updates are '
          'optional. Nothing is emailed until you choose the categories '
          'and save your consent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose settings'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (allowSettings == false) {
      await _save(newFollowers: false, newPosts: false, showSuccess: false);
      if (mounted) {
        setState(() => _notice = 'Email updates remain off. You can change this any time.');
      }
    }
  }

  Future<void> _save({
    required bool newFollowers,
    required bool newPosts,
    bool showSuccess = true,
  }) async {
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final data = _data(await widget.api.updateMyEmailNotificationPreferences(
        newFollowerEmailEnabled: newFollowers,
        newPostEmailEnabled: newPosts,
      ));
      if (!mounted) return;
      setState(() {
        _newFollowers = data['new_follower_email_enabled'] == true;
        _newPosts = data['new_post_email_enabled'] == true;
        _notice = showSuccess ? 'Your email preferences have been saved.' : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TestagramAppBar(title: 'Email notifications'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You are in control',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                          'Social emails are off by default. Choose exactly '
                          'which updates you want. Your choice is recorded '
                          'when you save and can be withdrawn at any time.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _newFollowers,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _newFollowers = value),
                  title: const Text('When someone follows me'),
                  subtitle: const Text(
                    'Email me when a person follows me or requests to follow a protected account.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _newPosts,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _newPosts = value),
                  title: const Text('New posts from people I follow'),
                  subtitle: const Text(
                    'Email me when an account I follow shares a post I can access.',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () => _save(
                              newFollowers: _newFollowers,
                              newPosts: _newPosts,
                            ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save my choices'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(_notice!,
                      style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
              ],
            ),
    );
  }
}
