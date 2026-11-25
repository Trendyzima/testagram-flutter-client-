/// A strictly allow-listed destination parsed from an incoming Testagram link.
/// This parser never accepts arbitrary hosts, redirect URLs or payment parameters.
enum TestagramDeepLinkKind { destination, profileUsername, profileId, profileConnections, profileMedia, socialList, post, thread, wallet, hashtag }

class TestagramDeepLink {
  const TestagramDeepLink._({
    required this.kind,
    this.username,
    this.userId,
    this.tag,
    this.destination,
    this.postId,
    this.connectionKind,
    this.listId,
    this.threadId,
  });

  final TestagramDeepLinkKind kind;
  final String? username;
  final String? userId;
  final String? tag;
  final String? destination;
  final String? postId;
  final String? connectionKind;
  final String? listId;
  final String? threadId;

  static const Set<String> _destinations = {
    'home', 'explore', 'search', 'notifications', 'communities', 'messages', 'inbox',
    'lists', 'bookmarks', 'settings', 'knowledge', 'ask', 'video', 'shorts', 'threads',
    'polls', 'calls', 'spaces', 'audio-spaces', 'follow-requests', 'history', 'creator', 'hashtags', 'topics', 'compose',
    'following', 'for-you', 'for_you', 'latest', 'media', 'discover', 'questions', 'videos', 'watch', 'live', 'federated', 'federation', 'profile',
  };

  static final RegExp _username = RegExp(r'^[A-Za-z0-9_.]{2,30}$');
  static final RegExp _tag = RegExp(r'^[\p{L}\p{N}_]{1,64}$', unicode: true);
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static TestagramDeepLink? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 2048) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasFragment || uri.hasQuery || uri.userInfo.isNotEmpty) return null;

    final isWeb = uri.scheme == 'https' &&
        const {'testagram.site', 'www.testagram.site'}.contains(uri.host.toLowerCase()) &&
        uri.port == 443;
    final isCustom = uri.scheme == 'testagram' &&
        uri.port == 0 &&
        uri.userInfo.isEmpty;
    final isLocalRoute = uri.scheme.isEmpty &&
        uri.host.isEmpty &&
        !value.startsWith('//');
    if (!isWeb && !isCustom && !isLocalRoute) return null;

    if (isCustom && _destinations.contains(uri.host.toLowerCase()) && uri.pathSegments.isEmpty) {
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: uri.host.toLowerCase(),
      );
    }
    if (isCustom && uri.host.toLowerCase() == 'wallet' && uri.pathSegments.isEmpty) {
      return const TestagramDeepLink._(kind: TestagramDeepLinkKind.wallet);
    }
    if (isCustom &&
        uri.host.toLowerCase() == 'compose' &&
        uri.pathSegments.length == 1 &&
        uri.pathSegments.single.toLowerCase() == 'post') {
      return const TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: 'compose',
      );
    }
    if (isCustom && uri.host.toLowerCase() == 'profile' && uri.pathSegments.length == 1) {
      return _profileUsername(uri.pathSegments.single);
    }
    if (isCustom && uri.host.toLowerCase() == 'tag' && uri.pathSegments.length == 1) {
      return _hashtag(uri.pathSegments.single);
    }

    final segments = uri.pathSegments;
    if (segments.length == 1 && _destinations.contains(segments.single.toLowerCase())) {
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: segments.single.toLowerCase(),
      );
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'i') {
      const aliases = {
        'communities': 'communities',
        'notifications': 'notifications',
        'messages': 'messages',
        'search': 'search',
        'explore': 'explore',
        'spaces': 'spaces',
        'shorts': 'shorts',
      };
      final destination = aliases[segments[1].toLowerCase()];
      if (destination != null) {
        return TestagramDeepLink._(
          kind: TestagramDeepLinkKind.destination,
          destination: destination,
        );
      }
    }
    if (segments.length == 3 &&
        segments.first.toLowerCase() == 'i' &&
        segments[1].toLowerCase() == 'lists' &&
        _uuid.hasMatch(segments[2])) {
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.socialList,
        listId: segments[2].toLowerCase(),
      );
    }
    if (segments.length == 2 &&
        segments.first.toLowerCase() == 'i' &&
        segments[1].toLowerCase() == 'bookmarks') {
      return const TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: 'bookmarks',
      );
    }
    if (segments.length == 2 &&
        segments.first.toLowerCase() == 'i' &&
        segments[1].toLowerCase() == 'lists') {
      return const TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: 'lists',
      );
    }
    if (segments.length == 2 &&
        segments.first.toLowerCase() == 'compose' &&
        segments[1].toLowerCase() == 'post') {
      return const TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: 'compose',
      );
    }
    if (segments.length == 2 &&
        segments.first.toLowerCase() == 'settings' &&
        segments[1].toLowerCase() == 'federation') {
      return const TestagramDeepLink._(
        kind: TestagramDeepLinkKind.destination,
        destination: 'federation',
      );
    }
    if (segments.length == 2 &&
        {'thread', 'threads'}.contains(segments.first.toLowerCase()) &&
        _uuid.hasMatch(segments[1])) {
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.thread,
        threadId: segments[1].toLowerCase(),
      );
    }
    if (segments.length == 2 &&
        {'post', 'status'}.contains(segments.first.toLowerCase()) &&
        _uuid.hasMatch(segments[1])) {
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.post,
        postId: segments[1].toLowerCase(),
      );
    }
    if (segments.length == 2 &&
        segments[0].startsWith('@') &&
        segments[1].toLowerCase() == 'media') {
      final profile = _profileUsername(segments[0]);
      if (profile == null) return null;
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.profileMedia,
        username: profile.username,
      );
    }
    if (segments.length == 2 &&
        segments[0].startsWith('@') &&
        {'followers', 'following'}.contains(segments[1].toLowerCase())) {
      final profile = _profileUsername(segments[0]);
      if (profile == null) return null;
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.profileConnections,
        username: profile.username,
        connectionKind: segments[1].toLowerCase(),
      );
    }
    if (segments.length == 3 &&
        segments[0].startsWith('@') &&
        segments[1].toLowerCase() == 'status' &&
        _uuid.hasMatch(segments[2])) {
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.post,
        postId: segments[2].toLowerCase(),
      );
    }
    if (segments.length == 1 && segments.single.toLowerCase() == 'wallet') {
      return const TestagramDeepLink._(kind: TestagramDeepLinkKind.wallet);
    }
    if (segments.length == 1 && segments.single.startsWith('@')) {
      return _profileUsername(segments.single.substring(1));
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'u') {
      return _profileUsername(segments[1]);
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'tags') {
      return _hashtag(segments[1]);
    }
    if (segments.length == 2 && segments.first.toLowerCase() == 'profile') {
      final id = segments[1].toLowerCase();
      if (!_uuid.hasMatch(id)) return null;
      return TestagramDeepLink._(
        kind: TestagramDeepLinkKind.profileId,
        userId: id,
      );
    }
    return null;
  }

  static TestagramDeepLink? _profileUsername(String raw) {
    final username = raw.startsWith('@') ? raw.substring(1) : raw;
    if (!_username.hasMatch(username)) return null;
    return TestagramDeepLink._(
      kind: TestagramDeepLinkKind.profileUsername,
      username: username,
    );
  }

  static TestagramDeepLink? _hashtag(String raw) {
    final tag = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!_tag.hasMatch(tag)) return null;
    return TestagramDeepLink._(
      kind: TestagramDeepLinkKind.hashtag,
      tag: tag,
    );
  }
}
