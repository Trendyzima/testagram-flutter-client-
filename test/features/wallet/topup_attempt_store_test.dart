import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/wallet/topup_attempt_store.dart';

void main() {
  group('M-Pesa top-up attempt safety', () {
    test('normalizes Kenyan Safaricom number formats to one canonical value', () {
      expect(normalizeKenyanMpesaPhone('0712 345 678'), '254712345678');
      expect(normalizeKenyanMpesaPhone('+254 712 345 678'), '254712345678');
      expect(normalizeKenyanMpesaPhone('712345678'), '254712345678');
      expect(normalizeKenyanMpesaPhone('0112 345 678'), '254112345678');
    });

    test('rejects invalid or non-Kenyan phone formats', () {
      for (final value in ['', '12345', '254612345678', '071234567', '07123456789']) {
        expect(normalizeKenyanMpesaPhone(value), isNull, reason: value);
      }
    });

    test('accepts only complete bounded stored attempts', () {
      final attempt = WalletTopUpAttempt.fromJson({
        'phone': '254712345678',
        'amount_kes': 500,
        'idempotency_key': 'topup-test-123',
      });
      expect(attempt?.phone, '254712345678');
      expect(attempt?.amountKes, 500);
      expect(attempt?.idempotencyKey, 'topup-test-123');

      expect(WalletTopUpAttempt.fromJson({
        'phone': '254712345678',
        'amount_kes': 9,
        'idempotency_key': 'topup-test-123',
      }), isNull);
    });
  });
}
