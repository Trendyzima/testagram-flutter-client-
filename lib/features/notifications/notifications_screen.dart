import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../posts/post_detail_screen.dart';
import '../wallet/wallet_transaction_detail_screen.dart';
import '../../core/widgets/testagram_app_bar.dart';
import '../../core/widgets/testagram_state_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final BackendApi api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false, _hasMore = true;
  int _loadGeneration = 0;
  int _activeLoads = 0;
  String? _cursor, _error;
  final Set<String> _marking = {};

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

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final raw = payload['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : payload;
  }

  void _onScroll() {
    if (_scroll.hasClients && !_loading && _hasMore && _scroll.position.extentAfter < 500) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    final pageCursor = reset ? null : _cursor;
    setState(() {
      _activeLoads++;
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final data = _data(await widget.api.listNotifications(
        limit: 30,
        cursor: pageCursor,
      ));
      final raw = data['items'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted && generation == _loadGeneration) {
        setState(() {
          final ids = _items.map((e) => (e['id'] ?? '').toString()).toSet();
          _items.addAll(rows.where((e) => !ids.contains((e['id'] ?? '').toString())));
          _cursor = (data['next_cursor'] ?? '').toString();
          _hasMore = _cursor!.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeLoads--;
          _loading = _activeLoads > 0;
        });
      }
    }
  }

  IconData _notificationIcon(String kind) {
    final normalized = kind.toLowerCase();
    if (normalized.contains('follow')) return Icons.person_add_alt_1_rounded;
    if (normalized.contains('mention')) return Icons.alternate_email_rounded;
    if (normalized.contains('reply') || normalized.contains('comment')) return Icons.mode_comment_outlined;
    if (normalized.contains('like') || normalized.contains('reaction')) return Icons.favorite_border_rounded;
    if (normalized.contains('repost') || normalized.contains('share')) return Icons.repeat_rounded;
    if (normalized.contains('wallet') || normalized.contains('deposit') || normalized.contains('transfer') || normalized.contains('topup')) return Icons.account_balance_wallet_outlined;
    if (normalized.contains('answer')) return Icons.lightbulb_outline_rounded;
    if (normalized.contains('moderation') || normalized.contains('security')) return Icons.shield_outlined;
    return Icons.notifications_none_rounded;
  }

  String _walletNotificationTitle(String kind, String amount) {
    final suffix = amount.isEmpty ? '' : ' · KES $amount';
    switch (kind) {
      case 'wallet.transfer.sent':
        return 'Wallet transfer sent$suffix';
      case 'wallet.transfer.received':
        return 'You received a wallet transfer$suffix';
      case 'wallet.tip.sent':
        return 'Tip sent$suffix';
      case 'wallet.tip.received':
        return 'You received a tip$suffix';
      case 'wallet.superchat.sent':
        return 'Super Chat sent$suffix';
      case 'wallet.superchat.received':
        return 'You received a Super Chat$suffix';
      case 'wallet.deposit.completed':
        return 'M-Pesa deposit completed$suffix';
      case 'wallet.deposit.failed':
        return 'M-Pesa deposit failed';
      case 'wallet.withdrawal.completed':
        return 'Wallet withdrawal completed$suffix';
      case 'wallet.withdrawal.failed':
        return 'Wallet withdrawal failed';
      default:
        return 'Wallet activity$suffix';
    }
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    await _markRead(item);
    if (!mounted) return;
    final kind = (item['kind'] ?? '').toString().toLowerCase();
    final postId = (item['post_id'] ?? '').toString();
    if (kind.startsWith('wallet.')) {
      final rawPayload = item['payload'];
      final payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{};
      final reference = (payload['transfer_id'] ??
              payload['topup_id'] ??
              payload['withdrawal_id'] ??
              payload['transaction_id'] ??
              item['entity_id'] ??
              '')
          .toString();
      if (reference.isNotEmpty) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WalletTransactionDetailScreen(
            api: widget.api,
            transactionReference: reference,
          ),
        ));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This wallet notification has no transaction reference.')),
        );
      }
      return;
    }
    if (kind == 'mention' && postId.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(api: widget.api, postId: postId),
      ));
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty || item['read_at'] != null || _marking.contains(id)) return;
    setState(() => _marking.add(id));
    try {
      await widget.api.markNotificationRead(id);
      if (mounted) setState(() => item['read_at'] = DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _marking.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TestagramAppBar(
      title: 'Notifications',
      actions: [
        IconButton(
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh notifications',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _loading && _items.isEmpty
        ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            TestagramStateView(
              icon: Icons.notifications_none_rounded,
              title: 'Loading notifications',
              message: 'Checking for new activity.',
              loading: true,
            ),
          ],
        )
        : _error != null && _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                TestagramStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Notifications could not load',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: () => _load(reset: true),
                ),
              ],
            )
          : _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  TestagramStateView(
                    icon: Icons.notifications_none_rounded,
                    title: 'You are all caught up',
                    message: 'New replies, follows and other activity will appear here.',
                  ),
                ],
              )
            : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: _loading ? const CircularProgressIndicator() : TextButton(onPressed: _load, child: const Text('Load more'))),
                    );
                  }
                  final item = _items[index];
                  final actor = item['actor'];
                  final actorName = actor is Map ? (actor['display_name'] ?? actor['username'] ?? 'Someone') : 'Testagram';
                  final rawKind = (item['kind'] ?? 'activity').toString().toLowerCase();
                  final kind = rawKind.replaceAll('_', ' ');
                  final rawPayload = item['payload'];
                  final payload = rawPayload is Map
                      ? Map<String, dynamic>.from(rawPayload)
                      : <String, dynamic>{};
                  final walletAmount = (payload['amount_kes'] ??
                          payload['amount'] ??
                          '')
                      .toString();
                  final title = rawKind == 'mention'
                      ? '$actorName mentioned you in a post'
                      : rawKind.startsWith('wallet.')
                          ? _walletNotificationTitle(rawKind, walletAmount)
                          : rawKind == 'social.reactions.aggregated'
                              ? 'People reacted to your post'
                              : '$actorName $kind';
                  final unread = item['read_at'] == null;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unread ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: Icon(_notificationIcon((item['kind'] ?? '').toString())),
                    ),
                    title: Text(title),
                    subtitle: Text((item['created_at'] ?? '').toString()),
                    trailing: unread
                      ? _marking.contains((item['id'] ?? '').toString())
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            tooltip: 'Mark as read',
                            onPressed: () => _markRead(item),
                            icon: const Icon(Icons.done_all_rounded),
                          )
                      : null,
                    onTap: () => _openNotification(item),
                  );
                },
              ),
    ),
  );
}
