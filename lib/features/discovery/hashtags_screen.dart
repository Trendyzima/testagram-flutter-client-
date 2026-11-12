import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import 'hashtag_screen.dart';

class HashtagsScreen extends StatefulWidget {
  const HashtagsScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<HashtagsScreen> createState() => _HashtagsScreenState();
}

class _HashtagsScreenState extends State<HashtagsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _topics = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.getTrendingHashtags(limit: 50);
      final raw = response['data'];
      final data = raw is Map ? raw : response;
      final items = data['items'];
      if (!mounted) return;
      setState(() {
        _topics = items is List
            ? items.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String raw) {
    final tag = raw.trim().replaceFirst(RegExp(r'^#'), '');
    if (tag.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HashtagScreen(api: widget.api, tag: tag),
    ));
  }

  void _submitSearch() {
    final value = _search.text.trim();
    if (value.isEmpty) return;
    _open(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hashtags')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                hintText: 'Find a hashtag',
                prefixIcon: const Icon(Icons.tag),
                suffixIcon: IconButton(
                  tooltip: 'Open hashtag',
                  onPressed: _submitSearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Trending this week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          if (_loading && _topics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _topics.isEmpty)
            ListTile(
              title: const Text('Trending hashtags are unavailable'),
              subtitle: Text(_error!),
              trailing: IconButton(
                tooltip: 'Retry',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            )
          else if (_topics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No trending hashtags yet. Be the first to start a conversation.'),
            )
          else
            for (var index = 0; index < _topics.length; index++)
              ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('#${(_topics[index]['tag'] ?? '').toString()}'),
                subtitle: Text('${_topics[index]['posts_count'] ?? 0} public posts this week'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open((_topics[index]['tag'] ?? '').toString()),
              ),
        ],
      ),
    ),
  );
}
