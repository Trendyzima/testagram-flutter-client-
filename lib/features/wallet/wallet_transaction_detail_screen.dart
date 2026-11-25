import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../../core/widgets/testagram_app_bar.dart';
import '../../core/widgets/testagram_state_view.dart';

class WalletTransactionDetailScreen extends StatefulWidget {
  const WalletTransactionDetailScreen({
    super.key,
    required this.api,
    required this.transactionReference,
  });

  final BackendApi api;
  final String transactionReference;

  @override
  State<WalletTransactionDetailScreen> createState() =>
      _WalletTransactionDetailScreenState();
}

class _WalletTransactionDetailScreenState
    extends State<WalletTransactionDetailScreen> {
  Map<String, dynamic>? _transaction;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.listWalletTransactions(limit: 100);
      final raw = response['items'];
      final rows = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row))
          : const <Map<String, dynamic>>[];
      Map<String, dynamic>? match;
      for (final row in rows) {
        if (row['id']?.toString() == widget.transactionReference ||
            row['transfer_id']?.toString() == widget.transactionReference) {
          match = row;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _transaction = match;
        _loading = false;
        if (match == null) _error = 'This transaction is unavailable in your wallet.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _value(String key, [String fallback = '—']) {
    final value = _transaction?[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final tx = _transaction;
    final amount = _value('amount');
    final currency = _value('currency', 'KES');
    final kind = _value('kind', 'Wallet transaction').replaceAll('_', ' ');
    final status = _value('status', 'unknown').toUpperCase();
    return Scaffold(
      appBar: const TestagramAppBar(title: 'Transaction details'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? TestagramStateView(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Transaction unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Icon(
                        status == 'COMPLETED'
                            ? Icons.check_circle_outline_rounded
                            : status == 'FAILED'
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                        size: 48,
                        color: status == 'COMPLETED'
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '$currency $amount',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(child: Text(kind)),
                      const SizedBox(height: 20),
                      Card(
                        child: Column(
                          children: [
                            _detail('Status', status),
                            _detail('Transaction ID', _value('id')),
                            _detail('Date', _value('created_at')),
                            _detail('Payment method', _value('provider', 'Testagram Wallet')),
                            if (_value('receipt_number', '').isNotEmpty)
                              _detail('M-Pesa receipt', _value('receipt_number')),
                            if (_value('note', '').isNotEmpty)
                              _detail('Note', _value('note')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This information is loaded from your authenticated Testagram wallet history.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _detail(String label, String value) => ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(value),
      );
}
