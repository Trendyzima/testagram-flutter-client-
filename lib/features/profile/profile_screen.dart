import 'package:material_ui/material_ui.dart';

import '../posts/post_detail_screen.dart';

import '../../core/backend_api.dart';
import '../../core/widgets/testagram_app_bar.dart';
import 'profile_connections_screen.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.userId, this.initialTab = 0});

  const ProfileScreen.currentUser({super.key, required this.api, this.initialTab = 0}) : userId = null;

  final BackendApi api;
  final String? userId;
  final int initialTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final List<Map<String, dynamic>> _posts = [];
  String? _postsCursor;
  bool _postsHasMore = false;
  bool _loadingPosts = false;
  String? _postsError;
  String? _resolvedUserId;
  int _profileTabIndex = 0;

  String get _targetUserId => widget.userId ?? _resolvedUserId ?? '';

  @override
  void initState() {
    super.initState();
    _profileTabIndex = widget.initialTab.clamp(0, 1).toInt();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = widget.userId == null
          ? await widget.api.getMyProfile()
          : await widget.api.getProfile(widget.userId!);
      final raw = response['data'];
      if (raw is! Map) {
        throw const BackendApiException('The server returned an invalid profile.');
      }
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(raw);
          _resolvedUserId = (raw['id'] ?? raw['user_id'] ?? '').toString();
          _posts.clear();
          _postsCursor = null;
          _postsHasMore = false;
          _postsError = null;
        });
        // Public profiles remain viewable when older API payloads omit this flag.
        // Protected profiles require the server's explicit permission grant.
        if (_canViewPosts(raw)) {
          await _loadPosts(reset: true);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canViewPosts(Map profile) =>
      profile['is_self'] == true ||
      profile['protected_account'] != true ||
      profile['can_view_posts'] == true;

  List<Map<String, dynamic>> get _mediaPosts =>
      _posts.where(_postHasMedia).toList(growable: false);

  bool _postHasMedia(Map<String, dynamic> post) {
    final urls = post['media_urls'];
    final contentTypes = post['media_content_types'];
    final hasTypedMedia = contentTypes is List && contentTypes.any((value) {
      final type = value.toString().toLowerCase().trim();
      return type.startsWith('image/') ||
          type.startsWith('video/') ||
          type.startsWith('audio/');
    });
    return (post['image_url'] ?? '').toString().isNotEmpty ||
        (urls is List && urls.isNotEmpty) ||
        post['is_video'] == true ||
        hasTypedMedia;
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (_loadingPosts || (!reset && !_postsHasMore)) {
      return;
    }
    setState(() {
      _loadingPosts = true;
      _postsError = null;
      if (reset) {
        _posts.clear();
        _postsCursor = null;
        _postsHasMore = true;
      }
    });
    try {
      final response = await widget.api.getProfilePosts(
        _targetUserId,
        cursor: _postsCursor,
        mediaOnly: _profileTabIndex == 1,
      );
      final data = response['data'];
      if (data is! Map || data['posts'] is! List) {
        throw const BackendApiException('The server returned an invalid profile posts page.');
      }
      final page = (data['posts'] as List)
          .whereType<Map>()
          .map((post) => Map<String, dynamic>.from(post))
          .toList();
      if (mounted) {
        setState(() {
          // Cursor pages can repeat their boundary item; retain the first copy.
          final knownIds = _posts
              .map((post) => (post['id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();
          for (final post in page) {
            final id = (post['id'] ?? '').toString();
            if (id.isEmpty || knownIds.add(id)) _posts.add(post);
          }
          final nextCursor = (data['next_cursor'] ?? '').toString();
          final cursorAdvanced =
              nextCursor.isNotEmpty && nextCursor != _postsCursor;
          _postsCursor = nextCursor.isEmpty ? null : nextCursor;
          _postsHasMore = data['has_more'] == true && cursorAdvanced;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _postsError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Widget _buildMediaPreview(Map<String, dynamic> post) {
    final rawUrls = post['media_urls'];
    final firstUrl = rawUrls is List && rawUrls.isNotEmpty
        ? rawUrls.first
        : post['image_url'];
    final url = firstUrl is Map
        ? (firstUrl['url'] ?? firstUrl['media_url'] ?? firstUrl['src'] ?? '').toString()
        : (firstUrl ?? '').toString();
    final contentTypes = post['media_content_types'];
    final firstType = contentTypes is List && contentTypes.isNotEmpty
        ? contentTypes.first.toString().toLowerCase()
        : '';
    final icon = firstType.startsWith('video/') || post['is_video'] == true
        ? Icons.play_circle_outline_rounded
        : firstType.startsWith('audio/')
            ? Icons.audio_file_outlined
            : Icons.image_outlined;

    if (url.startsWith('https://') || url.startsWith('http://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.network(
          url,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 28),
          ),
        ),
      );
    }
    return SizedBox(width: 64, height: 64, child: Icon(icon, size: 30));
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _busy) return;
    setState(() => _busy = true);
    try {
      final following = profile['is_following'] == true;
      if (following || profile['follow_status'] == 'pending') {
        await widget.api.unfollowUser(_targetUserId);
      } else {
        await widget.api.followUser(_targetUserId);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _blockProfileAccount() async {
    if (_busy || _targetUserId.isEmpty || _profile?['is_self'] == true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this account?'),
        content: const Text(
          'They will no longer be able to interact with you through this account. '
          'Both follow relationships will be removed and will not be restored if you unblock them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Block account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.blockUser(_targetUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account blocked.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editProfile() async {
    final current = _profile;
    if (current == null || current['is_self'] != true) return;
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => ProfileEditScreen(api: widget.api, profile: current),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _profile = updated);
      await _load();
    }
  }

  void _openConnections(String kind) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfileConnectionsScreen(api: widget.api, userId: _targetUserId, kind: kind),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final avatar = (profile?['avatar_url'] ?? '').toString();
    final username = (profile?['username'] ?? '').toString();
    final displayName = (profile?['display_name'] ?? username).toString();
    final isSelf = profile?['is_self'] == true;
    final following = profile?['is_following'] == true;
    final pending = profile?['follow_status'] == 'pending';
    final socialLinks = profile?['social_links'] is Map
        ? Map<String, dynamic>.from(profile!['social_links'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      appBar: TestagramAppBar(
        title: 'Profile',
        showBrand: !Navigator.of(context).canPop(),
        actions: [
          if (_profile != null && _profile?['is_self'] != true)
            PopupMenuButton<String>(
              tooltip: 'Profile safety',
              enabled: !_busy,
              onSelected: (value) {
                if (value == 'block') _blockProfileAccount();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block_outlined),
                      SizedBox(width: 12),
                      Text('Block account'),
                    ],
                  ),
                ),
              ],
            ),
          if (_profile?['is_self'] == true)
            IconButton(
              tooltip: 'Edit profile',
              onPressed: _busy ? null : _editProfile,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && profile == null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ))
              : profile == null
                  ? const Center(child: Text('Profile unavailable.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.zero,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (profile['cover_url'] ?? '').toString().startsWith('http')
                                    ? Image.network(
                                        profile['cover_url'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.expand(),
                                      )
                                    : const Center(child: Icon(Icons.landscape_outlined, size: 38)),
                              ),
                              Positioned(
                                left: 16,
                                bottom: -42,
                                child: CircleAvatar(
                                  radius: 54,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  child: CircleAvatar(
                                    radius: 48,
                                    backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                                    child: avatar.startsWith('http') ? null : Text(
                                      displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 54),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName.isEmpty ? 'Testagram user' : displayName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        if (profile['is_verified'] == true || profile['verified'] == true) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.verified_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                                        ],
                                      ],
                                    ),
                                    if (username.isNotEmpty)
                                      Text('@$username', style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              if (isSelf)
                                OutlinedButton.icon(
                                  onPressed: _editProfile,
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit'),
                                ),
                            ],
                          ),
                          if ((profile['bio'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(profile['bio'].toString(), style: Theme.of(context).textTheme.bodyLarge),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              if ((profile['location'] ?? '').toString().isNotEmpty)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.location_on_outlined, size: 16),
                                  const SizedBox(width: 4),
                                  Text(profile['location'].toString()),
                                ]),
                              if ((profile['website'] ?? '').toString().isNotEmpty)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.link_rounded, size: 16),
                                  const SizedBox(width: 4),
                                  Text(profile['website'].toString()),
                                ]),
                            ],
                          ),
                          if (socialLinks.values.any((value) => value.toString().trim().isNotEmpty)) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final entry in socialLinks.entries)
                                  if (entry.value.toString().trim().isNotEmpty)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: Icon(
                                        entry.key == 'instagram'
                                            ? Icons.camera_alt_outlined
                                            : entry.key == 'linkedin'
                                                ? Icons.work_outline_rounded
                                                : entry.key == 'facebook'
                                                    ? Icons.facebook
                                                    : Icons.alternate_email_rounded,
                                        size: 16,
                                      ),
                                      label: Text('${entry.key}: ${entry.value}'),
                                    ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _Count(
                                    label: 'Followers',
                                    value: profile['followers_count'],
                                    onTap: () => _openConnections('followers'),
                                  ),
                                  _Count(
                                    label: 'Following',
                                    value: profile['following_count'],
                                    onTap: () => _openConnections('following'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isSelf) ...[
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: _busy ? null : _toggleFollow,
                                  child: _busy
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text(following ? 'Following' : pending ? 'Requested' : 'Follow'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (_canViewPosts(profile)) ...[
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Posts'),
                                  selected: _profileTabIndex == 0,
                                  onSelected: _loadingPosts ? null : (_) {
                                    setState(() => _profileTabIndex = 0);
                                    _loadPosts(reset: true);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Media'),
                                  selected: _profileTabIndex == 1,
                                  onSelected: _loadingPosts ? null : (_) {
                                    setState(() => _profileTabIndex = 1);
                                    _loadPosts(reset: true);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!_canViewPosts(profile))
                            const Center(child: Text('This account is private. Follow to see their posts.'))
                          else ...[
                            const SizedBox(height: 12),
                            Text(_profileTabIndex == 0 ? 'Posts' : 'Media', style: Theme.of(context).textTheme.titleLarge),
                            if (_postsError != null)
                              TextButton(
                                onPressed: () => _loadPosts(reset: _posts.isEmpty),
                                child: const Text('Could not load posts. Retry'),
                              ),
                            for (final post in (_profileTabIndex == 0 ? _posts : _mediaPosts))
                              Card(
                                child: ListTile(
                                  leading: _profileTabIndex == 1
                                      ? _buildMediaPreview(post)
                                      : null,
                                  title: Text((post['content'] ?? '').toString(), maxLines: 5, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${post['likes_count'] ?? 0} likes · ${post['replies_count'] ?? 0} replies'),
                                  onTap: (post['id'] ?? '').toString().isEmpty ? null : () {
                                    Navigator.of(context).push(MaterialPageRoute<void>(
                                      builder: (_) => PostDetailScreen(
                                        api: widget.api,
                                        postId: post['id'].toString(),
                                      ),
                                    ));
                                  },
                                ),
                              ),
                            if (_loadingPosts)
                              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                            if (_postsHasMore && !_loadingPosts)
                              Center(child: TextButton(
                                onPressed: _loadPosts,
                                child: Text(_profileTabIndex == 1 ? 'Load more media' : 'Load more posts'),
                              )),
                            if ((_profileTabIndex == 0 ? _posts.isEmpty : _mediaPosts.isEmpty) && !_loadingPosts && _postsError == null)
                              Center(child: Text(_profileTabIndex == 0 ? 'No posts yet.' : 'No media posts yet.')),
                          ],
                        ],
                      ),
                        ),
                      ),
                    ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.onTap});
  final String label;
  final dynamic value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        Text((value ?? 0).toString(), style: Theme.of(context).textTheme.titleLarge),
        Text(label),
      ]),
    ),
  );
}
