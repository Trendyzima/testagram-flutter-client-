import 'package:flutter/material.dart';

import '../core/backend_api.dart';
import '../core/testagram_background.dart';
import '../features/discovery/explore_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/polls/polls_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/threads/threads_screen.dart';
import '../features/tv/tv_screen.dart';
import '../core/app_config.dart';
import '../features/wallet/wallet_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.onSignOut,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final BackendApi api;
  final Future<void> Function() onSignOut;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedScreen(api: widget.api, onSignOut: widget.onSignOut),
      ExploreScreen(api: widget.api),
      NotificationsScreen(api: widget.api),
      ThreadsScreen(api: widget.api),
      PollsScreen(api: widget.api),
      WalletScreen(api: widget.api),
      if (AppConfig.enableTvCatalogue)\n        TvScreen(api: widget.api, allowedPlaybackHosts: AppConfig.tvPlaybackHosts),
      SettingsScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onSignOut: widget.onSignOut,
      ),
    ];
    return Scaffold(
      body: TestagramBackground(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Threads'),
          NavigationDestination(icon: Icon(Icons.poll_outlined), label: 'Polls'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          if (AppConfig.enableTvCatalogue)\n            NavigationDestination(icon: Icon(Icons.live_tv_outlined), label: 'TV'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
