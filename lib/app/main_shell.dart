import 'package:flutter/material.dart';

import '../core/backend_api.dart';
import '../features/feed/feed_screen.dart';
import '../features/discovery/explore_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/threads/threads_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api, required this.onSignOut});
  final BackendApi api;
  final Future<void> Function() onSignOut;
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
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
        NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Threads'),
        ],
      ),
    );
  }
}
