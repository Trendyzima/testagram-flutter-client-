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
}
