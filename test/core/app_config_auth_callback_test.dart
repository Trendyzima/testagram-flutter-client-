import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/app_config.dart';
import 'package:testagram/features/auth/auth_entry.dart';

void main() {
  group('Testagram native application configuration', () {
    test('uses the canonical Testagram Backend and website origins', () {
      expect(AppConfig.backendOrigin.toString(), 'https://api.testagram.site');
      expect(AppConfig.siteUrl, 'https://testagram.site');
      expect(AppConfig.isConfigured, isTrue);
    });

    test('keeps the account creation entry point visible by default', () {
      expect(AppConfig.enableIdentityRegistrationUi, isTrue);
    });

    test('requires video to use a separately configured HTTPS service origin', () {
      expect(AppConfig.videoApiOrigin, isNull);
      expect(
        AppConfig.parseVideoApiOrigin('https://video.testagram.site'),
        Uri.parse('https://video.testagram.site'),
      );
    });

    test('rejects product API, website, insecure and path-prefixed video origins', () {
      expect(
        AppConfig.parseVideoApiOrigin('https://api.testagram.site'),
        isNull,
      );
      expect(
        AppConfig.parseVideoApiOrigin('https://testagram.site'),
        isNull,
      );
      expect(
        AppConfig.parseVideoApiOrigin('http://video.testagram.site'),
        isNull,
      );
      expect(
        AppConfig.parseVideoApiOrigin('https://video.testagram.site/v1'),
        isNull,
      );
    });
  });

  group('Testagram authentication callback routing', () {
    test('recognizes native email verification links without legacy application IDs', () {
      final entry = AuthEntry.fromUri(
        Uri.parse('https://testagram.site/verify-email?token=single-use-token'),
      );

      expect(entry.mode, AuthEntryMode.verifyEmail);
      expect(entry.hasCompleteCallback, isFalse);
      expect(entry.isNativeVerification, isTrue);
      expect(entry.token, 'single-use-token');
    });

    test('keeps password reset callbacks distinct from email verification', () {
      final entry = AuthEntry.fromUri(
        Uri.parse('https://testagram.site/reset-password?token=reset-capability'),
      );

      expect(entry.mode, AuthEntryMode.resetPassword);
      expect(entry.hasCompleteCallback, isTrue);
    });
  });

}
