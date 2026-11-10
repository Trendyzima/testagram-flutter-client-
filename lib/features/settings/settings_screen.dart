import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSignOut,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeChoice(
                  title: 'Use device settings',
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: onThemeModeChanged,
                ),
                const Divider(height: 1),
                _ThemeChoice(
                  title: 'Light',
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: onThemeModeChanged,
                ),
                const Divider(height: 1),
                _ThemeChoice(
                  title: 'Dark',
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: onThemeModeChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              subtitle: const Text('End this Testagram session on this device.'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('You can sign in again at any time.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await onSignOut();
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'More account, privacy, notification and connected-service controls will be added when their native Backend contracts are available.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
