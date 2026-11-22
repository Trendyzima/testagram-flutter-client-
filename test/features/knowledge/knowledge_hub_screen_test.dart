import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/features/knowledge/knowledge_hub_screen.dart';

void main() {
  testWidgets('knowledge hub exposes the four Q&A discovery lanes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KnowledgeHubScreen()));

    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Unanswered'), findsOneWidget);
    expect(find.text('Your questions'), findsOneWidget);
    expect(find.text('A place for thoughtful answers'), findsOneWidget);
  });

  testWidgets('question creation stays disabled until Backend contracts exist',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KnowledgeHubScreen()));

    final composer = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(composer.onPressed, isNull);
    expect(find.text('Ask a question'), findsOneWidget);
    expect(
      find.textContaining('authenticated Backend routes'),
      findsOneWidget,
    );
  });

  testWidgets('each Q&A lane remains honest and does not fabricate records',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KnowledgeHubScreen()));

    await tester.tap(find.text('Unanswered'));
    await tester.pumpAndSettle();

    expect(find.text('Help answer the open questions'), findsOneWidget);
    expect(
      find.textContaining('will not show sample or invented questions'),
      findsOneWidget,
    );
  });

  testWidgets('knowledge information action is accessible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KnowledgeHubScreen()));

    final info = find.byTooltip('About Questions & Answers');
    expect(info, findsOneWidget);
    await tester.tap(info);
    await tester.pumpAndSettle();

    expect(find.textContaining('Testagram Questions & Answers'), findsOneWidget);
  });
}
