import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../profile/profile_screen.dart';
import 'hashtag_screen.dart';
import 'hashtags_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.api});
  final BackendApi api;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _trending = [];
  bool _trendingLoading = true;
  String? _trendingError;
  final Map<String, String> _followStatus = {};
  final Set<String> _busyFollow = {};
  bool _loading = false;
  int _searchGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() { _trendingLoading = true; _trendingError = null; });
    try {
      final response = await widget.api.getTrendingHashtags(limit: 20);
      final rawData = response['data'];
      final data = rawData is Map ? rawData : response;
      final rawItems = data['items'];
      if (!mounted) return;
      setState(() {
        _trending = rawItems is List
            ? rawItems.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : [];
      });
    } catch (error) {
      if (mounted) setState(() => _trendingError = error.toString());
    } finally {
      if (mounted) setState(() => _trendingLoading = false);
    }
  }

  void _openHashtag(String value) {
    final tag = value.trim().replaceFirst(RegExp(r'^#'), '');
    if (tag.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HashtagScreen(api: widget.api, tag: tag),
    ));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _query.text.trim();
    if (value.startsWith('#') && value.length > 1) {
      _openHashtag(value);
      return;
    }
    final generation = ++_searchGeneration;
    if (value.length < 2) {
      setState(() {
        _loading = false;
        _error = 'Enter at least two characters to search.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.search(query: value);
      final raw = response['data'];
      final data = raw is Map ? raw : response;
      final postRows = data['posts'];
      final userRows = data['users'];
      final people = userRows is List ? userRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      final followStates = await Future.wait(people.map((person) async {
        final id = (person['id'] ?? person['user_id'] ?? '').toString();
        if (id.isEmpty) return <String, dynamic>{};
        try {
          final state = await widget.api.getFollowState(id);
          final data = state['data'];
          return {'id': id, 'status': data is Map ? (data['status'] ?? (data['following'] == true ? 'accepted' : '')).toString() : ''};
        } catch (_) { return {'id': id, 'status': ''}; }
      }));
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _followStatus.clear();
        for (final state in followStates) {
          if (state['id'] != null) _followStatus[state['id'] as String] = (state['status'] ?? '').toString();
        }
        _posts = postRows is List ? postRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _people = people;
      });
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleFollow(String id) async {
    if (id.isEmpty || _busyFollow.contains(id)) return;
    setState(() => _busyFollow.add(id));
    try {
      if (_followStatus[id] == 'accepted' || _followStatus[id] == 'pending') {
        await widget.api.unfollowUser(id);
      } else {
        await widget.api.followUser(id);
      }
      final response = await widget.api.getFollowState(id);
      final data = response['data'];
      if (mounted) setState(() => _followStatus[id] = data is Map ? (data['status'] ?? (data['following'] == true ? 'accepted' : '')).toString() : '');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyFollow.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Explore'),
      actions: [
        IconButton(
          tooltip: 'Browse hashtags',
          icon: const Icon(Icons.tag),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => HashtagsScreen(api: widget.api),
          )),
        ),
      ],
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Search people and posts',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
      Expanded(child: ListView(
        children: [
          if (_trending.isNotEmpty) ...[
            const _SectionTitle('Trending hashtags'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _trending.map((topic) {
                  final tag = (topic['tag'] ?? '').toString();
                  final count = (topic['posts_count'] ?? 0).toString();
                  return ActionChip(
                    avatar: const Icon(Icons.tag, size: 16),
                    label: Text('#$tag  ·  $count'),
                    onPressed: tag.isEmpty ? null : () => _openHashtag(tag),
                  );
                }).toList(),
              ),
            ),
          ] else if (_trendingLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: LinearProgressIndicator(),
            )
          else if (_trendingError != null)
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Trending topics unavailable'),
              subtitle: Text(_trendingError!),
              trailing: IconButton(
                tooltip: 'Retry trending topics',
                onPressed: _loadTrending,
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (_people.isNotEmpty) ...[
            const _SectionTitle('People'),
            for (final person in _people)
              ListTile(
                onTap: (person['id'] ?? person['user_id']) == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(
                              api: widget.api,
                              userId: (person['id'] ?? person['user_id']).toString(),
                            ),
                          ),
                        ),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text((person['display_name'] ?? person['username'] ?? 'Testagram user').toString()),
                subtitle: Text('@${(person['username'] ?? '').toString()}'),
                trailing: (person['id'] ?? person['user_id']) == null
                    ? null
                    : OutlinedButton(
                        onPressed: _busyFollow.contains((person['id'] ?? person['user_id']).toString())
                            ? null
                            : () => _toggleFollow((person['id'] ?? person['user_id']).toString()),
                        child: Text(switch (_followStatus[(person['id'] ?? person['user_id']).toString()]) { 'accepted' => 'Following', 'pending' => 'Requested', _ => 'Follow' }),
                      ),
              ),
          ],
          if (_posts.isNotEmpty) ...[
            const _SectionTitle('Posts'),
            for (final post in _posts)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.article_outlined)),
                title: Text((post['content'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text((post['author'] is Map ? (post['author']['username'] ?? '') : '').toString()),
              ),
          ],
          if (!_loading && _error == null && _posts.isEmpty && _people.isEmpty && _trending.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('Search for people or posts to explore Testagram.')),
        ],
      )),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(value, style: Theme.of(context).textTheme.titleMedium),
  );
}
