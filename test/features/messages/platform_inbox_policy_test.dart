import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/messages/platform_inbox_policy.dart';

void main() {
  test('filters all, unread and message types independently', () {
    const unread = {'type': 'payment', 'read': false};
    const read = {'type': 'trending', 'read': true};
    expect(PlatformInboxPolicy.matchesFilter(unread, 'all'), isTrue);
    expect(PlatformInboxPolicy.matchesFilter(read, 'all'), isTrue);
    expect(PlatformInboxPolicy.matchesFilter(unread, 'unread'), isTrue);
    expect(PlatformInboxPolicy.matchesFilter(read, 'unread'), isFalse);
    expect(PlatformInboxPolicy.matchesFilter(unread, 'payment'), isTrue);
    expect(PlatformInboxPolicy.matchesFilter(unread, 'trending'), isFalse);
  });

  test('counts missing read flags as unread', () {
    expect(PlatformInboxPolicy.unreadCount([
      {'read': false}, {'read': true}, <String, dynamic>{},
    ]), 2);
  });

  test('accepts safe internal routes and query strings', () {
    expect(PlatformInboxPolicy.safeInternalPath('/wallet'), '/wallet');
    expect(PlatformInboxPolicy.safeInternalPath('/profile/alex?tab=posts'),
        '/profile/alex?tab=posts');
  });

  test('rejects external, protocol-relative and traversal paths', () {
    for (final path in [
      'https://attacker.example',
      '//attacker.example/path',
      '/\\\\attacker.example',
      '/../admin',
      '/%2e%2e/admin',
      '/%2f%2fattacker.example',
      '/path%0d%0aheader',
    ]) {
      expect(PlatformInboxPolicy.safeInternalPath(path), isNull, reason: path);
    }
    expect(PlatformInboxPolicy.safeInternalPath(null), isNull);
  });
}
