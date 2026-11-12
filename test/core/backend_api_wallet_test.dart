import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:testagram/core/backend_api.dart';

void main() {
  test('M-Pesa top-up uses the Backend capability with KES and idempotency', () async {
    http.Request? captured;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'session-jwt',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'pending',
            'checkout_request_id': 'ws_CO_123456789',
          }),
          202,
        );
      }),
    );

    final result = await api.requestMpesaTopUp(
      phone: '0712345678',
      amountKes: 500,
      idempotencyKey: 'topup-test-123',
    );

    expect(result['status'], 'pending');
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/api/capability');
    expect(captured!.headers['Authorization'], 'Bearer session-jwt');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['capability'], 'testagram.wallet.mpesa.stk_push');
    expect(body['input'], {
      'phone': '0712345678',
      'amount_kes': 500,
      'currency': 'KES',
      'idempotency_key': 'topup-test-123',
    });
    api.close();
  });

  test('M-Pesa top-up rejects out-of-range amounts before network access', () async {
    var requests = 0;
    final api = BackendApi(
      baseUri: Uri.parse('https://api.testagram.site'),
      getJwt: () async => 'session-jwt',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );

    expect(
      () => api.requestMpesaTopUp(
        phone: '0712345678',
        amountKes: 9,
        idempotencyKey: 'topup-test-123',
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
    api.close();
  });
}
