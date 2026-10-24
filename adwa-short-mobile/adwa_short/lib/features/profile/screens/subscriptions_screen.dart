import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bloodRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Subscriptions',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0x66E50914),
                Colors.transparent,
              ],
              stops: [0.0, 0.4],
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: p.plans.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _planCard(p.plans[i]),
      ),
    );
  }

  Widget _planCard(SubscriptionPlan plan) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F080A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bloodRed.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bloodRed.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Red atmospheric corner gradient glow
          Positioned(
            top: -25,
            left: -25,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.bloodRed.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Gold Badge Icon + Plan Name
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFB800),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFC837),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        plan.name,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Price Row in bold bright red
                Text(
                  plan.priceLabel,
                  style: AppTextStyles.display3.copyWith(
                    color: const Color(0xFFE50914),
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 18),
                // Bottom Action Button: Wide pill-shaped glowing red button
                GestureDetector(
                  onTap: () => _onSubscribe(plan),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bloodRed,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bloodRed.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Subscribe',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
        child: LoadingShimmer(height: 160, borderRadius: 16),
      ),
    );
  }
}
