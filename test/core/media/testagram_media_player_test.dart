import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/media/testagram_media_player.dart';

void main() {
  group('MediaPlaybackDescriptor', () {
    test('detects video MIME types rather than guessing from opaque object keys', () {
      expect(MediaPlaybackDescriptor.isVideoContentType('video/mp4'), isTrue);
      expect(MediaPlaybackDescriptor.isVideoContentType(' VIDEO/WEBM '), isTrue);
      expect(MediaPlaybackDescriptor.isVideoContentType('image/webp'), isFalse);
      expect(MediaPlaybackDescriptor.isVideoContentType(null), isFalse);
    });

    test('binds a viewer assertion only to the exact media URL', () {
      const url = 'https://media.testagram.site/v1/users/u1/0123456789abcdef0123456789abcdef';
      final headers = MediaPlaybackDescriptor.headersForUrl(
        {url: 'Bearer v1.viewer-assertion'},
        url,
      );
      expect(headers, {'Authorization': 'Bearer v1.viewer-assertion'});
      expect(
        MediaPlaybackDescriptor.headersForUrl(
          {url: 'Bearer v1.viewer-assertion'},
          '$url/another-object',
        ),
        isEmpty,
      );
    });

    test('rejects malformed viewer assertion values', () {
      const url = 'https://media.testagram.site/v1/users/u1/object';
      expect(
        MediaPlaybackDescriptor.headersForUrl({url: 'Basic invalid'}, url),
        isEmpty,
      );
      expect(
        MediaPlaybackDescriptor.headersForUrl({url: 'Bearer v1.bad\nheader'}, url),
        isEmpty,
      );
    });
  });
}
