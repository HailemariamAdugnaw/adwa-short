import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/monetization_description_section.dart';
import '../../../models/access_status.dart';
import '../../../models/subscription.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/cbe_checkout_sheet.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isAuth(BuildContext context) {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      return auth.isAuthenticated;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WalletProvider>();
      if (p.subsStatus == WalletLoadStatus.idle) p.loadSubscriptions();
      if (_isAuth(context)) {
        p.loadAccessDashboard();
      }
    });
  }

  Future<void> _onManageSubscription(ActiveSubscriptionStatus activeSub) async {
    final wp = context.read<WalletProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F080A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.bloodRed, width: 1.5),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bloodRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bloodRed, width: 1.5),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: AppColors.bloodRed, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeSub.planName ?? 'Active Subscription',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tier: ${activeSub.billingCycle?.toUpperCase() ?? "MONTHLY"}',
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bloodRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Renewal Mode:',
                            style: AppTextStyles.body2.copyWith(color: const Color(0xFF8E8E93)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.autorenew_rounded, size: 15, color: Color(0xFF00C853)),
                              const SizedBox(width: 4),
                              Text(
                                'Auto-Renewing',
                                style: AppTextStyles.body2.copyWith(
                                  color: const Color(0xFF00C853),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Billing Date:',
                            style: AppTextStyles.body2.copyWith(color: const Color(0xFF8E8E93)),
                          ),
                          Flexible(
                            child: Text(
                              activeSub.formattedExpiresAt,
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Unsubscribe / Cancel Button
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF0F080A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.bloodRed, width: 1.5),
                        ),
                        title: Text(
                          'Cancel Subscription?',
                          style: AppTextStyles.h3.copyWith(color: AppColors.white),
                        ),
                        content: Text(
                          'Are you sure you want to cancel your ${activeSub.planName ?? "subscription"}? You will lose unlimited access once this period ends.',
                          style: AppTextStyles.body2.copyWith(color: const Color(0xFFCCCCCC)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: Text(
                              'Keep Subscription',
                              style: AppTextStyles.button.copyWith(color: const Color(0xFF8E8E93)),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.bloodRed,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(dCtx).pop(true),
                            child: Text(
                              'Yes, Cancel',
                              style: AppTextStyles.button.copyWith(color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      Navigator.of(ctx).pop();
                      final ok = await wp.cancelSubscription(subscriptionId: activeSub.subscriptionId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Subscription successfully canceled.' : 'Failed to cancel subscription.',
                              style: const TextStyle(color: AppColors.white),
                            ),
                            backgroundColor: ok ? AppColors.surfaceElevated : AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.bloodRed, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel_outlined, color: AppColors.bloodRed, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Unsubscribe / Cancel Subscription',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.bloodRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSubscribe(SubscriptionPlan plan) async {
    if (!_isAuth(context)) {
      final loggedIn = await GuestAuthPrompt.show(
        context,
        title: 'Sign In to Subscribe',
        message:
            'Please sign in or register to activate a VIP subscription and enjoy unlimited access.',
      );
      if (!loggedIn || !mounted) return;
      await context.read<WalletProvider>().loadWallet(refresh: true);
      await context.read<WalletProvider>().loadAccessDashboard(refresh: true);
    }

    final method = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Subscribe to "${plan.name}"',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Price: ${Formatters.birr(plan.priceBirr)} / ${plan.billingCycle}',
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.bloodRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Option 1: CBE Birr (Automated)
              InkWell(
                onTap: () => Navigator.of(ctx).pop('cbe'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bloodRed, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bloodRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: AppColors.bloodRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'CBE / CBE Birr',
                                    style: AppTextStyles.body1.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bloodRed,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'AUTOMATED',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instant checkout via CBE Birr App or USSD',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Wallet Balance
              InkWell(
                onTap: () => Navigator.of(ctx).pop('wallet'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet Balance',
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pay from deposited Birr funds',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (method == null || !mounted) return;

    if (method == 'cbe') {
      final wp = context.read<WalletProvider>();
      final initRes = await wp.initiateCbePayment(
        itemType: 'subscription',
        itemId: plan.id,
        amountBirr: plan.priceBirr,
      );
      if (!mounted) return;
      if (initRes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate CBE checkout. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final success = await CbeCheckoutSheet.show(
        context,
        initResult: initRes,
        title: plan.name,
        amountBirr: plan.priceBirr,
      );
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription activated instantly — enjoy unlimited streaming!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).maybePop();
      }
    } else if (method == 'wallet') {
      final ok = await context.read<WalletProvider>().subscribe(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Subscription activated — enjoy unlimited streaming'
              : 'Subscription failed. Insufficient Birr balance or server error.'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
      if (ok) Navigator.of(context).maybePop();
    }
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
      itemCount: p.plans.length + 1,
      itemBuilder: (_, i) {
        if (i < p.plans.length) {
          final plan = p.plans[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _planCard(plan),
          );
        }
        return const MonetizationDescriptionSection(
          rules: [
            DescriptionRule(
              title: 'All-access VIP membership',
              body:
                  'Subscriptions unlock full VIP access to all ADWA SHORT drama series, originals, and newly released episodes without coin paywalls.',
            ),
            DescriptionRule(
              title: 'Ad-free & high-bitrate streaming',
              body:
                  'Enjoy seamless high-definition video playback with zero commercial interruptions and priority server streaming bandwidth.',
            ),
            DescriptionRule(
              title: 'Flexible ETB renewal',
              body:
                  'Subscriptions renew automatically at the end of each billing cycle (weekly, monthly, or yearly) via your linked CBE Birr or wallet account.',
            ),
            DescriptionRule(
              title: 'Cancel anytime in settings',
              body:
                  'Manage or cancel your subscription at any time directly through your ADWA SHORT Account Settings or My Wallet at least 24 hours before the current period ends.',
            ),
          ],
          footerPrefix: 'Subscription means agree to the ',
          footerLink: 'VIP Member Agreement',
        );
      },
    );
  }

  Widget _planCard(SubscriptionPlan plan) {
    final wp = context.watch<WalletProvider>();
    final activeSub = wp.activeSubscription;
    final int? planIdInt = int.tryParse(plan.id);
    final bool isCurrentPlan = activeSub != null &&
        activeSub.hasActiveSubscription &&
        activeSub.planId == planIdInt;
    final bool hasOtherSub = activeSub != null &&
        activeSub.hasActiveSubscription &&
        !isCurrentPlan;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F080A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan
              ? const Color(0xFFFFB800)
              : AppColors.bloodRed.withValues(alpha: 0.8),
          width: isCurrentPlan ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCurrentPlan ? const Color(0xFFFFB800) : AppColors.bloodRed)
                .withValues(alpha: 0.22),
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
                    (isCurrentPlan ? const Color(0xFFFFB800) : AppColors.bloodRed)
                        .withValues(alpha: 0.35),
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
                // Top Row: Gold Badge Icon + Plan Name + Active Badge
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
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.bloodRed,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFB800), width: 1),
                        ),
                        child: Text(
                          'ACTIVE TIER',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
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
                if (isCurrentPlan) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.autorenew_rounded, size: 15, color: Color(0xFFFFC837)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Auto-renews: ${activeSub.formattedExpiresAt}',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFFFFC837),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                // Dynamic Action Button: Changes dynamically based on subscription state
                GestureDetector(
                  onTap: () {
                    if (isCurrentPlan) {
                      _onManageSubscription(activeSub);
                    } else if (hasOtherSub) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'You are already subscribed to ${activeSub.planName ?? "another plan"}. Please manage or cancel your existing subscription first.',
                            style: const TextStyle(color: AppColors.white),
                          ),
                          backgroundColor: AppColors.surfaceElevated,
                        ),
                      );
                    } else {
                      _onSubscribe(plan);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isCurrentPlan
                          ? const Color(0xFF260A0E)
                          : (hasOtherSub ? const Color(0xFF1C1C1E) : AppColors.bloodRed),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrentPlan
                            ? AppColors.bloodRed
                            : (hasOtherSub ? Colors.white24 : Colors.transparent),
                        width: isCurrentPlan ? 1.5 : 1.0,
                      ),
                      boxShadow: isCurrentPlan || !hasOtherSub
                          ? [
                              BoxShadow(
                                color: AppColors.bloodRed.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCurrentPlan
                              ? Icons.check_circle_rounded
                              : (hasOtherSub
                                  ? Icons.lock_outline_rounded
                                  : Icons.workspace_premium_outlined),
                          color: isCurrentPlan
                              ? AppColors.bloodRed
                              : (hasOtherSub ? const Color(0xFF8E8E93) : AppColors.white),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isCurrentPlan
                                ? 'Subscribed · Manage'
                                : (hasOtherSub
                                    ? 'Active on ${activeSub.planName ?? "Other Plan"}'
                                    : 'Subscribe'),
                            style: AppTextStyles.label.copyWith(
                              color: isCurrentPlan
                                  ? AppColors.white
                                  : (hasOtherSub ? const Color(0xFF8E8E93) : AppColors.white),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
