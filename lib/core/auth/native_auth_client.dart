import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

/// Optional UI status exposed while the public InstaBox port resumes.
abstract interface class NativeAuthWakeAware {
  ValueListenable<String?> get wakeStatus;
}

/// Testagram-owned authentication and rotating session client.
///
/// Only the refresh credential is persisted. Short-lived access tokens remain
/// in memory and are never written to browser local storage or preferences.
class NativeAuthClient implements NativeAuthSession, NativeAuthWakeAware {
  NativeAuthClient({
    required this.baseUri,
    NativeAuthStorage? storage,
    http.Client? httpClient,
    Future<void> Function(Duration delay)? waitBeforeWakeRetry,
  })  : _storage = storage ?? FlutterNativeAuthStorage(),
        _http = httpClient ?? http.Client(),
        _waitBeforeWakeRetry =
            waitBeforeWakeRetry ?? ((delay) => Future<void>.delayed(delay));

  final Uri baseUri;
  final NativeAuthStorage _storage;
  final http.Client _http;
  final Future<void> Function(Duration delay) _waitBeforeWakeRetry;
  final ValueNotifier<String?> _wakeStatus = ValueNotifier<String?>(null);

  @override
  ValueListenable<String?> get wakeStatus => _wakeStatus;

  static const _refreshKey = 'testagram.auth.refresh.v1';
  static const _requestTimeout = Duration(seconds: 60);
  static const _wakeRetryWindow = Duration(seconds: 120);
  static const _maxWakeRetries = 12;
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
    final response = await _postWithWakeRecovery(
      action,
      body ?? const <String, dynamic>{},
    );
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } catch (_) {
      throw NativeAuthException(
        'Testagram returned an invalid authentication response.',
        statusCode: response.statusCode,
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

  /// A public InstaBox HTTP port automatically resumes a machine paused by
  /// inactivity. If it has not resumed within the proxy's 45-second wait, the
  /// proxy returns its specific 503 wake response and Retry-After. Retry only
  /// that response; never retry ordinary application 503s or manual stops.
  Future<http.Response> _postWithWakeRecovery(
    String action,
    Map<String, dynamic> body,
  ) async {
    final uri = _endpoint(action);
    final deadline = DateTime.now().add(_wakeRetryWindow);
    var retries = 0;
    _wakeStatus.value = (action == 'login' || action == 'refresh')
        ? 'Connecting to Testagram…'
        : null;

    try {
      while (true) {
        final response = await _http
            .post(
              uri,
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(_requestTimeout);

        final retryDelay = _instaBoxWakeRetryDelay(response);
        if (retryDelay == null) return response;

        if (retries >= _maxWakeRetries ||
            DateTime.now().add(retryDelay).isAfter(deadline)) {
          throw const NativeAuthException(
            'Testagram is still waking up. Please wait a moment and try again; your credentials have not been rejected.',
            statusCode: 503,
            code: 'SANDBOX_WAKING_UP',
          );
        }

        retries++;
        _wakeStatus.value = 'Waking Testagram… reconnecting automatically.';
        await _waitBeforeWakeRetry(retryDelay);
      }
    } finally {
      _wakeStatus.value = null;
    }
  }

  Duration? _instaBoxWakeRetryDelay(http.Response response) {
    if (response.statusCode != 503) return null;
    final body = response.body.toLowerCase();
    if (!body.contains('waking up') ||
        (!body.contains('sandbox') && !body.contains('machine'))) {
      return null;
    }

    final retryAfter = int.tryParse(response.headers['retry-after']?.trim() ?? '');
    // InstaBox currently sends Retry-After as whole seconds. Respect the
    // complete value: capping it at 15 seconds would retry earlier than the
    // provider requested and can amplify load during a slow resume.
    final seconds = retryAfter != null && retryAfter > 0 ? retryAfter : 2;
    return Duration(seconds: seconds);
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

  @override
  Future<void> signOut() async {
    try {
      // Backend revocation is authorized by the short-lived access token,
      // not by submitting the refresh secret in a logout request body.
      final token = await accessToken();
      if (token != null) await _revokeWithBearer('logout', token);
    } finally {
      _clearMemory();
      await _storage.delete(key: _refreshKey);
    }
  }

  Future<void> signOutAll() async {
    try {
      final token = await accessToken();
      if (token != null) await _revokeWithBearer('logout-all', token);
    } finally {
      _clearMemory();
      await _storage.delete(key: _refreshKey);
    }
  }

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
    _wakeStatus.dispose();
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
