import 'package:material_ui/material_ui.dart';

/// Honest entry point for Testagram's knowledge experience.
///
/// Question and answer data must come from the native Backend knowledge API.
/// Until its authenticated handlers and client transport are available, this
/// screen deliberately does not fabricate questions or accept submissions.
class KnowledgeHubScreen extends StatelessWidget {
  const KnowledgeHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Questions & Answers'),
          actions: [
            IconButton(
              tooltip: 'About the knowledge hub',
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Testagram',
                children: const [
                  Text(
                    'Questions and answers are being connected to Testagram’s '
                    'native knowledge service. Your questions and answers will '
                    'be separate from social posts and replies.',
                  ),
                ],
              ),
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 38,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'A place for real answers',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The Testagram knowledge hub is being connected to its '
                    'native Backend. Questions, answers, topics and accepted '
                    'answers will have their own experience—not be disguised '
                    'as posts or replies.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  const Chip(
                    avatar: Icon(Icons.lock_outline_rounded, size: 17),
                    label: Text('Backend integration in progress'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
