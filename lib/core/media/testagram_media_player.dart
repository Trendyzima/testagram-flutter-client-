import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shared media renderer for public and viewer-authorized private media.
class TestagramMediaView extends StatelessWidget {
  const TestagramMediaView({
    super.key,
    required this.url,
    required this.contentType,
    this.headers = const {},
    this.height = 230,
    this.fit = BoxFit.cover,
  });

  final String url;
  final String contentType;
  final Map<String, String> headers;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (MediaPlaybackDescriptor.isVideoContentType(contentType)) {
      return TestagramVideoPlayer(
        key: ValueKey(url),
        url: url,
        headers: headers,
        height: height,
      );
    }
    return Image.network(
      url,
      width: double.infinity,
      height: height,
      fit: fit,
      headers: headers.isEmpty ? null : headers,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class MediaPlaybackDescriptor {
  const MediaPlaybackDescriptor._();

  static bool isVideoContentType(String? value) =>
      (value ?? '').toLowerCase().trim().startsWith('video/');

  static Map<String, String> headersForUrl(
    Map<dynamic, dynamic>? rawHeaders,
    String url,
  ) {
    final value = rawHeaders?[url]?.toString() ?? '';
    if (value.startsWith('Bearer v1.') && !value.contains('\n') && !value.contains('\r')) {
      return {'Authorization': value};
    }
    return const {};
  }
}

class TestagramVideoPlayer extends StatefulWidget {
  const TestagramVideoPlayer({
    super.key,
    required this.url,
    this.headers = const {},
    this.height = 230,
  });

  final String url;
  final Map<String, String> headers;
  final double height;

  @override
  State<TestagramVideoPlayer> createState() => _TestagramVideoPlayerState();
}

class _TestagramVideoPlayerState extends State<TestagramVideoPlayer> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = const FormatException('Media URL must be HTTPS.'));
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: widget.headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final ratio = controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: ratio, child: VideoPlayer(controller)),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                  setState(() {});
                },
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
