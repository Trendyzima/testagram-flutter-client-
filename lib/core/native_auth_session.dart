import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class NativeAuthTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureNativeAuthTokenStore implements NativeAuthTokenStore {
  SecureNativeAuthTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class NativeAuthException implements Exception {
  const NativeAuthException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// Native Testagram credentials and rotating session lifecycle.
///
/// Only the refresh credential is long-lived. Both credentials are held in
/// platform secure storage; the Backend stores only a SHA-256 digest of the
/// refresh token. Appwrite credentials are never read or forwarded here.
class NativeAuthSession {
  NativeAuthSession({
    required this.backendOrigin,
    NativeAuthTokenStore? tokenStore,
    http.Client? client,
    DateTime Function()? clock,
  })  : _store = tokenStore ?? SecureNativeAuthTokenStore(),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _clock = clock ?? DateTime.now;

  final Uri backendOrigin;
  final NativeAuthTokenStore _store;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;

  static const _accessKey = 'testagram.native.access.v1';
  static const _refreshKey = 'testagram.native.refresh.v1';
  static const _expiryKey = 'testagram.native.expiry.v1';

  Future<String>? _refreshInFlight;

  Future<void> signIn({required String email, required String password}) async {
    final result = await _post('/api/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    await _persist(result);
  }

  Future<String> getAccessToken({bool forceRefresh = false}) async {
    final access = await _store.read(_accessKey);
    final expiryRaw = await _store.read(_expiryKey);
    final expiry = expiryRaw == null ? null : DateTime.tryParse(expiryRaw);
    if (!forceRefresh &&
        access != null &&
        access.isNotEmpty &&
        expiry != null &&
        expiry.isAfter(_clock().toUtc().add(const Duration(seconds: 60)))) {
      return access;
    }
    final refresh = await _store.read(_refreshKey);
    if (refresh == null || refresh.isEmpty) {
      await clear();
      throw const NativeAuthException('Sign in to continue.');
    }
    return _refresh(refresh);
  }

  Future<String> _refresh(String refreshToken) {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final pending = _refreshOnce(refreshToken);
    _refreshInFlight = pending;
    return pending.whenComplete(() {
      if (identical(_refreshInFlight, pending)) _refreshInFlight = null;
    });
  }

  Future<String> _refreshOnce(String refreshToken) async {
    try {
      final result = await _post('/api/auth/refresh', {
        'refresh_token': refreshToken,
      });
      await _persist(result);
      return result['access_token'] as String;
    } catch (_) {
      // An ambiguous rotation must not leave the old refresh credential
      // available for reuse: the server may already have consumed it.
      await clear();
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _post('/api/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _post('/api/auth/reset-password', {
      'token': token,
      'password': newPassword,
    });
    await clear();
  }

  Future<void> signOut({bool allSessions = false}) async {
    try {
      final token = await getAccessToken();
      await _post(
        allSessions ? '/api/auth/logout-all' : '/api/auth/logout',
        const {},
        bearer: token,
      );
    } finally {
      await clear();
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _store.delete(_accessKey),
      _store.delete(_refreshKey),
      _store.delete(_expiryKey),
    ]);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            backendOrigin.resolve(path),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (bearer != null) 'Authorization': 'Bearer $bearer',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const NativeAuthException('Authentication request timed out. Retry.');
    } on http.ClientException {
      throw const NativeAuthException('Cannot reach Testagram. Check your connection.');
    }

    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } on FormatException {
      throw NativeAuthException('Authentication service returned an invalid response.',
          statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawError = decoded['error'];
      final error = rawError is Map ? Map<String, dynamic>.from(rawError) : const <String, dynamic>{};
      throw NativeAuthException(
        (error['message'] ?? decoded['message'] ?? 'Authentication failed.').toString(),
        statusCode: response.statusCode,
        code: error['code']?.toString(),
      );
    }

    final rawData = decoded['data'];
    if (rawData is Map) return Map<String, dynamic>.from(rawData);
    return decoded;
  }

  Future<void> _persist(Map<String, dynamic> result) async {
    final access = result['access_token'];
    final refresh = result['refresh_token'];
    final expiresIn = result['expires_in'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.length < 40 ||
        expiresIn is! int ||
        expiresIn < 60 ||
        expiresIn > 3600) {
      throw const NativeAuthException('Backend returned an invalid native session.');
    }
    final expiry = _clock().toUtc().add(Duration(seconds: expiresIn));
    try {
      await _store.write(_accessKey, access);
      await _store.write(_expiryKey, expiry.toIso8601String());
      // Write the rotated refresh token last. If any write fails, clear the
      // incomplete local session; never reuse a consumed refresh token.
      await _store.write(_refreshKey, refresh);
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
