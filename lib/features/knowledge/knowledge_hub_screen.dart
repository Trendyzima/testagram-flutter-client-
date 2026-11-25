import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../../core/widgets/testagram_state_view.dart';
import '../../core/widgets/testagram_app_bar.dart';

class KnowledgeHubScreen extends StatefulWidget {
  const KnowledgeHubScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
  Future<void> _askQuestion() async {
    var topicOptions = <Map<String, dynamic>>[];
    try {
      final response = await widget.api.getKnowledgeTopics(limit: 50);
      final raw = response['data'];
      if (raw is Map && raw['items'] is List) {
        topicOptions = (raw['items'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {
      // Topic discovery is optional while the Q&A service remains available.
    }
    if (!mounted) return;
    final title = TextEditingController();
    final body = TextEditingController();
    var visibility = 'public';
    final selectedTopics = <String>{};
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ask the community'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Your question',
                    hintText: 'Be clear and specific',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  maxLines: 5,
                  maxLength: 20000,
                  decoration: const InputDecoration(
                    labelText: 'Add context (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(
                    labelText: 'Who can see this?',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Everyone')),
                    DropdownMenuItem(value: 'followers', child: Text('Followers')),
                    DropdownMenuItem(value: 'private', child: Text('Only me')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => visibility = value);
                  },
                ),
                if (topicOptions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add topics (up to 5)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      for (final topic in topicOptions)
                        FilterChip(
                          label: Text((topic['name'] ?? topic['slug'] ?? '').toString()),
                          selected: selectedTopics.contains((topic['slug'] ?? '').toString()),
                          onSelected: (selected) {
                            final slug = (topic['slug'] ?? '').toString();
                            if (selected && selectedTopics.length >= 5) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('Choose no more than five topics.')),
                              );
                              return;
                            }
                            setDialogState(() {
                              if (selected) {
                                selectedTopics.add(slug);
                              } else {
                                selectedTopics.remove(slug);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().runes.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Write a question with at least 8 characters.')),
                  );
                  return;
                }
                try {
                  await widget.api.createKnowledgeQuestion(
                    title: title.text.trim(),
                    body: body.text.trim(),
                    visibility: visibility,
                    topicSlugs: selectedTopics.toList()..sort(),
                    idempotencyKey: 'question-${DateTime.now().microsecondsSinceEpoch}',
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Could not publish question: $error')),
                    );
                  }
                }
              },
              child: const Text('Publish question'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    if (created == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['Topics', 'For you', 'Following', 'Topic feed', 'Unanswered', 'Your questions'];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: 1,
      child: Scaffold(
        appBar: TestagramAppBar(
          title: 'Knowledge',
          actions: [
            IconButton(
              tooltip: 'About Questions & Answers',
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Testagram Knowledge',
                applicationVersion: 'Native Q&A',
                children: const [
                  Text('Ask useful questions, share substantive answers and accept the answer that solves your question. Knowledge uses your Testagram account and Backend privacy controls.'),
                ],
              ),
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(text: tab)],
          ),
        ),
        body: TabBarView(
          children: [
            _KnowledgeTopicsTab(api: widget.api),
            _KnowledgeQuestionList(api: widget.api, status: 'all'),
            _KnowledgeQuestionList(api: widget.api, status: 'all', following: true),
            _KnowledgeQuestionList(api: widget.api, status: 'all', topicsFollowing: true),
            _KnowledgeQuestionList(api: widget.api, status: 'open'),
            _KnowledgeQuestionList(api: widget.api, status: 'all', mine: true),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _askQuestion,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ask a question'),
        ),
      ),
    );
  }
}

class _KnowledgeTopicsTab extends StatefulWidget {
  const _KnowledgeTopicsTab({required this.api});
  final BackendApi api;

  @override
  State<_KnowledgeTopicsTab> createState() => _KnowledgeTopicsTabState();
}

class _KnowledgeTopicsTabState extends State<_KnowledgeTopicsTab> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _future;
  String _nextCursor = '';
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load({String? after}) async {
    final response = await widget.api.getKnowledgeTopics(
      query: _search.text.trim(),
      limit: 50,
      after: after,
    );
    final raw = response['data'];
    if (raw is Map) {
      _nextCursor = (raw['next_cursor'] ?? '').toString();
      _hasMore = raw['has_more'] == true && _nextCursor.isNotEmpty;
    }
    return response;
  }

  Future<void> _refresh() async {
    _nextCursor = '';
    _hasMore = false;
    final next = _load();
    setState(() {
      _loadingMore = false;
      _future = next;
    });
    await next;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final current = await _future;
      final next = await _load(after: _nextCursor);
      final currentData = current['data'];
      final nextData = next['data'];
      if (currentData is! Map || nextData is! Map) return;
      final existing = currentData['items'] is List
          ? List<dynamic>.from(currentData['items'] as List)
          : <dynamic>[];
      final incoming = nextData['items'] is List
          ? List<dynamic>.from(nextData['items'] as List)
          : <dynamic>[];
      final merged = <String, dynamic>{
        ...Map<String, dynamic>.from(currentData),
        'items': [...existing, ...incoming],
        'has_more': nextData['has_more'] == true,
        'next_cursor': nextData['next_cursor'] ?? '',
      };
      setState(() {
        _future = Future.value({...current, 'data': merged});
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load more topics: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> topic) async {
    final slug = (topic['slug'] ?? '').toString();
    if (slug.isEmpty) return;
    try {
      if (topic['is_following'] == true) {
        await widget.api.unfollowKnowledgeTopic(slug);
      } else {
        await widget.api.followKnowledgeTopic(slug);
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update topic follow: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _refresh(),
            decoration: InputDecoration(
              hintText: 'Search topics',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search topics',
                onPressed: _refresh,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 10),
                        const Text('Topics could not be loaded.'),
                        const SizedBox(height: 10),
                        FilledButton.tonal(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }
              final raw = snapshot.data?['data'];
              final topics = raw is Map && raw['items'] is List
                  ? (raw['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                  : <Map<String, dynamic>>[];
              if (topics.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 110),
                      Icon(Icons.topic_outlined, size: 42),
                      SizedBox(height: 12),
                      Center(child: Text('No matching topics yet.')),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: topics.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == topics.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextButton(
                            onPressed: _loadingMore ? null : _loadMore,
                            child: Text(_loadingMore ? 'Loading topics…' : 'Load more topics'),
                          ),
                        ),
                      );
                    }
                    final topic = topics[index];
                    final slug = (topic['slug'] ?? '').toString();
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      leading: const CircleAvatar(child: Icon(Icons.topic_outlined)),
                      title: Text((topic['name'] ?? slug).toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${topic['followers_count'] ?? 0} followers · ${topic['questions_count'] ?? 0} questions\n${topic['description'] ?? ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: OutlinedButton(
                        onPressed: () => _toggleFollow(topic),
                        child: Text(topic['is_following'] == true ? 'Following' : 'Follow'),
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => KnowledgeTopicScreen(api: widget.api, slug: slug),
                      )),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class KnowledgeTopicScreen extends StatefulWidget {
  const KnowledgeTopicScreen({super.key, required this.api, required this.slug});
  final BackendApi api;
  final String slug;

  @override
  State<KnowledgeTopicScreen> createState() => KnowledgeTopicScreenState();
}

class KnowledgeTopicScreenState extends State<KnowledgeTopicScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getKnowledgeTopic(widget.slug);
  }

  Future<void> _reload() async {
    final next = widget.api.getKnowledgeTopic(widget.slug);
    setState(() => _future = next);
    await next;
  }

  Future<void> _toggleFollow(bool following) async {
    try {
      if (following) {
        await widget.api.unfollowKnowledgeTopic(widget.slug);
      } else {
        await widget.api.followKnowledgeTopic(widget.slug);
      }
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update topic follow: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Topic')),
      body: Column(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text('Topic unavailable.'),
                      TextButton(onPressed: _reload, child: const Text('Retry')),
                    ],
                  ),
                );
              }
              final raw = snapshot.data?['data'];
              if (raw is! Map) return const SizedBox.shrink();
              final topic = Map<String, dynamic>.from(raw);
              final following = topic['is_following'] == true;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (topic['name'] ?? widget.slug).toString(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if ((topic['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(topic['description'].toString()),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text('${topic['followers_count'] ?? 0} followers · ${topic['questions_count'] ?? 0} questions'),
                        ),
                        OutlinedButton(
                          onPressed: () => _toggleFollow(following),
                          child: Text(following ? 'Following' : 'Follow topic'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _KnowledgeQuestionList(api: widget.api, status: 'all', topicSlug: widget.slug),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeQuestionList extends StatefulWidget {
  const _KnowledgeQuestionList({
    required this.api,
    required this.status,
    this.mine = false,
    this.following = false,
    this.topicsFollowing = false,
    this.topicSlug,
  });
  final BackendApi api;
  final String status;
  final bool mine;
  final bool following;
  final bool topicsFollowing;
  final String? topicSlug;

  @override
  State<_KnowledgeQuestionList> createState() => _KnowledgeQuestionListState();
}

class _KnowledgeQuestionListState extends State<_KnowledgeQuestionList> {
  late Future<Map<String, dynamic>> _future;
  String _nextCursor = '';
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load({String? before}) async {
    final response = await widget.api.getKnowledgeQuestions(
      status: widget.status,
      mine: widget.mine,
      following: widget.following,
      topicsFollowing: widget.topicsFollowing,
      topicSlug: widget.topicSlug,
      before: before,
    );
    final raw = response['data'];
    if (raw is Map) {
      _nextCursor = (raw['next_cursor'] ?? '').toString();
      _hasMore = raw['has_more'] == true && _nextCursor.isNotEmpty;
    }
    return response;
  }

  Future<void> _refresh() async {
    _nextCursor = '';
    _hasMore = false;
    final next = _load();
    setState(() {
      _loadingMore = false;
      _future = next;
    });
    await next;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final current = await _future;
      final next = await _load(before: _nextCursor);
      final currentData = current['data'];
      final nextData = next['data'];
      if (currentData is! Map || nextData is! Map) return;
      final existing = currentData['items'] is List
          ? List<dynamic>.from(currentData['items'] as List)
          : <dynamic>[];
      final incoming = nextData['items'] is List
          ? List<dynamic>.from(nextData['items'] as List)
          : <dynamic>[];
      final merged = <String, dynamic>{
        ...Map<String, dynamic>.from(currentData),
        'items': [...existing, ...incoming],
        'has_more': nextData['has_more'] == true,
        'next_cursor': nextData['next_cursor'] ?? '',
      };
      setState(() => _future = Future.value({...current, 'data': merged}));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load more questions: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 12),
                  const Text('Questions could not be loaded.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final raw = snapshot.data?['data'];
        final items = raw is Map && raw['items'] is List
            ? (raw['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 130),
                Icon(Icons.lightbulb_outline_rounded, size: 46, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 14),
                Center(child: Text(widget.mine ? 'You have not asked a question yet.' : 'No questions here yet.')),
                const SizedBox(height: 8),
                const Center(child: Text('Pull down to refresh.', style: TextStyle(fontSize: 12))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? 'Loading questions…' : 'Load more questions'),
                    ),
                  ),
                );
              }
              final question = items[index];
              final author = question['author'] is Map ? Map<String, dynamic>.from(question['author'] as Map) : <String, dynamic>{};
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                title: Text((question['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((question['body'] ?? '').toString().isNotEmpty)
                        Text((question['body'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text('@${author['username'] ?? 'member'} · ${question['answers_count'] ?? 0} answers · ${question['status'] ?? 'open'}'),
                      if (question['topics'] is List && (question['topics'] as List).isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final topic in (question['topics'] as List).whereType<Map>())
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text((topic['name'] ?? topic['slug'] ?? '').toString()),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _KnowledgeQuestionDetail(api: widget.api, questionId: (question['id'] ?? '').toString()),
                  ));
                  if (mounted) _refresh();
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _KnowledgeQuestionDetail extends StatefulWidget {
  const _KnowledgeQuestionDetail({required this.api, required this.questionId});
  final BackendApi api;
  final String questionId;

  @override
  State<_KnowledgeQuestionDetail> createState() => _KnowledgeQuestionDetailState();
}

class _KnowledgeQuestionDetailState extends State<_KnowledgeQuestionDetail> {
  late Future<Map<String, dynamic>> _future;
  final _answer = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getKnowledgeQuestion(widget.questionId);
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final next = widget.api.getKnowledgeQuestion(widget.questionId);
    setState(() => _future = next);
    await next;
  }

  Future<void> _sendAnswer() async {
    if (_answer.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.createKnowledgeAnswer(
        questionId: widget.questionId,
        body: _answer.text.trim(),
        idempotencyKey: 'answer-${DateTime.now().microsecondsSinceEpoch}',
      );
      _answer.clear();
      await _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not publish answer: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _accept(String answerId) async {
    try {
      await widget.api.acceptKnowledgeAnswer(questionId: widget.questionId, answerId: answerId);
      await _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not accept answer: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Question')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TestagramStateView(
              icon: Icons.help_outline_rounded,
              title: 'Loading question',
              message: 'Preparing the question and its answers.',
              loading: true,
            );
          }
          if (snapshot.hasError) {
            return TestagramStateView(
              icon: Icons.cloud_off_outlined,
              title: 'Question could not load',
              message: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }
          final raw = snapshot.data?['data'];
          if (raw is! Map) {
            return const TestagramStateView(
              icon: Icons.search_off_rounded,
              title: 'Question not found',
              message: 'It may have been removed or you may no longer have permission to view it.',
            );
          }
          final q = Map<String, dynamic>.from(raw);
          final author = q['author'] is Map ? Map<String, dynamic>.from(q['author'] as Map) : <String, dynamic>{};
          final answers = q['answers'] is List
              ? (q['answers'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
              Text(q['title'].toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('@${author['username'] ?? 'member'} · ${q['status'] ?? 'open'}', style: Theme.of(context).textTheme.labelMedium),
              if (q['topics'] is List && (q['topics'] as List).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    for (final topic in (q['topics'] as List).whereType<Map>())
                      Chip(
                        avatar: const Icon(Icons.topic_outlined, size: 16),
                        label: Text((topic['name'] ?? topic['slug'] ?? '').toString()),
                      ),
                  ],
                ),
              ],
              if ((q['body'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(q['body'].toString(), style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 22),
              Text('Answers (${answers.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (answers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No answers yet. Be the first to share a useful, specific answer.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final answer in answers)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (answer['accepted'] == true)
                          const Row(children: [Icon(Icons.verified_rounded, color: Colors.green, size: 18), SizedBox(width: 6), Text('Accepted answer', style: TextStyle(fontWeight: FontWeight.w700))]),
                        Text((answer['body'] ?? '').toString()),
                        const SizedBox(height: 10),
                        Text('@${(answer['author'] as Map?)?['username'] ?? 'member'}', style: Theme.of(context).textTheme.labelSmall),
                        if (q['can_accept_answer'] == true && answer['accepted'] != true && q['status'] == 'open')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _accept((answer['id'] ?? '').toString()),
                              icon: const Icon(Icons.check_circle_outline_rounded),
                              label: const Text('Accept answer'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (q['status'] == 'open') ...[
                const SizedBox(height: 18),
                Text('Your answer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _answer,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 20000,
                  decoration: const InputDecoration(hintText: 'Share a useful, specific answer…', border: OutlineInputBorder()),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendAnswer,
                    icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                    label: const Text('Publish answer'),
                  ),
                ),
              ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
