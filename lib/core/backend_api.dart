import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:http/http.dart' as http;

class PrivateMediaAccess {
  const PrivateMediaAccess({required this.url, required this.authorization, required this.expiresAt});
  final Uri url;
  final String authorization;
  final DateTime expiresAt;
  Map<String, String> get headers => {'Authorization': authorization};
}

class BackendApi {
  BackendApi({
    required this.baseUri,
    required this.getAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  /// Testagram-native session provider. Access tokens remain in memory.
  final Future<String?> Function({bool forceRefresh}) getAccessToken;
  final http.Client _client;

  Future<Map<String, dynamic>> getBookmarkedPosts({
    int limit = 20,
    String? cursor,
  }) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/bookmarks').replace(queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'before': cursor,
      }),
    );
  }

  Future<Map<String, dynamic>> getHomeFeed({
    int limit = 20,
    String? cursor,
    bool followingOnly = false,
    bool videoOnly = false,
    String? feed,
    String? listId,
  }) async {
    final normalizedFeed = feed?.trim().toLowerCase();
    final normalizedListId = listId?.trim().toLowerCase();
    if (normalizedListId != null &&
        normalizedListId.isNotEmpty &&
        !_isCanonicalAccountId(normalizedListId)) {
      throw ArgumentError.value(listId, 'listId', 'Invalid Testagram List UUID');
    }
    final uri = baseUri.resolve('/api/feed/home').replace(queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'before': cursor,
      if (normalizedFeed != null && normalizedFeed.isNotEmpty) 'feed': normalizedFeed,
      if (followingOnly) 'following_only': 'true',
      if (videoOnly) 'video_only': 'true',
      if (normalizedListId != null && normalizedListId.isNotEmpty)
        'list_id': normalizedListId,
    });
    return _request('GET', uri);
  }

  Future<Map<String, dynamic>> getKnowledgeTopics({
    String? query,
    int limit = 30,
    String? after,
  }) =>
      _request(
        'GET',
        baseUri.resolve('/api/knowledge/topics').replace(queryParameters: {
          'limit': '$limit',
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (after != null && after.isNotEmpty) 'after': after,
        }),
      );

  Future<Map<String, dynamic>> getKnowledgeTopic(String slug) =>
      _request('GET', baseUri.resolve('/api/knowledge/topics/${Uri.encodeComponent(slug)}'));

  Future<Map<String, dynamic>> followKnowledgeTopic(String slug) =>
      _request('POST', baseUri.resolve('/api/knowledge/topics/${Uri.encodeComponent(slug)}/follow'));

  Future<Map<String, dynamic>> unfollowKnowledgeTopic(String slug) =>
      _request('DELETE', baseUri.resolve('/api/knowledge/topics/${Uri.encodeComponent(slug)}/follow'));

  Future<Map<String, dynamic>> getKnowledgeQuestions({
    int limit = 20,
    String status = 'all',
    bool mine = false,
    bool following = false,
    String? before,
    String? topicSlug,
    bool topicsFollowing = false,
  }) =>
      _request(
        'GET',
        baseUri.resolve(
          topicSlug == null || topicSlug.isEmpty
              ? '/api/knowledge/questions'
              : '/api/knowledge/topics/${Uri.encodeComponent(topicSlug)}/questions',
        ).replace(queryParameters: {
          'limit': '$limit',
          'status': status,
          if (mine) 'mine': 'true',
          if (following) 'following': 'true',
          if (topicsFollowing) 'topics_following': 'true',
          if (before != null && before.isNotEmpty) 'before': before,
        }),
      );

  Future<Map<String, dynamic>> createKnowledgeQuestion({
    required String title,
    String body = '',
    String visibility = 'public',
    String language = '',
    List<String> topicSlugs = const [],
    required String idempotencyKey,
  }) =>
      _request(
        'POST',
        baseUri.resolve('/api/knowledge/questions'),
        body: {
          'title': title,
          'body': body,
          'visibility': visibility,
          'language': language,
          if (topicSlugs.isNotEmpty) 'topic_slugs': topicSlugs,
        },
        extraHeaders: {'Idempotency-Key': idempotencyKey},
      );

  Future<Map<String, dynamic>> getKnowledgeQuestion(String questionId) =>
      _request('GET', baseUri.resolve('/api/knowledge/questions/$questionId'));

  Future<Map<String, dynamic>> createKnowledgeAnswer({
    required String questionId,
    required String body,
    required String idempotencyKey,
  }) =>
      _request(
        'POST',
        baseUri.resolve('/api/knowledge/questions/$questionId/answers'),
        body: {'body': body},
        extraHeaders: {'Idempotency-Key': idempotencyKey},
      );

  Future<Map<String, dynamic>> acceptKnowledgeAnswer({
    required String questionId,
    required String answerId,
  }) =>
      _request(
        'POST',
        baseUri.resolve('/api/knowledge/questions/$questionId/answers/$answerId/accept'),
      );

  Future<Map<String, dynamic>> getSocialSuggestions({int limit = 8}) =>
      _request('GET', baseUri.resolve('/api/social/suggestions').replace(
        queryParameters: {'limit': '$limit'},
      ));

  Future<Map<String, dynamic>> getSocialLists() =>
      _request('GET', baseUri.resolve('/api/social/lists'));

  Future<Map<String, dynamic>> createSocialList({
    required String name,
    String description = '',
    String visibility = 'private',
  }) =>
      _request(
        'POST',
        baseUri.resolve('/api/social/lists'),
        body: {
          'name': name,
          'description': description,
          'visibility': visibility,
        },
      );

  Future<Map<String, dynamic>> getSocialList(String listId) =>
      _request('GET', baseUri.resolve('/api/social/lists/$listId'));

  Future<Map<String, dynamic>> updateSocialListPin(
    String listId, {
    required bool pinned,
  }) =>
      _request(
        'PUT',
        baseUri.resolve('/api/social/lists/$listId/pin'),
        body: {'pinned': pinned},
      );

  Future<Map<String, dynamic>> getSocialListMembers(String listId) =>
      _request('GET', baseUri.resolve('/api/social/lists/$listId/members'));

  Future<Map<String, dynamic>> addSocialListMember({
    required String listId,
    required String userId,
  }) =>
      _request(
        'POST',
        baseUri.resolve('/api/social/lists/$listId/members'),
        body: {'user_id': userId},
      );

  Future<Map<String, dynamic>> removeSocialListMember({
    required String listId,
    required String userId,
  }) =>
      _request(
        'DELETE',
        baseUri.resolve('/api/social/lists/$listId/members/$userId'),
      );

  Future<Map<String, dynamic>> deleteSocialList(String listId) =>
      _request('DELETE', baseUri.resolve('/api/social/lists/$listId'));

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
  }) => _uploadPublicMedia(
        name: name,
        contentType: contentType,
        bytes: bytes,
        allowedTypes: const {
          'image/jpeg',
          'image/png',
          'image/webp',
          'image/gif',
          'image/avif',
        },
        mediaLabel: 'Image',
      );

  /// Uploads a small public MP4/WebM clip through the same verified media
  /// lifecycle used by images. Public post attachments are capped at 20 MiB.
  Future<Map<String, dynamic>> uploadPublicVideo({
    required String name,
    required String contentType,
    required List<int> bytes,
  }) => _uploadPublicMedia(
        name: name,
        contentType: contentType,
        bytes: bytes,
        allowedTypes: const {'video/mp4', 'video/webm'},
        mediaLabel: 'Video',
      );

  Future<Map<String, dynamic>> _uploadPublicMedia({
    required String name,
    required String contentType,
    required List<int> bytes,
    required Set<String> allowedTypes,
    required String mediaLabel,
  }) async {
    final normalizedType = contentType.toLowerCase().trim();
    if (!allowedTypes.contains(normalizedType)) {
      throw BackendApiException('Unsupported $mediaLabel content type.');
    }
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw BackendApiException('$mediaLabel files must be between 1 byte and 20 MiB.');
    }

    final intent = await _request(
      'POST',
      baseUri.resolve('/api/media/upload-intent'),
      body: {
        'name': name,
        'content_type': normalizedType,
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
      ..headers['Content-Type'] = normalizedType
      ..bodyBytes = bytes;
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 90));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final response = await http.Response.fromStream(streamed);
        _decodeObject(response);
        throw BackendApiException('$mediaLabel upload failed with status ${streamed.statusCode}.',
            statusCode: streamed.statusCode);
      }
    } on TimeoutException {
      throw BackendApiException(
        '$mediaLabel upload timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw BackendApiException(
        'Could not upload the $mediaLabel. Check your connection.',
      );
    }

    final checksum = sha256.convert(bytes).toString();
    // Do not expose a pending object as ready. The Backend verifies the
    // primary object and its independent replica before attachment.
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (true) {
      late final Map<String, dynamic> completed;
      try {
        completed = await _request(
          'POST',
          baseUri.resolve('/api/media/complete'),
          body: {
            'key': key,
            'visibility': 'public',
            'content_type': normalizedType,
            'checksum_sha256': checksum,
          },
        );
      } on BackendApiException catch (error) {
        if ((error.statusCode == 502 || error.statusCode == 503) &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        rethrow;
      }

      final asset = completed['data'];
      if (asset is! Map) {
        throw const BackendApiException('The server did not confirm the uploaded media.');
      }
      final result = Map<String, dynamic>.from(asset);
      final state = (result['status'] ?? '').toString();
      if (state == 'ready') return result;
      if (state != 'replication_pending') {
        throw const BackendApiException('The uploaded media did not reach a valid ready state.');
      }
      if (!DateTime.now().isBefore(deadline)) {
        throw BackendApiException(
          'The $mediaLabel is still being replicated. Retry; it has not been attached or published.',
          statusCode: 503,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Attaches an already verified public media asset to an owned main-feed post.
  /// The Backend checks asset ownership, readiness, visibility and post ownership.
  Future<Map<String, dynamic>> attachPostMedia(String postId, String key) =>
      _request(
        'POST',
        baseUri.resolve('/api/media/attach'),
        body: {'key': key, 'post_id': postId},
      );

  Future<Map<String, dynamic>> attachThreadMedia(String threadId, String key) =>
      _request(
        'POST',
        baseUri.resolve('/api/threads/$threadId/media'),
        body: {'key': key},
      );

  /// Fetch a short-lived viewer-bound assertion for one ready private object.
  /// Use headers for every image, video, HLS manifest, segment and key request.
  /// Never persist the assertion or put it in a URL.
  Future<PrivateMediaAccess> getPrivateMediaAccess(String key) async {
    if (!RegExp(r'^users/[A-Za-z0-9._-]{1,128}/[a-f0-9]{32}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'Invalid private media object key');
    }
    final response = await _request('POST', baseUri.resolve('/api/media/cdn-download-url'), body: {'key': key});
    final rawData = response['data'];
    if (rawData is! Map) throw const BackendApiException('The server did not return private media authorization.');
    final data = Map<String, dynamic>.from(rawData);
    final uri = Uri.tryParse((data['url'] ?? '').toString());
    final authorization = (data['authorization'] ?? '').toString();
    final expiresAt = DateTime.tryParse((data['expires_at'] ?? '').toString())?.toUtc();
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.hasQuery || uri.hasFragment ||
        !uri.path.endsWith('/$key') || !authorization.startsWith('Bearer v1.') ||
        authorization.length > 8192 || expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const BackendApiException('The server returned invalid or expired private media authorization.');
    }
    return PrivateMediaAccess(url: uri, authorization: authorization, expiresAt: expiresAt);
  }
  Future<Map<String, dynamic>> deleteMedia(String key) =>
      _request('POST', baseUri.resolve('/api/media/delete'), body: {'key': key});

  Future<Map<String, dynamic>> toggleThreadLike(String threadId) =>
      _request('POST', baseUri.resolve('/api/threads/$threadId/likes/toggle'));

  Future<Map<String, dynamic>> toggleThreadRepost(String threadId) =>
      _request('POST', baseUri.resolve('/api/threads/$threadId/reposts/toggle'));

  Future<Map<String, dynamic>> toggleThreadBookmark(String threadId) =>
      _request('POST', baseUri.resolve('/api/threads/$threadId/bookmarks/toggle'));

  /// Loads a single post through the Backend's privacy-filtered read route.
  /// Publishes a canonical main-feed post. The Backend enforces moderation,
  /// visibility, idempotency and durable federation outbox delivery.
  Future<Map<String, dynamic>> createPost({
    required String content,
    String visibility = 'public',
    required String idempotencyKey,
  }) {
    final normalized = content.trim();
    const allowedVisibility = {'public', 'followers', 'private'};
    if (normalized.isEmpty || normalized.runes.length > 5000) {
      throw ArgumentError.value(content, 'content', 'Post must contain 1-5000 characters');
    }
    if (!allowedVisibility.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility', 'Unsupported post visibility');
    }
    if (!RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(idempotencyKey)) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey', 'Invalid idempotency key');
    }
    return _request(
      'POST',
      baseUri.resolve('/api/social/posts'),
      body: {'content': normalized, 'visibility': visibility},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
  }

  Future<Map<String, dynamic>> getPost(String postId) =>
      _request('GET', baseUri.resolve('/api/social/posts/$postId'));

  /// Records a view through the Backend's privacy-filtered social post route.
  /// Callers should de-duplicate within a viewing session to avoid inflating counts.
  Future<Map<String, dynamic>> recordPostView(String postId) =>
      _request('POST', baseUri.resolve('/api/social/posts/$postId/view'));

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

  /// Returns public hashtag topics ordered by distinct-post volume over seven days.
  Future<Map<String, dynamic>> getTrendingHashtags({int limit = 20}) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/hashtags/trending').replace(
        queryParameters: {'limit': '$limit'},
      ),
    );
  }

  /// Returns globally trending public discussion words from the last seven days.
  Future<Map<String, dynamic>> getTrendingWords({int limit = 20}) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/trends/words').replace(
        queryParameters: {'limit': '$limit'},
      ),
    );
  }

  /// Loads a privacy-filtered, cursor-paginated hashtag timeline.
  Future<Map<String, dynamic>> getHashtagTimeline(
    String tag, {
    int limit = 20,
    String? cursor,
  }) {
    final normalized = tag.trim().replaceFirst(RegExp(r'^#'), '');
    if (normalized.isEmpty || normalized.runes.length > 64 ||
        normalized.contains(RegExp(r'[^\p{L}\p{N}_]', unicode: true))) {
      throw ArgumentError.value(tag, 'tag', 'Hashtag must contain 1-64 letters, numbers or underscores');
    }
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/hashtags/${Uri.encodeComponent(normalized)}').replace(
        queryParameters: {
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'before': cursor,
        },
      ),
    );
  }

  /// Follows a hashtag as a private viewer-interest signal for Explore.
  Future<Map<String, dynamic>> followHashtag(String tag) {
    final normalized = _normalizeHashtag(tag);
    return _request(
      'POST',
      baseUri.resolve('/api/hashtags/${Uri.encodeComponent(normalized)}/follow'),
      body: const {},
    );
  }

  /// Removes the current viewer's hashtag-interest signal.
  Future<Map<String, dynamic>> unfollowHashtag(String tag) {
    final normalized = _normalizeHashtag(tag);
    return _request(
      'DELETE',
      baseUri.resolve('/api/hashtags/${Uri.encodeComponent(normalized)}/follow'),
    );
  }

  String _normalizeHashtag(String tag) {
    final normalized = tag.trim().replaceFirst(RegExp(r'^#'), '');
    if (normalized.isEmpty || normalized.runes.length > 64 ||
        normalized.contains(RegExp(r'[^\p{L}\p{N}_]', unicode: true))) {
      throw ArgumentError.value(tag, 'tag', 'Hashtag must contain 1-64 letters, numbers or underscores');
    }
    return normalized;
  }

  Future<Map<String, dynamic>> search({
    required String query,
    String kind = 'all',
    int limit = 20,
    String? from,
    String? since,
    String? until,
    String? language,
    String sort = 'latest',
    bool mediaOnly = false,
    bool videoOnly = false,
  }) =>
      _request('GET', baseUri.resolve('/api/search').replace(queryParameters: {
        'q': query,
        'kind': kind,
        'limit': '$limit',
        'sort': sort,
        if (from != null && from.trim().isNotEmpty)
          'from': from.trim().replaceFirst(RegExp(r'^@'), ''),
        if (since != null && since.trim().isNotEmpty) 'since': since.trim(),
        if (until != null && until.trim().isNotEmpty) 'until': until.trim(),
        if (language != null && language.trim().isNotEmpty)
          'language': language.trim().toLowerCase(),
        if (mediaOnly) 'media_only': 'true',
        if (videoOnly) 'video_only': 'true',
      }));

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

  Future<Map<String, dynamic>> getMyNotificationPreferences() =>
      _request('GET', baseUri.resolve('/api/me/notification-preferences'));

  Future<Map<String, dynamic>> updateMyNotificationPreferences({
    bool? pushSocialEnabled,
    bool? pushWalletEnabled,
    bool? pushMessagesEnabled,
  }) =>
      _request(
        'PUT',
        baseUri.resolve('/api/me/notification-preferences'),
        body: {
          if (pushSocialEnabled != null) 'push_social_enabled': pushSocialEnabled,
          if (pushWalletEnabled != null) 'push_wallet_enabled': pushWalletEnabled,
          if (pushMessagesEnabled != null) 'push_messages_enabled': pushMessagesEnabled,
        },
      );

  Future<Map<String, dynamic>> listNotifications({
    int limit = 30,
    String? cursor,
    String category = 'all',
    bool unreadOnly = false,
  }) =>
      _request('GET', baseUri.resolve('/api/social/notifications')
          .replace(queryParameters: {
            'limit': '$limit',
            'category': category,
            'unread_only': '$unreadOnly',
            if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          }));

  /// Opens the authenticated Backend notification stream. The Backend
  /// reads the canonical notification inbox from its own PostgreSQL database;
  /// the client never calls internal services directly. Reconnect with the returned stream_cursor.
  Stream<Map<String, dynamic>> streamNotifications({String? lastEventId}) async* {
    final request = http.Request(
      'GET',
      baseUri.resolve('/api/social/notifications/stream'),
    );
    request.headers.addAll(await _headers());
    request.headers['Accept'] = 'text/event-stream';
    if (lastEventId != null && lastEventId.isNotEmpty) {
      request.headers['Last-Event-ID'] = lastEventId;
    }
    final response = await _client.send(request);
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').toLowerCase().startsWith('text/event-stream')) {
      _decodeObject(await http.Response.fromStream(response));
      throw BackendApiException(
        'The notification stream returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    var buffer = '';
    String? eventId;
    String? eventType;
    final dataLines = <String>[];

    Map<String, dynamic>? dispatch() {
      if (dataLines.isEmpty || eventType != null && eventType != 'notification') {
        dataLines.clear();
        eventType = null;
        return null;
      }
      final decoded = jsonDecode(dataLines.join('\n'));
      dataLines.clear();
      eventType = null;
      if (decoded is! Map) {
        throw const FormatException('Notification stream event must be a JSON object.');
      }
      return <String, dynamic>{
        ...Map<String, dynamic>.from(decoded),
        if (eventId != null) 'stream_cursor': eventId,
      };
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final newline = buffer.indexOf('\n');
        if (newline < 0) break;
        var line = buffer.substring(0, newline);
        buffer = buffer.substring(newline + 1);
        if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
        if (line.isEmpty) {
          final item = dispatch();
          if (item != null) yield item;
        } else if (line.startsWith(':')) {
          continue;
        } else if (line.startsWith('id:')) {
          eventId = line.substring(3).trimLeft();
        } else if (line.startsWith('event:')) {
          eventType = line.substring(6).trimLeft();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }
    }
    if (buffer.isNotEmpty) {
      var line = buffer;
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.startsWith('data:')) dataLines.add(line.substring(5).trimLeft());
      if (line.startsWith('id:')) eventId = line.substring(3).trimLeft();
      if (line.startsWith('event:')) eventType = line.substring(6).trimLeft();
    }
    final finalItem = dispatch();
    if (finalItem != null) yield finalItem;
  }

  Future<Map<String, dynamic>> markNotificationRead(String notificationId) =>
      _request('POST', baseUri.resolve('/api/social/notifications/$notificationId/read'));

  /// Reads an active profile through the authenticated Backend boundary.
  Future<Map<String, dynamic>> getProfile(String userId) =>
      _request('GET', baseUri.resolve('/api/social/profiles/$userId'));

  /// Resolves the caller's canonical Testagram profile from the verified session.
  /// External identity-provider IDs are not canonical Testagram account UUIDs.
  /// Resolves a public Testagram handle through the authenticated Backend.
  /// The Backend applies discoverability, protected-account and block rules.
  Future<Map<String, dynamic>> resolveProfileUsername(String username) {
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9_.]{2,30}$').hasMatch(normalized)) {
      throw ArgumentError.value(username, 'username', 'Enter a valid Testagram username');
    }
    return callCapability('testagram.social.profile.resolve', input: {'username': normalized});
  }
  Future<Map<String, dynamic>> getMyProfile() =>
      _request('GET', baseUri.resolve('/api/me/profile'));

  /// Updates the authenticated member's canonical profile. The Backend verifies
  /// ownership and readiness of uploaded avatar and cover media before saving.
  Future<Map<String, dynamic>> updateMyProfile({
    required String displayName,
    required String bio,
    required String website,
    required String location,
    required String avatarKey,
    required String coverKey,
    Map<String, String> socialLinks = const {},
  }) =>
      _request(
        'PUT',
        baseUri.resolve('/api/me/profile'),
        body: {
          'display_name': displayName,
          'bio': bio,
          'website': website,
          'location': location,
          'avatar_key': avatarKey,
          'cover_key': coverKey,
          'social_links': socialLinks,
        },
      );

  /// Loads a profile's privacy-filtered posts using chronological pagination.
  Future<Map<String, dynamic>> getProfilePosts(
    String userId, {
    int limit = 20,
    String? cursor,
    bool mediaOnly = false,
  }) {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be between 1 and 50');
    }
    return _request(
      'GET',
      baseUri.resolve('/api/social/profiles/$userId/posts').replace(
        queryParameters: {
          'limit': '$limit',
          'media_only': '$mediaOnly',
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
  // Keep the client-side UUID rules identical to Backend socialUUIDPattern.
  // The Backend accepts RFC UUID versions 1-8 and the RFC variant bits only.
  bool _isCanonicalAccountId(String id) {
    if (id.length != 36) return false;
    final version = id.codeUnitAt(14);
    final variant = id.codeUnitAt(19);
    if (version < 49 || version > 56) return false;
    if (variant != 56 && variant != 57 && variant != 97 && variant != 98) return false;
    for (var index = 0; index < id.length; index++) {
      if (const {8, 13, 18, 23}.contains(index)) {
        if (id[index] != '-') return false;
        continue;
      }
      final code = id.codeUnitAt(index);
      final isDigit = code >= 48 && code <= 57;
      final isLowerHex = code >= 97 && code <= 102;
      if (!isDigit && !isLowerHex) return false;
      if (index == 14 && !'12345678'.contains(id[index])) return false;
      if (index == 19 && !'89ab'.contains(id[index])) return false;
    }
    return true;
  }
  /// Blocks a Testagram account. The Backend removes both directions of follow.
  Future<Map<String, dynamic>> blockUser(String targetUserId) {
    final id = targetUserId.trim().toLowerCase();
    if (!_isCanonicalAccountId(id)) {
      throw ArgumentError.value(targetUserId, 'targetUserId', 'Invalid Testagram account UUID');
    }
    return _request('POST', baseUri.resolve('/api/social/blocks'),
        body: {'target_user_id': id});
  }

  /// Removes only the caller's block; previous follows are not restored.
  Future<Map<String, dynamic>> unblockUser(String targetUserId) {
    final id = targetUserId.trim().toLowerCase();
    if (!_isCanonicalAccountId(id)) {
      throw ArgumentError.value(targetUserId, 'targetUserId', 'Invalid Testagram account UUID');
    }
    return _request('DELETE', baseUri.resolve('/api/social/blocks/$id'));
  }

  /// Reads the canonical federation preference through the public Backend API.
  /// The Testagram native access token is attached by the shared authenticated request path.
  Future<Map<String, dynamic>> getMyFederationPreference() =>
      _request('GET', baseUri.resolve('/api/me/federation'));

  /// Updates federation opt-in. Backend remains authoritative for account
  /// status, discoverability, privacy and rollout eligibility.
  Future<Map<String, dynamic>> updateMyFederationPreference({required bool enabled}) =>
      _request(
        'PUT',
        baseUri.resolve('/api/me/federation'),
        body: {'enabled': enabled},
      );

  /// Reads explicit opt-in settings for Testagram social activity emails.
  Future<Map<String, dynamic>> getMyEmailNotificationPreferences() =>
      _request('GET', baseUri.resolve('/api/me/email-notifications'));

  /// Saves granular consent for new-follower and new-post email notifications.
  Future<Map<String, dynamic>> updateMyEmailNotificationPreferences({
    required bool newFollowerEmailEnabled,
    required bool newPostEmailEnabled,
  }) =>
      _request(
        'PUT',
        baseUri.resolve('/api/me/email-notifications'),
        body: {
          'new_follower_email_enabled': newFollowerEmailEnabled,
          'new_post_email_enabled': newPostEmailEnabled,
        },
      );

  /// Lists remote ActivityPub and Bluesky authors followed by this native
  /// Testagram account. Remote identities remain distinct from local accounts.
  Future<Map<String, dynamic>> listRemoteAuthorSubscriptions() =>
      _request('GET', baseUri.resolve('/api/federation/subscriptions'));

  /// Subscribes to a canonical ActivityPub actor URI or Bluesky DID.
  /// The Backend/Federation services verify the identity before it is feed-eligible.
  Future<Map<String, dynamic>> subscribeRemoteAuthor({
    required String protocol,
    required String identity,
    String handle = '',
  }) {
    final normalizedProtocol = protocol.trim().toLowerCase();
    final normalizedIdentity = identity.trim();
    final normalizedHandle = handle.trim();
    if (normalizedProtocol == 'activitypub') {
      final uri = Uri.tryParse(normalizedIdentity);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
          uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
          normalizedIdentity.length > 2048) {
        throw ArgumentError.value(identity, 'identity', 'Use a canonical HTTPS ActivityPub actor URI');
      }
    } else if (normalizedProtocol == 'bluesky') {
      if (!RegExp(r'^did:(plc:[a-z2-7]{24}|web:[^\s/?#@]+)$').hasMatch(normalizedIdentity) ||
          normalizedIdentity.length > 512) {
        throw ArgumentError.value(identity, 'identity', 'Use a canonical Bluesky DID');
      }
    } else {
      throw ArgumentError.value(protocol, 'protocol', 'Protocol must be activitypub or bluesky');
    }
    if (normalizedHandle.length > 256) {
      throw ArgumentError.value(handle, 'handle', 'Remote display handle is too long');
    }
    return _request(
      'POST',
      baseUri.resolve('/api/federation/subscriptions'),
      body: {
        'protocol': normalizedProtocol,
        'identity': normalizedIdentity,
        if (normalizedHandle.isNotEmpty) 'handle': normalizedHandle,
      },
    );
  }

  /// Removes only this user's remote-author subscription.
  Future<Map<String, dynamic>> unsubscribeRemoteAuthor(String subscriptionId) {
    final id = subscriptionId.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id)) {
      throw ArgumentError.value(subscriptionId, 'subscriptionId', 'Invalid subscription UUID');
    }
    return _request('DELETE', baseUri.resolve('/api/federation/subscriptions/$id'));
  }

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

  /// Sends a creator tip from the authenticated user's KES wallet.
  /// The Backend records it as a distinct, idempotent ledger transfer.
  Future<Map<String, dynamic>> tipWalletCreator({
    required String recipientId,
    required String amount,
    String note = '',
    required String idempotencyKey,
  }) {
    final normalizedAmount = amount.trim();
    final amountParts = normalizedAmount.split('.');
    final validAmount = amountParts.length <= 2 &&
        amountParts.first.isNotEmpty &&
        RegExp(r'^[0-9]+$').hasMatch(amountParts.first) &&
        (amountParts.length == 1 ||
            (amountParts[1].isNotEmpty &&
                amountParts[1].length <= 2 &&
                RegExp(r'^[0-9]+$').hasMatch(amountParts[1])));
    final parsedAmount = double.tryParse(normalizedAmount);
    if (recipientId.trim().isEmpty ||
        !validAmount ||
        parsedAmount == null ||
        parsedAmount <= 0 ||
        parsedAmount > 10000 ||
        idempotencyKey.trim().length < 8 ||
        idempotencyKey.trim().length > 128 ||
        note.length > 280) {
      throw ArgumentError('Recipient, amount, note or idempotency key is invalid');
    }
    return callCapability('testagram.wallet.tip', input: {
      'recipient_id': recipientId.trim(),
      'amount': normalizedAmount,
      'note': note.trim(),
      'idempotency_key': idempotencyKey.trim(),
    });
  }

  /// Starts a KES-only M-Pesa STK Push. Settlement is confirmed asynchronously
  /// by the signed provider callback; a successful request is not a credit.
  Future<Map<String, dynamic>> requestMpesaTopUp({
    required String phone,
    required int amountKes,
    required String idempotencyKey,
  }) {
    if (amountKes < 10 || amountKes > 150000 ||
        idempotencyKey.trim().length < 8 || idempotencyKey.trim().length > 128) {
      throw ArgumentError('Amount or idempotency key is invalid');
    }
    return callCapability('testagram.wallet.mpesa.stk_push', input: {
      'phone': phone.trim(),
      'amount_kes': amountKes,
      'currency': 'KES',
      'idempotency_key': idempotencyKey.trim(),
    });
  }

  /// Reads the server-side settlement state for an M-Pesa checkout request.
  Future<Map<String, dynamic>> getMpesaTopUpStatus(String checkoutRequestId) {
    if (checkoutRequestId.trim().isEmpty || checkoutRequestId.length > 128) {
      throw ArgumentError.value(checkoutRequestId, 'checkoutRequestId');
    }
    return callCapability('testagram.wallet.mpesa.status', input: {
      'checkout_request_id': checkoutRequestId.trim(),
    });
  }

  /// Recovers an ambiguous M-Pesa attempt by its owner-scoped idempotency key.
  Future<Map<String, dynamic>> getMpesaTopUpAttemptStatus(String idempotencyKey) {
    final key = idempotencyKey.trim();
    if (key.length < 8 || key.length > 128) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    return callCapability('testagram.wallet.mpesa.status', input: {'idempotency_key': key});
  }
  /// Native Backend conversation list. Only active memberships are returned.
  Future<Map<String, dynamic>> listConversations({int limit = 50}) {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    return callCapability('testagram.conversations.list', input: {'limit': limit});
  }

  /// Creates or reuses a one-to-one conversation. Group creation remains
  /// disabled until the Backend exposes explicit invitation acceptance.
  Future<Map<String, dynamic>> createConversation(List<String> memberIds, {String title = ''}) {
    if (memberIds.length != 1) {
      throw ArgumentError.value(memberIds, 'memberIds', 'Provide exactly one recipient');
    }
    return callCapability('testagram.conversations.create', input: {
      'member_ids': memberIds,
      if (title.trim().isNotEmpty) 'title': title.trim(),
    });
  }

  /// Lists encrypted message envelopes for an active conversation membership.
  Future<Map<String, dynamic>> listMessages(String conversationId, {int limit = 50, String? cursor}) {
    if (conversationId.trim().isEmpty || limit < 1 || limit > 100) {
      throw ArgumentError('Conversation ID or message limit is invalid');
    }
    return callCapability('testagram.messages.list', input: {
      'conversation_id': conversationId.trim(),
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
  }

  /// Writes a message only after the caller has encrypted it locally.
  /// This method accepts ciphertext and never accepts plaintext body text.
  Future<Map<String, dynamic>> sendEncryptedMessage({
    required String conversationId,
    required String ciphertext,
    required String nonce,
    required String clientMessageId,
    required int epoch,
    String aad = '',
  }) {
    if (conversationId.trim().isEmpty || ciphertext.isEmpty || nonce.isEmpty ||
        clientMessageId.trim().isEmpty || epoch < 1) {
      throw ArgumentError('Encrypted message envelope is incomplete');
    }
    return callCapability('testagram.messages.send_encrypted', input: {
      'conversation_id': conversationId.trim(),
      'ciphertext': ciphertext,
      'nonce': nonce,
      'client_message_id': clientMessageId.trim(),
      'e2ee_epoch': epoch,
      'aad': aad,
    });
  }

  Future<Map<String, dynamic>> deleteMessage(String messageId) {
    if (!_isCanonicalAccountId(messageId)) throw ArgumentError.value(messageId, 'messageId');
    return callCapability('testagram.messages.delete', input: {'message_id': messageId.trim()});
  }

  Future<Map<String, dynamic>> reactToMessage({
    required String messageId,
    String reaction = '❤️',
    bool remove = false,
  }) {
    if (!_isCanonicalAccountId(messageId)) throw ArgumentError.value(messageId, 'messageId');
    final emoji = reaction.trim();
    if (emoji.isEmpty || emoji.length > 32) throw ArgumentError.value(reaction, 'reaction');
    return callCapability('testagram.messages.react', input: {
      'message_id': messageId.trim(),
      'reaction': emoji,
      'remove': remove,
    });
  }
  Future<Map<String, dynamic>> markMessageRead(String messageId) {
    if (messageId.trim().isEmpty) throw ArgumentError.value(messageId, 'messageId');
    return callCapability('testagram.messages.mark_read', input: {'message_id': messageId.trim()});
  }

  Future<Map<String, dynamic>> listConversationCalls(String conversationId) {
    if (conversationId.trim().isEmpty) throw ArgumentError.value(conversationId, 'conversationId');
    return callCapability('testagram.calls.list', input: {'conversation_id': conversationId.trim()});
  }

  Future<Map<String, dynamic>> getCallSession(String callId) {
    if (callId.trim().isEmpty) throw ArgumentError.value(callId, 'callId');
    return callCapability('testagram.calls.get', input: {'call_id': callId.trim()});
  }

  /// Session creation is intentionally separate from media transport setup.
  /// A created session does not mean an audio/video connection exists.
  Future<Map<String, dynamic>> createCallSession(String conversationId, {String kind = 'video'}) {
    if (conversationId.trim().isEmpty || !const {'voice', 'video', 'screen'}.contains(kind)) {
      throw ArgumentError('Call session parameters are invalid');
    }
    return callCapability('testagram.calls.create', input: {
      'conversation_id': conversationId.trim(),
      'kind': kind,
    });
  }

  Future<Map<String, dynamic>> joinCallSession(String callId) {
    if (callId.trim().isEmpty) throw ArgumentError.value(callId, 'callId');
    return callCapability('testagram.calls.join', input: {'call_id': callId.trim()});
  }

  Future<Map<String, dynamic>> endCallSession(String callId) {
    if (callId.trim().isEmpty) throw ArgumentError.value(callId, 'callId');
    return callCapability('testagram.calls.end', input: {'call_id': callId.trim()});
  }

  /// Lists live Audio Spaces using the canonical Backend authorization boundary.
  Future<Map<String, dynamic>> listLiveAudioSpaces() =>
      callCapability('testagram.audio_spaces.list_live');

  Future<Map<String, dynamic>> getAudioSpace(String spaceId) =>
      callCapability('testagram.audio_spaces.get', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> getMyAudioSpaceStatus(String spaceId) =>
      callCapability('testagram.audio_spaces.my_status', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> createAudioSpace({
    required String title,
    String description = '',
    int maxAudience = 1000,
  }) {
    final name = title.trim();
    if (name.isEmpty || name.length > 120 || description.length > 2000 ||
        maxAudience < 2 || maxAudience > 10000) {
      throw ArgumentError('Audio Space title, description or audience limit is invalid');
    }
    return callCapability('testagram.audio_spaces.create', input: {
      'title': name,
      'description': description.trim(),
      'max_audience': maxAudience,
    });
  }

  Future<Map<String, dynamic>> joinAudioSpace(String spaceId) =>
      callCapability('testagram.audio_spaces.join', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> leaveAudioSpace(String spaceId) =>
      callCapability('testagram.audio_spaces.leave', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> requestAudioSpaceSpeaker(String spaceId) =>
      callCapability('testagram.audio_spaces.request_speaker', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> listAudioSpaceSpeakerRequests(String spaceId) =>
      callCapability('testagram.audio_spaces.pending_speaker_requests', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> decideAudioSpaceSpeaker({
    required String spaceId,
    required String userId,
    required bool approve,
  }) {
    if (userId.trim().isEmpty || userId.length > 64) {
      throw ArgumentError.value(userId, 'userId');
    }
    return callCapability('testagram.audio_spaces.decide_speaker', input: {
      'space_id': _requiredSpaceId(spaceId),
      'user_id': userId.trim(),
      'decision': approve ? 'approved' : 'denied',
    });
  }

  Future<Map<String, dynamic>> updateAudioSpace({
    required String spaceId,
    required String title,
    String description = '',
  }) {
    final name = title.trim();
    if (name.isEmpty || name.length > 120 || description.length > 2000) {
      throw ArgumentError('Audio Space update is invalid');
    }
    return callCapability('testagram.audio_spaces.update', input: {
      'space_id': _requiredSpaceId(spaceId),
      'title': name,
      'description': description.trim(),
    });
  }

  Future<Map<String, dynamic>> endAudioSpace(String spaceId) =>
      callCapability('testagram.audio_spaces.end', input: {'space_id': _requiredSpaceId(spaceId)});

  Future<Map<String, dynamic>> sendAudioSpaceSuperchat({
    required String spaceId,
    required String message,
    required String amount,
    required String idempotencyKey,
  }) {
    if (message.trim().isEmpty || message.trim().length > 280 ||
        amount.trim().isEmpty || idempotencyKey.trim().length < 8 ||
        idempotencyKey.trim().length > 128) {
      throw ArgumentError('Audio Space Super Chat details are invalid');
    }
    return callCapability('testagram.audio_spaces.superchat', input: {
      'space_id': _requiredSpaceId(spaceId),
      'message': message.trim(),
      'amount': amount.trim(),
      'idempotency_key': idempotencyKey.trim(),
    });
  }

  String _requiredSpaceId(String value) {
    final id = value.trim();
    if (id.isEmpty || id.length > 64) throw ArgumentError.value(value, 'spaceId');
    return id;
  }

  /// Follow-request moderation uses the same Backend handlers as native social routes.
  Future<Map<String, dynamic>> listFollowRequests() =>
      callCapability('testagram.follow_requests.list');

  Future<Map<String, dynamic>> acceptFollowRequest(String followerId) {
    if (followerId.trim().isEmpty || followerId.length > 64) {
      throw ArgumentError.value(followerId, 'followerId');
    }
    return callCapability('testagram.follow_requests.accept',
        input: {'target_user_id': followerId.trim()});
  }

  Future<Map<String, dynamic>> rejectFollowRequest(String followerId) {
    if (followerId.trim().isEmpty || followerId.length > 64) {
      throw ArgumentError.value(followerId, 'followerId');
    }
    return callCapability('testagram.follow_requests.reject',
        input: {'target_user_id': followerId.trim()});
  }

  Future<Map<String, dynamic>> getPostPoll(String postId) {
    if (postId.trim().isEmpty || postId.length > 64) {
      throw ArgumentError.value(postId, 'postId');
    }
    return _request('GET', baseUri.resolve('/api/social/posts/${Uri.encodeComponent(postId.trim())}/poll'));
  }

  Future<Map<String, dynamic>> getPostReactionState(String postId) {
    if (postId.trim().isEmpty || postId.length > 64) {
      throw ArgumentError.value(postId, 'postId');
    }
    return _request('GET', baseUri.resolve('/api/social/posts/${Uri.encodeComponent(postId.trim())}/reaction'));
  }

  Future<Map<String, dynamic>> getPostRepostState(String postId) {
    if (postId.trim().isEmpty || postId.length > 64) {
      throw ArgumentError.value(postId, 'postId');
    }
    return _request('GET', baseUri.resolve('/api/social/posts/${Uri.encodeComponent(postId.trim())}/reposts'));
  }

  Future<Map<String, dynamic>> getPublicFeed({int limit = 20, String? before}) {
    if (limit < 1 || limit > 50) throw ArgumentError.value(limit, 'limit');
    final query = <String, String>{'limit': '$limit'};
    if (before != null && before.trim().isNotEmpty) query['before'] = before.trim();
    return _request('GET', baseUri.resolve('/api/feed/public').replace(queryParameters: query));
  }

  String _requiredThreadId(String value) {
    final id = value.trim();
    if (!_isCanonicalAccountId(id.toLowerCase())) {
      throw ArgumentError.value(value, 'threadId', 'Invalid Testagram thread UUID');
    }
    return id.toLowerCase();
  }

  Future<Map<String, dynamic>> getThread(String threadId) =>
      _request('GET', baseUri.resolve('/api/threads/${_requiredThreadId(threadId)}'));

  Future<Map<String, dynamic>> deleteThread(String threadId) =>
      _request('DELETE', baseUri.resolve('/api/threads/${_requiredThreadId(threadId)}'));

  Future<Map<String, dynamic>> listThreadLikes(String threadId, {int limit = 50}) {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    return _request('GET', baseUri.resolve('/api/threads/${_requiredThreadId(threadId)}/likes')
        .replace(queryParameters: {'limit': '$limit'}));
  }

  Future<Map<String, dynamic>> getThreadLikeState(String threadId) =>
      _request('GET', baseUri.resolve('/api/threads/${_requiredThreadId(threadId)}/likes/state'));

  Future<Map<String, dynamic>> listThreadReposts(String threadId, {int limit = 50}) {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    return _request('GET', baseUri.resolve('/api/threads/${_requiredThreadId(threadId)}/reposts')
        .replace(queryParameters: {'limit': '$limit'}));
  }

  Future<Map<String, dynamic>> getThreadRepostState(String threadId) =>
      _request('GET', baseUri.resolve('/api/threads/${_requiredThreadId(threadId)}/reposts/state'));

  Future<Map<String, dynamic>> getThreadLikeStates(List<String> threadIds) {
    final ids = threadIds.map((id) => id.trim().toLowerCase()).toList();
    if (ids.length > 100 || ids.any((id) => !_isCanonicalAccountId(id))) {
      throw ArgumentError('Provide up to 100 valid thread IDs');
    }
    return _request('POST', baseUri.resolve('/api/threads/likes/states'), body: {'thread_ids': ids});
  }

  Future<Map<String, dynamic>> getThreadRepostStates(List<String> threadIds) {
    final ids = threadIds.map((id) => id.trim().toLowerCase()).toList();
    if (ids.length > 100 || ids.any((id) => !_isCanonicalAccountId(id))) {
      throw ArgumentError('Provide up to 100 valid thread IDs');
    }
    return _request('POST', baseUri.resolve('/api/threads/reposts/states'), body: {'thread_ids': ids});
  }

  Future<Map<String, dynamic>> getThreadBookmarkStates(List<String> threadIds) {
    final ids = threadIds.map((id) => id.trim().toLowerCase()).toList();
    if (ids.length > 100 || ids.any((id) => !_isCanonicalAccountId(id))) {
      throw ArgumentError('Provide up to 100 valid thread IDs');
    }
    return _request('POST', baseUri.resolve('/api/threads/bookmarks/states'), body: {'thread_ids': ids});
  }

  Future<Map<String, dynamic>> getBrowsingHistory() =>
      _request('GET', baseUri.resolve('/api/social/history'));

  Future<Map<String, dynamic>> recordBrowsingHistory({
    required String entityType,
    required String entityId,
    Map<String, dynamic> metadata = const {},
  }) {
    if (!const {'post', 'thread', 'video'}.contains(entityType.trim().toLowerCase()) ||
        entityId.trim().isEmpty || entityId.length > 64) {
      throw ArgumentError('Browsing history item is invalid');
    }
    return _request('POST', baseUri.resolve('/api/social/history'), body: {
      'entity_type': entityType.trim().toLowerCase(),
      'entity_id': entityId.trim(),
      'metadata': metadata,
    });
  }

  Future<Map<String, dynamic>> clearBrowsingHistory() =>
      _request('DELETE', baseUri.resolve('/api/social/history'));

  Future<Map<String, dynamic>> listOwnedMedia() =>
      _request('POST', baseUri.resolve('/api/media/list'), body: const {});

  Future<Map<String, dynamic>> getPrivateMediaDownloadUrl(String key) {
    if (key.trim().isEmpty || key.length > 1024) throw ArgumentError.value(key, 'key');
    return _request('POST', baseUri.resolve('/api/media/private-download-url'),
        body: {'key': key.trim()});
  }

  /// Calls a first-party Backend capability. Product data never bypasses
  /// the Backend and the Testagram native access token is attached by the shared request path.
  Future<List<Map<String, dynamic>>> getCreatorVideoChannels() async {
    final result = await _request('GET', baseUri.resolve('/api/video/channels'));
    final raw = result['items'];
    if (raw is! List) {
      throw const BackendApiException('The Backend returned an invalid creator channel list.');
    }
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> createCreatorVideoChannel({
    required String handle,
    required String name,
    String description = '',
  }) {
    final normalizedHandle = handle.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    final normalizedName = name.trim();
    final validHandle = normalizedHandle.length >= 3 && normalizedHandle.length <= 40 &&
        normalizedHandle.split('').every((character) => RegExp(r'[a-z0-9._-]').hasMatch(character));
    if (!validHandle || normalizedName.isEmpty || normalizedName.length > 120 || description.length > 2000) {
      throw ArgumentError('Enter a valid channel handle, name and description.');
    }
    return _request(
      'POST',
      baseUri.resolve('/api/video/channels'),
      body: {
        'handle': normalizedHandle,
        'name': normalizedName,
        'description': description.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> uploadCreatorVideo({
    required String filePath,
    required String channelId,
    required String title,
    String description = '',
  }) async {
    final normalizedTitle = title.trim();
    final filename = filePath.split('/').last;
    final extension = filename.contains('.') ? filename.substring(filename.lastIndexOf('.')).toLowerCase() : '';
    if (filePath.trim().isEmpty || channelId.trim().isEmpty || normalizedTitle.isEmpty ||
        normalizedTitle.length > 200 || description.length > 4000 ||
        !const {'.mp4', '.mov', '.mkv', '.webm'}.contains(extension)) {
      throw ArgumentError('Choose a valid MP4, MOV, MKV or WebM video and enter its title.');
    }
    Future<http.Response> send({bool forceRefresh = false}) async {
      final request = http.MultipartRequest('POST', baseUri.resolve('/api/video/uploads'))
        ..headers.addAll(await _headers(forceRefresh: forceRefresh))
        ..fields['channel_id'] = channelId
        ..fields['title'] = normalizedTitle
        ..fields['description'] = description.trim()
        ..fields['visibility'] = 'private'
        ..files.add(await http.MultipartFile.fromPath('video', filePath));
      final streamed = await _client.send(request).timeout(const Duration(hours: 2));
      return http.Response.fromStream(streamed);
    }
    http.Response response;
    try {
      response = await send();
      if (response.statusCode == 401) response = await send(forceRefresh: true);
    } on TimeoutException {
      throw const BackendApiException('Upload status is unknown after the connection timed out. Do not retry the same file until the upload has been checked.');
    } on http.ClientException {
      throw const BackendApiException('The upload connection was interrupted. Its final status is unknown; do not retry the same file until it has been checked.');
    }
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> getCreatorVideoStatus(String videoId) {
    return _request('GET', baseUri.resolve('/api/video/uploads/$videoId'));
  }

  Future<Map<String, dynamic>> publishCreatorVideo(String videoId) {
    return _request('POST', baseUri.resolve('/api/video/uploads/$videoId/publish'));
  }
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
    Map<String, String> extraHeaders = const {},
  }) async {
    Future<http.Response> send(Map<String, String> headers) async {
      try {
        switch (method) {
          case 'GET':
            return await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
          case 'POST':
            return await _client.post(uri, headers: headers, body: jsonEncode(body ?? {}))
                .timeout(const Duration(seconds: 20));
          case 'PUT':
            return await _client.put(uri, headers: headers, body: jsonEncode(body ?? {}))
                .timeout(const Duration(seconds: 20));
          case 'DELETE':
            return await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 20));
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
    }

    Map<String, String> headers = {
      ...await _headers(),
      ...extraHeaders,
      if (body != null || method == 'POST' || method == 'PUT') 'Content-Type': 'application/json',
    };
    var response = await send(headers);

    // Native access tokens are short-lived. Retry exactly once after the
    // shared session manager rotates the refresh token. Backend auth rejects
    // before executing protected handlers, so this retry cannot duplicate a
    // successfully applied product mutation.
    if (response.statusCode == 401) {
      headers = {
        ...await _headers(forceRefresh: true),
        ...extraHeaders,
        if (body != null || method == 'POST' || method == 'PUT') 'Content-Type': 'application/json',
      };
      response = await send(headers);
    }

    // An idle InstaBox machine is woken by the real request through the
    // Cloudflare gateway. The gateway marks recovery responses explicitly and
    // supplies Retry-After. Retry once only for safe reads or requests carrying
    // an endpoint-supported Idempotency-Key; never duplicate an arbitrary POST.
    final hasIdempotencyKey = headers.entries.any((entry) =>
        entry.key.toLowerCase() == 'idempotency-key' && entry.value.trim().isNotEmpty);
    // Today, post creation is the only mutation endpoint whose backend contract
    // guarantees idempotent replay. Do not let a future caller accidentally
    // make an unrelated mutation replayable merely by adding this header.
    final idempotentPostCreate = method == 'POST' &&
        uri.path == '/api/social/posts' &&
        hasIdempotencyKey;
    final replaySafe =
        const {'GET', 'HEAD', 'OPTIONS'}.contains(method) || idempotentPostCreate;
    if (response.statusCode == 503 &&
        response.headers['x-testagram-recovery'] == 'attempted' &&
        replaySafe) {
      final retryAfterSeconds = _retryAfterSeconds(response) ?? 5;
      // Long max-run cooldowns should be shown to the caller, not hold an
      // interactive request open for minutes.
      if (retryAfterSeconds <= 30) {
        if (retryAfterSeconds > 0) {
          await Future<void>.delayed(Duration(seconds: retryAfterSeconds));
        }
        response = await send(headers);
      }
    }
    return _decodeObject(response);
  }

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    final token = await getAccessToken(forceRefresh: forceRefresh);
    if (token == null || token.trim().isEmpty) {
      throw const BackendApiException('Your session has expired. Sign in again.', statusCode: 401);
    }
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  int? _retryAfterSeconds(http.Response response) {
    final value = int.tryParse(response.headers['retry-after']?.trim() ?? '');
    return value != null && value >= 0 ? value : null;
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
      final retryAfterSeconds = _retryAfterSeconds(response);
      final isMachineRecovery = response.statusCode == 503 &&
          response.headers['x-testagram-recovery'] == 'attempted';
      final errorCode = error is Map
          ? error['code']?.toString()
          : isMachineRecovery && error is String
              ? error
              : null;
      final readableMessage = isMachineRecovery
          ? (retryAfterSeconds != null && retryAfterSeconds > 30
              ? 'Testagram is temporarily unavailable. Please try again in $retryAfterSeconds seconds.'
              : 'Testagram is waking up. Please try again shortly.')
          : (message?.isNotEmpty == true ? message! : 'Request failed. Please try again.');
      throw BackendApiException(
        readableMessage,
        statusCode: response.statusCode,
        code: errorCode,
        retryAfter: retryAfterSeconds == null ? null : Duration(seconds: retryAfterSeconds),
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    throw const BackendApiException('The server returned an unexpected response.');
  }

  void close() => _client.close();
}

class BackendApiException implements Exception {
  const BackendApiException(this.message, {this.statusCode, this.code, this.retryAfter});
  final String message;
  final int? statusCode;
  /// Stable machine-readable Backend error code, when supplied by the API.
  final String? code;
  /// Server-provided wait before retrying a temporarily unavailable service.
  final Duration? retryAfter;

  @override
  String toString() => message;
}
