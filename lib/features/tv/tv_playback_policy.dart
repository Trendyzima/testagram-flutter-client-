import 'package:flutter/widgets.dart';

/// Whether the selected TV item has an actual playback surface.
bool tvHasPlaybackSurface({
  required bool isWeb,
  required String? webPlaybackUrl,
  required bool hasExternalPlaybackAction,
  required bool hasInitializedNativePlayer,
}) {
  if (hasExternalPlaybackAction || hasInitializedNativePlayer) return true;
  return isWeb && (webPlaybackUrl?.trim().isNotEmpty ?? false);
}

/// Request an ad only after playback starts and only for the current channel.
bool tvCanRequestSponsoredAd({
  required bool hasPlaybackStarted,
  required bool alreadyRequested,
  required bool isCurrentGeneration,
}) =>
    hasPlaybackStarted && !alreadyRequested && isCurrentGeneration;

/// Pause native playback whenever the app is not foregrounded.
bool tvShouldPauseForLifecycle(AppLifecycleState state) =>
    state != AppLifecycleState.resumed;

/// Resume only the same controller that was playing before backgrounding.
bool tvShouldResumeAfterLifecycle({
  required AppLifecycleState state,
  required bool wasPlayingBeforePause,
}) =>
    state == AppLifecycleState.resumed && wasPlayingBeforePause;

/// Build a canonical external YouTube URL only for a valid 11-char video ID.
String? tvExternalYoutubeWatchUrl(String videoId) {
  final id = videoId.trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
  return Uri.https('www.youtube.com', '/watch', {'v': id}).toString();
}
