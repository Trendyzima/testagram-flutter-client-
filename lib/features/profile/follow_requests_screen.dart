import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key, required this.api});
  final BackendApi api;

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _busy = {};
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = _payload(await widget.api.listFollowRequests());
      final raw = response['items'];
      final items = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() { _requests = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _respond(String userId, {required bool accept}) async {
    if (userId.isEmpty || !_busy.add(userId)) return;
    setState(() {});
    try {
      if (accept) {
        await widget.api.acceptFollowRequest(userId);
      } else {
        await widget.api.rejectFollowRequest(userId);
      }
      if (mounted) {
        setState(() => _requests.removeWhere((item) => (item['user_id'] ?? '').toString() == userId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept ? 'Follow request accepted.' : 'Follow request declined.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      _busy.remove(userId);
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Follow requests'),
      actions: [
        IconButton(
          tooltip: 'Refresh follow requests',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: _loading && _requests.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _requests.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ]),
              ))
            : _requests.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(children: const [
                      SizedBox(height: 120),
                      Icon(Icons.person_add_alt_1_outlined, size: 48),
                      SizedBox(height: 12),
                      Center(child: Text('You have no pending follow requests.')),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final request = _requests[index];
                        final id = (request['user_id'] ?? '').toString();
                        final busy = _busy.contains(id);
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                          title: Text((request['display_name'] ?? request['username'] ?? 'Testagram member').toString()),
                          subtitle: Text('@${(request['username'] ?? '').toString()}'),
                          trailing: Wrap(spacing: 4, children: [
                            IconButton(
                              tooltip: 'Accept follow request',
                              onPressed: busy ? null : () => _respond(id, accept: true),
                              icon: busy
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline_rounded),
                            ),
                            IconButton(
                              tooltip: 'Decline follow request',
                              onPressed: busy ? null : () => _respond(id, accept: false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
  );
}
