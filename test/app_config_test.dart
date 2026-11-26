import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/app_config.dart';

void main() {
  group('Video API origin', () {
    test('uses the canonical Backend origin for video operations', () {
      expect(AppConfig.videoApiOrigin, AppConfig.backendOrigin);
      expect(AppConfig.videoApiUrl, AppConfig.backendApiUrl);
      expect(AppConfig.videoApiOrigin.host, 'api.testagram.site');
    });
  });
}
