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

    test('rejects oversized input', () {
      expect(TestagramDeepLink.parse('/${List.filled(2049, 'a').join()}'), isNull);
    });
  });
}
