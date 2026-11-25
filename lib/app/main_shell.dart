import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/backend_api.dart';
import '../core/app_config.dart';
import '../core/testagram_deep_link.dart';
import '../core/testagram_background.dart';
import '../core/testagram_theme.dart';
import '../core/widgets/testagram_brand_mark.dart';
import '../features/discovery/explore_screen.dart';
import '../features/discovery/hashtag_screen.dart';
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
import '../features/lists/social_lists_screen.dart';

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
  // All signed-in destinations are reachable directly from the mobile strip
  // and desktop sidebar. Keep these indexes aligned with _pages().
  int _index = 0;
  bool _bottomBarVisible = true;
  bool _loadingSidebarTrends = false;
  List<Map<String, dynamic>> _sidebarTrends = [];
  List<Map<String, dynamic>> _sidebarTrendingWords = [];
  List<Map<String, dynamic>> _sidebarKnowledgeTopics = [];
  List<Map<String, dynamic>> _sidebarSuggestions = [];
  final Set<String> _followingSuggestions = {};
  Map<String, dynamic>? _sidebarProfile;
  bool _loadingSidebarContext = false;

  @override
  void initState() {
    super.initState();
    _loadSidebarTrends();
    _loadSidebarContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialDeepLink();
    });
  }

  Future<void> _loadSidebarTrends() async {
    if (_loadingSidebarTrends) return;
    _loadingSidebarTrends = true;
    try {
      final response = await widget.api.getTrendingHashtags(limit: 8);
      final raw = response['data'];
      final data = raw is Map ? Map<String, dynamic>.from(raw) : response;
      final rows = data['items'] ?? data['hashtags'] ?? data['trends'];
      final values = rows is List
          ? rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _sidebarTrends = values);
    } catch (_) {
      // The navigation shell remains useful if trend discovery is unavailable.
    } finally {
      _loadingSidebarTrends = false;
    }
  }

  Future<void> _loadSidebarContext() async {
    if (_loadingSidebarContext) return;
    _loadingSidebarContext = true;
    try {
      Future<Map<String, dynamic>> optional(
        Future<Map<String, dynamic>> request,
      ) async {
        try {
          return await request;
        } catch (_) {
          return <String, dynamic>{};
        }
      }

      // Each sidebar module is independent: a trends outage must not hide
      // the signed-in profile or knowledge discovery.
      final responses = await Future.wait([
        optional(widget.api.getMyProfile()),
        optional(widget.api.getTrendingWords(limit: 6)),
        optional(widget.api.getKnowledgeTopics(limit: 6)),
        optional(widget.api.getSocialSuggestions(limit: 8)),
      ]);
      final profileRaw = responses[0]['data'];
      final wordsRaw = responses[1]['data'];
      final wordsData = wordsRaw is Map ? wordsRaw : responses[1];
      final topicsRaw = responses[2]['data'];
      final topicsData = topicsRaw is Map ? topicsRaw : responses[2];
      final suggestionsRaw = responses[3]['data'];
      final suggestionsData = suggestionsRaw is Map ? suggestionsRaw : responses[3];
      final rawWords = wordsData['items'];
      final rawTopics = topicsData['items'];
      final rawSuggestions = suggestionsData['items'];
      if (!mounted) return;
      setState(() {
        if (profileRaw is Map) {
          _sidebarProfile = Map<String, dynamic>.from(profileRaw);
        }
        _sidebarTrendingWords = rawWords is List
            ? rawWords.whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        _sidebarKnowledgeTopics = rawTopics is List
            ? rawTopics.whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        _sidebarSuggestions = rawSuggestions is List
            ? rawSuggestions.whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
      });
    } catch (_) {
      // Sidebar data is optional; core navigation remains available.
    } finally {
      _loadingSidebarContext = false;
    }
  }

  Future<void> _followSuggestedAccount(Map<String, dynamic> account) async {
    final id = (account['id'] ?? '').toString();
    if (id.isEmpty || _followingSuggestions.contains(id)) return;
    setState(() => _followingSuggestions.add(id));
    try {
      final response = await widget.api.followUser(id);
      final raw = response['data'];
      final data = raw is Map ? Map<String, dynamic>.from(raw) : response;
      final status = (data['status'] ?? 'accepted').toString();
      if (!mounted) return;
      setState(() {
        account['is_following'] = status == 'accepted';
        account['follow_status'] = status;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'pending'
            ? 'Follow request sent.'
            : 'You are now following @${account['username'] ?? 'this account'}.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not follow this account: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _followingSuggestions.remove(id));
    }
  }

  static const _destinations = <(int, IconData, IconData, String)>[
    (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (1, Icons.travel_explore_outlined, Icons.travel_explore_rounded, 'Discover'),
    (2, Icons.lightbulb_outline_rounded, Icons.lightbulb_rounded, 'Ask'),
    (3, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Notifications'),
    (4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    (5, Icons.video_library_outlined, Icons.video_library_rounded, 'Video'),
    (6, Icons.play_circle_outline_rounded, Icons.play_circle_rounded, 'Shorts'),
    (7, Icons.forum_outlined, Icons.forum_rounded, 'Threads'),
    (8, Icons.poll_outlined, Icons.poll_rounded, 'Polls'),
    (9, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Wallet'),
    (10, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    (11, Icons.monetization_on_outlined, Icons.monetization_on_rounded, 'Creator'),
    (12, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages'),
    (13, Icons.call_outlined, Icons.call_rounded, 'Calls'),
    (14, Icons.list_alt_outlined, Icons.list_alt_rounded, 'Lists'),
  ];

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
      case TestagramDeepLinkKind.hashtag:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => HashtagScreen(api: widget.api, tag: link.tag!),
        ));
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

  void _selectDestination(int value) {
    if (value < 0 || value >= _destinations.length) return;
    setState(() {
      _index = value;
      _bottomBarVisible = true;
    });
  }

  bool _handleScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final direction = notification.direction;
    final shouldShow = notification.metrics.extentBefore <= 0 ||
        direction == ScrollDirection.forward;
    final shouldHide = direction == ScrollDirection.reverse &&
        notification.metrics.extentBefore > 0;
    if ((shouldShow && !_bottomBarVisible) ||
        (shouldHide && _bottomBarVisible)) {
      setState(() => _bottomBarVisible = shouldShow);
    }
    return false;
  }


  Widget _sidebarSection(String title, List<int> indexes) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 7),
          child: Text(title, style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          )),
        ),
        for (final index in indexes)
          Builder(builder: (context) {
            final item = _destinations[index];
            final selected = _index == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectDestination(index),
                  child: SizedBox(
                    height: 44,
                    child: Row(children: [
                      const SizedBox(width: 12),
                      Icon(selected ? item.$3 : item.$2,
                        size: 21,
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 13),
                      Expanded(child: Text(item.$4,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: selected ? theme.colorScheme.primary : null,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ))),
                      if (selected)
                        Container(
                          width: 3,
                          height: 22,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      const SizedBox(width: 10),
                    ]),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, bool extended) {
    return SizedBox(
      width: extended ? 275 : 88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TestagramBrandMark(size: 42, radius: 13),
                if (extended) ...[
                  const SizedBox(width: 12),
                  const Text('Testagram', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.7,
                  )),
                ],
              ],
            ),
          ),
          Expanded(
            child: extended
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sidebarSection('YOUR SPACE', const [0, 1, 2, 3, 4]),
                        const SizedBox(height: 12),
                        _sidebarSection('CONNECT', const [12, 13, 14, 7]),
                        const SizedBox(height: 12),
                        _sidebarSection('WATCH & CREATE', const [5, 6, 11, 8]),
                        const SizedBox(height: 12),
                        _sidebarSection('TOOLS', const [9, 10]),
                      ],
                    ),
                  )
                : NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _selectDestination,
                    extended: false,
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: -1,
                    minWidth: 76,
                    destinations: [
                      for (final item in _destinations)
                        NavigationRailDestination(
                          icon: Icon(item.$2),
                          selectedIcon: Icon(item.$3),
                          label: Text(item.$4),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildRightSidebar(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 350,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 18, 20, 24),
        children: [
          Text('Your space', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_sidebarProfile != null)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _selectDestination(4),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundImage: (_sidebarProfile!['avatar_url'] ?? '').toString().startsWith('http')
                          ? NetworkImage(_sidebarProfile!['avatar_url'].toString())
                          : null,
                      child: (_sidebarProfile!['avatar_url'] ?? '').toString().startsWith('http')
                          ? null : const Icon(Icons.person_outline_rounded),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((_sidebarProfile!['display_name'] ?? _sidebarProfile!['username'] ?? 'Your profile').toString(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                        Text('@${(_sidebarProfile!['username'] ?? '').toString()}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                      ],
                    )),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ]),
                ),
              ),
            )
          else if (_loadingSidebarContext)
            const LinearProgressIndicator(),
          const SizedBox(height: 18),
          Text('Explore Testagram', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.trending_up_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Trending hashtags', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh trends',
                      visualDensity: VisualDensity.compact,
                      onPressed: _loadingSidebarTrends ? null : _loadSidebarTrends,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ]),
                  if (_loadingSidebarTrends && _sidebarTrends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_sidebarTrends.isEmpty)
                    Text('Trending topics will appear here.',
                      style: theme.textTheme.bodySmall)
                  else
                    for (final trend in _sidebarTrends.take(8))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tag_rounded, size: 18),
                        title: Text(
                          '#${(trend['tag'] ?? trend['hashtag'] ?? trend['name'] ?? '').toString().replaceFirst(RegExp(r'^#'), '')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${trend['posts_count'] ?? trend['post_count'] ?? trend['count'] ?? ''} posts'),
                        onTap: () {
                          final tag = (trend['tag'] ?? trend['hashtag'] ?? trend['name'] ?? '').toString().replaceFirst(RegExp(r'^#'), '');
                          if (tag.isNotEmpty) {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => HashtagScreen(api: widget.api, tag: tag),
                            ));
                          }
                        },
                      ),
                ],
              ),
            ),
          ),
          if (_sidebarTrendingWords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 19),
                      const SizedBox(width: 8),
                      Text('Trending words', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 8),
                    for (final item in _sidebarTrendingWords.take(6))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.trending_up_rounded, size: 18),
                        title: Text((item['word'] ?? '').toString(),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item['posts_count'] ?? 0} posts'),
                        onTap: () => _selectDestination(1),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_sidebarSuggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          color: theme.colorScheme.primary, size: 19),
                      const SizedBox(width: 8),
                      Text('Who to follow', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 8),
                    for (final account in _sidebarSuggestions.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: (account['avatar_url'] ?? '').toString().startsWith('http')
                                ? NetworkImage(account['avatar_url'].toString())
                                : null,
                            child: (account['avatar_url'] ?? '').toString().startsWith('http')
                                ? null : const Icon(Icons.person_outline_rounded),
                          ),
                          const SizedBox(width: 9),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((account['display_name'] ?? account['username'] ?? 'Testagram member').toString(),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge),
                              Text('@${account['username'] ?? ''}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall),
                              if (((account['mutual_followers_count'] as num?)?.toInt() ?? 0) > 0)
                                Text('${account['mutual_followers_count']} mutual connections',
                                  style: theme.textTheme.bodySmall),
                            ],
                          )),
                          const SizedBox(width: 6),
                          FilledButton.tonal(
                            onPressed: _followingSuggestions.contains((account['id'] ?? '').toString()) ||
                                    account['is_following'] == true
                                ? null
                                : () => _followSuggestedAccount(account),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: _followingSuggestions.contains((account['id'] ?? '').toString())
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(account['follow_status'] == 'pending' ? 'Requested' :
                                    account['is_following'] == true ? 'Following' : 'Follow'),
                          ),
                        ]),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _selectDestination(1),
                        child: const Text('Discover more'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_sidebarKnowledgeTopics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_stories_rounded, color: theme.colorScheme.primary, size: 19),
                      const SizedBox(width: 8),
                      Text('Knowledge topics', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 6),
                    Text('Follow ideas worth learning about.',
                      style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    for (final topic in _sidebarKnowledgeTopics.take(6))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                        title: Text(
                          (topic['name'] ?? topic['slug'] ?? 'Topic').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (topic['description'] ?? '').toString().isEmpty
                            ? null
                            : Text(
                                topic['description'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () {
                          final slug = (topic['slug'] ?? '').toString().trim();
                          if (slug.isEmpty) {
                            _selectDestination(2);
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => KnowledgeTopicScreen(
                              api: widget.api,
                              slug: slug,
                            ),
                          ));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick access', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final item in const [
                    (1, Icons.travel_explore_rounded, 'Discover people'),
                    (7, Icons.forum_rounded, 'Join conversations'),
                    (8, Icons.poll_rounded, 'Community polls'),
                    (14, Icons.list_alt_rounded, 'Your lists'),
                  ])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.$2, size: 19),
                      title: Text(item.$3),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: () => _selectDestination(item.$1),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('A space for your ideas, communities and conversations.',
            style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      height: _bottomBarVisible
          ? 76 + MediaQuery.of(context).padding.bottom
          : 0,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: _bottomBarVisible ? 1 : 0,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 76,
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 8,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _destinations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 2),
                  itemBuilder: (context, position) {
                    final item = _destinations[position];
                    final selected = _index == item.$1;
                    final color = selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: item.$4,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _selectDestination(item.$1),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 68, maxWidth: 94),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(selected ? item.$3 : item.$2, color: color, size: 23),
                                const SizedBox(height: 4),
                                Text(item.$4, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
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
        SocialListsScreen(api: widget.api, onSignOut: widget.onSignOut),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        // Match X's desktop proportions: a stable navigation rail, a focused
        // ~600px conversation column, and a contextual discovery rail.
        // Keep the navigation compact until there is room for all three.
        final extended = constraints.maxWidth >= 1280;
        final showRightSidebar = constraints.maxWidth >= 1280;
        final content = TestagramBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: showRightSidebar ? 600 : TestagramTheme.contentMaxWidth),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        );

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: NotificationListener<UserScrollNotification>(
              onNotification: _handleScroll,
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSidebar(context, extended),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        Expanded(child: content),
                        if (showRightSidebar) ...[
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: Theme.of(context).dividerColor,
                          ),
                          _buildRightSidebar(context),
                        ],
                      ],
                    )
                  : content,
            ),
          ),
          bottomNavigationBar: desktop ? null : _buildBottomNavigation(context),
        );
      },
    );
  }
}
