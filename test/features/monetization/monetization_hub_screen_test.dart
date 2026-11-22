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

  testWidgets('lists the wallet and all planned monetization destinations',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MonetizationHubScreen(api: api)),
    );

    expect(find.text('Monetization'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Ad campaigns'), findsOneWidget);
    expect(find.text('Creator earnings'), findsOneWidget);
    expect(find.text('Premium membership'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('Promotions and boosts'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Gifts and tips'), findsOneWidget);
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
    expect(find.textContaining('not been simulated'), findsOneWidget);
  });
}
