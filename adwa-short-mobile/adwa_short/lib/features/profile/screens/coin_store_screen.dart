import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/coin_package.dart';
import '../providers/wallet_provider.dart';

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WalletProvider>();
      if (p.packagesStatus == WalletLoadStatus.idle) p.loadPackages();
      if (p.walletStatus == WalletLoadStatus.idle) p.loadWallet();
    });
  }

  Future<void> _onPurchase(CoinPackage pkg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Confirm purchase', style: AppTextStyles.h3),
        content: Text(
          'Buy ${pkg.totalCoins} coins for ${Formatters.birr(pkg.priceBirr)} '
          '(${pkg.episodesUnlocked} episodes unlocked)?',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await context.read<WalletProvider>().purchaseCoins(pkg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Purchase successful — ${pkg.totalCoins} coins added'
            : 'Purchase failed. Please try again.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WalletProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: const Text('Coin Store')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          onRefresh: () => p.loadPackages(),
          child: _body(p),
        ),
      ),
    );
  }

  Widget _body(WalletProvider p) {
    switch (p.packagesStatus) {
      case WalletLoadStatus.idle:
      case WalletLoadStatus.loading:
        return _skeleton();
      case WalletLoadStatus.error:
        return ErrorView(
          message: p.packagesError ?? 'Failed to load packages',
          onRetry: () => p.loadPackages(),
        );
      case WalletLoadStatus.refreshing:
      case WalletLoadStatus.success:
        if (p.packages.isEmpty) {
          return const EmptyState(
            icon: Icons.monetization_on_outlined,
            title: 'No coin packages available',
            message: 'Please check back later',
          );
        }
        break;
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: p.packages.length,
      itemBuilder: (_, i) {
        final pkg = p.packages[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _packageCard(pkg),
        );
      },
    );
  }

  Widget _packageCard(CoinPackage pkg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pkg.isPopular ? AppColors.bloodRed : AppColors.border,
          width: pkg.isPopular ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.vipGold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.monetization_on_rounded,
                color: AppColors.vipGold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(pkg.name, style: AppTextStyles.h4),
                    if (pkg.isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bloodRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'POPULAR',
                          style: AppTextStyles.overline.copyWith(
                            color: AppColors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${Formatters.thousands(pkg.totalCoins)} coins',
                  style: AppTextStyles.body2
                      .copyWith(color: AppColors.vipGold),
                ),
                if (pkg.episodesUnlocked > 0)
                  Text(
                    '+ Unlocks ${pkg.episodesUnlocked} episodes',
                    style: AppTextStyles.body3,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AdwaButton(
            label: Formatters.birr(pkg.priceBirr, withDecimals: false),
            onPressed: () => _onPurchase(pkg),
            expanded: false,
            size: AdwaButtonSize.sm,
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LoadingShimmer(height: 84, borderRadius: 14),
      ),
    );
  }
}
