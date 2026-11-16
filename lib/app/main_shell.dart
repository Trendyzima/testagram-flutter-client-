import 'package:material_ui/material_ui.dart';

import '../core/backend_api.dart';
import '../core/app_config.dart';
import '../core/testagram_background.dart';
import '../core/testagram_theme.dart';
import '../core/widgets/testagram_brand_mark.dart';
import '../features/discovery/explore_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/shorts/shorts_screen.dart';
import '../features/polls/polls_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/threads/threads_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/video/video_feed_screen.dart';
import '../features/profile/profile_screen.dart';

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

  int get _mobileSelectedIndex {
    if (_index <= 2) return _index;
    if (_index == 4) return 3;
    return 4;
  }

  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Text('Explore Testagram', style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Your profile'),
              subtitle: const Text('Posts, followers and profile details'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen.currentUser(api: widget.api),
                ));
              },
            ),
            const Divider(height: 1),
            for (final item in const [
              (3, Icons.search_rounded, 'Explore'),
              (5, Icons.forum_outlined, 'Threads'),
              (6, Icons.poll_outlined, 'Polls'),
              (7, Icons.account_balance_wallet_outlined, 'Wallet'),
              (8, Icons.settings_outlined, 'Settings'),
            ])
              ListTile(
                selected: _index == item.$1,
                leading: Icon(item.$2),
                title: Text(item.$3),
                trailing: _index == item.$1 ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (mounted) setState(() => _index = item.$1);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pages() => [
        FeedScreen(api: widget.api, onSignOut: widget.onSignOut),
        VideoFeedScreen(api: widget.api, videoApiBaseUri: AppConfig.videoApiOrigin, isActive: _index == 1),
        ShortsScreen(api: widget.api, isActive: _index == 2),
        ExploreScreen(api: widget.api),
        NotificationsScreen(api: widget.api),
        ThreadsScreen(api: widget.api),
        PollsScreen(api: widget.api),
        WalletScreen(api: widget.api),
        SettingsScreen(
          api: widget.api,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onSignOut: widget.onSignOut,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final extended = constraints.maxWidth >= 1120;
        final content = TestagramBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: TestagramTheme.contentMaxWidth),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        );

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: (value) => setState(() => _index = value),
                        extended: extended,
                        labelType: extended ? null : NavigationRailLabelType.all,
                        groupAlignment: -0.82,
                        leading: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const TestagramBrandMark(size: 42, radius: 13),
                              if (extended) ...[
                                const SizedBox(width: 12),
                                const Text(
                                  'Testagram',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: Text('Home'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.video_library_outlined),
                            selectedIcon: Icon(Icons.video_library_rounded),
                            label: Text('Video'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.play_circle_outline_rounded),
                            selectedIcon: Icon(Icons.play_circle_fill_rounded),
                            label: Text('Shorts'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.search_rounded),
                            selectedIcon: Icon(Icons.travel_explore_rounded),
                            label: Text('Explore'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.notifications_none_rounded),
                            selectedIcon: Icon(Icons.notifications_rounded),
                            label: Text('Notifications'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.forum_outlined),
                            selectedIcon: Icon(Icons.forum_rounded),
                            label: Text('Threads'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.poll_outlined),
                            selectedIcon: Icon(Icons.poll_rounded),
                            label: Text('Polls'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                            label: Text('Wallet'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings_rounded),
                            label: Text('Settings'),
                          ),
                        ],
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _mobileSelectedIndex,
                  onDestinationSelected: (value) {
                    if (value == 4) {
                      _openMoreMenu();
                    } else {
                      setState(() => _index = value);
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.video_library_outlined),
                      selectedIcon: Icon(Icons.video_library_rounded),
                      label: 'Video',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.play_circle_outline_rounded),
                      selectedIcon: Icon(Icons.play_circle_fill_rounded),
                      label: 'Shorts',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_none_rounded),
                      selectedIcon: Icon(Icons.notifications_rounded),
                      label: 'Alerts',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_rounded),
                      selectedIcon: Icon(Icons.menu_open_rounded),
                      label: 'More',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
