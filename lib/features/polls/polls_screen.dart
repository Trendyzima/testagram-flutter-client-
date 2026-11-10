import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final _scroll = ScrollController();
  final _polls = <Map<String, dynamic>>[];
  final _voting = <String>{};
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  int _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 500 && !_loading && _hasMore) _load();
  }

  Map<String, dynamic>? _payload(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _offset = 0;
        _hasMore = true;
        _polls.clear();
      }
    });
    try {
      final response = await widget.api.listPolls(offset: reset ? 0 : _offset);
      final data = _payload(response);
      final rawItems = data?['items'];
      if (data == null || rawItems is! List) {
        throw const BackendApiException('The server returned an invalid polls response.');
      }
      final items = rawItems.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _polls.clear();
        _polls.addAll(items);
        _offset = (data['next_offset'] as num?)?.toInt() ?? (_offset + items.length);
        _hasMore = data['has_more'] == true;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error.toString());
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _vote(Map<String, dynamic> poll, Map<String, dynamic> option) async {
    final pollId = (poll['id'] ?? '').toString();
    final optionId = (option['id'] ?? '').toString();
    if (pollId.isEmpty ||
        optionId.isEmpty ||
        poll['has_voted'] == true ||
        poll['status'] != 'open' ||
        _voting.contains(pollId)) {
      return;
    }
    setState(() => _voting.add(pollId));
    try {
      await widget.api.votePoll(pollId, optionId);
      final refreshed = await widget.api.getPoll(pollId);
      final data = _payload(refreshed);
      if (data == null) {
        throw const BackendApiException('Your vote was sent, but the updated poll could not be loaded.');
      }
      if (!mounted) return;
      setState(() {
        final index = _polls.indexWhere((item) => item['id'] == pollId);
        if (index >= 0) _polls[index] = data;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote could not be confirmed: $error')),
        );
        _load(reset: true);
      }
    } finally {
      if (mounted) setState(() => _voting.remove(pollId));
    }
  }

  Future<void> _createPoll() async {
    final question = TextEditingController();
    final optionOne = TextEditingController();
    final optionTwo = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: optionOne,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Option 1'),
              ),
              TextField(
                controller: optionTwo,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Option 2'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final q = question.text.trim();
    final options = [optionOne.text.trim(), optionTwo.text.trim()];
    question.dispose();
    optionOne.dispose();
    optionTwo.dispose();
    if (result != true) return;
    if (q.length < 5 || options.any((value) => value.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a question of at least 5 characters and two options.')),
        );
      }
      return;
    }
    try {
      await widget.api.createPoll(question: q, options: options);
      await _load(reset: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Poll could not be created: $error')),
        );
      }
    }
  }

  Widget _pollCard(Map<String, dynamic> poll) {
    final rawOptions = poll['options'];
    final options = (rawOptions is List ? rawOptions : const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final total = (poll['total_votes'] as num?)?.toInt() ?? 0;
    final voted = poll['has_voted'] == true;
    final open = poll['status'] == 'open';
    final pollId = (poll['id'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (poll['question'] ?? 'Poll').toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if ((poll['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(poll['description'].toString()),
            ],
            const SizedBox(height: 12),
            for (final option in options) _optionRow(poll, option, total, voted, open),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('$total votes', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text(
                  open ? (voted ? 'Voted' : 'Open') : 'Closed',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                if (_voting.contains(pollId)) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(
    Map<String, dynamic> poll,
    Map<String, dynamic> option,
    int total,
    bool voted,
    bool open,
  ) {
    final votes = (option['votes'] as num?)?.toInt() ?? 0;
    final ratio = total == 0 ? 0.0 : (votes / total).clamp(0.0, 1.0).toDouble();
    final showResults = voted || !open;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: showResults ? null : () => _vote(poll, option),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text((option['label'] ?? '').toString())),
                  if (showResults) Text('${(ratio * 100).round()}%'),
                  if (!showResults) const Icon(Icons.radio_button_unchecked, size: 18),
                ],
              ),
              if (showResults) ...[
                const SizedBox(height: 7),
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 3),
                Text('$votes votes', style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Polls'),
          actions: [
            IconButton(
              tooltip: 'Create poll',
              onPressed: _createPoll,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => _load(reset: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (_polls.isEmpty && !_loading && _error == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No polls yet. Create one to start a conversation.')),
                ),
              for (final poll in _polls) _pollCard(poll),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _hasMore)
                Center(
                  child: TextButton(onPressed: _load, child: const Text('Load more')),
                ),
            ],
          ),
        ),
      );
}
