import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
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
      appBar: AppBar(title: const Text('Loyalty Rewards')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (p.rule != null) ...[
          _ruleCard(p.rule!),
          const SizedBox(height: 20),
        ],
        Text('Your Rewards', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        if (p.grants.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.card_giftcard_outlined,
            title: 'No rewards yet',
            message: 'Watch more episodes to earn loyalty rewards',
          )
        else
          ...p.grants.map(_grantTile),
      ],
    );
  }

  Widget _ruleCard(AdUnlockRule rule) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceElevated, AppColors.bloodRedDark],
        ),
        border: Border.all(color: AppColors.bloodRedMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.white, size: 22),
              const SizedBox(width: 8),
              Text('Ad-Unlock Rule',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Watch ${rule.adsRequired} ad${rule.adsRequired == 1 ? '' : 's'} '
            'to unlock ${rule.episodesUnlocked} '
            'episode${rule.episodesUnlocked == 1 ? '' : 's'}.',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 4),
          Text(
            'Keep watching to earn more free episodes through your loyalty streak.',
            style: AppTextStyles.body3,
          ),
        ],
      ),
    );
  }

  Widget _grantTile(LoyaltyGrant g) {
    final (icon, color) = _iconFor(g.type);
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g.title, style: AppTextStyles.body1),
                if (g.description != null)
                  Text(g.description!, style: AppTextStyles.body3),
                Text(
                  'Granted ${Formatters.date(g.grantedAt)}'
                  '${g.expiresAt != null ? " · expires ${Formatters.date(g.expiresAt!)}" : ""}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (g.value > 0)
            Text(
              '+${g.value}',
              style: AppTextStyles.h4.copyWith(color: color),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _iconFor(LoyaltyGrantType type) {
    switch (type) {
      case LoyaltyGrantType.coins:
        return (Icons.monetization_on_rounded, AppColors.vipGold);
      case LoyaltyGrantType.freeEpisode:
        return (Icons.play_circle_rounded, AppColors.bloodRed);
      case LoyaltyGrantType.pass:
        return (Icons.access_time_filled_rounded, AppColors.bloodRedBright);
      case LoyaltyGrantType.subscription:
        return (Icons.workspace_premium_rounded, AppColors.exclusivePurple);
    }
  }

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: LoadingShimmer(height: 76, borderRadius: 12),
      ),
    );
  }
}
