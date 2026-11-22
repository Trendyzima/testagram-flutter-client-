import 'package:material_ui/material_ui.dart';

/// Testagram's Quora-inspired knowledge destination.
///
/// This is intentionally a real, polished product shell—not a mock feed.
/// Questions, answers, topics and accepted-answer state must be supplied by
/// the native Backend knowledge contract before any records or composers are
/// rendered. Until then, every tab presents the same explicit integration
/// state and never invents content.
class KnowledgeHubScreen extends StatelessWidget {
  const KnowledgeHubScreen({super.key});

  static const _tabs = <String>[
    'For you',
    'Following',
    'Unanswered',
    'Your questions',
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Knowledge'),
          actions: [
            IconButton(
              tooltip: 'About Questions & Answers',
              onPressed: () => _showAbout(context),
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final label in _tabs) Tab(text: label)],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return TabBarView(
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  _KnowledgeUnavailableState(
                    title: _stateTitle(index),
                    description: _stateDescription(index),
                    compact: compact,
                  ),
              ],
            );
          },
        ),
        floatingActionButton: Tooltip(
          message: 'Question creation will be enabled when the knowledge API is ready',
          child: FloatingActionButton.extended(
            onPressed: null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ask a question'),
          ),
        ),
      ),
    );
  }

  static String _stateTitle(int index) => switch (index) {
        1 => 'Follow the topics you care about',
        2 => 'Help answer the open questions',
        3 => 'Your questions will live here',
        _ => 'A place for thoughtful answers',
      };

  static String _stateDescription(int index) => switch (index) {
        1 => 'Followed topics and their latest questions will appear here once the knowledge service is connected.',
        2 => 'Questions waiting for a useful answer will appear here. We will not show sample or invented questions.',
        3 => 'Questions you publish and their answer activity will be available here after Backend integration.',
        _ => 'Ask useful questions, share experience and build answers that last. Questions and answers stay distinct from posts and replies.',
      };

  static void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Testagram Knowledge',
      applicationVersion: 'Native Q&A experience',
      children: const [
        Text(
          'Testagram Questions & Answers is designed for focused questions, '
          'substantive answers, topic discovery, revisions and accepted answers. '
          'It will use Testagram authentication and Backend authorization; '
          'it will not create a separate account or identity system.',
        ),
      ],
    );
  }
}

class _KnowledgeUnavailableState extends StatelessWidget {
  const _KnowledgeUnavailableState({
    required this.title,
    required this.description,
    required this.compact,
  });

  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 22 : 48,
          vertical: 28,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 30,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.55,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.construction_outlined,
                            color: colors.secondary,
                            size: 21,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Knowledge service integration in progress',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Question lists, answer publishing, topic follows and accepted-answer actions stay unavailable until their authenticated Backend routes and privacy rules pass integration tests.',
                                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 17, color: colors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No demo questions. No fake answers. Your private activity stays private.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
