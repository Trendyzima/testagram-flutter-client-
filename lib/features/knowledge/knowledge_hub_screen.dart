import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class KnowledgeHubScreen extends StatefulWidget {
  const KnowledgeHubScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
  Future<void> _askQuestion() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var visibility = 'public';
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
    const tabs = ['For you', 'Following', 'Unanswered', 'Your questions'];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Knowledge'),
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
            _KnowledgeQuestionList(api: widget.api, status: 'all'),
            _KnowledgeQuestionList(api: widget.api, status: 'all', following: true),
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

class _KnowledgeQuestionList extends StatefulWidget {
  const _KnowledgeQuestionList({required this.api, required this.status, this.mine = false, this.following = false});
  final BackendApi api;
  final String status;
  final bool mine;
  final bool following;

  @override
  State<_KnowledgeQuestionList> createState() => _KnowledgeQuestionListState();
}

class _KnowledgeQuestionListState extends State<_KnowledgeQuestionList> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() => widget.api.getKnowledgeQuestions(
        status: widget.status,
        mine: widget.mine,
        following: widget.following,
      );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
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
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
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
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _KnowledgeQuestionDetail(api: widget.api, questionId: (question['id'] ?? '').toString()),
                  ));
                  if (mounted) setState(() => _future = _load());
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
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Question unavailable: ${snapshot.error}'));
          final raw = snapshot.data?['data'];
          if (raw is! Map) return const Center(child: Text('Question not found.'));
          final q = Map<String, dynamic>.from(raw);
          final author = q['author'] is Map ? Map<String, dynamic>.from(q['author'] as Map) : <String, dynamic>{};
          final answers = q['answers'] is List
              ? (q['answers'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Text(q['title'].toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('@${author['username'] ?? 'member'} · ${q['status'] ?? 'open'}', style: Theme.of(context).textTheme.labelMedium),
              if ((q['body'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(q['body'].toString(), style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 22),
              Text('Answers (${answers.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
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
          );
        },
      ),
    );
  }
}
