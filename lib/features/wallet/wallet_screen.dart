import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/backend_api.dart';
import 'transfer_idempotency.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Map<String, dynamic> _wallet = const {};
  List<Map<String, dynamic>> _transactions = const [];
  final WalletTransferAttempt _transferAttempt = WalletTransferAttempt();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final values = await Future.wait([
        widget.api.getWalletBalance(currency: 'KES'),
        widget.api.listWalletTransactions(limit: 50),
      ]);
      final items = values[1]['items'];
      if (!mounted) return;
      setState(() {
        _wallet = values[0];
        _transactions = items is List
            ? items
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
            : const [];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _transfer() async {
    final username = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    try {
      final form = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Send money'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Recipient username',
                    hintText: '@username',
                  ),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${(_wallet['currency'] ?? 'KES')}' ,
                  ),
                ),
                TextField(
                  controller: note,
                  maxLength: 280,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final recipient = username.text.trim().replaceFirst(RegExp(r'^@'), '');
                final value = amount.text.trim();
                if (recipient.length < 2 || value.isEmpty) return;
                Navigator.pop(dialogContext, {
                  'username': recipient,
                  'amount': value,
                  'note': note.text.trim(),
                });
              },
              child: const Text('Review transfer'),
            ),
          ],
        ),
      );
      if (form == null || !mounted) return;

      setState(() => _sending = true);
      final recipient = await widget.api.resolveWalletRecipient(form['username']!);
      final recipientId = (recipient['user_id'] ?? '').toString();
      final canonicalUsername = (recipient['username'] ?? form['username']!).toString();
      if (recipientId.isEmpty) {
        throw const BackendApiException('The recipient account could not be verified.');
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm transfer'),
          content: Text(
            'Send ${_wallet['currency'] ?? 'KES'} ${form['amount']} to @$canonicalUsername?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send money'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final currency = (_wallet['currency'] ?? 'KES').toString();
      final fingerprint = walletTransferFingerprint(
        recipientId: recipientId,
        amount: form['amount']!,
        currency: currency,
        note: form['note']!,
      );
      final idempotencyKey = _transferAttempt.keyFor(
        fingerprint: fingerprint,
        generateKey: _newIdempotencyKey,
      );
      await widget.api.transferWalletFunds(
        recipientId: recipientId,
        amount: form['amount']!,
        note: form['note']!,
        idempotencyKey: idempotencyKey,
      );
      _transferAttempt.complete(fingerprint);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transfer to @$canonicalUsername completed.')),
      );
      await _load(silent: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      username.dispose();
      amount.dispose();
      note.dispose();
      if (mounted) setState(() => _sending = false);
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  @override
  Widget build(BuildContext context) {
    final currency = (_wallet['currency'] ?? 'KES').toString();
    final balance = (_wallet['balance'] ?? '0.00').toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            tooltip: 'Refresh wallet',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available balance',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '$currency $balance',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _sending ? null : _transfer,
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: Text(_sending ? 'Processing…' : 'Send money'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ],
                  const SizedBox(height: 20),
                  Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No wallet transactions yet.')),
                    )
                  else
                    ..._transactions.map((item) {
                      final kind = (item['kind'] ?? 'transaction').toString();
                      final status = (item['status'] ?? 'completed').toString();
                      final amountText = (item['amount'] ?? '0.00').toString();
                      final itemCurrency = (item['currency'] ?? currency).toString();
                      final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());
                      final localDate = createdAt?.toLocal();
                      final date = localDate == null
                          ? ''
                          : '${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                          title: Text(kind.replaceAll('_', ' ')),
                          subtitle: Text('$date • $status'),
                          trailing: Text('$itemCurrency $amountText'),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  Text(
                    'Transfers are authorized by the Testagram Backend. Check the recipient and amount before confirming.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
