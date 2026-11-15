class ShortsFeedItem {
  const ShortsFeedItem({
    required this.post,
    required this.mediaUrl,
    required this.mediaHeaders,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.caption,
    required this.isFollowing,
  });

  final Map<String, dynamic> post;
  final String mediaUrl;
  final Map<String, String> mediaHeaders;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String caption;
  final bool isFollowing;

  String get postId => (post['id'] ?? '').toString();
  int get likes => _count(post['likes_count']);
  int get replies => _count(post['replies_count']);
  int get reposts => _count(post['reposts_count']);

  static int _count(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// Converts only Backend-authorized video attachments into Shorts cards.
/// The Backend remains responsible for privacy, ownership and media readiness.
class ShortsFeedPolicy {
  const ShortsFeedPolicy._();

  static List<ShortsFeedItem> parsePosts(Iterable<dynamic> values) {
    final items = <ShortsFeedItem>[];
    final seen = <String>{};
    for (final value in values) {
      if (value is! Map) continue;
      final post = Map<String, dynamic>.from(value);
      final item = fromPost(post);
      if (item == null || item.postId.isEmpty || !seen.add(item.postId)) continue;
      items.add(item);
    }
    return items;
  }

  static ShortsFeedItem? fromPost(Map<String, dynamic> post) {
    final rawUrls = post['media_urls'];
    final rawTypes = post['media_content_types'];
    if (rawUrls is! List || rawTypes is! List) return null;

    final authorValue = post['author'];
    final author = authorValue is Map
        ? Map<String, dynamic>.from(authorValue)
        : <String, dynamic>{};
    final rawHeaders = post['media_auth_headers'];
    final headers = rawHeaders is Map
        ? Map<String, dynamic>.from(rawHeaders)
        : <String, dynamic>{};

    final count = rawUrls.length < rawTypes.length ? rawUrls.length : rawTypes.length;
    for (var index = 0; index < count; index++) {
      final contentType = (rawTypes[index] ?? '').toString().toLowerCase();
      if (!contentType.startsWith('video/')) continue;

      final rawUrl = (rawUrls[index] ?? '').toString().trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
          uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty) {
        continue;
      }

      final authorization = (headers[rawUrl] ?? '').toString();
      final mediaHeaders = authorization.startsWith('Bearer v1.')
          ? <String, String>{'Authorization': authorization}
          : <String, String>{};

      return ShortsFeedItem(
        post: post,
        mediaUrl: rawUrl,
        mediaHeaders: mediaHeaders,
        username: (author['username'] ?? 'testagram_user').toString(),
        displayName: (author['display_name'] ?? author['username'] ?? 'Testagram user').toString(),
        avatarUrl: (author['avatar_url'] ?? '').toString(),
        caption: (post['content'] ?? '').toString(),
        isFollowing: post['is_following'] == true,
      );
    }
    return null;
  }
}
