import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/app_config.dart';

void main() {
  group('Testagram native application configuration', () {
    test('uses the canonical Testagram Backend and website origins', () {
      expect(AppConfig.backendOrigin.toString(), 'https://api.testagram.site');
      expect(AppConfig.siteUrl, 'https://testagram.site');
      expect(AppConfig.isConfigured, isTrue);
    });

    test('does not enable identity registration by default', () {
      expect(
        AppConfig.enableIdentityRegistrationUi,
        const bool.fromEnvironment('TESTAGRAM_IDENTITY_REGISTRATION_UI_ENABLED', defaultValue: false),
      );
    });

    test('does not enable a separate video API until explicitly configured', () {
      expect(AppConfig.videoApiOrigin, isNull);
    });
  });
}
