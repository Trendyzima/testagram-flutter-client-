import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// UI-facing contract so auth screens and gates do not depend on a
/// particular transport implementation.
abstract interface class NativeAuthStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterNativeAuthStorage implements NativeAuthStorage {
  FlutterNativeAuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

abstract interface class NativeAuthSession {
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  });
  Future<void> resendVerification(String email);
  Future<void> verifyEmail(String token, {String? email});
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  });
  Future<String?> accessToken({bool forceRefresh = false});
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String token,
    required String password,
  });
}

/// Testagram-owned authentication and rotating session client.
///
/// Only the refresh credential is persisted. Short-lived access tokens remain
/// in memory and are never written to browser local storage or preferences.
class NativeAuthClient implements NativeAuthSession {
  NativeAuthClient({
    required this.baseUri,
    NativeAuthStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? FlutterNativeAuthStorage(),
        _http = httpClient ?? http.Client();

  final Uri baseUri;
  final NativeAuthStorage _storage;
  final http.Client _http;

  static const _refreshKey = 'testagram.auth.refresh.v1';
  String? _accessToken;
  DateTime? _accessExpiresAt;
  Future<String?>? _refreshInFlight;
  bool _closed = false;

  Uri _endpoint(String action) => baseUri.resolve('/api/auth/$action');

  Future<Map<String, dynamic>> _post(
    String action, {
    Map<String, dynamic>? body,
  }) async {
    if (_closed) throw StateError('Authentication client is closed.');
    late final http.Response response;
    try {
      response = await _http
          .post(
            _endpoint(action),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          // The edge recovery path can spend up to 40 seconds resolving a
          // provider lifecycle operation, then up to 20 seconds confirming
          // authenticated PostgreSQL/application readiness. Keep the original
          // request alive long enough to receive the explicit ready marker;
          // this does not replay login credentials or change user intent.
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const NativeAuthException(
        'Testagram is taking longer than expected to respond. Wait a moment and retry.',
        code: 'API_ORIGIN_TIMEOUT',
      );
    } on http.ClientException {
      throw const NativeAuthException(
        'Testagram could not be reached. Check your connection and try again.',
        code: 'API_ORIGIN_UNAVAILABLE',
      );
    }

    // This distinct marker is emitted only after the edge has separately
    // confirmed the provider machine and authenticated PostgreSQL readiness.
    // Do not replay login here: keep the user's form intent in the UI and let
    // the user retry the same action once the ready signal is visible.
    if (response.statusCode == 503 &&
        response.headers['x-testagram-recovery'] == 'ready') {
      throw const NativeAuthException(
        'Testagram is awake and its application database is ready. Retry sign-in to continue.',
        statusCode: 503,
        code: 'API_ORIGIN_RETRY_READY',
      );
    }

    // A recovery marker means the edge tried to reach the origin but it was
    // unavailable while waking. Login creates a new session, so never replay
    // this POST automatically; let the user retry after the machine is ready.
    if (response.statusCode == 503 &&
        response.headers['x-testagram-recovery'] == 'attempted') {
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      final wait = retryAfter != null && retryAfter > 0
          ? ' Wait about $retryAfter seconds, then retry.'
          : ' Wait a moment, then retry.';
      throw NativeAuthException(
        'Testagram is waking up.$wait',
        statusCode: 503,
        code: 'API_ORIGIN_WAKING',
      );
    }

    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } catch (_) {
      throw const NativeAuthException(
        'Testagram returned an invalid authentication response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        decoded['ok'] != true) {
      final error = decoded['error'];
      final code = error is Map ? error['code']?.toString() : null;
      final message = error is Map ? error['message']?.toString() : null;
      throw NativeAuthException(
        message?.isNotEmpty == true
            ? message!
            : 'Authentication failed. Please try again.',
        statusCode: response.statusCode,
        code: code,
      );
    }
    return decoded;
  }

  Map<String, dynamic> _tokenData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const NativeAuthException(
        'Testagram did not return a valid session.',
      );
    }
    final value = Map<String, dynamic>.from(data);
    final access = value['access_token'];
    final refresh = value['refresh_token'];
    final expires = value['expires_in'];
    if (access is! String || access.length < 32 ||
        refresh is! String || refresh.length < 40 ||
        expires is! int || expires < 60 || expires > 3600) {
      throw const NativeAuthException(
        'Testagram returned an incomplete or unsafe session.',
      );
    }
    return value;
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    try {
      await _storage.write(key: _refreshKey, value: data['refresh_token'] as String);
    } catch (_) {
      try {
        await _storage.delete(key: _refreshKey);
      } catch (_) {}
      _clearMemory();
      throw const NativeAuthException(
        'Secure session storage is unavailable. Sign in again after restoring device storage.',
      );
    }
    _accessToken = data['access_token'] as String;
    _accessExpiresAt = DateTime.now().toUtc().add(
      Duration(seconds: data['expires_in'] as int),
    );
  }

  @override
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  }) async {
    await _post('signup', body: {
      'email': email.trim().toLowerCase(),
      'username': username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
      'password': password,
    });
  }

  @override
  Future<void> resendVerification(String email) async {
    await _post('resend-verification', body: {'email': email.trim().toLowerCase()});
  }

  @override
  Future<void> verifyEmail(String token, {String? email}) async {
    await _post('verify-email', body: {
      'token': token,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _post('login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final data = _tokenData(response);
    await _persistSession(data);
    return data;
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _accessToken = null;
      _accessExpiresAt = null;
    }
    final expiry = _accessExpiresAt;
    if (!forceRefresh &&
        _accessToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 60)))) {
      return _accessToken;
    }
    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _refresh() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null || refresh.isEmpty) {
      _clearMemory();
      return null;
    }
    try {
      final response = await _post('refresh', body: {'refresh_token': refresh});
      final data = _tokenData(response);
      // Persist the rotated refresh token before exposing its access token.
      await _persistSession(data);
      return _accessToken;
    } on NativeAuthException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _storage.delete(key: _refreshKey);
        _clearMemory();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _revokeWithBearer(String action, String token) async {
    final response = await _http
        .post(
          _endpoint(action),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NativeAuthException(
        'Testagram could not confirm session revocation.',
        statusCode: response.statusCode,
        code: 'SESSION_REVOKE_FAILED',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        throw const FormatException();
      }
    } catch (_) {
      throw const NativeAuthException(
        'Testagram returned an invalid session-revocation response.',
        code: 'SESSION_REVOKE_FAILED',
      );
    }
  }

  Future<void> _revokeAndClear(String action) async {
    // Do not destroy the only retry credential when the Backend is unreachable.
    // A 401/403 means the server already considers this session unusable; all
    // other failures must be surfaced so the caller can retry revocation.
    final token = await accessToken();
    if (token != null) {
      try {
        await _revokeWithBearer(action, token);
      } on NativeAuthException catch (error) {
        if (error.statusCode != 401 && error.statusCode != 403) rethrow;
      }
    }
    _clearMemory();
    await _storage.delete(key: _refreshKey);
  }

  @override
  Future<void> signOut() => _revokeAndClear('logout');

  Future<void> signOutAll() => _revokeAndClear('logout-all');

  @override
  Future<void> requestPasswordReset(String email) async {
    await _post('forgot-password', body: {
      'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _post('reset-password', body: {
      'token': token,
      'password': password,
    });
    try {
      await _storage.delete(key: _refreshKey);
    } finally {
      _clearMemory();
    }
  }

  void _clearMemory() {
    _accessToken = null;
    _accessExpiresAt = null;
  }

  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _refreshKey);
    } finally {
      _clearMemory();
    }
  }

  void close() {
    _closed = true;
    _clearMemory();
    _http.close();
  }
}

class NativeAuthException implements Exception {
  const NativeAuthException(
    this.message, {
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}
