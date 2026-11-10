import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/wallet/transfer_idempotency.dart';

void main() {
  group('WalletTransferAttempt', () {
    const fingerprint = 'same-transfer-intent';
    var generated = 0;

    String generateKey() {
      generated++;
      return 'key-$generated';
    }

    setUp(() {
      generated = 0;
    });

    test('reuses the same idempotency key when the same transfer is retried', () {
      final attempt = WalletTransferAttempt();

      final first = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );
      final retry = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );

      expect(first, 'key-1');
      expect(retry, first);
      expect(generated, 1);
    });

    test('creates a new key when the transfer intent changes', () {
      final attempt = WalletTransferAttempt();

      final first = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );
      final second = attempt.keyFor(
        fingerprint: 'different-transfer-intent',
        generateKey: generateKey,
      );

      expect(first, 'key-1');
      expect(second, 'key-2');
      expect(generated, 2);
    });

    test('clears a successful attempt so a new intentional transfer gets a new key', () {
      final attempt = WalletTransferAttempt();

      final first = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );
      attempt.complete(fingerprint);
      final next = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );

      expect(first, 'key-1');
      expect(next, 'key-2');
      expect(generated, 2);
    });

    test('does not clear a different pending transfer', () {
      final attempt = WalletTransferAttempt();
      final first = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );

      attempt.complete('different-transfer-intent');

      final retry = attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: generateKey,
      );

      expect(retry, first);
      expect(generated, 1);
    });
  });

  group('walletTransferFingerprint', () {
    test('normalizes amount, currency and surrounding whitespace', () {
      final first = walletTransferFingerprint(
        recipientId: ' recipient-1 ',
        amount: ' 100.00 ',
        currency: 'kes',
        note: ' lunch ',
      );
      final second = walletTransferFingerprint(
        recipientId: 'recipient-1',
        amount: '100.00',
        currency: 'KES',
        note: 'lunch',
      );

      expect(first, second);
    });

    test('changes when any transfer payload value changes', () {
      final original = walletTransferFingerprint(
        recipientId: 'recipient-1',
        amount: '100.00',
        currency: 'KES',
        note: 'lunch',
      );
      final changed = walletTransferFingerprint(
        recipientId: 'recipient-1',
        amount: '101.00',
        currency: 'KES',
        note: 'lunch',
      );

      expect(original, isNot(changed));
    });
  });
}
