import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_verification_client.dart';

abstract interface class IdentityApplicationSecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterIdentityApplicationSecureStorage
    implements IdentityApplicationSecureStorage {
  FlutterIdentityApplicationSecureStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// A recoverable registration draft. It deliberately excludes passwords,
/// native access or refresh tokens, raw evidence bytes and evidence object URLs.
class IdentityApplicationDraft {
  const IdentityApplicationDraft({
    required this.email,
    required this.username,
    required this.displayName,
    required this.idempotencyKey,
    required this.createdAt,
    this.application,
  });

  final String email;
  final String username;
  final String displayName;
  final String idempotencyKey;
  final DateTime createdAt;
  final IdentityApplication? application;

  IdentityApplicationDraft copyWith({
    IdentityApplication? application,
  }) {
    return IdentityApplicationDraft(
      email: email,
      username: username,
      displayName: displayName,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      application: application ?? this.application,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'email': email,
        'username': username,
        'display_name': displayName,
        'idempotency_key': idempotencyKey,
        'created_at': createdAt.toUtc().toIso8601String(),
        'application': application?.toJson(),
      };

  factory IdentityApplicationDraft.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported identity draft version.');
    }
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Identity draft is missing $key.');
      }
      return value;
    }

    final idempotencyKey = requiredString('idempotency_key');
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(idempotencyKey)) {
      throw const FormatException('Identity draft idempotency key is invalid.');
    }
    final createdAtRaw = requiredString('created_at');
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Identity draft timestamp is invalid.');
    }
    final rawApplication = json['application'];
    if (rawApplication != null && rawApplication is! Map<String, dynamic>) {
      throw const FormatException('Identity application credentials are invalid.');
    }
    return IdentityApplicationDraft(
      email: requiredString('email'),
      username: requiredString('username'),
      displayName: requiredString('display_name'),
      idempotencyKey: idempotencyKey,
      createdAt: createdAt.toUtc(),
      application: rawApplication == null
          ? null
          : IdentityApplication.fromJson(rawApplication),
    );
  }
}

class IdentityApplicationStore {
  IdentityApplicationStore({
    IdentityApplicationSecureStorage? storage,
  }) : _storage = storage ?? FlutterIdentityApplicationSecureStorage();

  static const _storageKey = 'testagram.identity_application.v1';

  final IdentityApplicationSecureStorage _storage;

  Future<IdentityApplicationDraft?> load() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Identity draft is not an object.');
      }
      return IdentityApplicationDraft.fromJson(decoded);
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  Future<void> save(IdentityApplicationDraft draft) async {
    await _storage.write(_storageKey, jsonEncode(draft.toJson()));
  }

  Future<void> clear() => _storage.delete(_storageKey);
}
