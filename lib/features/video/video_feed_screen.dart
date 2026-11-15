import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../core/backend_api.dart';
import '../../core/video_api.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key, required this.api, required this.videoApiBaseUri, this.isActive = true});
  final BackendApi api;
  final Uri? videoApiBaseUri;
  final bool isActive;

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final _pages = PageController();
  final _session = List.generate(32, (_) => Random.secure().nextInt(16).toRadixString(16)).join();
  VideoApi? _videoApi;
  VideoPlayerController? _player;
  List<Map<String, dynamic>> _videos = [];
  final Set<String> _liked = {};
  final Set<String> _busy = {};
  final Set<String> _viewedThisSession = {};
  int _active = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final origin = widget.videoApiBaseUri;
    if (origin != null) {
      _videoApi = VideoApi(baseUri: origin, getJwt: () => widget.api.getJwt());
    }
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant VideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        if (_videoApi != null && _videos.isEmpty && !_loading) {
          _load();
        } else {
          final player = _player;
          if (player != null && player.value.isInitialized) {
            player.play();
            _recordActiveView();
          }
        }
      } else {
        _player?.pause();
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _player?.dispose();
    _videoApi?.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (_videoApi == null) {
      setState(() {
        _loading = false;
        _error = 'Video is not connected yet. Set TESTAGRAM_VIDEO_API_URL after the video service has an approved HTTPS deployment.';
      });
      return;
    }
    try {
      final items = await _videoApi!.feed();
      if (!mounted) return;
      setState(() { _videos = items; _loading = false; _error = null; });
      if (items.isNotEmpty) await _activate(0);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _activate(int index) async {
    if (_videoApi == null || index < 0 || index >= _videos.length) return;
    final old = _player;
    _player = null;
    await old?.dispose();
    if (!mounted) return;

    final id = (_videos[index]['id'] ?? '').toString();
    final player = VideoPlayerController.networkUrl(_videoApi!.manifestUri(id));
    _player = player;
    setState(() => _active = index);
    try {
      await player.initialize();
      await player.setLooping(true);
      if (!mounted || _player != player || _active != index) {
        await player.dispose();
        return;
      }
      if (!widget.isActive) return;
      await player.play();
      await _recordActiveView();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted && _player == player) setState(() => _error = 'Unable to play this video: $e');
    }
  }

  Future<void> _recordActiveView() async {
    if (!widget.isActive || _videoApi == null || _active >= _videos.length) return;
    final id = (_videos[_active]['id'] ?? '').toString();
    if (id.isEmpty || !_viewedThisSession.add(id)) return;
    try {
      // Count only after the active controller has actually started playback.
      await _videoApi!.recordView(id, _session);
    } catch (_) {
      _viewedThisSession.remove(id);
    }
  }

  Future<void> _like(Map<String, dynamic> video) async {
    final id = (video['id'] ?? '').toString();
    if (_videoApi == null || id.isEmpty || _liked.contains(id) || !_busy.add(id)) return;
    setState(() {});
    try {
      if (await _videoApi!.like(id) && mounted) {
        setState(() {
          _liked.add(id);
          video['likes'] = ((video['likes'] as num?)?.toInt() ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _comments(Map<String, dynamic> video) async {
    if (_videoApi == null) return;
    final id = (video['id'] ?? '').toString();
    final input = TextEditingController();
    var rows = <Map<String, dynamic>>[];
    var loading = true;
    var sending = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> refresh() async {
          setSheet(() { loading = true; error = null; });
          try { rows = await _videoApi!.comments(id); } catch (e) { error = e.toString(); }
          setSheet(() => loading = false);
        }
        Future<void> send() async {
          if (sending || input.text.trim().isEmpty) return;
          setSheet(() => sending = true);
          try {
            await _videoApi!.addComment(id, input.text);
            input.clear();
            await refresh();
          } catch (e) { setSheet(() => error = e.toString()); }
          setSheet(() => sending = false);
        }
        if (loading && rows.isEmpty && error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Comments', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null && rows.isEmpty
                  ? Center(child: Text(error!))
                  : rows.isEmpty
                    ? const Center(child: Text('Be the first to comment.'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text((rows[i]['user_id'] ?? 'Testagram member').toString()),
                          subtitle: Text((rows[i]['body'] ?? '').toString()),
                        ),
                      )),
              if (error != null && rows.isNotEmpty) Text(error!),
              Row(children: [
                Expanded(child: TextField(controller: input, minLines: 1, maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Add a comment'))),
                IconButton.filled(onPressed: sending ? null : send, icon: const Icon(Icons.send_rounded)),
              ]),
            ]),
          ),
        );
      }),
    );
    input.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Testagram TV', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          tooltip: 'Refresh videos',
          onPressed: _loading ? null : () async {
            await _player?.pause();
            setState(() { _loading = true; _videos = []; _error = null; });
            await _load();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: Colors.white))
      : _error != null && _videos.isEmpty
        ? _empty(_error!, retry: _videoApi != null)
        : _videos.isEmpty
          ? _empty('No public videos are ready yet. Be the first creator to publish.')
          : PageView.builder(
              controller: _pages,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: _activate,
              itemBuilder: (context, index) {
                final video = _videos[index];
                final id = (video['id'] ?? '').toString();
                final player = index == _active ? _player : null;
                final ready = player?.value.isInitialized == true;
                return Stack(fit: StackFit.expand, children: [
                  const ColoredBox(color: Color(0xFF101014)),
                  if (ready)
                    Center(child: AspectRatio(
                      aspectRatio: player!.value.aspectRatio,
                      child: VideoPlayer(player),
                    ))
                  else
                    const Center(child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 76)),
                  Positioned(
                    right: 14,
                    bottom: 112,
                    child: Column(children: [
                      _VideoAction(
                        icon: _liked.contains(id) ? Icons.favorite : Icons.favorite_border,
                        color: _liked.contains(id) ? Colors.pinkAccent : Colors.white,
                        label: _count(video['likes']),
                        onTap: () => _like(video),
                      ),
                      const SizedBox(height: 22),
                      _VideoAction(icon: Icons.mode_comment_outlined,
                        label: _count(video['comments']), onTap: () => _comments(video)),
                      const SizedBox(height: 22),
                      _VideoAction(icon: Icons.visibility_outlined, label: _count(video['views'])),
                    ]),
                  ),
                  Positioned(
                    left: 18, right: 88, bottom: 24,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((video['title'] ?? 'Untitled video').toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      if ((video['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(video['description'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                      const SizedBox(height: 8),
                      Text('Testagram creator  •  ${_duration(video['duration_ms'])}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  if (ready)
                    Positioned(top: 8, right: 8, child: IconButton(
                      tooltip: player!.value.isPlaying ? 'Pause video' : 'Play video',
                      onPressed: () => setState(() {
                        player.value.isPlaying ? player.pause() : player.play();
                      }),
                      icon: Icon(player.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                        color: Colors.white, size: 36),
                    )),
                ]);
              },
            ),
  );

  Widget _empty(String message, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.video_library_outlined, color: Colors.white70, size: 54),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        if (retry) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ],
      ]),
    ),
  );

  static String _count(dynamic raw) {
    final n = (raw as num?)?.toInt() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  static String _duration(dynamic raw) {
    final seconds = max(0, ((raw as num?)?.toInt() ?? 0) ~/ 1000);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({required this.icon, required this.label, this.color = Colors.white, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(28),
    child: Column(children: [
      Icon(icon, color: color, size: 31),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}
