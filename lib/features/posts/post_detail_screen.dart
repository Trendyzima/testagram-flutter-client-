import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import 'post_interactions_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.api, required this.postId});

  final BackendApi api;
  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  Map<String, dynamic> _interaction = {};
  List<Map<String, dynamic>> _replies = [];
  final _replyController = TextEditingController();
  bool _loading = true;
  bool _loadingReplies = true;
  bool _sending = false;
  bool _acting = false;
  String? _error;
  String? _replyError;

  Map<String, dynamic>? _data(Map<String, dynamic> response) {
    final raw = response['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = _data(await widget.api.getPost(widget.postId));
      if (post == null || (post['id'] ?? '').toString().isEmpty) {
        throw const BackendApiException('The server returned an invalid post.');
      }
      final interaction = _data(await widget.api.getPostInteractionSummary(widget.postId)) ?? {};
      if (!mounted) return;
      setState(() {
        _post = post;
        _interaction = interaction;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReplies() async {
    setState(() {
      _loadingReplies = true;
      _replyError = null;
    });
    try {
      final data = _data(await widget.api.listPostReplies(widget.postId));
      final rows = data?['items'];
      if (data == null || rows is! List) {
        throw const BackendApiException('The server returned an invalid replies response.');
      }
      if (!mounted) return;
      setState(() {
        _replies = rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      });
    } catch (error) {
      if (mounted) setState(() => _replyError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  Future<void> _toggle(String action) async {
    if (_acting || _post == null) return;
    setState(() => _acting = true);
    try {
      final liked = _interaction['is_liked'] == true;
      final reposted = _interaction['is_reposted'] == true;
      final bookmarked = _interaction['is_bookmarked'] == true;
      switch (action) {
        case 'like':
          if (liked) {
            await widget.api.removePostReaction(widget.postId);
          } else {
            await widget.api.reactToPost(widget.postId);
          }
          break;
        case 'repost':
          if (reposted) {
            await widget.api.removePostRepost(widget.postId);
          } else {
            await widget.api.repostPost(widget.postId);
          }
          break;
        case 'bookmark':
          if (bookmarked) {
            await widget.api.removePostBookmark(widget.postId);
          } else {
            await widget.api.bookmarkPost(widget.postId);
          }
          break;
      }
      final updated = _data(await widget.api.getPostInteractionSummary(widget.postId));
      if (updated == null) {
        throw const BackendApiException('The action was sent, but its updated state could not be loaded.');
      }
      if (mounted) setState(() => _interaction = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _openInteractions(String kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostInteractionsScreen(
          api: widget.api,
          postId: widget.postId,
          kind: kind,
        ),
      ),
    );
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _replyError = null;
    });
    try {
      await widget.api.createPostReply(widget.postId, content);
      _replyController.clear();
      await _loadReplies();
      await _loadPost();
    } catch (error) {
      if (mounted) setState(() => _replyError = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _actionButton(IconData icon, String label, String action, bool active) {
    return TextButton.icon(
      onPressed: _acting ? null : () => _toggle(action),
      icon: Icon(icon, color: active ? Theme.of(context).colorScheme.primary : null),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final author = post?['profiles'] ?? post?['user_profiles'];
    final authorMap = author is Map ? author : const <String, dynamic>{};
    final name = (authorMap['display_name'] ?? authorMap['username'] ?? 'Testagram user').toString();
    final username = (authorMap['username'] ?? '').toString();
    final imageUrl = (post?['image_url'] ?? '').toString();
    final mediaUrl = imageUrl.isNotEmpty
        ? imageUrl
        : ((post?['media_urls'] is List && (post!['media_urls'] as List).isNotEmpty)
            ? (post['media_urls'] as List).first.toString()
            : '');

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: _loading && post == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && post == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _loadPost, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : post == null
                  ? const Center(child: Text('Post unavailable.'))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(name),
                          subtitle: username.isEmpty ? null : Text('@$username'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Text(
                            (post['content'] ?? '').toString(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (mediaUrl.startsWith('http'))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Wrap(
                            alignment: WrapAlignment.spaceAround,
                            children: [
                              _actionButton(
                                _interaction['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                                (_interaction['likes'] ?? post['likes_count'] ?? 0).toString(),
                                'like',
                                _interaction['is_liked'] == true,
                              ),
                              _actionButton(
                                Icons.repeat,
                                (_interaction['reposts'] ?? post['reposts_count'] ?? 0).toString(),
                                'repost',
                                _interaction['is_reposted'] == true,
                              ),
                              _actionButton(
                                _interaction['is_bookmarked'] == true ? Icons.bookmark : Icons.bookmark_border,
                                'Save',
                                'bookmark',
                                _interaction['is_bookmarked'] == true,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(onPressed: () => _openInteractions('likes'), child: const Text('View likes')),
                              TextButton(onPressed: () => _openInteractions('reposts'), child: const Text('View reposts')),
                              TextButton(onPressed: () => _openInteractions('quotes'), child: const Text('View quotes')),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Replies', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (_replyError != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(_replyError!),
                                TextButton(onPressed: _loadReplies, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        if (_loadingReplies)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (!_loadingReplies && _replies.isEmpty && _replyError == null)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No replies yet. Start the conversation.'),
                          ),
                        for (final reply in _replies)
                          ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                            title: Text((reply['content'] ?? '').toString()),
                            subtitle: Text((reply['created_at'] ?? '').toString()),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 2000,
                                  decoration: const InputDecoration(
                                    hintText: 'Write a reply',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _sending ? null : _sendReply,
                                tooltip: 'Send reply',
                                icon: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
