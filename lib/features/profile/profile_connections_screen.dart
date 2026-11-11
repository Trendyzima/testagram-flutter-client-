import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../profile/profile_screen.dart';

class ProfileConnectionsScreen extends StatefulWidget {
  const ProfileConnectionsScreen({
    super.key,
    required this.api,
    required this.userId,
    required this.kind,
  });

  final BackendApi api;
  final String userId;
  final String kind;

  @override
  State<ProfileConnectionsScreen> createState() => _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState extends State<ProfileConnectionsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  String? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300 && !_loading && _hasMore) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) {
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final response = await widget.api.listProfileConnections(
        widget.userId,
        kind: widget.kind,
        cursor: _cursor,
      );
      final data = response['data'];
      if (data is! Map || data['items'] is! List) {
        throw const BackendApiException('The server returned an invalid connections page.');
      }
      final page = (data['items'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) {
        setState(() {
          _items.addAll(page);
          _cursor = (data['next_cursor'] ?? '').toString();
          _hasMore = data['has_more'] == true && _cursor!.isNotEmpty;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.kind == 'followers' ? 'Followers' : 'Following';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _error != null && _items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ]))
          : RefreshIndicator(
              onRefresh: () async {
                setState(() { _items.clear(); _cursor = null; _hasMore = true; });
                await _load();
              },
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = _items[index];
                  final avatar = (item['avatar_url'] ?? '').toString();
                  final userId = (item['id'] ?? '').toString();
                  final username = (item['username'] ?? '').toString();
                  final name = (item['display_name'] ?? username).toString();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                      child: avatar.startsWith('http') ? null : const Icon(Icons.person_outline),
                    ),
                    title: Text(name),
                    subtitle: Text('@$username'),
                    onTap: userId.isEmpty ? null : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileScreen(api: widget.api, userId: userId),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
