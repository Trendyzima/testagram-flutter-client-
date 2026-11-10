import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/app.dart';

void main() {
  testWidgets('shows the configuration guidance when runtime settings are absent',
      (tester) async {
    await tester.pumpWidget(const TestagramApp());

    expect(find.text('Testagram'), findsOneWidget);
    expect(
      find.textContaining('This build needs an Appwrite endpoint'),
      findsOneWidget,
    );
  });
}
