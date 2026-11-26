import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testagram/core/backend_api.dart';
import 'package:testagram/features/video/video_feed_screen.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const apiOrigin = String.fromEnvironment('TESTAGRAM_STAGING_API_URL');
  const accessToken = String.fromEnvironment('TESTAGRAM_STAGING_ACCESS_TOKEN');
  const expectedVideoId = String.fromEnvironment('TESTAGRAM_STAGING_VIDEO_ID');
  const expectedVideoTitle = String.fromEnvironment('TESTAGRAM_STAGING_VIDEO_TITLE');

  testWidgets(
    'real Android feed initializes, plays and seeks the published staging video',
    (tester) async {
      expect(apiOrigin, isNotEmpty, reason: 'Staging API origin must be supplied');
      expect(accessToken, isNotEmpty, reason: 'Short-lived staging access token must be supplied');
      expect(expectedVideoId, isNotEmpty, reason: 'Exact disposable video ID must be supplied');
      expect(expectedVideoTitle, isNotEmpty, reason: 'Exact disposable video title must be supplied');

      final baseUri = Uri.parse(apiOrigin);
      final api = BackendApi(
        baseUri: baseUri,
        getAccessToken: ({bool forceRefresh = false}) async => accessToken,
      );

      final initialFeed = await api.getVideoFeed();
      expect(initialFeed, isNotEmpty, reason: 'Staging video feed must contain the published test video');
      expect(initialFeed.first['id'], expectedVideoId,
          reason: 'The disposable acceptance video must be the newest feed item');

      await tester.pumpWidget(
        MaterialApp(
          home: VideoFeedScreen(
            api: api,
            videoApiBaseUri: baseUri,
          ),
        ),
      );

      final titleFinder = find.text(expectedVideoTitle);
      final playerFinder = find.byType(VideoPlayer);
      for (var attempt = 0; attempt < 90; attempt++) {
        await tester.pump(const Duration(seconds: 1));
        if (titleFinder.evaluate().isNotEmpty && playerFinder.evaluate().isNotEmpty) {
          break;
        }
      }

      expect(titleFinder, findsOneWidget,
          reason: 'The exact staging video must be the active item in the Flutter feed');
      expect(playerFinder, findsOneWidget,
          reason: 'The native Flutter feed must render its initialized VideoPlayer');

      final playerWidget = tester.widget<VideoPlayer>(playerFinder);
      final controller = playerWidget.controller;
      expect(controller.value.isInitialized, isTrue,
          reason: 'Android must initialize the Backend-proxied HLS manifest');
      expect(controller.value.isPlaying, isTrue,
          reason: 'The feed must start actual native playback');

      await controller.seekTo(const Duration(seconds: 5));
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (controller.value.position >= const Duration(seconds: 4)) {
          break;
        }
      }
      expect(controller.value.position, greaterThanOrEqualTo(const Duration(seconds: 4)),
          reason: 'Native HLS playback must seek forward successfully');

      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
