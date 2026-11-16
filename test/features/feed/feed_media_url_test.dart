import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/feed/feed_media_url.dart';

void main() {
  group('FeedMediaUrl', () {
    test('preserves canonical Backend CDN URLs', () {
      const url = 'https://media.testagram.site/v1/users/u1/video.mp4';
      expect(FeedMediaUrl.normalize(url), url);
    });

    test('repairs legacy first-party CDN paths through the media alias', () {
      expect(
        FeedMediaUrl.normalize(
          'https://media.testagram.site/users/u1/video.mp4',
        ),
        'https://media.testagram.site/media/users/u1/video.mp4',
      );
    });

    test('upgrades first-party HTTP URLs and preserves query parameters', () {
      expect(
        FeedMediaUrl.normalize(
          'http://media.testagram.site/users/u1/video.mp4?variant=preview',
        ),
        'https://media.testagram.site/media/users/u1/video.mp4?variant=preview',
      );
    });

    test('rejects unrelated external HTTPS media hosts', () {
      expect(FeedMediaUrl.normalize('https://cdn.example/video.mp4'), isNull);
      expect(FeedMediaUrl.normalize('https://media.testagram.site.evil.example/a.mp4'), isNull);
      expect(FeedMediaUrl.normalize('https://media.testagram.site:8443/a.mp4'), isNull);
    });

    test('rejects unsafe, malformed, or hostless URLs', () {
      expect(FeedMediaUrl.normalize('javascript:alert(1)'), isNull);
      expect(FeedMediaUrl.normalize('file:///tmp/video.mp4'), isNull);
      expect(FeedMediaUrl.normalize('https://user:pass@cdn.example/a.mp4'), isNull);
      expect(FeedMediaUrl.normalize('https:///missing-host.mp4'), isNull);
      expect(FeedMediaUrl.normalize('  '), isNull);
      expect(FeedMediaUrl.normalize(42), isNull);
    });
  });
}
