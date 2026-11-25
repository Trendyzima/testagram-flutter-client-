import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../feed/feed_screen.dart';

class SocialListsScreen extends StatefulWidget {
  const SocialListsScreen({super.key, required this.api, required this.onSignOut});
  final BackendApi api;
  final Future<void> Function() onSignOut;

  @override
  State<SocialListsScreen> createState() => _SocialListsScreenState();
}

class _SocialListsScreenState extends State<SocialListsScreen> {
  late Future<Map<String, dynamic>> _future;
  final Set<String> _pinning = {};

  @override
  void initState() {
    super.initState();
    _future = widget.api.getSocialLists();
  }

  Future<void> _reload() async {
    final next = widget.api.getSocialLists();
    setState(() => _future = next);
    await next;
  }

  Future<void> _togglePin(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty || !_pinning.add(id)) return;
    final nextPinned = item['pinned'] != true;
    setState(() {});
    try {
      await widget.api.updateSocialListPin(id, pinned: nextPinned);
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${nextPinned ? 'pin' : 'unpin'} list: $error')),
        );
      }
    } finally {
      _pinning.remove(id);
      if (mounted) setState(() {});
    }
  }
  Future<void> _createList() async {
    final name = TextEditingController();
    final description = TextEditingController();
    var visibility = 'private';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create a list'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  maxLength: 64,
                  decoration: const InputDecoration(labelText: 'List name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(labelText: 'Who can view this list?', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('Only me')),
                    DropdownMenuItem(value: 'unlisted', child: Text('Anyone with the link')),
                    DropdownMenuItem(value: 'public', child: Text('Public')),
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
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a list name.')));
                  return;
                }
                try {
                  await widget.api.createSocialList(
                    name: name.text.trim(),
                    description: description.text.trim(),
                    visibility: visibility,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not create list: $error')));
                  }
                }
              },
              child: const Text('Create list'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    if (result == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your lists'),
        actions: [
          IconButton(tooltip: 'Create list', onPressed: _createList, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Your lists could not be loaded.'),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: _reload, child: const Text('Retry')),
            ]));
          }
          final raw = snapshot.data?['data'];
          final items = raw is Map && raw['items'] is List
              ? (raw['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.list_alt_rounded, size: 48),
                const SizedBox(height: 12),
                Text('Organize the accounts you follow', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Create private, unlisted or public lists for topics, people and interests.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _createList, icon: const Icon(Icons.add_rounded), label: const Text('Create your first list')),
              ]),
            ));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final visibility = (item['visibility'] ?? 'private').toString();
                return ListTile(
                  leading: CircleAvatar(child: Icon(visibility == 'private' ? Icons.lock_outline : Icons.list_alt_rounded)),
                  title: Text((item['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${item['members_count'] ?? 0} members · $visibility'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: item['pinned'] == true ? 'Unpin list' : 'Pin list to Home',
                        onPressed: _pinning.contains((item['id'] ?? '').toString())
                            ? null
                            : () => _togglePin(item),
                        icon: Icon(
                          item['pinned'] == true
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _SocialListDetailScreen(api: widget.api, onSignOut: widget.onSignOut, list: item),
                    ));
                    if (mounted) await _reload();
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createList,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New list'),
      ),
    );
  }
}

class _SocialListDetailScreen extends StatefulWidget {
  const _SocialListDetailScreen({required this.api, required this.onSignOut, required this.list});
  final BackendApi api;
  final Future<void> Function() onSignOut;
  final Map<String, dynamic> list;

  @override
  State<_SocialListDetailScreen> createState() => _SocialListDetailScreenState();
}

class _SocialListDetailScreenState extends State<_SocialListDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getSocialListMembers(widget.list['id'].toString());
  }

  Future<void> _reload() async {
    final next = widget.api.getSocialListMembers(widget.list['id'].toString());
    setState(() => _future = next);
    await next;
  }

  Future<void> _addMember() async {
    final username = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add an account'),
        content: TextField(
          controller: username,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '@', labelText: 'Username', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final value = username.text.trim().replaceFirst(RegExp(r'^@'), '');
              if (value.isEmpty) return;
              try {
                final profile = await widget.api.resolveProfileUsername(value);
                final raw = profile['data'];
                final userId = raw is Map ? (raw['id'] ?? raw['user_id'] ?? '').toString() : '';
                if (userId.isEmpty) throw StateError('Account not found.');
                await widget.api.addSocialListMember(listId: widget.list['id'].toString(), userId: userId);
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not add account: $error')));
                }
              }
            },
            child: const Text('Add to list'),
          ),
        ],
      ),
    );
    username.dispose();
    if (ok == true && mounted) await _reload();
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    try {
      await widget.api.removeSocialListMember(
        listId: widget.list['id'].toString(),
        userId: member['user_id'].toString(),
      );
      await _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove account: $error')));
    }
  }

  Future<void> _deleteList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this list?'),
        content: const Text('The list and its membership will be removed. This does not delete any posts or accounts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.api.deleteSocialList(widget.list['id'].toString());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete list: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    return Scaffold(
      appBar: AppBar(
        title: Text((list['name'] ?? 'List').toString()),
        actions: [
          IconButton(
            tooltip: 'Open custom feed',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => FeedScreen(
                api: widget.api,
                onSignOut: widget.onSignOut,
                listId: list['id'].toString(),
                feedTitle: (list['name'] ?? 'Custom feed').toString(),
              ),
            )),
            icon: const Icon(Icons.dynamic_feed_rounded),
          ),
          IconButton(tooltip: 'Add account', onPressed: _addMember, icon: const Icon(Icons.person_add_alt_1_rounded)),
          IconButton(tooltip: 'Delete list', onPressed: _deleteList, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((list['description'] ?? '').toString().isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Text(list['description'].toString())),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('${list['visibility'] ?? 'private'} list', style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: FilledButton.tonal(onPressed: _reload, child: const Text('Retry')));
                final raw = snapshot.data?['data'];
                final items = raw is Map && raw['items'] is List
                    ? (raw['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                    : <Map<String, dynamic>>[];
                if (items.isEmpty) return const Center(child: Text('No accounts in this list yet.'));
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = items[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                        title: Text((member['display_name'] ?? member['username'] ?? 'Member').toString()),
                        subtitle: Text('@${member['username'] ?? 'member'}'),
                        trailing: IconButton(
                          tooltip: 'Remove from list',
                          onPressed: () => _removeMember(member),
                          icon: const Icon(Icons.person_remove_alt_1_outlined),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add account'),
      ),
    );
  }
}
