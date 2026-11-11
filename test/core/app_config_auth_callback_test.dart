import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/app_config.dart';

void main() {
  group('AppConfig.authCallbackOriginFor', () {
    test('uses the canonical site for native applications', () {
      expect(
        AppConfig.authCallbackOriginFor(
          Uri.parse('https://testagram.site/path'),
          isWeb: false,
        ),
        AppConfig.siteUrl,
      );
    });

    test('uses the active canonical Pages origin in browser builds', () {
      expect(
        AppConfig.authCallbackOriginFor(
          Uri.parse('https://testagram.site/?mode=signup'),
          isWeb: true,
        ),
        'https://testagram.site',
      );
      expect(
        AppConfig.authCallbackOriginFor(
          Uri.parse('https://feat-auth.testagram-flutter-web.pages.dev/?mode=recovery&userId=u&secret=s#callback'),
          isWeb: true,
        ),
        'https://feat-auth.testagram-flutter-web.pages.dev',
      );
    });

    test('does not trust arbitrary or insecure callback origins', () {
      for (final uri in [
        Uri.parse('http://testagram.site/?mode=signup'),
        Uri.parse('https://evil.example/?mode=signup'),
        Uri.parse('https://testagram.site.evil.example/?mode=signup'),
        Uri.parse('https://user:pass@testagram.site/?mode=signup'),
      ]) {
        expect(
          AppConfig.authCallbackOriginFor(uri, isWeb: true),
          AppConfig.siteUrl,
          reason: uri.toString(),
        );
      }
    });
  });
}
