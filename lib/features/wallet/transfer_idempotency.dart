import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Tracks a transfer intent so retries reuse the same Backend idempotency key.
///
/// The fingerprint excludes mutable UI state and includes every value that
/// determines the server-side transfer payload.
String walletTransferFingerprint({
  required String recipientId,
  required String amount,
  required String currency,
  required String note,
}) {
  final intent = <String>[
    recipientId.trim(),
    amount.trim(),
    currency.trim().toUpperCase(),
    note.trim(),
  ];
  return sha256.convert(utf8.encode(jsonEncode(intent))).toString();
}

class WalletTransferAttempt {
  String? _fingerprint;
  String? _idempotencyKey;

  String keyFor({
    required String fingerprint,
    required String Function() generateKey,
  }) {
    if (_fingerprint != fingerprint || _idempotencyKey == null) {
      _fingerprint = fingerprint;
      _idempotencyKey = generateKey();
    }
    return _idempotencyKey!;
  }

  /// Clear only the matching attempt after the Backend confirms success.
  void complete(String fingerprint) {
    if (_fingerprint != fingerprint) return;
    _fingerprint = null;
    _idempotencyKey = null;
  }
}
