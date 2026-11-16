import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/app.dart';
import 'package:testagram/core/app_config.dart';

void main() {
  testWidgets('uses canonical HTTPS defaults when no runtime overrides are supplied',
      (tester) async {
    await tester.pumpWidget(const TestagramApp());

    expect(AppConfig.isConfigured, isTrue);
    expect(
      find.textContaining('This build needs a valid HTTPS Backend URL'),
      findsNothing,
    );
  });
}
