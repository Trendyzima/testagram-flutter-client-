import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../../core/widgets/testagram_app_bar.dart';
import '../profile/profile_screen.dart';
import '../posts/post_detail_screen.dart';
import '../federation/remote_post_detail_screen.dart';
import '../feed/social_post_text.dart';
import 'hashtag_screen.dart';
import 'hashtags_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.api, this.initialQuery});
  final BackendApi api;
  final String? initialQuery;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _query = TextEditingController();
  final _from = TextEditingController();
  final _since = TextEditingController();
  final _until = TextEditingController();
  final _language = TextEditingController();
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _trending = [];
  List<Map<String, dynamic>> _trendingWords = [];
  bool _trendingWordsLoading = true;
  String? _trendingWordsError;
  bool _trendingLoading = true;
  String? _trendingError;
  final Map<String, String> _followStatus = {};
  final Set<String> _busyFollow = {};
  bool _loading = false;
  String _searchKind = 'all';
  String _searchSort = 'latest';
  bool _mediaOnly = false;
  bool _videoOnly = false;
  bool _hasSearched = false;
  int _searchGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _loadTrendingWords();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.length >= 2) {
      _query.text = initial;
      _searchKind = 'posts';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
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

  Future<void> _loadTrendingWords() async {
    setState(() { _trendingWordsLoading = true; _trendingWordsError = null; });
    try {
      final response = await widget.api.getTrendingWords(limit: 20);
      final rawData = response['data'];
      final data = rawData is Map ? rawData : response;
      final rawItems = data['items'];
      if (!mounted) return;
      setState(() {
        _trendingWords = rawItems is List
            ? rawItems.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : [];
      });
    } catch (error) {
      if (mounted) setState(() => _trendingWordsError = error.toString());
    } finally {
      if (mounted) setState(() => _trendingWordsLoading = false);
    }
  }

  void _searchWord(String word) {
    _query.text = word;
    setState(() => _searchKind = 'posts');
    _search();
  }

  Future<void> _openMention(String handle) async {
    try {
      final response = await widget.api.resolveProfileUsername(handle);
      final rawData = response['data'];
      final data = rawData is Map ? rawData : response;
      final raw = data['profile'] ?? data['user'] ?? data;
      final userId = raw is Map
          ? (raw['id'] ?? raw['user_id'] ?? '').toString()
          : '';
      if (!mounted) return;
      if (userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('@$handle is unavailable or not discoverable.')),
        );
        return;
      }
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(api: widget.api, userId: userId),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open @$handle: $error')),
        );
      }
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
    _from.dispose();
    _since.dispose();
    _until.dispose();
    _language.dispose();
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
      final response = await widget.api.search(
        query: value,
        kind: _searchKind,
        from: _from.text,
        since: _since.text,
        until: _until.text,
        language: _language.text,
        sort: _searchSort,
        mediaOnly: _mediaOnly,
        videoOnly: _videoOnly,
      );
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
        _hasSearched = true;
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

  bool _isCanonicalAccountPostId(String value) {
    final parts = value.split('-');
    if (parts.length != 5 ||
        parts[0].length != 8 ||
        parts[1].length != 4 ||
        parts[2].length != 4 ||
        parts[3].length != 4 ||
        parts[4].length != 12 ||
        value.length != 36 ||
        !'12345678'.contains(value[14]) ||
        !'89abAB'.contains(value[19])) {
      return false;
    }
    bool isHex(String part) => part.codeUnits.every((code) =>
        (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 70) ||
        (code >= 97 && code <= 102));
    return parts.every(isHex);
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
    appBar: TestagramAppBar(
      title: 'Discover',
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All')),
            ButtonSegment(value: 'posts', label: Text('Posts')),
            ButtonSegment(value: 'people', label: Text('People')),
          ],
          selected: {_searchKind},
          onSelectionChanged: (selection) {
            setState(() => _searchKind = selection.first);
            if (_query.text.trim().length >= 2) _search();
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: _searchKind == 'people' ? 'Search people' : _searchKind == 'posts' ? 'Search posts' : 'Search people and posts',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      ExpansionTile(
        title: const Text('Advanced search'),
        leading: const Icon(Icons.tune_rounded),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          TextField(
            controller: _from,
            decoration: const InputDecoration(
              labelText: 'From account',
              prefixText: '@',
              hintText: 'username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _since,
                decoration: const InputDecoration(
                  labelText: 'Since',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _until,
                decoration: const InputDecoration(
                  labelText: 'Until (exclusive)',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _language,
            decoration: const InputDecoration(
              labelText: 'Language',
              hintText: 'e.g. en-KE',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _searchSort,
            decoration: const InputDecoration(
              labelText: 'Sort results',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Newest first')),
              DropdownMenuItem(value: 'popular', child: Text('Most engaging')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _searchSort = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Posts with media'),
            value: _mediaOnly,
            onChanged: (value) => setState(() => _mediaOnly = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Videos only'),
            value: _videoOnly,
            onChanged: (value) => setState(() => _videoOnly = value),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Apply filters'),
            ),
          ),
        ],
      ),
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
          if (_trendingWords.isNotEmpty) ...[
            const _SectionTitle('Trending words'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _trendingWords.map((item) {
                  final word = (item['word'] ?? '').toString();
                  final count = (item['posts_count'] ?? 0).toString();
                  final reasons = item['reasons'];
                  final rising = reasons is List && reasons.contains('accelerating');
                  return ActionChip(
                    avatar: Icon(rising ? Icons.trending_up_rounded : Icons.text_fields_rounded, size: 16),
                    label: Text('$word · $count'),
                    onPressed: word.isEmpty ? null : () => _searchWord(word),
                  );
                }).toList(),
              ),
            ),
          ] else if (_trendingWordsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_trendingWordsError != null)
            ListTile(
              leading: const Icon(Icons.text_fields_rounded),
              title: const Text('Trending words unavailable'),
              subtitle: Text(_trendingWordsError!),
              trailing: IconButton(
                tooltip: 'Retry trending words',
                onPressed: _loadTrendingWords,
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
              Builder(builder: (context) {
                final origin = (post['origin'] ?? '').toString().toLowerCase();
                final postId = (post['id'] ?? '').toString();
                // Federated object URIs and DIDs are not native post UUIDs.
                // Only an explicitly local canonical UUID may enter the
                // local detail route. Opaque IDs are treated as remote snapshots.
                final isRemote = origin != 'local';
                final canOpen = isRemote || _isCanonicalAccountPostId(postId);
                final source = switch (origin) {
                  'activitypub' => 'Fediverse',
                  'atproto' || 'bluesky' => 'Bluesky',
                  'local' => '',
                  _ => 'Federated network',
                };
                final author = (post['author'] is Map
                    ? (post['author']['username'] ?? '')
                    : '').toString();
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(isRemote ? Icons.public_rounded : Icons.article_outlined),
                  ),
                  title: SocialPostText(
                    text: (post['content'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    onHashtagTap: _openHashtag,
                    onMentionTap: _openMention,
                  ),
                  subtitle: Text([
                    if (author.isNotEmpty) '@$author',
                    if (isRemote) 'Remote · $source',
                  ].join('  · ')),
                  trailing: Icon(isRemote ? Icons.public_rounded : Icons.chevron_right_rounded),
                  onTap: postId.isEmpty || !canOpen
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => isRemote
                                  ? RemotePostDetailScreen(
                                      post: Map<String, dynamic>.from(post),
                                    )
                                  : PostDetailScreen(
                                      api: widget.api,
                                      postId: postId,
                                    ),
                            ),
                          ),
                );
              }),
          ],
          if (_hasSearched && !_loading && _error == null && _posts.isEmpty && _people.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(switch (_searchKind) {
                'people' => 'No discoverable people matched this search.',
                'posts' => 'No visible posts matched this search.',
                _ => 'No visible people or posts matched this search.',
              }),
            ),
          if (!_hasSearched && !_loading && _error == null && _posts.isEmpty && _people.isEmpty && _trending.isEmpty)
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
