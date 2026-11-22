import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'topup_attempt_store.dart';

import '../../core/backend_api.dart';
import 'transfer_idempotency.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.api,
    this.topUpAttemptStore,
  });

  final BackendApi api;
  final WalletTopUpAttemptStore? topUpAttemptStore;

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
  late final WalletTopUpAttemptStore _topUpAttemptStore =
      widget.topUpAttemptStore ?? SecureWalletTopUpAttemptStore();
  String? _pendingTopUpIdempotencyKey;
  String? _pendingCheckoutRequestId;
  String? _pendingDepositAmount;

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
      final transactions = items is List
          ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      final pendingDeposit = transactions.cast<Map<String, dynamic>?>().firstWhere(
            (item) =>
                item != null &&
                item['provider'] == 'mpesa' &&
                item['status'] == 'pending' &&
                (item['checkout_request_id'] ?? '').toString().isNotEmpty,
            orElse: () => null,
          );
      final storedAttempt = await _topUpAttemptStore.read();
      final matchingAttempt = storedAttempt == null
          ? null
          : transactions.cast<Map<String, dynamic>?>().firstWhere(
              (item) =>
                  item != null &&
                  item['idempotency_key'] == storedAttempt.idempotencyKey,
              orElse: () => null,
            );
      final matchingCheckout =
          (matchingAttempt?['checkout_request_id'] ?? '').toString().isNotEmpty;
      final matchingTerminal =
          matchingAttempt?['status'] == 'settled' || matchingAttempt?['status'] == 'failed';
      final attemptResolved = matchingAttempt != null && (matchingCheckout || matchingTerminal);
      if (attemptResolved) await _topUpAttemptStore.clear();
      final unresolvedAttempt = attemptResolved ? null : storedAttempt;
      if (!mounted) return;
      setState(() {
        _wallet = values[0];
        _transactions = transactions;
        // A provider checkout ID is recoverable from the Backend ledger.
        _pendingCheckoutRequestId = pendingDeposit == null
            ? null
            : pendingDeposit['checkout_request_id'].toString();
        // If the provider response was lost before a checkout ID was returned,
        // retain the secure idempotency key and recover status by that key.
        _pendingTopUpIdempotencyKey = unresolvedAttempt?.idempotencyKey;
        _pendingDepositAmount = pendingDeposit != null
            ? (pendingDeposit['amount_kes'] ?? pendingDeposit['amount'] ?? '').toString()
            : unresolvedAttempt?.amountKes.toString();
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

  Future<void> _topUp() async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = TextEditingController();
    final amount = TextEditingController(text: '100');
    try {
      final form = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add money with M-Pesa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Safaricom phone number',
                    hintText: '07XX XXX XXX',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'KES ',
                    helperText: 'KES 10 – 150,000 · whole shillings',
                  ),
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
                final rawAmount = int.tryParse(amount.text.trim());
                final rawPhone = phone.text.trim();
                if (rawPhone.isEmpty || rawAmount == null ||
                    rawAmount < 10 || rawAmount > 150000) {
                  return;
                }
                Navigator.pop(dialogContext, {
                  'phone': rawPhone,
                  'amount': rawAmount.toString(),
                });
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (form == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm M-Pesa deposit'),
          content: Text(
            'Request an STK Push for KES ${form['amount']} to ${form['phone']}? '
            'Your wallet is credited only after Safaricom confirms payment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send prompt'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final normalizedPhone = normalizeKenyanMpesaPhone(form['phone']!);
      if (normalizedPhone == null) {
        throw const BackendApiException('Enter a valid Kenyan Safaricom number.');
      }
      final amountKes = int.parse(form['amount']!);
      final previousAttempt = await _topUpAttemptStore.read();
      if (previousAttempt != null &&
          (previousAttempt.phone != normalizedPhone ||
              previousAttempt.amountKes != amountKes)) {
        throw const BackendApiException(
          'An earlier M-Pesa request is unresolved. Retry the same number and amount or check its status before starting another deposit.',
        );
      }
      final attempt = previousAttempt ??
          WalletTopUpAttempt(
            phone: normalizedPhone,
            amountKes: amountKes,
            idempotencyKey: _newIdempotencyKey(),
          );
      // Persist before the network call so a timeout or process death cannot
      // turn a retry into a second Safaricom STK Push.
      if (previousAttempt == null) await _topUpAttemptStore.save(attempt);
      setState(() {
        _sending = true;
        _pendingTopUpIdempotencyKey = attempt.idempotencyKey;
        _pendingDepositAmount = amountKes.toString();
      });
      final request = await widget.api.requestMpesaTopUp(
        phone: normalizedPhone,
        amountKes: amountKes,
        idempotencyKey: attempt.idempotencyKey,
      );
      final checkoutId = (request['checkout_request_id'] ?? '').toString();
      var state = (request['status'] ?? 'pending').toString();
      if (checkoutId.isNotEmpty || state == 'failed') {
        await _topUpAttemptStore.clear();
        if (mounted) setState(() => _pendingTopUpIdempotencyKey = null);
      }
      String receipt = '';
      if (checkoutId.isNotEmpty && state != 'settled' && state != 'failed') {
        setState(() {
          _pendingCheckoutRequestId = checkoutId;
          _pendingDepositAmount = form['amount'];
        });
        // Keep the foreground wait short. The checkout ID remains available
        // for a later status check if Safaricom is slow or the user navigates away.
        for (var attempt = 0; attempt < 5; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 3));
          if (!mounted) return;
          final status = await widget.api.getMpesaTopUpStatus(checkoutId);
          state = (status['status'] ?? state).toString();
          receipt = (status['receipt_number'] ?? '').toString();
          if (state == 'settled' || state == 'failed') break;
        }
      }
      if (state == 'settled' || state == 'failed') {
        await _topUpAttemptStore.clear();
        if (mounted) {
          setState(() {
            _pendingCheckoutRequestId = null;
            _pendingTopUpIdempotencyKey = null;
            _pendingDepositAmount = null;
          });
        }
      }
      if (!mounted) return;
      await _load(silent: true);
      if (!mounted) return;
      final message = state == 'settled'
          ? 'Deposit confirmed${receipt.isEmpty ? '.' : ' · Receipt $receipt'}'
          : state == 'failed'
              ? 'M-Pesa payment was not completed. No funds were added.'
              : 'M-Pesa prompt sent. Deposit is pending; check its status below when you finish on your phone.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
        await _load(silent: true);
      }
    } finally {
      phone.dispose();
      amount.dispose();
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkPendingDeposit() async {
    final checkoutId = _pendingCheckoutRequestId;
    final attemptKey = _pendingTopUpIdempotencyKey;
    if ((checkoutId == null && attemptKey == null) || _sending) return;
    setState(() => _sending = true);
    try {
      final status = checkoutId != null
          ? await widget.api.getMpesaTopUpStatus(checkoutId)
          : await widget.api.getMpesaTopUpAttemptStatus(attemptKey!);
      final state = (status['status'] ?? 'pending').toString();
      final receipt = (status['receipt_number'] ?? '').toString();
      final recoveredCheckout = (status['checkout_request_id'] ?? '').toString();
      if (state == 'settled' || state == 'failed') {
        await _topUpAttemptStore.clear();
        setState(() {
          _pendingCheckoutRequestId = null;
          _pendingTopUpIdempotencyKey = null;
          _pendingDepositAmount = null;
        });
      } else if (recoveredCheckout.isNotEmpty) {
        // The Backend has recovered the provider checkout. From this point the
        // checkout ID and transaction ledger are sufficient for restart recovery.
        await _topUpAttemptStore.clear();
        setState(() {
          _pendingCheckoutRequestId = recoveredCheckout;
          _pendingTopUpIdempotencyKey = null;
        });
      }
      await _load(silent: true);
      if (!mounted) return;
      final message = state == 'settled'
          ? 'Deposit confirmed${receipt.isEmpty ? '.' : ' · Receipt $receipt'}'
          : state == 'failed'
              ? 'M-Pesa payment was not completed. No funds were added.'
              : 'Payment is still being reconciled. Your balance has not changed.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (error is BackendApiException &&
          error.code == 'TOPUP_NOT_FOUND' &&
          attemptKey != null) {
        await _topUpAttemptStore.clear();
        if (mounted) {
          setState(() {
            _pendingTopUpIdempotencyKey = null;
            _pendingDepositAmount = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No M-Pesa request was recorded. You can start a new deposit.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check deposit status: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
                    prefixText: '${(_wallet['currency'] ?? 'KES')} ',
                    helperText: 'KES 0.01 – 10,000.00 · up to 2 decimal places',
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
                final parsedAmount = double.tryParse(value);
                final validAmount = RegExp(r'^[0-9]+([.][0-9]{1,2})?$').hasMatch(value) &&
                    parsedAmount != null && parsedAmount > 0 && parsedAmount <= 10000;
                if (recipient.length < 2 || !validAmount) return;
                Navigator.pop(dialogContext, {
                  'username': recipient,
                  'amount': parsedAmount.toStringAsFixed(2),
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
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: _sending ||
                                        _pendingCheckoutRequestId != null ||
                                        _pendingTopUpIdempotencyKey != null
                                    ? null
                                    : _topUp,
                                icon: const Icon(Icons.account_balance_wallet_rounded),
                                label: Text(
                                  _pendingCheckoutRequestId == null && _pendingTopUpIdempotencyKey == null
                                      ? 'Add with M-Pesa'
                                      : 'Deposit pending',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _sending ? null : _transfer,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded),
                                label: Text(_sending ? 'Processing…' : 'Send money'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'KES wallet · M-Pesa deposits · verified transfers',
                            style: Theme.of(context).textTheme.bodySmall,
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
                  if (_pendingCheckoutRequestId != null || _pendingTopUpIdempotencyKey != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_top_rounded),
                        title: Text('M-Pesa deposit pending · KES ${_pendingDepositAmount ?? ''}'),
                        subtitle: Text(
                          _pendingCheckoutRequestId != null
                              ? 'The wallet is not credited until Safaricom confirms settlement.'
                              : 'The request is being reconciled. Check its status before trying again.',
                        ),
                        trailing: TextButton(
                          onPressed: _sending ? null : _checkPendingDeposit,
                          child: const Text('Check status'),
                        ),
                      ),
                    ),
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
                      final isOutgoing = kind.endsWith('_out');
                      final isIncoming = kind.endsWith('_in') || kind.contains('topup');
                      final icon = isOutgoing
                          ? Icons.arrow_upward_rounded
                          : isIncoming
                              ? Icons.arrow_downward_rounded
                              : Icons.account_balance_wallet_rounded;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(icon)),
                          title: Text(kind.replaceAll('_', ' ')),
                          subtitle: Text('$date • $status'),
                          trailing: Text(
                            '${isOutgoing ? '−' : isIncoming ? '+' : ''}$itemCurrency $amountText',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isOutgoing
                                  ? Theme.of(context).colorScheme.error
                                  : isIncoming
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                            ),
                          ),
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
