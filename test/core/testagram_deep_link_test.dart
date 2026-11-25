import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/testagram_deep_link.dart';

void main() {
  group('Testagram deep links', () {
    test('resolves canonical username profile URLs', () {
      final cases = [
        'https://testagram.site/@Trendz_01',
        'https://www.testagram.site/u/Trendz_01',
        '/u/Trendz_01',
        'testagram://profile/Trendz_01',
      ];
      for (final value in cases) {
        final link = TestagramDeepLink.parse(value);
        expect(link?.kind, TestagramDeepLinkKind.profileUsername, reason: value);
        expect(link?.username, 'Trendz_01', reason: value);
      }
    });

    test('resolves wallet landing links without accepting payment instructions', () {
      for (final value in [
        'https://testagram.site/wallet',
        '/wallet',
        'testagram://wallet',
      ]) {
        expect(
          TestagramDeepLink.parse(value)?.kind,
          TestagramDeepLinkKind.wallet,
          reason: value,
        );
      }
      expect(TestagramDeepLink.parse('https://testagram.site/wallet?amount=500'), isNull);
      expect(TestagramDeepLink.parse('https://testagram.site/@user?redirect=https://evil.example'), isNull);
      expect(TestagramDeepLink.parse('testagram://wallet?amount=500'), isNull);
    });

    test('resolves canonical hashtag timeline links', () {
      for (final value in [
        'https://testagram.site/tags/KenyaTech',
        'https://www.testagram.site/tags/BuildInPublic',
        '/tags/KenyaTech',
        'testagram://tag/KenyaTech',
      ]) {
        final link = TestagramDeepLink.parse(value);
        expect(link?.kind, TestagramDeepLinkKind.hashtag, reason: value);
        expect(link?.tag, value.contains('BuildInPublic') ? 'BuildInPublic' : 'KenyaTech',
            reason: value);
      }
      for (final value in [
        'https://testagram.site/tags/bad%20tag',
        'https://testagram.site/tags/',
        'https://testagram.site/tags/a?redirect=https://evil.example',
        'https://evil.example/tags/KenyaTech',
      ]) {
        expect(TestagramDeepLink.parse(value), isNull, reason: value);
      }
    });

    test('accepts only canonical UUID profile links', () {
      const id = '123e4567-e89b-42d3-a456-426614174000';
      final link = TestagramDeepLink.parse('https://testagram.site/profile/$id');
      expect(link?.kind, TestagramDeepLinkKind.profileId);
      expect(link?.userId, id);
      expect(TestagramDeepLink.parse('https://testagram.site/profile/not-a-uuid'), isNull);
    });

    test('rejects untrusted hosts, schemes, redirects and malformed handles', () {
      for (final value in [
        'http://testagram.site/@user',
        'https://evil.example/@user',
        'https://testagram.site.evil.example/@user',
        'https://user@evil.example/@user',
        'javascript:alert(1)',
        '//evil.example/@user',
        'https://testagram.site/@bad%20name',
        'https://testagram.site/@a',
        'https://testagram.site/transfer?to=someone&amount=1',
        'https://testagram.site/@user#fragment',
      ]) {
        expect(TestagramDeepLink.parse(value), isNull, reason: value);
      }
    });

    test('resolves first-class X-style Testagram destinations', () {
      const routes = {
        '/home': 'home',
        '/explore': 'explore',
        '/search': 'search',
        '/notifications': 'notifications',
        '/messages': 'messages',
        '/inbox': 'inbox',
        '/i/bookmarks': 'bookmarks',
        '/i/lists': 'lists',
        '/lists': 'lists',
        '/settings': 'settings',
        '/settings/federation': 'federation',
        '/knowledge': 'knowledge',
        '/ask': 'ask',
        '/video': 'video',
        '/shorts': 'shorts',
        '/threads': 'threads',
        '/polls': 'polls',
        '/calls': 'calls',
        '/creator': 'creator',
        '/hashtags': 'hashtags',
      };
      for (final entry in routes.entries) {
        final link = TestagramDeepLink.parse(entry.key);
        expect(link?.kind, TestagramDeepLinkKind.destination, reason: entry.key);
        expect(link?.destination, entry.value, reason: entry.key);
      }
      expect(TestagramDeepLink.parse('testagram://messages')?.destination, 'messages');
      expect(TestagramDeepLink.parse('https://evil.example/messages'), isNull);
      expect(TestagramDeepLink.parse('/messages?redirect=https://evil.example'), isNull);
    });

    test('resolves post and profile connection routes with validated identifiers', () {
      const postId = '123e4567-e89b-42d3-a456-426614174000';
      final post = TestagramDeepLink.parse('/post/$postId');
      expect(post?.kind, TestagramDeepLinkKind.post);
      expect(post?.postId, postId);
      final status = TestagramDeepLink.parse('/@Trendz_01/status/$postId');
      expect(status?.kind, TestagramDeepLinkKind.post);
      expect(status?.postId, postId);
      final followers = TestagramDeepLink.parse('/@Trendz_01/followers');
      expect(followers?.kind, TestagramDeepLinkKind.profileConnections);
      expect(followers?.username, 'Trendz_01');
      expect(followers?.connectionKind, 'followers');
      final following = TestagramDeepLink.parse('/@Trendz_01/following');
      expect(following?.connectionKind, 'following');
      expect(TestagramDeepLink.parse('/post/not-a-uuid'), isNull);
      expect(TestagramDeepLink.parse('/@Trendz_01/blocked'), isNull);
    });

    test('rejects oversized input', () {
      expect(TestagramDeepLink.parse('/${List.filled(2049, 'a').join()}'), isNull);
    });
  });
}
