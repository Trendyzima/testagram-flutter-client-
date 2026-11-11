import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class PostInteractionsScreen extends StatefulWidget {
  const PostInteractionsScreen({
    super.key,
    required this.api,
    required this.postId,
    required this.kind,
  });

  final BackendApi api;
  final String postId;
  final String kind;

  @override
  State<PostInteractionsScreen> createState() => _PostInteractionsScreenState();
}

class _PostInteractionsScreenState extends State<PostInteractionsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String get _title => switch (widget.kind) {
        'likes' => 'Liked by',
        'reposts' => 'Reposted by',
        'quotes' => 'Quoted by',
        _ => 'Post interactions',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? _data(Map<String, dynamic> response) {
    final raw = response['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = _data(await widget.api.listPostInteractions(
        widget.postId,
        kind: widget.kind,
      ));
      final rows = data?['items'];
      if (data == null || rows is! List) {
        throw const BackendApiException('The server returned an invalid interactions response.');
      }
      if (!mounted) return;
      setState(() {
        _items = rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading && _items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : _error != null && _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
                      ],
                    )
                  : _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(child: Text('No ${widget.kind} yet.')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final rawProfile = item['profile'] ?? item['user_profiles'];
                            final profile = rawProfile is Map
                                ? Map<String, dynamic>.from(rawProfile)
                                : <String, dynamic>{};
                            final username = (profile['username'] ?? '').toString();
                            final displayName = (profile['display_name'] ?? username).toString();
                            final avatar = (profile['avatar_url'] ?? '').toString();
                            final quote = (item['quote'] ?? item['content'] ?? '').toString();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                                child: avatar.startsWith('http')
                                    ? null
                                    : Text(displayName.isEmpty ? '?' : displayName[0].toUpperCase()),
                              ),
                              title: Text(displayName.isEmpty ? 'Testagram user' : displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (username.isNotEmpty) Text('@$username'),
                                  if (quote.isNotEmpty) Text(quote),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      );
}
