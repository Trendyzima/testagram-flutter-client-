import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/backend_api.dart';
import '../core/testagram_background.dart';
import '../features/discovery/explore_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/polls/polls_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/threads/threads_screen.dart';
import '../features/tv/tv_screen.dart';
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
    final pages = <Widget>[
      FeedScreen(api: widget.api, onSignOut: widget.onSignOut),
      ExploreScreen(api: widget.api),
      NotificationsScreen(api: widget.api),
      ThreadsScreen(api: widget.api),
      PollsScreen(api: widget.api),
      WalletScreen(api: widget.api),
      if (AppConfig.enableTvCatalogue)
        TvScreen(api: widget.api, allowedPlaybackHosts: AppConfig.tvPlaybackHosts),
      SettingsScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onSignOut: widget.onSignOut,
      ),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
      const NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
      const NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Threads'),
      const NavigationDestination(icon: Icon(Icons.poll_outlined), label: 'Polls'),
      const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
      if (AppConfig.enableTvCatalogue)
        const NavigationDestination(icon: Icon(Icons.live_tv_outlined), label: 'TV'),
      const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
    ];
    final safeIndex = _index < pages.length ? _index : 0;
    return Scaffold(
      body: TestagramBackground(child: IndexedStack(index: safeIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
