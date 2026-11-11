import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testagram/features/tv/tv_playback_policy.dart';

void main() {
  test('recognizes web, external and initialized native playback surfaces', () {
    expect(tvHasPlaybackSurface(
      isWeb: true,
      webPlaybackUrl: 'https://cdn.example/live.m3u8',
      hasExternalPlaybackAction: false,
      hasInitializedNativePlayer: false,
    ), isTrue);
    expect(tvHasPlaybackSurface(
      isWeb: true,
      webPlaybackUrl: ' ',
      hasExternalPlaybackAction: false,
      hasInitializedNativePlayer: false,
    ), isFalse);
    expect(tvHasPlaybackSurface(
      isWeb: false,
      webPlaybackUrl: 'https://cdn.example/live.m3u8',
      hasExternalPlaybackAction: false,
      hasInitializedNativePlayer: false,
    ), isFalse);
    expect(tvHasPlaybackSurface(
      isWeb: false,
      webPlaybackUrl: null,
      hasExternalPlaybackAction: true,
      hasInitializedNativePlayer: false,
    ), isTrue);
    expect(tvHasPlaybackSurface(
      isWeb: false,
      webPlaybackUrl: null,
      hasExternalPlaybackAction: false,
      hasInitializedNativePlayer: true,
    ), isTrue);
  });

  test('sponsored ads require started playback and current generation', () {
    expect(tvCanRequestSponsoredAd(
      hasPlaybackStarted: true,
      alreadyRequested: false,
      isCurrentGeneration: true,
    ), isTrue);
    expect(tvCanRequestSponsoredAd(
      hasPlaybackStarted: false,
      alreadyRequested: false,
      isCurrentGeneration: true,
    ), isFalse);
    expect(tvCanRequestSponsoredAd(
      hasPlaybackStarted: true,
      alreadyRequested: true,
      isCurrentGeneration: true,
    ), isFalse);
    expect(tvCanRequestSponsoredAd(
      hasPlaybackStarted: true,
      alreadyRequested: false,
      isCurrentGeneration: false,
    ), isFalse);
  });

  test('pauses when app leaves foreground and resumes only prior playback', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      expect(tvShouldPauseForLifecycle(state), isTrue, reason: '$state');
    }
    expect(tvShouldPauseForLifecycle(AppLifecycleState.resumed), isFalse);
    expect(tvShouldResumeAfterLifecycle(
      state: AppLifecycleState.resumed,
      wasPlayingBeforePause: true,
    ), isTrue);
    expect(tvShouldResumeAfterLifecycle(
      state: AppLifecycleState.resumed,
      wasPlayingBeforePause: false,
    ), isFalse);
    expect(tvShouldResumeAfterLifecycle(
      state: AppLifecycleState.paused,
      wasPlayingBeforePause: true,
    ), isFalse);
  });

  test('YouTube URLs require a valid video identifier', () {
    expect(
      tvExternalYoutubeWatchUrl('dQw4w9WgXcQ'),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(tvExternalYoutubeWatchUrl(''), isNull);
    expect(tvExternalYoutubeWatchUrl('not a video id'), isNull);
    expect(tvExternalYoutubeWatchUrl('dQw4w9WgXcQ&autoplay=1'), isNull);
  });
}
