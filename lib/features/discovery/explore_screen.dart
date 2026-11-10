import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

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
  final Map<String, String> _followStatus = {};
  final Set<String> _busyFollow = {};
  bool _loading = false;
  int _searchGeneration = 0;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _query.text.trim();
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
    appBar: AppBar(title: const Text('Explore')),
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
          if (_people.isNotEmpty) ...[
            const _SectionTitle('People'),
            for (final person in _people)
              ListTile(
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
          if (!_loading && _error == null && _posts.isEmpty && _people.isEmpty)
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
