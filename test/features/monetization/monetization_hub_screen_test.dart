import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/monetization/monetization_hub_screen.dart';

void main() {
  late BackendApi api;

  setUp(() {
    api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => null,
    );
  });

  tearDown(() => api.close());

  testWidgets('lists the wallet and every planned monetization destination',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MonetizationHubScreen(api: api)),
    );

    expect(find.text('Monetization'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    for (final label in const [
      'Ad campaigns',
      'Creator earnings',
      'Premium membership',
      'Subscriptions',
      'Promotions and boosts',
      'Payouts',
      'Gifts and tips',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('invented earnings'), findsOneWidget);
  });

  testWidgets('unwired monetization destination fails closed with honest status',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MonetizationHubScreen(api: api)),
    );

    await tester.tap(find.text('Ad campaigns'));
    await tester.pumpAndSettle();

    expect(find.text('Backend integration required'), findsOneWidget);
    expect(find.textContaining('has been simulated'), findsOneWidget);
  });
}
