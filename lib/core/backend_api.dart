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

  /// Loads a single post through the Backend's privacy-filtered read route.
  Future<Map<String, dynamic>> getPost(String postId) =>
      _request('GET', baseUri.resolve('/api/social/posts/$postId'));

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

  /// Lists users who liked, reposted or quoted a visible post.
  /// The Backend validates visibility and caps the requested page at 100.
  Future<Map<String, dynamic>> listPostInteractions(
    String postId, {
    required String kind,
    int limit = 100,
  }) {
    const supported = {'likes', 'reposts', 'quotes'};
    if (!supported.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Unsupported post interaction kind');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 100');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/posts/$postId/interactions/$kind')
          .replace(queryParameters: {'limit': '$limit'}),
    );
  }

  Future<Map<String, dynamic>> createPostReply(String postId, String content) =>
      _request('POST', baseUri.resolve('/api/social/posts/$postId/replies'),
          body: {'content': content});

  Future<Map<String, dynamic>> search({required String query, String kind = 'all', int limit = 20}) =>
      _request('GET', baseUri.resolve('/api/search').replace(queryParameters: {
        'q': query,
        'kind': kind,
        'limit': '$limit',
      }));

  /// Reads the public, normalized TV catalogue through the Backend.
  /// This route is contract-first and must not be used until Backend issue #161
  /// is implemented and deployed.
  Future<Map<String, dynamic>> listTvChannels({
    int limit = 20,
    String? cursor,
    String? country,
    String? category,
    String? language,
    String? query,
  }) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    if (country != null && !RegExp(r'^[A-Za-z]{2}
      _request('GET', baseUri.resolve('/api/social/polls').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      }));

  Future<Map<String, dynamic>> getPoll(String pollId) =>
      _request('GET', baseUri.resolve('/api/social/polls/$pollId'));

  Future<Map<String, dynamic>> createPoll({
    required String question,
    String description = '',
    required List<String> options,
    DateTime? endsAt,
    String mediaObjectKey = '',
  }) =>
      _request('POST', baseUri.resolve('/api/social/polls'), body: {
        'question': question,
        'description': description,
        'options': options,
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        if (mediaObjectKey.isNotEmpty) 'media_object_key': mediaObjectKey,
      });

  Future<Map<String, dynamic>> votePoll(String pollId, String optionId) =>
      _request('POST', baseUri.resolve('/api/social/polls/$pollId/vote'),
          body: {'option_id': optionId});

  Future<Map<String, dynamic>> listNotifications({int limit = 30, String? cursor}) =>
      _request('GET', baseUri.resolve('/api/social/notifications')
          .replace(queryParameters: {
            'limit': '$limit',
            if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          }));

  Future<Map<String, dynamic>> markNotificationRead(String notificationId) =>
      _request('POST', baseUri.resolve('/api/social/notifications/$notificationId/read'));

  /// Reads an active profile through the authenticated Backend boundary.
  Future<Map<String, dynamic>> getProfile(String userId) =>
      _request('GET', baseUri.resolve('/api/social/profiles/$userId'));

  /// Loads a profile's privacy-filtered posts using chronological pagination.
  Future<Map<String, dynamic>> getProfilePosts(
    String userId, {
    int limit = 20,
    String? cursor,
  }) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/profiles/$userId/posts').replace(
        queryParameters: {
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'before': cursor,
        },
      ),
    );
  }

  /// Lists a profile's privacy-filtered followers or following accounts.
  Future<Map<String, dynamic>> listProfileConnections(
    String userId, {
    required String kind,
    int limit = 30,
    String? cursor,
  }) {
    const supported = {'followers', 'following'};
    if (!supported.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Expected followers or following');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 100');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/profiles/$userId/connections').replace(
        queryParameters: {
          'kind': kind,
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getFollowState(String targetUserId) =>
      _request('GET', baseUri.resolve('/api/social/follows/$targetUserId'));

  Future<Map<String, dynamic>> followUser(String targetUserId) =>
      _request('POST', baseUri.resolve('/api/social/follows'),
          body: {'target_user_id': targetUserId});

  Future<Map<String, dynamic>> unfollowUser(String targetUserId) =>
      _request('DELETE', baseUri.resolve('/api/social/follows/$targetUserId'));

  /// Reads the authenticated user's wallet from the native Backend ledger.
  Future<Map<String, dynamic>> getWalletBalance({String currency = 'KES'}) =>
      callCapability('testagram.wallet.balance', input: {'currency': currency});

  /// Lists the authenticated user's wallet transactions (Backend maximum: 100).
  Future<Map<String, dynamic>> listWalletTransactions({int limit = 50}) {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 100');
    }
    return callCapability('testagram.wallet.transactions.list', input: {'limit': limit});
  }

  /// Resolves a recipient username before the user confirms a transfer.
  Future<Map<String, dynamic>> resolveWalletRecipient(String username) {
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (normalized.length < 2 || normalized.length > 30) {
      throw ArgumentError.value(username, 'username', 'Enter a valid recipient username');
    }
    return callCapability('testagram.wallet.recipient.resolve', input: {'username': normalized});
  }

  /// Transfers funds using a client-generated idempotency key.
  Future<Map<String, dynamic>> transferWalletFunds({
    required String recipientId,
    required String amount,
    String note = '',
    required String idempotencyKey,
  }) {
    if (recipientId.trim().isEmpty || amount.trim().isEmpty ||
        idempotencyKey.trim().length < 8 || idempotencyKey.trim().length > 128 ||
        note.length > 280) {
      throw ArgumentError('Recipient, amount, note or idempotency key is invalid');
    }
    return callCapability('testagram.wallet.transfer', input: {
      'recipient_id': recipientId.trim(),
      'amount': amount.trim(),
      'note': note,
      'idempotency_key': idempotencyKey.trim(),
    });
  }

  /// Calls a first-party Backend capability. Product data never bypasses
  /// the Backend and the Appwrite JWT is attached by the shared request path.
  Future<Map<String, dynamic>> callCapability(
    String capability, {
    Map<String, dynamic> input = const {},
  }) {
    if (capability.trim().isEmpty || capability.length > 128) {
      throw ArgumentError.value(capability, 'capability', 'Invalid capability name');
    }
    return _request(
      'POST',
      baseUri.resolve('/api/capability'),
      body: {'capability': capability, 'input': input},
    );
  }

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
).hasMatch(country)) {
      throw ArgumentError.value(country, 'country', 'Country must be an ISO alpha-2 code');
    }
    if (query != null && query.trim().length > 120) {
      throw ArgumentError.value(query, 'query', 'Search query must be at most 120 characters');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/tv/channels').replace(queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (country != null && country.isNotEmpty) 'country': country.toUpperCase(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (language != null && language.isNotEmpty) 'language': language,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      }),
    );
  }

  Future<Map<String, dynamic>> getTvChannel(String channelId) {
    final id = channelId.trim();
    if (id.isEmpty || id.length > 256) {
      throw ArgumentError.value(channelId, 'channelId', 'Channel ID is invalid');
    }
    return _request('GET', baseUri.resolve('/api/tv/channels/${Uri.encodeComponent(id)}'));
  }

  /// Requests a short-lived playback grant. The Backend—not Flutter—decides
  /// whether this viewer may watch the selected channel.
  Future<Map<String, dynamic>> createTvPlaybackGrant(
    String channelId, {
    String playbackProfile = 'auto',
  }) {
    const profiles = {'auto', 'low', 'standard', 'high'};
    final id = channelId.trim();
    if (id.isEmpty || id.length > 256 || !profiles.contains(playbackProfile)) {
      throw ArgumentError('Channel ID or playback profile is invalid');
    }
    return _request(
      'POST',
      baseUri.resolve('/api/tv/channels/${Uri.encodeComponent(id)}/playback'),
      body: {'playback_profile': playbackProfile},
    );
  }

  Future<Map<String, dynamic>> listPolls({int limit = 20, int offset = 0}) =>
      _request('GET', baseUri.resolve('/api/social/polls').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      }));

  Future<Map<String, dynamic>> getPoll(String pollId) =>
      _request('GET', baseUri.resolve('/api/social/polls/$pollId'));

  Future<Map<String, dynamic>> createPoll({
    required String question,
    String description = '',
    required List<String> options,
    DateTime? endsAt,
    String mediaObjectKey = '',
  }) =>
      _request('POST', baseUri.resolve('/api/social/polls'), body: {
        'question': question,
        'description': description,
        'options': options,
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        if (mediaObjectKey.isNotEmpty) 'media_object_key': mediaObjectKey,
      });

  Future<Map<String, dynamic>> votePoll(String pollId, String optionId) =>
      _request('POST', baseUri.resolve('/api/social/polls/$pollId/vote'),
          body: {'option_id': optionId});

  Future<Map<String, dynamic>> listNotifications({int limit = 30, String? cursor}) =>
      _request('GET', baseUri.resolve('/api/social/notifications')
          .replace(queryParameters: {
            'limit': '$limit',
            if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          }));

  Future<Map<String, dynamic>> markNotificationRead(String notificationId) =>
      _request('POST', baseUri.resolve('/api/social/notifications/$notificationId/read'));

  /// Reads an active profile through the authenticated Backend boundary.
  Future<Map<String, dynamic>> getProfile(String userId) =>
      _request('GET', baseUri.resolve('/api/social/profiles/$userId'));

  /// Loads a profile's privacy-filtered posts using chronological pagination.
  Future<Map<String, dynamic>> getProfilePosts(
    String userId, {
    int limit = 20,
    String? cursor,
  }) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/profiles/$userId/posts').replace(
        queryParameters: {
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'before': cursor,
        },
      ),
    );
  }

  /// Lists a profile's privacy-filtered followers or following accounts.
  Future<Map<String, dynamic>> listProfileConnections(
    String userId, {
    required String kind,
    int limit = 30,
    String? cursor,
  }) {
    const supported = {'followers', 'following'};
    if (!supported.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Expected followers or following');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 100');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/profiles/$userId/connections').replace(
        queryParameters: {
          'kind': kind,
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getFollowState(String targetUserId) =>
      _request('GET', baseUri.resolve('/api/social/follows/$targetUserId'));

  Future<Map<String, dynamic>> followUser(String targetUserId) =>
      _request('POST', baseUri.resolve('/api/social/follows'),
          body: {'target_user_id': targetUserId});

  Future<Map<String, dynamic>> unfollowUser(String targetUserId) =>
      _request('DELETE', baseUri.resolve('/api/social/follows/$targetUserId'));

  /// Reads the authenticated user's wallet from the native Backend ledger.
  Future<Map<String, dynamic>> getWalletBalance({String currency = 'KES'}) =>
      callCapability('testagram.wallet.balance', input: {'currency': currency});

  /// Lists the authenticated user's wallet transactions (Backend maximum: 100).
  Future<Map<String, dynamic>> listWalletTransactions({int limit = 50}) {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 100');
    }
    return callCapability('testagram.wallet.transactions.list', input: {'limit': limit});
  }

  /// Resolves a recipient username before the user confirms a transfer.
  Future<Map<String, dynamic>> resolveWalletRecipient(String username) {
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (normalized.length < 2 || normalized.length > 30) {
      throw ArgumentError.value(username, 'username', 'Enter a valid recipient username');
    }
    return callCapability('testagram.wallet.recipient.resolve', input: {'username': normalized});
  }

  /// Transfers funds using a client-generated idempotency key.
  Future<Map<String, dynamic>> transferWalletFunds({
    required String recipientId,
    required String amount,
    String note = '',
    required String idempotencyKey,
  }) {
    if (recipientId.trim().isEmpty || amount.trim().isEmpty ||
        idempotencyKey.trim().length < 8 || idempotencyKey.trim().length > 128 ||
        note.length > 280) {
      throw ArgumentError('Recipient, amount, note or idempotency key is invalid');
    }
    return callCapability('testagram.wallet.transfer', input: {
      'recipient_id': recipientId.trim(),
      'amount': amount.trim(),
      'note': note,
      'idempotency_key': idempotencyKey.trim(),
    });
  }

  /// Calls a first-party Backend capability. Product data never bypasses
  /// the Backend and the Appwrite JWT is attached by the shared request path.
  Future<Map<String, dynamic>> callCapability(
    String capability, {
    Map<String, dynamic> input = const {},
  }) {
    if (capability.trim().isEmpty || capability.length > 128) {
      throw ArgumentError.value(capability, 'capability', 'Invalid capability name');
    }
    return _request(
      'POST',
      baseUri.resolve('/api/capability'),
      body: {'capability': capability, 'input': input},
    );
  }

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
