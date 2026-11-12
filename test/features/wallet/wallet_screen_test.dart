import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/wallet/wallet_screen.dart';

void main() {
  testWidgets('wallet shows KES balance and M-Pesa deposit action', (tester) async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final capability = body['capability'];
      if (capability == 'testagram.wallet.balance') {
        return http.Response(jsonEncode({
          'id': 'member-1',
          'balance': '250.00',
          'currency': 'KES',
          'status': 'active',
        }), 200);
      }
      if (capability == 'testagram.wallet.transactions.list') {
        return http.Response(jsonEncode({'items': []}), 200);
      }
      return http.Response('{}', 404);
    });
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'test-jwt',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(home: WalletScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('KES 250.00'), findsOneWidget);
    expect(find.text('Add with M-Pesa'), findsOneWidget);
    expect(find.text('Send money'), findsOneWidget);
    api.close();
  });
  testWidgets('wallet rejects transfers with more than two decimal places', (tester) async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['capability'] == 'testagram.wallet.balance') {
        return http.Response(jsonEncode({
          'id': 'member-1',
          'balance': '250.00',
          'currency': 'KES',
          'status': 'active',
        }), 200);
      }
      if (body['capability'] == 'testagram.wallet.transactions.list') {
        return http.Response(jsonEncode({'items': []}), 200);
      }
      return http.Response('{}', 404);
    });
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'test-jwt',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(home: WalletScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send money'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'recipient');
    await tester.enterText(find.byType(TextField).at(1), '10000.001');
    await tester.tap(find.text('Review transfer'));
    await tester.pumpAndSettle();

    expect(find.text('Review transfer'), findsOneWidget);
    expect(find.text('Confirm transfer'), findsNothing);
    api.close();
  });

  testWidgets('wallet restores a pending M-Pesa deposit from transaction history', (tester) async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['capability'] == 'testagram.wallet.balance') {
        return http.Response(jsonEncode({
          'id': 'member-1',
          'balance': '250.00',
          'currency': 'KES',
          'status': 'active',
        }), 200);
      }
      if (body['capability'] == 'testagram.wallet.transactions.list') {
        return http.Response(jsonEncode({
          'items': [{
            'kind': 'deposit',
            'status': 'pending',
            'provider': 'mpesa',
            'checkout_request_id': 'ws_CO_pending_123',
            'amount_kes': '500',
            'amount': '500.00',
            'currency': 'KES',
          }],
        }), 200);
      }
      return http.Response('{}', 404);
    });
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'test-jwt',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(home: WalletScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('M-Pesa deposit pending · KES 500'), findsOneWidget);
    expect(find.text('Check status'), findsOneWidget);
    api.close();
  });

}
