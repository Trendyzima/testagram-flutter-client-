import 'package:material_ui/material_ui.dart';

import '../core/backend_api.dart';
import '../core/app_config.dart';
import '../core/testagram_deep_link.dart';
import '../core/testagram_background.dart';
import '../core/testagram_theme.dart';
import '../core/widgets/testagram_brand_mark.dart';
import '../features/discovery/explore_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/knowledge/knowledge_hub_screen.dart';
import '../features/monetization/monetization_hub_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/shorts/shorts_screen.dart';
import '../features/polls/polls_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/threads/threads_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/video/video_feed_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/messaging/direct_messages_screen.dart';
import '../features/calls/calls_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    this.initialDeepLink = '/',
    required this.onSignOut,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final BackendApi api;
  final String initialDeepLink;
  final Future<void> Function() onSignOut;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Primary destinations: Home, Discover, Ask, Notifications.
  // Index 4 and above are secondary destinations opened from More.
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialDeepLink();
    });
  }

  Future<void> _openInitialDeepLink() async {
    final link = TestagramDeepLink.parse(widget.initialDeepLink);
    if (link == null || !mounted) return;
    switch (link.kind) {
      case TestagramDeepLinkKind.wallet:
        setState(() => _index = 9);
        break;
      case TestagramDeepLinkKind.profileId:
        _openProfile(link.userId!);
        break;
      case TestagramDeepLinkKind.profileUsername:
        try {
          final response = await widget.api.resolveProfileUsername(link.username!);
          final raw = response['data'];
          final userId = raw is Map ? (raw['id'] ?? raw['user_id'] ?? '').toString() : '';
          if (!mounted) return;
          if (userId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This profile is unavailable.')),
            );
            return;
          }
          _openProfile(userId);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open profile: $error')),
            );
          }
        }
        break;
    }
  }

  void _openProfile(String userId) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfileScreen(api: widget.api, userId: userId),
    ));
  }
  int get _selectedPrimaryIndex => _index < 4 ? _index : 4;

  void _selectDestination(int value) {
    if (value == 4) {
      _openMoreMenu();
      return;
    }
    setState(() => _index = value);
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
              child: Text(
                'More from Testagram',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final item in const [
              (4, Icons.person_outline_rounded, 'Your profile', 'Posts and profile details'),
              (5, Icons.video_library_outlined, 'Video', 'Long-form video'),
              (6, Icons.play_circle_outline_rounded, 'Shorts', 'Short-form video'),
              (7, Icons.forum_outlined, 'Threads', 'Long-form conversations'),
              (8, Icons.poll_outlined, 'Polls', 'Community polls'),
              (9, Icons.account_balance_wallet_outlined, 'Wallet', 'Your wallet'),
              (10, Icons.settings_outlined, 'Settings', 'Privacy and account controls'),
              (11, Icons.monetization_on_outlined, 'Monetization', 'Creator tools and earnings'),
              (12, Icons.forum_outlined, 'Direct messages', 'Private conversations'),
              (13, Icons.call_outlined, 'Calls', 'Voice and video call centre'),
            ])
              ListTile(
                selected: _index == item.$1,
                leading: Icon(item.$2),
                title: Text(item.$3),
                subtitle: Text(item.$4),
                trailing: _index == item.$1
                    ? const Icon(Icons.check_rounded)
                    : null,
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
        ExploreScreen(api: widget.api),
        KnowledgeHubScreen(api: widget.api),
        NotificationsScreen(api: widget.api),
        ProfileScreen.currentUser(api: widget.api),
        VideoFeedScreen(
          api: widget.api,
          videoApiBaseUri: AppConfig.videoApiOrigin,
          isActive: _index == 5,
        ),
        ShortsScreen(api: widget.api, isActive: _index == 6),
        ThreadsScreen(api: widget.api),
        PollsScreen(api: widget.api),
        WalletScreen(api: widget.api),
        SettingsScreen(
          api: widget.api,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onSignOut: widget.onSignOut,
        ),
        MonetizationHubScreen(api: widget.api),
        DirectMessagesScreen(api: widget.api),
        CallsScreen(api: widget.api),
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
              constraints: const BoxConstraints(
                maxWidth: TestagramTheme.contentMaxWidth,
              ),
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
                        selectedIndex: _selectedPrimaryIndex,
                        onDestinationSelected: _selectDestination,
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
                            icon: Icon(Icons.travel_explore_outlined),
                            selectedIcon: Icon(Icons.travel_explore_rounded),
                            label: Text('Discover'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.lightbulb_outline_rounded),
                            selectedIcon: Icon(Icons.lightbulb_rounded),
                            label: Text('Ask'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.notifications_none_rounded),
                            selectedIcon: Icon(Icons.notifications_rounded),
                            label: Text('Notifications'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.menu_rounded),
                            selectedIcon: Icon(Icons.menu_open_rounded),
                            label: Text('More'),
                          ),
                        ],
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedPrimaryIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.travel_explore_outlined),
                      selectedIcon: Icon(Icons.travel_explore_rounded),
                      label: 'Discover',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.lightbulb_outline_rounded),
                      selectedIcon: Icon(Icons.lightbulb_rounded),
                      label: 'Ask',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_none_rounded),
                      selectedIcon: Icon(Icons.notifications_rounded),
                      label: 'Notifications',
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
