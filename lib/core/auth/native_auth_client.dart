import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Testagram-owned authentication and rotating session client.
///
/// Only the refresh credential is persisted. Short-lived access tokens remain
/// in memory and are never written to browser local storage or preferences.
class NativeAuthClient {
  NativeAuthClient({
    required this.baseUri,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client();

  final Uri baseUri;
  final FlutterSecureStorage _storage;
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
    final response = await _http
        .post(
          _endpoint(action),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body ?? const <String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 15));
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
    _accessToken = access;
    _accessExpiresAt = DateTime.now().toUtc().add(Duration(seconds: expires));
    return value;
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _post('login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final data = _tokenData(response);
    await _storage.write(key: _refreshKey, value: data['refresh_token'] as String);
    return data;
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
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
      // Persist the rotated token before returning the access token. If secure
      // storage fails, fail closed rather than using an unrefreshable session.
      await _storage.write(
        key: _refreshKey,
        value: data['refresh_token'] as String,
      );
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

  Future<void> signOut() async {
    try {
      // Backend revocation is authorized by the short-lived access token,
      // not by submitting the refresh secret in a logout request body.
      final token = await accessToken();
      if (token != null) await _revokeWithBearer('logout', token);
    } finally {
      await _storage.delete(key: _refreshKey);
      _clearMemory();
    }
  }

  Future<void> signOutAll() async {
    try {
      final token = await accessToken();
      if (token != null) await _revokeWithBearer('logout-all', token);
    } finally {
      await _storage.delete(key: _refreshKey);
      _clearMemory();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _post('forgot-password', body: {
      'email': email.trim().toLowerCase(),
    });
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _post('reset-password', body: {
      'token': token,
      'password': password,
    });
    await _storage.delete(key: _refreshKey);
    _clearMemory();
  }

  Future<void> register({
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

  void _clearMemory() {
    _accessToken = null;
    _accessExpiresAt = null;
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
