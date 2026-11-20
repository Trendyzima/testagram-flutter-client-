import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/app_config.dart';

void main() {
  group('Testagram native application configuration', () {
    test('uses the canonical Testagram Backend and website origins', () {
      expect(AppConfig.backendOrigin.toString(), 'https://api.testagram.site');
      expect(AppConfig.siteUrl, 'https://testagram.site');
      expect(AppConfig.isConfigured, isTrue);
    });

    test('keeps identity registration closed by default until explicitly enabled', () {
      expect(AppConfig.enableIdentityRegistrationUi, isFalse);
    });

    test('routes the video service through the canonical HTTPS API origin', () {
      expect(AppConfig.videoApiOrigin, AppConfig.backendOrigin);
      expect(AppConfig.videoApiOrigin?.scheme, 'https');
    });
  });
}
