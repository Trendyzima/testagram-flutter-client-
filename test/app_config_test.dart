import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/core/app_config.dart';

void main() {
  group('Video microservice origin', () {
    test('rejects Backend and website origins', () {
      expect(AppConfig.parseVideoApiOrigin('https://api.testagram.site'), isNull);
      expect(AppConfig.parseVideoApiOrigin('https://testagram.site'), isNull);
    });

    test('rejects insecure, path-prefixed and query-bearing origins', () {
      expect(AppConfig.parseVideoApiOrigin('http://video.testagram.site'), isNull);
      expect(AppConfig.parseVideoApiOrigin('https://video.testagram.site/prefix'), isNull);
      expect(AppConfig.parseVideoApiOrigin('https://video.testagram.site?token=secret'), isNull);
    });

    test('accepts a dedicated HTTPS video origin only', () {
      final uri = AppConfig.parseVideoApiOrigin('https://video.testagram.site');
      expect(uri?.scheme, 'https');
      expect(uri?.host, 'video.testagram.site');
      expect(AppConfig.parseVideoApiOrigin(''), isNull);
    });
  });
}