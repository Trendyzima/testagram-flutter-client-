import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletTopUpAttempt {
  const WalletTopUpAttempt({
    required this.phone,
    required this.amountKes,
    required this.idempotencyKey,
  });

  final String phone;
  final int amountKes;
  final String idempotencyKey;

  Map<String, Object> toJson() => {
        'phone': phone,
        'amount_kes': amountKes,
        'idempotency_key': idempotencyKey,
      };

  static WalletTopUpAttempt? fromJson(Object? value) {
    if (value is! Map) return null;
    final phone = (value['phone'] ?? '').toString();
    final amount = value['amount_kes'];
    final key = (value['idempotency_key'] ?? '').toString();
    if (phone.isEmpty || amount is! int || amount < 10 || amount > 150000 ||
        key.length < 8 || key.length > 128) {
      return null;
    }
    return WalletTopUpAttempt(phone: phone, amountKes: amount, idempotencyKey: key);
  }
}

abstract interface class WalletTopUpAttemptStore {
  Future<WalletTopUpAttempt?> read();
  Future<void> save(WalletTopUpAttempt attempt);
  Future<void> clear();
}

/// Persists the exact M-Pesa request identity before any provider call.
/// A lost response can therefore be retried with the same server idempotency key.
class SecureWalletTopUpAttemptStore implements WalletTopUpAttemptStore {
  SecureWalletTopUpAttemptStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'testagram.wallet.mpesa.topup-attempt.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<WalletTopUpAttempt?> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      final attempt = WalletTopUpAttempt.fromJson(decoded);
      if (attempt == null) {
        throw const FormatException('Stored M-Pesa attempt is invalid');
      }
      return attempt;
    } on FormatException {
      // Do not silently discard an ambiguous payment attempt. Fail closed.
      rethrow;
    }
  }

  @override
  Future<void> save(WalletTopUpAttempt attempt) =>
      _storage.write(key: storageKey, value: jsonEncode(attempt.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

String? normalizeKenyanMpesaPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 12 &&
      digits.startsWith('254') &&
      (digits[3] == '7' || digits[3] == '1')) {
    return digits;
  }
  if (digits.length == 10 &&
      digits.startsWith('0') &&
      (digits[1] == '7' || digits[1] == '1')) {
    return '254${digits.substring(1)}';
  }
  if (digits.length == 9 && (digits[0] == '7' || digits[0] == '1')) {
    return '254$digits';
  }
  return null;
}
