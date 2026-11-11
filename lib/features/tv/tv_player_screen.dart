import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'tv_models.dart';
import 'tv_repository.dart';

class TvPlayerScreen extends StatefulWidget {
  const TvPlayerScreen({
    super.key,
    required this.repository,
    required this.channel,
  });

  final TvRepository repository;
  final TvChannel channel;

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  TvPlaybackGrant? _grant;
  String? _error;
  bool _loading = true;
  bool _wasPlayingBeforePause = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wasPlayingBeforePause = controller.value.isPlaying;
      if (_wasPlayingBeforePause) unawaited(controller.pause());
    } else if (state == AppLifecycleState.resumed && _wasPlayingBeforePause) {
      _wasPlayingBeforePause = false;
      if (mounted && identical(controller, _controller)) {
        unawaited(controller.play());
      }
    }
  }

  Future<void> _startPlayback() async {
    final generation = ++_generation;
    final previous = _controller;
    _controller = null;
    if (previous != null) await previous.dispose();
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = true;
      _error = null;
      _grant = null;
    });
    try {
      final grant = await widget.repository.requestPlayback(
        widget.channel.id,
        now: DateTime.now().toUtc(),
      );
      if (!mounted || generation != _generation) return;
      final controller = VideoPlayerController.networkUrl(
        grant.playbackUrl,
        httpHeaders: grant.requiredHeaders,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      if (!grant.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const FormatException('Playback grant expired during initialization');
      }
      await controller.setLooping(false);
      setState(() {
        _grant = grant;
        _loading = false;
        _error = null;
      });
      await controller.play();
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is FormatException
            ? error.message
            : 'Playback could not start. The stream may be offline or unsupported.';
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.name),
        actions: [
          IconButton(
            tooltip: 'Retry playback',
            onPressed: _loading ? null : _startPlayback,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller?.value.isInitialized == true
                      ? controller!.value.aspectRatio
                      : 16 / 9,
                  child: _buildVideoSurface(controller),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Connecting to channel…', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _startPlayback,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (controller != null && controller.value.isInitialized)
              _controls(controller),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (widget.channel.countryCode != null) widget.channel.countryCode!,
                        widget.channel.categories.join(' • '),
                        if (_grant != null) 'Session expires ${_grant!.expiresAt.toLocal()}',
                      ].where((item) => item.isNotEmpty).join(' · '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSurface(VideoPlayerController? controller) {
    if (controller != null && controller.value.isInitialized) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(controller),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF18A957),
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      );
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: Icon(Icons.live_tv, color: Colors.white54, size: 64)),
    );
  }

  Widget _controls(VideoPlayerController controller) {
    final value = controller.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Restart stream',
            color: Colors.white,
            onPressed: () => controller.seekTo(Duration.zero),
            icon: const Icon(Icons.replay_10),
          ),
          const SizedBox(width: 16),
          IconButton.filled(
            tooltip: value.isPlaying ? 'Pause' : 'Play',
            onPressed: () => value.isPlaying ? controller.pause() : controller.play(),
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Mute or unmute',
            color: Colors.white,
            onPressed: () => controller.setVolume(value.volume > 0 ? 0 : 1),
            icon: Icon(value.volume > 0 ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
    );
  }
}
