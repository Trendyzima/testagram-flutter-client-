import 'package:flutter/material.dart';

import '../../core/backend_api.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.api, required this.onSignOut});
  final BackendApi api;
  final Future<void> Function() onSignOut;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  final Set<String> _busy = {};
  bool _loading = false, _hasMore = true, _following = false;
  String? _cursor, _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && !_loading && _hasMore && _scroll.position.extentAfter < 650) {
      _load();
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final value = payload['data'];
    return value is Map ? Map<String, dynamic>.from(value) : payload;
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) { _cursor = null; _hasMore = true; }
    });
    try {
      final payload = await widget.api.getHomeFeed(
        limit: 20, cursor: reset ? null : _cursor, followingOnly: _following,
      );
      final data = _data(payload);
      final raw = data['posts'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final summaries = await Future.wait(rows.map((post) async {
        final id = (post['id'] ?? '').toString();
        if (id.isEmpty) return <String, dynamic>{};
        try { return _data(await widget.api.getPostInteractionSummary(id)); }
        catch (_) { return <String, dynamic>{}; }
      }));
      for (var i = 0; i < rows.length; i++) {
        final summary = summaries[i];
        rows[i]['is_liked'] = summary['is_liked'] == true;
        rows[i]['is_reposted'] = summary['is_reposted'] == true;
        rows[i]['is_bookmarked'] = summary['is_bookmarked'] == true;
        rows[i]['likes_count'] = summary['likes'] ?? rows[i]['likes_count'];
        rows[i]['replies_count'] = summary['replies'] ?? rows[i]['replies_count'];
        rows[i]['reposts_count'] = summary['reposts'] ?? rows[i]['reposts_count'];
      }
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        final ids = _posts.map((p) => (p['id'] ?? '').toString()).toSet();
        _posts.addAll(rows.where((p) => !ids.contains((p['id'] ?? '').toString())));
        _cursor = (data['next_cursor'] ?? '').toString();
        _hasMore = data['has_more'] == true && (_cursor?.isNotEmpty ?? false);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Map<String, dynamic> post, String kind) async {
    final id = (post['id'] ?? '').toString();
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      if (kind == 'like') {
        if (post['is_liked'] == true) { await widget.api.removePostReaction(id); }
        else { await widget.api.reactToPost(id); }
      } else if (kind == 'repost') {
        if (post['is_reposted'] == true) { await widget.api.removePostRepost(id); }
        else { await widget.api.repostPost(id); }
      } else if (kind == 'bookmark') {
        if (post['is_bookmarked'] == true) { await widget.api.removePostBookmark(id); }
        else { await widget.api.bookmarkPost(id); }
      }
      final summary = _data(await widget.api.getPostInteractionSummary(id));
      if (!mounted) return;
      setState(() {
        post['is_liked'] = summary['is_liked'] == true;
        post['is_reposted'] = summary['is_reposted'] == true;
        post['is_bookmarked'] = summary['is_bookmarked'] == true;
        post['likes_count'] = summary['likes'] ?? post['likes_count'];
        post['replies_count'] = summary['replies'] ?? post['replies_count'];
        post['reposts_count'] = summary['reposts'] ?? post['reposts_count'];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _replies(Map<String, dynamic> post) async {
    final id = (post['id'] ?? '').toString();
    final controller = TextEditingController();
    var loading = true, sending = false;
    String? error;
    List<Map<String, dynamic>> replies = [];
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> load() async {
          setSheet(() { loading = true; error = null; });
          try {
            final data = _data(await widget.api.listPostReplies(id));
            final list = data['items'];
            replies = list is List ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
          } catch (e) { error = e.toString(); }
          setSheet(() => loading = false);
        }
        Future<void> send() async {
          final value = controller.text.trim();
          if (value.isEmpty || sending) return;
          setSheet(() => sending = true);
          try {
            await widget.api.createPostReply(id, value);
            controller.clear();
            await load();
          } catch (e) { setSheet(() => error = e.toString()); }
          setSheet(() => sending = false);
        }
        if (loading && replies.isEmpty && error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => load());
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Replies', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null && replies.isEmpty
                  ? Center(child: Text(error!))
                  : replies.isEmpty
                    ? const Center(child: Text('No replies yet. Start the conversation.'))
                    : ListView.builder(
                        itemCount: replies.length,
                        itemBuilder: (_, i) {
                          final row = replies[i];
                          final profile = row['user_profiles'];
                          final name = profile is Map ? (profile['display_name'] ?? profile['username'] ?? 'Testagram user') : 'Testagram user';
                          return ListTile(title: Text(name.toString()), subtitle: Text((row['content'] ?? '').toString()));
                        })),
              if (error != null && replies.isNotEmpty) Text(error!),
              Row(children: [
                Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Write a reply'))),
                IconButton.filled(onPressed: sending ? null : send, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
              ]),
            ]),
          ),
        );
      }),
    );
    controller.dispose();
  }

  void _composerNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post publishing is not yet exposed as a first-class Backend API. No post was sent.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Testagram', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout), tooltip: 'Sign out'),
      ],
    ),
    floatingActionButton: FloatingActionButton(onPressed: _composerNotice, tooltip: 'Compose post', child: const Icon(Icons.edit)),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('For you')),
            ButtonSegment(value: true, label: Text('Following')),
          ],
          selected: {_following},
          onSelectionChanged: (v) { setState(() => _following = v.first); _load(reset: true); },
        ),
      ),
      Expanded(child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _loading && _posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _posts.isEmpty
            ? ListView(children: [const SizedBox(height: 100), Center(child: Text(_error!)), Center(child: TextButton(onPressed: () => _load(reset: true), child: const Text('Retry')))])
            : _posts.isEmpty
              ? ListView(children: const [SizedBox(height: 120), Center(child: Icon(Icons.dynamic_feed_outlined, size: 48)), SizedBox(height: 12), Center(child: Text('No posts are available yet.'))])
              : ListView.separated(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _posts.length + (_loading || _hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == _posts.length) return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: _loading ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: const Text('Load more'))),
                    );
                    final post = _posts[index];
                    final id = (post['id'] ?? '').toString();
                    return _PostCard(
                      post: post,
                      busy: _busy.contains(id),
                      onLike: () => _action(post, 'like'),
                      onRepost: () => _action(post, 'repost'),
                      onBookmark: () => _action(post, 'bookmark'),
                      onReplies: () => _replies(post),
                    );
                  },
                ),
      )),
    ]),
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.busy, required this.onLike, required this.onRepost, required this.onBookmark, required this.onReplies});
  final Map<String, dynamic> post;
  final bool busy;
  final VoidCallback onLike, onRepost, onBookmark, onReplies;

  @override
  Widget build(BuildContext context) {
    final author = post['author'];
    final name = author is Map ? (author['display_name'] ?? author['username'] ?? 'Testagram user').toString() : 'Testagram user';
    final body = (post['content'] ?? '').toString();
    final created = (post['created_at'] ?? '').toString();
    final media = post['media_urls'];
    final mediaUrl = media is List && media.isNotEmpty ? media.first.toString() : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF174A2D),
          backgroundImage: author is Map && (author['avatar_url'] ?? '').toString().startsWith('http') ? NetworkImage(author['avatar_url'].toString()) : null,
          child: author is Map && (author['avatar_url'] ?? '').toString().startsWith('http') ? null : Text(name.isEmpty ? 'T' : name[0].toUpperCase()),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            if (created.isNotEmpty) Text('  ·  ' + (created.length > 10 ? created.substring(0, 10) : created), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
          const SizedBox(height: 7),
          Text(body, style: const TextStyle(height: 1.4)),
          if (mediaUrl.startsWith('http')) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(mediaUrl, width: double.infinity, height: 230, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 2, children: [
            _Action(icon: post['is_liked'] == true ? Icons.favorite : Icons.favorite_border, label: (post['likes_count'] ?? 0).toString(), active: post['is_liked'] == true, onTap: busy ? null : onLike),
            _Action(icon: Icons.mode_comment_outlined, label: (post['replies_count'] ?? 0).toString(), onTap: onReplies),
            _Action(icon: Icons.repeat, label: (post['reposts_count'] ?? 0).toString(), active: post['is_reposted'] == true, onTap: busy ? null : onRepost),
            _Action(icon: post['is_bookmarked'] == true ? Icons.bookmark : Icons.bookmark_border, label: '', active: post['is_bookmarked'] == true, onTap: busy ? null : onBookmark),
          ]),
        ])),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18, color: active ? Theme.of(context).colorScheme.primary : null),
    label: Text(label),
    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
  );
}
