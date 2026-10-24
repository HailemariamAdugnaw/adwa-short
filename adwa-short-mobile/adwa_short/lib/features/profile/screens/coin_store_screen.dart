import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
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
          'Buy ${pkg.totalCoins} coins for ${Formatters.birr(pkg.priceBirr)}'
          '${pkg.episodesUnlocked > 0 ? ' (+ Unlocks ${pkg.episodesUnlocked} episodes)' : ''}?',
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Coin Store',
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: p.packages.length,
      itemBuilder: (_, i) {
        final pkg = p.packages[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _packageCard(pkg),
        );
      },
    );
  }

  Widget _packageCard(CoinPackage pkg) {
    final formattedPrice = Formatters.birr(pkg.priceBirr, withDecimals: false);

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT SIDE: 3D Gold Coin Icon
                _goldCoin3D(),
                const SizedBox(width: 16),

                // CENTER: Title, Coins amount, Unlocks subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pkg.name,
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Formatters.thousands(pkg.totalCoins)} coins',
                        style: AppTextStyles.body1.copyWith(
                          color: const Color(0xFFFFC837),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pkg.episodesUnlocked > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '+ Unlocks ${pkg.episodesUnlocked} episodes',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF8E8E93),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // RIGHT SIDE: Pill-shaped glowing red Buy button with price
                GestureDetector(
                  onTap: () => _onPurchase(pkg),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bloodRed,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bloodRed.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formattedPrice,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
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

  Widget _goldCoin3D() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle golden glow cast downward and to its right
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.65),
                    blurRadius: 18,
                    spreadRadius: 4,
                    offset: const Offset(6, 8),
                  ),
                  BoxShadow(
                    color: AppColors.bloodRed.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 6,
                    offset: const Offset(8, 10),
                  ),
                ],
              ),
            ),
          ),
          // 3D Isometric Gold Coin tilted ~50° facing top-right/viewer
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0025)
              ..rotateX(-0.42)
              ..rotateY(0.92)
              ..rotateZ(-0.28),
            alignment: Alignment.center,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF7C2),
                    Color(0xFFFFC837),
                    Color(0xFFD48B00),
                    Color(0xFF6B4200),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 7,
                    offset: const Offset(5, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8A5C00).withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFFFFEA7B),
                        Color(0xFFFFB800),
                        Color(0xFF9E6500),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFF9D4),
                            Color(0xFFFFC01D),
                            Color(0xFFB87800),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFF2A1).withValues(alpha: 0.9),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LoadingShimmer(height: 90, borderRadius: 16),
      ),
    );
  }
}
