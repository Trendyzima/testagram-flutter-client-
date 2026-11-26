import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/monetization/creator_tip_screen.dart';
import 'package:testagram/features/monetization/monetization_hub_screen.dart';

void main() {
  test('creator tip uses the authenticated, idempotent wallet.tip capability', () async {
    late http.Request captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-testagram-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'ok': true,
          'data': {'transfer_id': 'tip-1', 'status': 'completed'},
        }), 200);
      }),
    );

    await api.tipWalletCreator(
      recipientId: '550e8400-e29b-41d4-a716-446655440000',
      amount: '25.00',
      note: 'Thank you',
      idempotencyKey: 'tip-attempt-0001',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/capability');
    expect(body['capability'], 'testagram.wallet.tip');
    expect(body['input'], {
      'recipient_id': '550e8400-e29b-41d4-a716-446655440000',
      'amount': '25.00',
      'note': 'Thank you',
      'idempotency_key': 'tip-attempt-0001',
    });
    expect(captured.headers['authorization'], 'Bearer native-testagram-token');
    api.close();
  });

  test('creator tip rejects malformed amounts before network access', () async {
    var requests = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'jwt',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => api.tipWalletCreator(
        recipientId: '550e8400-e29b-41d4-a716-446655440000',
        amount: '25.001',
        idempotencyKey: 'tip-attempt-0001',
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
    api.close();
  });

  testWidgets('Gifts and tips opens a real creator tip flow and sends after confirmation', (tester) async {
    final capabilities = <Map<String, dynamic>>[];
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getAccessToken: ({bool forceRefresh = false}) async => 'native-testagram-token',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final capability = body['capability'] as String;
        final input = Map<String, dynamic>.from(body['input'] as Map);
        capabilities.add({'capability': capability, 'input': input});
        if (capability == 'testagram.wallet.recipient.resolve') {
          return http.Response(jsonEncode({
            'user_id': '550e8400-e29b-41d4-a716-446655440000',
            'username': 'creator',
          }), 200);
        }
        if (capability == 'testagram.wallet.tip') {
          return http.Response(jsonEncode({
            'transfer_id': 'tip-1',
            'status': 'completed',
          }), 200);
        }
        return http.Response(jsonEncode({
          'ok': false,
          'error': {'code': 'UNEXPECTED_CAPABILITY', 'message': capability},
        }), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: MonetizationHubScreen(api: api)));
    await tester.scrollUntilVisible(
      find.text('Gifts and tips'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Gifts and tips'));
    await tester.pumpAndSettle();

    expect(find.byType(CreatorTipScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'creator');
    await tester.enterText(find.byType(TextField).at(1), '25');
    await tester.enterText(find.byType(TextField).at(2), 'Great work!');
    await tester.tap(find.text('Review and send tip'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm creator tip'), findsOneWidget);
    expect(find.text('Send KES 25.00 to @creator?'), findsOneWidget);
    await tester.tap(find.text('Send tip'));
    await tester.pumpAndSettle();

    expect(capabilities.map((item) => item['capability']), [
      'testagram.wallet.recipient.resolve',
      'testagram.wallet.tip',
    ]);
    final tipInput = capabilities.last['input'] as Map<String, dynamic>;
    expect(tipInput['recipient_id'], '550e8400-e29b-41d4-a716-446655440000');
    expect(tipInput['amount'], '25.00');
    expect(tipInput['note'], 'Great work!');
    expect((tipInput['idempotency_key'] as String).length, 32);
    expect(find.textContaining('tip to @creator was sent'), findsOneWidget);
    api.close();
  });
}
