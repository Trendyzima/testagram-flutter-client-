import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/backend_api.dart';

class CreatorVideoScreen extends StatefulWidget {
  const CreatorVideoScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<CreatorVideoScreen> createState() => _CreatorVideoScreenState();
}

class _CreatorVideoScreenState extends State<CreatorVideoScreen> {
  final _picker = ImagePicker();
  final _handle = TextEditingController();
  final _channelName = TextEditingController();
  final _channelDescription = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();

  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _videos = [];
  String? _channelId;
  XFile? _video;
  String? _videoId;
  String _status = '';
  String _visibility = 'private';
  bool _loadingChannels = true;
  bool _loadingVideos = true;
  bool _creatingChannel = false;
  bool _busy = false;
  bool _uploadOutcomeUnknown = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _loadVideos();
  }

  @override
  void dispose() {
    _handle.dispose();
    _channelName.dispose();
    _channelDescription.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loadingChannels = true;
      _error = null;
    });
    try {
      final channels = await widget.api.getCreatorVideoChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _channelId = channels.isEmpty
            ? null
            : (_channelId != null &&
                    channels.any((item) => item['id'].toString() == _channelId)
                ? _channelId
                : channels.first['id'].toString());
        _creatingChannel = channels.isEmpty;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          if (_channels.isEmpty) _creatingChannel = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  Future<void> _loadVideos() async {
    setState(() => _loadingVideos = true);
    try {
      final videos = await widget.api.getCreatorVideos();
      if (!mounted) return;
      setState(() => _videos = videos);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingVideos = false);
    }
  }

  Future<void> _refreshOwnedVideo(String id) async {
    if (_busy || id.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.getCreatorVideoStatus(id);
      if (!mounted) return;
      setState(() {
        _videos = _videos.map((video) => video['id'].toString() == id
            ? {...video, ...result}
            : video).toList();
        if (_videoId == id) {
          _status = (result['status'] ?? _status).toString();
          _visibility = (result['visibility'] ?? _visibility).toString();
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _createChannel() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final channel = await widget.api.createCreatorVideoChannel(
        handle: _handle.text,
        name: _channelName.text,
        description: _channelDescription.text,
      );
      final displayChannel = {
        ...channel,
        'handle': _handle.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
        'name': _channelName.text.trim(),
        'description': _channelDescription.text.trim(),
      };
      if (!mounted) return;
      setState(() {
        _channels = [displayChannel, ..._channels];
        _channelId = channel['id'].toString();
        _creatingChannel = false;
        _handle.clear();
        _channelName.clear();
        _channelDescription.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creator channel created.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      setState(() => _error =
          'Creator uploads are available in the native mobile app. Browser upload is not enabled yet.');
      return;
    }
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 30),
      );
      if (picked == null || !mounted) return;
      setState(() {
        _video = picked;
        _videoId = null;
        _status = '';
        _visibility = 'private';
        _uploadOutcomeUnknown = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not select this video: $error');
    }
  }

  Future<void> _upload() async {
    final video = _video;
    if (_busy || video == null || _channelId == null || _title.text.trim().isEmpty) {
      setState(() => _error = 'Choose a channel, select a video and enter a title.');
      return;
    }
    if (kIsWeb) {
      setState(() => _error = 'Creator uploads are not enabled in the browser yet.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _videoId = null;
      _uploadOutcomeUnknown = false;
      _status = 'uploading';
    });
    try {
      final result = await widget.api.uploadCreatorVideo(
        filePath: video.path,
        channelId: _channelId!,
        title: _title.text,
        description: _description.text,
      );
      if (!mounted) return;
      setState(() {
        _videoId = result['id'].toString();
        _status = (result['status'] ?? 'queued').toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload received. Testagram is processing your video.')),
      );
      await _loadVideos();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _uploadOutcomeUnknown = _error!.contains('status is unknown') ||
              _error!.contains('final status is unknown');
          if (_uploadOutcomeUnknown) _status = 'unknown';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshStatus() async {
    final id = _videoId;
    if (_busy || id == null || id.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.getCreatorVideoStatus(id);
      if (!mounted) return;
      setState(() {
        _status = (result['status'] ?? 'unknown').toString();
        _visibility = (result['visibility'] ?? 'private').toString();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishVideo(String id) async {
    if (_busy || id.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.publishCreatorVideo(id);
      if (!mounted) return;
      setState(() {
        _videos = _videos.map((video) => video['id'].toString() == id
            ? {...video, 'visibility': 'public'}
            : video).toList();
        if (_videoId == id) _visibility = 'public';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your video is now public on Testagram TV.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteVideo(String id, String status) async {
    if (_busy || id.isEmpty ||
        !const {'ready', 'failed', 'blocked'}.contains(status)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this video?'),
        content: const Text(
          'This removes the video from Testagram TV and schedules its original, HLS and poster files for cleanup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep video'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete video'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.deleteCreatorVideo(id);
      if (!mounted) return;
      setState(() {
        _videos.removeWhere((video) => video['id'].toString() == id);
        if (_videoId == id) {
          _videoId = null;
          _video = null;
          _status = '';
          _visibility = 'private';
          _uploadOutcomeUnknown = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video deleted. Media cleanup is queued securely.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final managedVideos = _videos
        .where((video) => video['id'].toString() != _videoId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Create video')),
      body: _loadingChannels
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Publish to Testagram TV',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Upload to a channel you own. Videos remain private while Testagram processes them; publishing is a separate action available only after processing succeeds.',
                ),
                const SizedBox(height: 20),
                if (_channels.isNotEmpty && !_creatingChannel) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _channelId,
                    decoration: const InputDecoration(labelText: 'Creator channel'),
                    items: _channels
                        .map((channel) => DropdownMenuItem<String>(
                              value: channel['id'].toString(),
                              child: Text('${channel['name']}  ·  @${channel['handle']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _channelId = value),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _creatingChannel = true),
                      icon: const Icon(Icons.add),
                      label: const Text('Create another channel'),
                    ),
                  ),
                ],
                if (_creatingChannel) ...[
                  Text('Create your channel', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _handle,
                    enabled: !_busy,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Channel handle',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _channelName,
                    enabled: !_busy,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Channel name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _channelDescription,
                    enabled: !_busy,
                    maxLines: 2,
                    maxLength: 2000,
                    decoration:
                        const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _createChannel,
                    child: const Text('Create channel'),
                  ),
                  if (_channels.isNotEmpty)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _creatingChannel = false),
                      child: const Text('Use an existing channel'),
                    ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Video title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  enabled: !_busy,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration:
                      const InputDecoration(labelText: 'Video description'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(_video == null
                      ? 'Choose video from device'
                      : _video!.name),
                ),
                const SizedBox(height: 8),
                const Text('Supported formats: MP4, MOV, MKV and WebM.'),
                if (_uploadOutcomeUnknown)
                  const Text('The upload may have reached Testagram. Do not retry this same file; choose a different file or contact support to check the original upload.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy || _uploadOutcomeUnknown || _video == null || _channelId == null
                      ? null
                      : _upload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(_busy && _status == 'uploading'
                      ? 'Uploading…'
                      : 'Upload video privately'),
                ),
                if (_loadingVideos)
                  const LinearProgressIndicator(),
                if (managedVideos.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('My videos', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...managedVideos.map((video) {
                    final id = video['id'].toString();
                    final status = (video['status'] ?? 'unknown').toString();
                    final visibility = (video['visibility'] ?? 'private').toString();
                    final canDelete = const {'ready', 'failed', 'blocked'}.contains(status);
                    final canPublish = status == 'ready' && visibility != 'public';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.video_library_outlined),
                        title: Text((video['title'] ?? 'Untitled video').toString(),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${(video['channel_name'] ?? 'Creator channel')} · ${status.toUpperCase()} · $visibility',
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'Refresh video status',
                              onPressed: _busy ? null : () => _refreshOwnedVideo(id),
                              icon: const Icon(Icons.refresh),
                            ),
                            if (canPublish)
                              IconButton(
                                tooltip: 'Publish video',
                                onPressed: _busy ? null : () => _publishVideo(id),
                                icon: const Icon(Icons.public),
                              ),
                            if (canDelete)
                              IconButton(
                                tooltip: 'Delete video',
                                onPressed: _busy ? null : () => _deleteVideo(id, status),
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else if (!_loadingVideos) ...[
                  const SizedBox(height: 24),
                  Text('My videos', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Your uploaded videos will appear here.'),
                ],
                if (_videoId != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Processing status',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.movie_creation_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status.toUpperCase(),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh processing status',
                                onPressed: _busy ? null : _refreshStatus,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          Text('Visibility: $_visibility'),
                          if (_status == 'failed')
                            const Text(
                              'Processing failed. The video has not been published.',
                            ),
                          if (_status == 'ready' && _visibility != 'public') ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _publishVideo(_videoId!),
                              icon: const Icon(Icons.public),
                              label: const Text('Publish video publicly'),
                            ),
                          ],
                          if (_visibility == 'public')
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.check_circle_outline),
                              title: Text('Published on Testagram TV'),
                            ),
                          if (const {'ready', 'failed', 'blocked'}.contains(_status)) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _busy ? null : () => _deleteVideo(_videoId!, _status),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete video'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  if (_channels.isEmpty)
                    TextButton.icon(
                      onPressed: _busy ? null : _loadChannels,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry loading channels'),
                    ),
                ],
              ],
            ),
    );
  }
}
