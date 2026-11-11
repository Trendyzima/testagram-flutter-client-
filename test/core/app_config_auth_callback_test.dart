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
          Uri.parse('https://feat-auth-complete-parity.testagram-flutter-web.pages.dev/'),
          isWeb: true,
        ),
        'https://feat-auth-complete-parity.testagram-flutter-web.pages.dev',
      );
    });

    test('does not trust arbitrary or insecure callback origins', () {
      for (final uri in [
        Uri.parse('http://testagram.site'),
        Uri.parse('https://evil.example'),
        Uri.parse('https://testagram.site.evil.example'),
        Uri.parse('https://user:pass@testagram.site'),
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
