import 'dart:convert';
import 'package:http/http.dart' as http;

/// Explicit client for the separately hosted Testagram video service.
class VideoApi {
  VideoApi({required this.baseUri, required this.getAccessToken, http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUri;
  final Future<String?> Function({bool forceRefresh}) getAccessToken;
  final http.Client _client;

  Future<List<Map<String, dynamic>>> channels() async {
    final result = await _send('GET', '/v1/channels', auth: true);
    if (result is! Map || result['items'] is! List) {
      throw const VideoApiException('Invalid creator channels response.');
    }
    return (result['items'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> createChannel({
    required String handle,
    required String name,
    String description = '',
  }) async {
    final normalizedHandle = handle.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    final normalizedName = name.trim();
    if (!RegExp(r'^[a-z0-9._-]{3,40}
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
).hasMatch(normalizedHandle) ||
        normalizedName.isEmpty || normalizedName.length > 120 ||
        description.length > 2000) {
      throw const VideoApiException('Enter a valid channel handle, name and description.');
    }
    final result = await _send('POST', '/v1/channels', auth: true, body: {
      'handle': normalizedHandle,
      'name': normalizedName,
      'description': description.trim(),
    });
    if (result is! Map || (result['id'] ?? '').toString().isEmpty) {
      throw const VideoApiException('The video service did not return a channel ID.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> uploadVideo({
    required String filePath,
    required String channelId,
    required String title,
    String description = '',
    String visibility = 'private',
  }) async {
    final normalizedTitle = title.trim();
    if (filePath.trim().isEmpty || channelId.trim().isEmpty ||
        normalizedTitle.isEmpty || normalizedTitle.length > 200 ||
        description.length > 4000 ||
        !const {'private', 'unlisted', 'public'}.contains(visibility)) {
      throw const VideoApiException('Video upload details are invalid.');
    }
    final filename = filePath.split(RegExp(r'[/\\\\]')).last;
    final extension = filename.contains('.') ? filename.substring(filename.lastIndexOf('.')).toLowerCase() : '';
    if (!const {'.mp4', '.mov', '.mkv', '.webm'}.contains(extension)) {
      throw const VideoApiException('Choose an MP4, MOV, MKV or WebM video.');
    }

    Future<http.Response> send({bool forceRefresh = false}) async {
      final token = (await getAccessToken(forceRefresh: forceRefresh) ?? '').trim();
      if (token.isEmpty) {
        throw const VideoApiException('Sign in again to upload a video.');
      }
      final request = http.MultipartRequest('POST', baseUri.resolve('/v1/videos'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['channel_id'] = channelId
        ..fields['title'] = normalizedTitle
        ..fields['description'] = description.trim()
        ..fields['visibility'] = visibility
        ..files.add(await http.MultipartFile.fromPath('video', filePath));
      final streamed = await _client.send(request).timeout(const Duration(hours: 2));
      return http.Response.fromStream(streamed);
    }

    var response = await send();
    if (response.statusCode == 401) {
      response = await send(forceRefresh: true);
    }
    final decoded = _decode(response);
    if (decoded is! Map || (decoded['id'] ?? '').toString().isEmpty) {
      throw const VideoApiException('The video service did not confirm the upload.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> videoStatus(String id) async {
    final result = await _send('GET', '/v1/videos/$id/status', auth: true);
    if (result is! Map) throw const VideoApiException('Invalid video processing status.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> publishVideo(String id) async {
    final result = await _send('POST', '/v1/videos/$id/publish', auth: true);
    if (result is! Map) throw const VideoApiException('Invalid video publish response.');
    return Map<String, dynamic>.from(result);
  }

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
