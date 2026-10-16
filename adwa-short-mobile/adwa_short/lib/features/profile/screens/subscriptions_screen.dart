import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/subscription.dart';
import '../providers/wallet_provider.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WalletProvider>();
      if (p.subsStatus == WalletLoadStatus.idle) p.loadSubscriptions();
    });
  }

  Future<void> _onSubscribe(SubscriptionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Confirm subscription', style: AppTextStyles.h3),
        content: Text(
          'Subscribe to "${plan.name}" (${plan.priceLabel})? '
          'You can cancel anytime.',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await context.read<WalletProvider>().subscribe(plan);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Subscription activated — enjoy unlimited streaming'
            : 'Subscription failed. Please try again.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WalletProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: const Text('Subscriptions')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          onRefresh: () => p.loadSubscriptions(),
          child: _body(p),
        ),
      ),
    );
  }

  Widget _body(WalletProvider p) {
    switch (p.subsStatus) {
      case WalletLoadStatus.idle:
      case WalletLoadStatus.loading:
        return _skeleton();
      case WalletLoadStatus.error:
        return ErrorView(
          message: p.subsError ?? 'Failed to load subscription plans',
          onRetry: () => p.loadSubscriptions(),
        );
      case WalletLoadStatus.refreshing:
      case WalletLoadStatus.success:
        if (p.plans.isEmpty) {
          return const EmptyState(
            icon: Icons.workspace_premium_outlined,
            title: 'No subscription plans available',
            message: 'Please check back later',
          );
        }
        break;
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: p.plans.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _planCard(p.plans[i]),
      ),
    );
  }

  Widget _planCard(SubscriptionPlan plan) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: plan.isPopular
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surfaceElevated, AppColors.bloodRedDark],
              )
            : null,
        color: plan.isPopular ? null : AppColors.surface,
        border: Border.all(
          color: plan.isPopular ? AppColors.bloodRed : AppColors.border,
          width: plan.isPopular ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.vipGold, size: 26),
              const SizedBox(width: 8),
              Text(plan.name, style: AppTextStyles.h3),
              const Spacer(),
              if (plan.isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('BEST VALUE',
                      style: AppTextStyles.overline
                          .copyWith(color: AppColors.white, fontSize: 8)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.priceLabel,
            style: AppTextStyles.display3.copyWith(color: AppColors.bloodRedBright),
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(plan.description, style: AppTextStyles.body2),
          ],
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: AppTextStyles.body2)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          AdwaButton(
            label: 'Subscribe',
            icon: Icons.workspace_premium_outlined,
            onPressed: () => _onSubscribe(plan),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: LoadingShimmer(height: 200, borderRadius: 16),
      ),
    );
  }
}
