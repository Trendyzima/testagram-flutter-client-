import 'package:flutter/material.dart';

import '../../core/backend_api.dart';
import 'profile_connections_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.userId});

  final BackendApi api;
  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.getProfile(widget.userId);
      final raw = response['data'];
      if (raw is! Map) {
        throw const BackendApiException('The server returned an invalid profile.');
      }
      if (mounted) setState(() => _profile = Map<String, dynamic>.from(raw));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _busy) return;
    setState(() => _busy = true);
    try {
      final following = profile['is_following'] == true;
      if (following || profile['follow_status'] == 'pending') {
        await widget.api.unfollowUser(widget.userId);
      } else {
        await widget.api.followUser(widget.userId);
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

  void _openConnections(String kind) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfileConnectionsScreen(api: widget.api, userId: widget.userId, kind: kind),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Center(child: CircleAvatar(
                            radius: 42,
                            backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                            child: avatar.startsWith('http') ? null : Text(
                              displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 28),
                            ),
                          )),
                          const SizedBox(height: 14),
                          Center(child: Text(
                            displayName.isEmpty ? 'Testagram user' : displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          )),
                          if (username.isNotEmpty) Center(child: Text('@$username')),
                          const SizedBox(height: 12),
                          if ((profile['bio'] ?? '').toString().isNotEmpty)
                            Text(profile['bio'].toString(), textAlign: TextAlign.center),
                          if ((profile['website'] ?? '').toString().isNotEmpty)
                            Center(child: Text(profile['website'].toString())),
                          const SizedBox(height: 20),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _Count(
                              label: 'Followers',
                              value: profile['followers_count'],
                              onTap: () => _openConnections('followers'),
                            ),
                            const SizedBox(width: 28),
                            _Count(
                              label: 'Following',
                              value: profile['following_count'],
                              onTap: () => _openConnections('following'),
                            ),
                          ]),
                          if (!isSelf) ...[
                            const SizedBox(height: 18),
                            Center(child: FilledButton(
                              onPressed: _busy ? null : _toggleFollow,
                              child: _busy
                                  ? const SizedBox(width: 16,height: 16,child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(following ? 'Following' : pending ? 'Requested' : 'Follow'),
                            )),
                          ],
                          const SizedBox(height: 20),
                          if (profile['protected_account'] == true && profile['can_view_posts'] != true)
                            const Center(child: Text('This account is private. Follow to see their posts.'))
                          else
                            const Center(child: Text('Profile posts are the next migration slice.')),
                        ],
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
