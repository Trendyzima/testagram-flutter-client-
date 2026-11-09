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
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _query.text.trim();
    if (value.length < 2) {
      setState(() => _error = 'Enter at least two characters to search.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.search(query: value);
      final raw = response['data'];
      final data = raw is Map ? raw : response;
      final postRows = data['posts'];
      final userRows = data['users'];
      if (!mounted) return;
      setState(() {
        _posts = postRows is List ? postRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _people = userRows is List ? userRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
                subtitle: Text('@' + (person['username'] ?? '').toString()),
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
