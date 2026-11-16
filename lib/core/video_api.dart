import 'dart:convert';
import 'package:http/http.dart' as http;

/// Explicit client for the separately hosted Testagram video service.
class VideoApi {
  VideoApi({required this.baseUri, required this.getAccessToken, http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUri;
  final Future<String?> Function({bool forceRefresh}) getAccessToken;
  final http.Client _client;

  Future<List<Map<String, dynamic>>> feed() async {
    final response = await _client.get(baseUri.resolve('/v1/feed'),
        headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
    final decoded = _decode(response);
    if (decoded is! List) throw const VideoApiException('Invalid video feed response.');
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['id'] ?? '').toString().isNotEmpty &&
            e['status'] == 'ready' && e['visibility'] == 'public').toList();
  }

  Uri manifestUri(String id) => baseUri.resolve('/v1/videos/$id/manifest');

  Future<void> recordView(String id, String session) async {
    await _send('POST', '/v1/videos/$id/view',
        extraHeaders: {'X-Playback-Session': session});
  }

  Future<bool> like(String id) async {
    final result = await _send('POST', '/v1/videos/$id/like', auth: true);
    return result is Map && result['liked'] == true;
  }

  Future<List<Map<String, dynamic>>> comments(String id) async {
    final result = await _send('GET', '/v1/videos/$id/comments');
    if (result is! List) throw const VideoApiException('Invalid comments response.');
    return result.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addComment(String id, String body) async {
    final value = body.trim();
    if (value.isEmpty || value.length > 4000) {
      throw const VideoApiException('Comments must contain 1–4000 characters.');
    }
    await _send('POST', '/v1/videos/$id/comments',
        body: {'body': value}, auth: true);
  }

  Future<dynamic> _send(String method, String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    Map<String, String> extraHeaders = const {},
  }) async {
    final uri = baseUri.resolve(path);

    Future<http.Response> send({bool forceRefresh = false}) async {
      final headers = <String, String>{'Accept': 'application/json', ...extraHeaders};
      if (body != null) headers['Content-Type'] = 'application/json';
      if (auth) {
        final token = (await getAccessToken(forceRefresh: forceRefresh) ?? '').trim();
        if (token.isEmpty) {
          throw const VideoApiException('Sign in again to use this video action.');
        }
        headers['Authorization'] = 'Bearer $token';
      }
      if (method == 'GET') {
        return _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      }
      if (method == 'POST') {
        return _client.post(uri, headers: headers,
            body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 20));
      }
      throw ArgumentError.value(method, 'method');
    }

    var response = await send();
    if (auth && response.statusCode == 401) {
      // A single coordinated refresh/retry matches BackendApi's native session
      // behavior. Never loop on repeated unauthorized responses.
      response = await send(forceRefresh: true);
    }
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['error'] ?? decoded['message'] ?? 'Video request failed').toString()
          : 'Video request failed (${response.statusCode}).';
      throw VideoApiException(message, statusCode: response.statusCode);
    }
    return decoded;
  }

  void close() => _client.close();
}

class VideoApiException implements Exception {
  const VideoApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
