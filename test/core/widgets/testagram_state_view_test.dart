import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/widgets/testagram_state_view.dart';

void main() {
  group('TestagramStateView', () {
    testWidgets('announces and renders an empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestagramStateView(
              icon: Icons.inbox_outlined,
              title: 'Nothing here yet',
              message: 'Follow a few topics to get started.',
            ),
          ),
        ),
      );

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Follow a few topics to get started.'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('shows a loading indicator without an action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestagramStateView(
              icon: Icons.error_outline,
              title: 'Loading',
              message: 'Please wait.',
              loading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('runs a supplied retry action', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestagramStateView(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });
}
