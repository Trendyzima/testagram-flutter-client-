import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/posts/post_detail_screen.dart';

void main() {
  group('postDetailMediaHeadersForUrl', () {
    const url = 'https://media.testagram.site/v1/users/owner-1/0123456789abcdef0123456789abcdef';
    const assertion = 'Bearer v1.payload.signature';

    test('attaches only the exact Backend-authorized HTTPS URL', () {
      final headers = postDetailMediaHeadersForUrl({
        'media_auth_headers': {url: assertion},
      }, url);
      expect(headers, {'Authorization': assertion});
    });

    test('does not reuse an assertion for a different URL', () {
      final headers = postDetailMediaHeadersForUrl({
        'media_auth_headers': {url: assertion},
      }, '$url?other=1');
      expect(headers, isNull);
    });

    test('rejects non-HTTPS URLs and malformed assertions', () {
      expect(
        postDetailMediaHeadersForUrl({
          'media_auth_headers': {'http://media.testagram.site/a': assertion},
        }, 'http://media.testagram.site/a'),
        isNull,
      );
      expect(
        postDetailMediaHeadersForUrl({
          'media_auth_headers': {url: 'Bearer ordinary-token'},
        }, url),
        isNull,
      );
      expect(
        postDetailMediaHeadersForUrl({
          'media_auth_headers': {url: 'Bearer v1.bad\\r\\nX-Evil: yes'},
        }, url),
        isNull,
      );
    });

    test('fails closed when Backend supplied no media authorization map', () {
      expect(postDetailMediaHeadersForUrl({}, url), isNull);
      expect(postDetailMediaHeadersForUrl(null, url), isNull);
    });
  });
}
