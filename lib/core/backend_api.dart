import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:http/http.dart' as http;

class BackendApi {
  BackendApi({required this.baseUri, required this.getJwt, http.Client? client})
      : _client = client ?? http.Client();

  final Uri baseUri;
  final Future<String> Function() getJwt;
  final http.Client _client;

  Future<Map<String, dynamic>> getHomeFeed({
    int limit = 20,
    String? cursor,
    bool followingOnly = false,
  }) async {
    final uri = baseUri.resolve('/api/feed/home').replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'before': cursor,
      if (followingOnly) 'following_only': 'true',
    });
    return _request('GET', uri);
  }

  Future<Map<String, dynamic>> getThreads({int limit = 20, String? cursor, String tab = 'for-you'}) =>
      _request('GET', baseUri.resolve('/api/threads').replace(queryParameters: {
        'tab': tab,
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      }));

  Future<Map<String, dynamic>> createThread(String body, {String visibility = 'public'}) =>
      _request('POST', baseUri.resolve('/api/threads'),
          body: {'body': body, 'visibility': visibility});

  /// Uploads a public image through the Backend's bounded, authenticated
  /// media gateway and verifies it before returning the ready asset.
  Future<Map<String, dynamic>> uploadPublicImage({
    required String name,
    required String contentType,
    required List<int> bytes,
  }) async {
    const allowedTypes = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'image/avif',
    };
    if (!allowedTypes.contains(contentType.toLowerCase())) {
      throw const BackendApiException('Choose a JPEG, PNG, WebP, GIF or AVIF image.');
    }
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const BackendApiException('Images must be between 1 byte and 20 MiB.');
    }

    final intent = await _request(
      'POST',
      baseUri.resolve('/api/media/upload-intent'),
      body: {
        'name': name,
        'content_type': contentType.toLowerCase(),
        'visibility': 'public',
        'size_bytes': bytes.length,
      },
    );
    final rawData = intent['data'];
    if (rawData is! Map) {
      throw const BackendApiException('The server did not return a valid upload intent.');
    }
    final data = Map<String, dynamic>.from(rawData);
    final key = (data['key'] ?? '').toString();
    final uploadUrl = (data['url'] ?? '').toString();
    if (key.isEmpty || uploadUrl.isEmpty) {
      throw const BackendApiException('The server returned an incomplete upload intent.');
    }

    final request = http.Request('PUT', baseUri.resolve(uploadUrl))
      ..headers.addAll(await _headers())
      ..headers['Content-Type'] = contentType.toLowerCase()
      ..bodyBytes = bytes;
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 90));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final response = await http.Response.fromStream(streamed);
        _decodeObject(response);
        throw BackendApiException('Image upload failed with status ${streamed.statusCode}.',
            statusCode: streamed.statusCode);
      }
    } on TimeoutException {
      throw const BackendApiException(
        'Image upload timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const BackendApiException(
        'Could not upload the image. Check your connection.',
      );
    }

    final checksum = sha256.convert(bytes).toString();
    final completed = await _request(
      'POST',
      baseUri.resolve('/api/media/complete'),
      body: {
        'key': key,
        'visibility': 'public',
        'content_type': contentType.toLowerCase(),
        'checksum_sha256': checksum,
      },
    );
    final asset = completed['data'];
    if (asset is! Map) {
      throw const BackendApiException('The server did not confirm the uploaded image.');
    }
    return Map<String, dynamic>.from(asset);
  }

  Future<Map<String, dynamic>> attachThreadMedia(String threadId, String key) =>
      _request(
        'POST',
        baseUri.resolve('/api/threads/$threadId/media'),
        body: {'key': key},
      );

  Future<Map<String, dynamic>> deleteMedia(String key) =>
      _request('POST', baseUri.resolve('/api/media/delete'), body: {'key': key});

  Future<Map<String, dynamic>> toggleThreadLike(String threadId) =>
      _request('POST', baseUri.resolve('/api/threads/$threadId/likes/toggle'));

  Future<Map<String, dynamic>> toggleThreadRepost(String threadId) =>
      _request('POST', baseUri.resolve('/api/threads/$threadId/reposts/toggle'));

  Future<Map<String, dynamic>> toggleThreadBookmark(String threadId) =>
      _request('POST', baseUri.resolve('/api/threads/$threadId/bookmarks/toggle'));

  Future<Map<String, dynamic>> getPostInteractionSummary(String postId) =>
      _request('GET', baseUri.resolve('/api/social/posts/$postId/interaction-summary'));

  Future<Map<String, dynamic>> reactToPost(String postId, {String emoji = '❤️'}) =>
      _request('POST', baseUri.resolve('/api/social/posts/$postId/reaction'),
          body: {'emoji': emoji});

  Future<Map<String, dynamic>> removePostReaction(String postId) =>
      _request('DELETE', baseUri.resolve('/api/social/posts/$postId/reaction'));

  Future<Map<String, dynamic>> repostPost(String postId, {String quote = ''}) =>
      _request('POST', baseUri.resolve('/api/social/posts/$postId/reposts'),
          body: {'quote': quote});

  Future<Map<String, dynamic>> removePostRepost(String postId) =>
      _request('DELETE', baseUri.resolve('/api/social/posts/$postId/reposts'));

  Future<Map<String, dynamic>> bookmarkPost(String postId) =>
      _request('POST', baseUri.resolve('/api/social/posts/$postId/bookmarks'));

  Future<Map<String, dynamic>> removePostBookmark(String postId) =>
      _request('DELETE', baseUri.resolve('/api/social/posts/$postId/bookmarks'));

  Future<Map<String, dynamic>> listPostReplies(String postId, {int limit = 50}) =>
      _request('GET', baseUri.resolve('/api/social/posts/$postId/replies')
          .replace(queryParameters: {'limit': '$limit'}));

  Future<Map<String, dynamic>> createPostReply(String postId, String content) =>
      _request('POST', baseUri.resolve('/api/social/posts/$postId/replies'),
          body: {'content': content});

  Future<Map<String, dynamic>> search({required String query, String kind = 'all', int limit = 20}) =>
      _request('GET', baseUri.resolve('/api/search').replace(queryParameters: {
        'q': query,
        'kind': kind,
        'limit': '$limit',
      }));

  Future<Map<String, dynamic>> listNotifications({int limit = 30, String? cursor}) =>
      _request('GET', baseUri.resolve('/api/social/notifications')
          .replace(queryParameters: {
            'limit': '$limit',
            if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          }));

  Future<Map<String, dynamic>> markNotificationRead(String notificationId) =>
      _request('POST', baseUri.resolve('/api/social/notifications/$notificationId/read'));

  Future<Map<String, dynamic>> getFollowState(String targetUserId) =>
      _request('GET', baseUri.resolve('/api/social/follows/$targetUserId'));

  Future<Map<String, dynamic>> followUser(String targetUserId) =>
      _request('POST', baseUri.resolve('/api/social/follows'),
          body: {'target_user_id': targetUserId});

  Future<Map<String, dynamic>> unfollowUser(String targetUserId) =>
      _request('DELETE', baseUri.resolve('/api/social/follows/$targetUserId'));

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      ...await _headers(),
      if (body != null) 'Content-Type': 'application/json',
    };
    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 20));
          break;
        default:
          throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
      }
    } on TimeoutException {
      throw const BackendApiException(
        'The request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const BackendApiException(
        'Could not connect to Testagram. Check your connection.',
      );
    }
    return _decodeObject(response);
  }

  Future<Map<String, String>> _headers() async {
    final jwt = await getJwt();
    if (jwt.trim().isEmpty) {
      throw const BackendApiException('Your session has expired. Sign in again.', statusCode: 401);
    }
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $jwt',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw BackendApiException('The server returned an invalid response.',
          statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? decoded['error'] : null;
      final message = decoded is Map
          ? (decoded['message'] ?? (error is Map ? error['message'] : error))?.toString()
          : null;
      throw BackendApiException(
        message?.isNotEmpty == true ? message! : 'Request failed. Please try again.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    throw const BackendApiException('The server returned an unexpected response.');
  }

  void close() => _client.close();
}

class BackendApiException implements Exception {
  const BackendApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
