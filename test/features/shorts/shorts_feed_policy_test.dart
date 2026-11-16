import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/shorts/shorts_feed_policy.dart';

void main() {
  test('extracts the first HTTPS video attachment and its viewer authorization', () {
    final item = ShortsFeedPolicy.fromPost({
      'id': 'post-1',
      'content': 'A short clip',
      'is_video': true,
      'is_following': true,
      'media_urls': [
        'https://cdn.testagram.site/image.webp',
        'https://cdn.testagram.site/video.mp4',
      ],
      'media_content_types': ['image/webp', 'video/mp4'],
      'media_auth_headers': {
        'https://cdn.testagram.site/video.mp4': 'Bearer v1.signed-assertion',
      },
      'author': {
        'username': 'creator',
        'display_name': 'Creator',
        'avatar_url': 'https://cdn.testagram.site/avatar.webp',
      },
      'likes_count': 12,
      'replies_count': 3,
      'reposts_count': 2,
    });

    expect(item, isNotNull);
    expect(item!.mediaUrl, 'https://cdn.testagram.site/video.mp4');
    expect(item.mediaHeaders['Authorization'], 'Bearer v1.signed-assertion');
    expect(item.username, 'creator');
    expect(item.displayName, 'Creator');
    expect(item.isFollowing, isTrue);
    expect(item.likes, 12);
    expect(item.replies, 3);
    expect(item.reposts, 2);
  });

  test('does not treat an image attachment as a video', () {
    expect(ShortsFeedPolicy.fromPost({
      'id': 'image-post',
      'media_urls': ['https://cdn.testagram.site/image.webp'],
      'media_content_types': ['image/webp'],
    }), isNull);
  });

  test('rejects insecure, malformed and credential-bearing media URLs', () {
    for (final url in [
      'http://cdn.testagram.site/video.mp4',
      'javascript:alert(1)',
      'https://user:password@cdn.testagram.site/video.mp4',
      'not a url',
    ]) {
      expect(ShortsFeedPolicy.fromPost({
        'id': 'unsafe-post',
        'media_urls': [url],
        'media_content_types': ['video/mp4'],
      }), isNull, reason: url);
    }
  });

  test('de-duplicates posts and skips malformed feed rows', () {
    final post = {
      'id': 'same-post',
      'media_urls': ['https://cdn.testagram.site/video.mp4'],
      'media_content_types': ['video/mp4'],
    };
    final items = ShortsFeedPolicy.parsePosts([post, post, 'invalid', null]);
    expect(items, hasLength(1));
    expect(items.single.postId, 'same-post');
  });

  test('does not forward an unrecognized media authorization value', () {
    final item = ShortsFeedPolicy.fromPost({
      'id': 'private-post',
      'media_urls': ['https://cdn.testagram.site/video.mp4'],
      'media_content_types': ['video/mp4'],
      'media_auth_headers': {
        'https://cdn.testagram.site/video.mp4': 'Bearer unrelated-token',
      },
    });

    expect(item, isNotNull);
    expect(item!.mediaHeaders, isEmpty);
  });
}
