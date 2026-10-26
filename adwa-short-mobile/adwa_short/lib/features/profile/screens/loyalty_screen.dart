import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/loyalty_grant.dart';
import '../providers/loyalty_provider.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoyaltyProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LoyaltyProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Loyalty Rewards & Perks', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            onPressed: () => p.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => p.load(),
          child: switch (p.status) {
            LoyaltyStatus.idle || LoyaltyStatus.loading => _skeleton(),
            LoyaltyStatus.error => ErrorView(
                message: p.errorMessage ?? 'Failed to load rewards',
                onRetry: () => p.load(),
              ),
            LoyaltyStatus.success => _content(p),
          },
        ),
      ),
    );
  }

  Widget _content(LoyaltyProvider p) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. Super Admin Configured Loyalty Tier Card
        if (p.loyaltyStatus != null) ...[
          _adminConfigCard(p.loyaltyStatus!),
          const SizedBox(height: 16),
          _userQualificationCard(p, p.loyaltyStatus!),
          const SizedBox(height: 16),
        ],

        // 2. Ad-Unlock Rule Card
        if (p.rule != null) ...[
          _ruleCard(p.rule!),
          const SizedBox(height: 20),
        ],

        // 3. Rewards History
        const Text('Your Rewards History', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        if (p.grants.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.card_giftcard_outlined,
            title: 'No rewards yet',
            message: 'Maintain your balance to earn platform loyalty tier rewards',
          )
        else
          ...p.grants.map(_grantTile),
      ],
    );
  }

  /// Super Admin Configuration Rules Card
  Widget _adminConfigCard(LoyaltyUserStatus status) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bloodRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: AppColors.bloodRed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Super Admin Loyalty Rules',
                      style: AppTextStyles.label.copyWith(color: AppColors.bloodRedBright),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Active Platform Rewards Tier',
                      style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold, color: AppColors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.isActive ? AppColors.bloodRed.withValues(alpha: 0.2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: status.isActive ? AppColors.bloodRed : AppColors.border,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  status.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: AppTextStyles.caption.copyWith(
                    color: status.isActive ? AppColors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _perkItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Min Balance',
                  value: '${status.minBalanceBirr.toStringAsFixed(0)} Birr',
                ),
              ),
              Expanded(
                child: _perkItem(
                  icon: Icons.monetization_on_outlined,
                  title: 'Free Coins',
                  value: '+${status.freeCoins}',
                ),
              ),
              Expanded(
                child: _perkItem(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Daily Pass',
                  value: '${status.dailyAccessDays} Days',
                ),
              ),
              Expanded(
                child: _perkItem(
                  icon: Icons.movie_filter_outlined,
                  title: 'Free Series',
                  value: '${status.freeFullSeriesCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _perkItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.bloodRed),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.label.copyWith(color: AppColors.white),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// User Qualification and Claim Action Card
  Widget _userQualificationCard(LoyaltyProvider p, LoyaltyUserStatus status) {
    final qualifies = status.qualifies;
    final progress = (status.progressPct / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: qualifies
              ? [AppColors.surfaceElevated, AppColors.bloodRedDark.withValues(alpha: 0.35)]
              : [AppColors.surfaceElevated, AppColors.surface],
        ),
        border: Border.all(
          color: qualifies ? AppColors.bloodRed.withValues(alpha: 0.8) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Your Qualification Status',
                  style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600, color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.isClaimed
                      ? AppColors.surface
                      : (qualifies ? AppColors.bloodRed.withValues(alpha: 0.2) : AppColors.surface),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: status.isClaimed
                        ? AppColors.border
                        : (qualifies ? AppColors.bloodRed : AppColors.border),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  status.isClaimed
                      ? 'CLAIMED'
                      : (qualifies ? 'QUALIFIED' : 'IN PROGRESS'),
                  style: AppTextStyles.caption.copyWith(
                    color: status.isClaimed
                        ? AppColors.textSecondary
                        : (qualifies ? AppColors.bloodRedBright : AppColors.textSecondary),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wallet: ${status.walletBalanceBirr.toStringAsFixed(2)} Birr',
                  style: AppTextStyles.h3.copyWith(color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Target: ${status.minBalanceBirr.toStringAsFixed(0)} Birr',
                style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHover,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.bloodRed),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            status.isClaimed
                ? 'You have already claimed this loyalty reward tier. Each tier can only be claimed once per user.'
                : (qualifies
                    ? 'Your balance qualifies for Super Admin tier perks! Claim your free coins and passes below.'
                    : 'Deposit ${status.neededBirr.toStringAsFixed(2)} more Birr into your wallet to unlock platform loyalty perks.'),
            style: AppTextStyles.caption.copyWith(
              color: qualifies ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          if (status.isClaimed) ...[
            const SizedBox(height: 16),
            const AdwaButton(
              label: 'Reward Already Claimed',
              icon: Icons.check_circle_outline_rounded,
              onPressed: null,
              disabled: true,
              expanded: true,
              size: AdwaButtonSize.md,
            ),
          ] else if (qualifies) ...[
            const SizedBox(height: 16),
            AdwaButton(
              label: p.isClaiming ? 'Claiming Perks...' : 'Claim Loyalty Perks (+${status.freeCoins} Coins)',
              icon: Icons.card_giftcard_rounded,
              onPressed: (p.isClaiming || !status.canClaim)
                  ? null
                  : () async {
                      final ok = await p.claimLoyaltyReward();
                      if (mounted) {
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Loyalty reward claimed successfully!'),
                              backgroundColor: AppColors.bloodRedDark,
                            ),
                          );
                        } else if (p.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(p.errorMessage!),
                              backgroundColor: AppColors.bloodRedDark,
                            ),
                          );
                        }
                      }
                    },
              expanded: true,
              size: AdwaButtonSize.md,
            ),
          ],
        ],
      ),
    );
  }

  Widget _ruleCard(AdUnlockRule rule) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated,
            AppColors.bloodRedDark.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: AppColors.bloodRedMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline_rounded, color: AppColors.bloodRedBright, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ad-Unlock Rule (${rule.provider.toUpperCase()})',
                  style: AppTextStyles.label.copyWith(color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Watch ${rule.adsRequired} ad${rule.adsRequired == 1 ? '' : 's'} '
            'to unlock ${rule.episodesUnlocked} '
            'episode${rule.episodesUnlocked == 1 ? '' : 's'}.',
            style: AppTextStyles.h3.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '100% free episode unlocks supported by ${rule.provider.toUpperCase()} Rewarded Video Network.',
            style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _grantTile(LoyaltyGrant g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bloodRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.bloodRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  g.title,
                  style: AppTextStyles.body1.copyWith(color: AppColors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (g.description != null)
                  Text(
                    g.description!,
                    style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Granted ${Formatters.date(g.grantedAt)}'
                  '${g.expiresAt != null ? " · expires ${Formatters.date(g.expiresAt!)}" : ""}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (g.value > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '+${g.value}',
                style: AppTextStyles.h4.copyWith(color: AppColors.bloodRedBright),
              ),
            ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        LoadingShimmer(width: double.infinity, height: 110, borderRadius: 14),
        SizedBox(height: 16),
        LoadingShimmer(width: double.infinity, height: 90, borderRadius: 14),
        SizedBox(height: 16),
        LoadingShimmer(width: double.infinity, height: 70, borderRadius: 12),
        SizedBox(height: 12),
        LoadingShimmer(width: double.infinity, height: 70, borderRadius: 12),
      ],
    );
  }
}
