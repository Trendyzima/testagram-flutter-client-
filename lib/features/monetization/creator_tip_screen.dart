import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../wallet/transfer_idempotency.dart';

class CreatorTipScreen extends StatefulWidget {
  const CreatorTipScreen({super.key, required this.api});

  final BackendApi api;

  @override
  State<CreatorTipScreen> createState() => _CreatorTipScreenState();
}

class _CreatorTipScreenState extends State<CreatorTipScreen> {
  final _username = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _attempt = WalletTransferAttempt();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _sendTip() async {
    final username = _username.text.trim().replaceFirst(RegExp(r'^@'), '');
    final amountText = _amount.text.trim();
    final amount = double.tryParse(amountText);
    final validAmount = RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(amountText) &&
        amount != null && amount > 0 && amount <= 10000;
    if (username.length < 2 || !validAmount || _note.text.trim().length > 280) {
      setState(() => _error = 'Enter a valid Testagram username and an amount from KES 0.01 to KES 10,000.00.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final resolved = await widget.api.resolveWalletRecipient(username);
      final recipientId = (resolved['user_id'] ?? '').toString();
      final canonicalUsername = (resolved['username'] ?? username).toString();
      if (recipientId.isEmpty) {
        throw const BackendApiException('The creator account could not be verified.');
      }
      if (!mounted) return;

      final normalizedAmount = amount.toStringAsFixed(2);
      final note = _note.text.trim();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm creator tip'),
          content: Text('Send KES $normalizedAmount to @$canonicalUsername?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send tip'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final fingerprint = walletTransferFingerprint(
        recipientId: recipientId,
        amount: normalizedAmount,
        currency: 'KES',
        note: note,
      );
      final idempotencyKey = _attempt.keyFor(
        fingerprint: fingerprint,
        generateKey: _newIdempotencyKey,
      );
      await widget.api.tipWalletCreator(
        recipientId: recipientId,
        amount: normalizedAmount,
        note: note,
        idempotencyKey: idempotencyKey,
      );
      _attempt.complete(fingerprint);
      if (!mounted) return;
      setState(() {
        _username.clear();
        _amount.clear();
        _note.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your KES $normalizedAmount tip to @$canonicalUsername was sent.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gifts and tips')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              Icon(Icons.card_giftcard_outlined, size: 44, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Support a creator', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Send a one-time tip from your Testagram KES wallet. The recipient is verified before confirmation; the Backend records the transfer with an idempotency key.'),
              const SizedBox(height: 20),
              TextField(
                controller: _username,
                enabled: !_sending,
                decoration: const InputDecoration(labelText: 'Creator username', prefixText: '@'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                enabled: !_sending,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tip amount', prefixText: 'KES '),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                enabled: !_sending,
                maxLength: 280,
                decoration: const InputDecoration(labelText: 'Message (optional)'),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : _sendTip,
                child: Text(_sending ? 'Processing…' : 'Review and send tip'),
              ),
              const SizedBox(height: 8),
              Text('Tips require sufficient available wallet balance. A confirmed tip is a real wallet transfer, not a simulated gift.', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
