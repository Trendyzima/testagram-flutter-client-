import 'package:material_ui/material_ui.dart';

import '../../core/backend_api.dart';
import '../wallet/wallet_screen.dart';

class MonetizationHubScreen extends StatelessWidget {
  const MonetizationHubScreen({super.key, required this.api});

  final BackendApi api;

  static const _features = <_MonetizationFeature>[
    _MonetizationFeature(
      title: 'Ad campaigns',
      subtitle: 'Create campaigns, manage budgets and review delivery',
      icon: Icons.campaign_outlined,
      detail:
          'Campaign creation, audience controls, budget reservation, ad review and delivery reporting need authenticated Backend contracts.',
    ),
    _MonetizationFeature(
      title: 'Creator earnings',
      subtitle: 'Revenue statements and creator analytics',
      icon: Icons.insights_outlined,
      detail:
          'Creator earnings need a reconciled revenue ledger, source attribution, statement history and owner-scoped analytics.',
    ),
    _MonetizationFeature(
      title: 'Premium membership',
      subtitle: 'Membership plans and account entitlements',
      icon: Icons.workspace_premium_outlined,
      detail:
          'Premium access needs a verified entitlement source, billing lifecycle, renewal and cancellation handling.',
    ),
    _MonetizationFeature(
      title: 'Subscriptions',
      subtitle: 'Support creators with recurring memberships',
      icon: Icons.subscriptions_outlined,
      detail:
          'Creator subscriptions need plan management, recurring payment state, subscriber access checks and cancellation/refund rules.',
    ),
    _MonetizationFeature(
      title: 'Promotions and boosts',
      subtitle: 'Promote eligible posts with transparent budgets',
      icon: Icons.rocket_launch_outlined,
      detail:
          'Promotions need eligibility and moderation checks, budget holds, delivery limits, spend reconciliation and performance reporting.',
    ),
    _MonetizationFeature(
      title: 'Payouts',
      subtitle: 'Manage verified payout destinations and withdrawals',
      icon: Icons.account_balance_outlined,
      detail:
          'Payouts need verified payee ownership, risk review, approval controls, immutable ledger entries and provider reconciliation.',
    ),
    _MonetizationFeature(
      title: 'Gifts and tips',
      subtitle: 'Send and receive creator support',
      icon: Icons.card_giftcard_outlined,
      detail:
          'Gifts and tips need recipient consent, idempotent transfers, fee disclosure, refund handling and ledger-backed receipts.',
    ),
  ];

  void _openWallet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletScreen(api: api),
      ),
    );
  }

  void _openFeature(BuildContext context, _MonetizationFeature feature) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MonetizationFeatureScreen(feature: feature),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Monetization')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Your money and creator tools',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your Testagram wallet and explore creator revenue tools. Each service is shown with its real integration status.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  title: const Text('Wallet'),
                  subtitle: const Text(
                    'Balance, M-Pesa top-ups, transfers and transaction history',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openWallet(context),
                ),
              ),
              const SizedBox(height: 18),
              Text('Creator and monetization tools',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final feature in _features)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(feature.icon)),
                    title: Text(feature.title),
                    subtitle: Text(feature.subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openFeature(context, feature),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Unavailable tools are deliberately gated. Testagram will not display invented earnings, campaign results, subscriber counts or payout balances.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonetizationFeature {
  const _MonetizationFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.detail,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String detail;
}

class _MonetizationFeatureScreen extends StatelessWidget {
  const _MonetizationFeatureScreen({super.key, required this.feature});

  final _MonetizationFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(feature.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_clock_outlined,
                  size: 48,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text('Backend integration required',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(feature.detail, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  'This page is reserved and navigable, but the workflow is not enabled. No payment, entitlement or earnings action has been simulated.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
