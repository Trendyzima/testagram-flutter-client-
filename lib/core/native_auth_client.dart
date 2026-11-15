import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Backend-owned authentication client.
///
/// Access and refresh tokens are stored only in the platform secure store.
/// The client rotates refresh tokens before expiry and never places tokens in
/// URLs, logs, analytics, or exception messages.
class NativeAuthClient {
  NativeAuthClient({
    required this.baseUri,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client() {
    if (baseUri.scheme != 'https' || baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty || baseUri.hasQuery || baseUri.hasFragment) {
      throw ArgumentError.value(baseUri, 'baseUri', 'A clean HTTPS API origin is required.');
    }
  }

  final Uri baseUri;
  final FlutterSecureStorage _storage;
  final http.Client _http;

  static const _accessKey = 'testagram.native.access.v1';
  static const _refreshKey = 'testagram.native.refresh.v1';
  static const _expiresKey = 'testagram.native.expires_at.v1';
  static const _refreshSkew = Duration(seconds: 60);
  Future<String?>? _refreshInFlight;

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _post('login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final user = _userFrom(result);
    await _saveSession(result);
    return user;
  }

  Future<void> requestPasswordReset(String email) async {
    await _post('forgot-password', {'email': email.trim().toLowerCase()});
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _post('reset-password', {'token': token, 'password': password});
    await clearSession();
  }

  /// Returns a valid access token, rotating the refresh token when necessary.
  /// A null result means there is no stored session.
  Future<String?> accessToken() async {
    final refresh = await _storage.read(key: _refreshKey);
    final access = await _storage.read(key: _accessKey);
    final expiresRaw = await _storage.read(key: _expiresKey);
    if (refresh == null || refresh.isEmpty || expiresRaw == null) {
      await clearSession();
      return null;
    }

    final expires = DateTime.tryParse(expiresRaw)?.toUtc();
    if (expires == null) {
      await clearSession();
      return null;
    }
    if (access != null && access.isNotEmpty &&
        DateTime.now().toUtc().add(_refreshSkew).isBefore(expires)) {
      return access;
    }

    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final rotation = _rotateRefresh(refresh);
    _refreshInFlight = rotation;
    try {
      return await rotation;
    } finally {
      if (identical(_refreshInFlight, rotation)) _refreshInFlight = null;
    }
  }

  Future<String> _rotateRefresh(String refresh) async {
    try {
      final result = await _post('refresh', {'refresh_token': refresh});
      await _saveSession(result);
      final rotated = (result['access_token'] ?? '').toString();
      if (rotated.isEmpty) {
        throw const NativeAuthException('The Backend returned an incomplete session.');
      }
      return rotated;
    } on NativeAuthException {
      await clearSession();
      rethrow;
    }
  }

  Future<void> signOut({bool everywhere = false}) async {
    try {
      final token = await accessToken();
      if (token != null) {
        await _post(
          everywhere ? 'logout-all' : 'logout',
          const {},
          bearer: token,
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _expiresKey),
    ]);
  }

  Future<void> _saveSession(Map<String, dynamic> result) async {
    final access = (result['access_token'] ?? '').toString();
    final refresh = (result['refresh_token'] ?? '').toString();
    final expiresIn = result['expires_in'];
    if (access.isEmpty || access.length > 8192 || refresh.length < 32 ||
        refresh.length > 256 || expiresIn is! num ||
        expiresIn <= 0 || expiresIn > 3600) {
      throw const NativeAuthException('The Backend returned an invalid session.');
    }
    final expires = DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()));
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    await _storage.write(key: _expiresKey, value: expires.toIso8601String());
  }

  Map<String, dynamic> _userFrom(Map<String, dynamic> result) {
    final user = result['user'];
    if (user is! Map) {
      throw const NativeAuthException('The Backend returned an invalid account.');
    }
    return Map<String, dynamic>.from(user);
  }

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    final uri = baseUri.resolve('/api/auth/$action');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (bearer != null) headers['Authorization'] = 'Bearer $bearer';

    late final http.Response response;
    try {
      response = await _http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const NativeAuthException('The authentication service timed out. Please try again.');
    } on http.ClientException {
      throw const NativeAuthException('Could not reach Testagram. Check your connection.');
    }

    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      envelope = Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const NativeAuthException('The authentication service returned an invalid response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300 ||
        envelope['ok'] != true) {
      final rawError = envelope['error'];
      final error = rawError is Map ? Map<String, dynamic>.from(rawError) : <String, dynamic>{};
      final code = (error['code'] ?? '').toString();
      final message = (error['message'] ?? envelope['message'] ??
          'Authentication request failed.').toString();
      throw NativeAuthException(
        message,
        statusCode: response.statusCode,
        code: code,
      );
    }

    final rawData = envelope['data'];
    if (rawData is Map) return Map<String, dynamic>.from(rawData);
    return envelope;
  }

  void close() => _http.close();
}

class NativeAuthException implements Exception {
  const NativeAuthException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}
