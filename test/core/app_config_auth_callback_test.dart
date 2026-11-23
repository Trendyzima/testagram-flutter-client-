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

    test('routes the video service through the canonical HTTPS API origin', () {
      expect(AppConfig.videoApiOrigin, AppConfig.backendOrigin);
      expect(AppConfig.videoApiOrigin?.scheme, 'https');
    });
  });

  group('Testagram authentication callback routing', () {
    test('recognizes native email verification links without legacy application IDs', () {
      final entry = AuthEntry.fromUri(
        Uri.parse('https://testagram.site/verify-email?token=single-use-token'),
      );

      expect(entry.mode, AuthEntryMode.verifyEmail);
      expect(entry.hasCompleteCallback, isTrue);
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
