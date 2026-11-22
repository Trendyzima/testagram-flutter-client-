import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/features/knowledge/knowledge_hub_screen.dart';

void main() {
  testWidgets('knowledge hub explains the Backend integration state honestly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: KnowledgeHubScreen()),
    );

    expect(find.text('Questions & Answers'), findsOneWidget);
    expect(find.text('A place for real answers'), findsOneWidget);
    expect(find.text('Backend integration in progress'), findsOneWidget);
    expect(find.textContaining('not be disguised as posts or replies'), findsOneWidget);
  });

  testWidgets('knowledge hub has an accessible information action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: KnowledgeHubScreen()),
    );

    final info = find.byTooltip('About the knowledge hub');
    expect(info, findsOneWidget);
    await tester.tap(info);
    await tester.pumpAndSettle();

    expect(find.textContaining('native knowledge service'), findsOneWidget);
  });
}
