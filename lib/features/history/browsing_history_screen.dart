import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../posts/post_detail_screen.dart';
import '../threads/threads_screen.dart';
import '../../core/app_config.dart';
import '../video/video_feed_screen.dart';

class BrowsingHistoryScreen extends StatefulWidget {
  const BrowsingHistoryScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<BrowsingHistoryScreen> createState() => _BrowsingHistoryScreenState();
}

class _BrowsingHistoryScreenState extends State<BrowsingHistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _clearing = false;
  String? _error;

  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final raw = response['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : response;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = _data(await widget.api.getBrowsingHistory());
      final raw = data['items'];
      final items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear browsing history?'),
        content: const Text('This removes your saved viewing history from your Testagram account. It does not delete posts, threads or videos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep history')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear history')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _clearing = true);
    try {
      await widget.api.clearBrowsingHistory();
      if (mounted) setState(() => _items = []);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not clear history: $error')));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _label(Map<String, dynamic> item) {
    final metadata = item['metadata'];
    final map = metadata is Map ? metadata : const <String, dynamic>{};
    final title = (map['title'] ?? map['name'] ?? map['text'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    switch ((item['entity_type'] ?? '').toString()) {
      case 'post': return 'Post';
      case 'thread': return 'Thread';
      case 'video': return 'Video';
      default: return 'Viewed item';
    }
  }

  String _timestamp(dynamic value) {
    final date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return 'Recently viewed';
    final local = date.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    if (sameDay) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      return 'Today · $hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  void _open(Map<String, dynamic> item) {
    final type = (item['entity_type'] ?? '').toString();
    final id = (item['entity_id'] ?? '').toString();
    if (type == 'thread' && id.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ThreadDetailScreen(api: widget.api, threadId: id)));
      return;
    }
    if (type == 'video' && id.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VideoFeedScreen(api: widget.api, videoApiBaseUri: AppConfig.videoApiOrigin)));
      return;
    }
    if (type == 'post' && id.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(api: widget.api, postId: id),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(type == 'video' ? 'Open Video from the Video feed.' : 'Open this Thread from the Threads feed.'),
    ));
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Browsing history'),
      actions: [
        IconButton(tooltip: 'Refresh history', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        IconButton(
          tooltip: 'Clear browsing history',
          onPressed: _items.isEmpty || _clearing ? null : _clear,
          icon: _clearing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_sweep_outlined),
        ),
      ],
    ),
    body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ])))
            : _items.isEmpty
                ? RefreshIndicator(onRefresh: _load, child: ListView(children: const [
                    SizedBox(height: 120),
                    Icon(Icons.history_rounded, size: 48),
                    SizedBox(height: 12),
                    Center(child: Text('Your viewed posts, threads and videos will appear here.')),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final type = (item['entity_type'] ?? 'item').toString();
                        final icon = type == 'post' ? Icons.article_outlined : type == 'thread' ? Icons.forum_outlined : Icons.play_circle_outline_rounded;
                        return ListTile(
                          leading: CircleAvatar(child: Icon(icon)),
                          title: Text(_label(item), maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${type.toUpperCase()} · ${_timestamp(item['created_at'])}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _open(item),
                        );
                      },
                    ),
                  ),
  );
}