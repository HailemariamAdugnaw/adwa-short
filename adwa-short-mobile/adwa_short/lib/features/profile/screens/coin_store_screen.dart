import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/coin_stack_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/monetization_description_section.dart';
import '../../../models/coin_package.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/cbe_checkout_sheet.dart';

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen> {
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
      if (p.packagesStatus == WalletLoadStatus.idle) p.loadPackages();
      if (_isAuth(context) && p.walletStatus == WalletLoadStatus.idle) {
        p.loadWallet();
      }
    });
  }

  Future<void> _onPurchase(CoinPackage pkg) async {
    if (!_isAuth(context)) {
      final loggedIn = await GuestAuthPrompt.show(
        context,
        title: 'Sign In to Buy Coins',
        message:
            'Please sign in or register to buy coins, unlock episodes, and access subscriptions.',
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
                'Buy ${pkg.totalCoins} Coins',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Price: ${Formatters.birr(pkg.priceBirr)}',
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
        itemType: 'coins',
        itemId: pkg.id,
        amountBirr: pkg.priceBirr,
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
        title: '${pkg.totalCoins} Coins',
        amountBirr: pkg.priceBirr,
      );
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase successful — ${pkg.totalCoins} coins added instantly!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (method == 'wallet') {
      final ok = await context.read<WalletProvider>().purchaseCoins(pkg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Purchase successful — ${pkg.totalCoins} coins added'
              : 'Purchase failed. Insufficient Birr balance or server error.'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
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
      itemCount: p.packages.length + 1,
      itemBuilder: (_, i) {
        if (i < p.packages.length) {
          final pkg = p.packages[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _packageCard(pkg),
          );
        }
        return const MonetizationDescriptionSection(
          rules: [
            DescriptionRule(
              title: 'Unlock short drama episodes',
              body:
                  'Coins and Bonus Coins are used to unlock premium episodes of ADWA SHORT original series.',
            ),
            DescriptionRule(
              title: 'Top-up via CBE & Birr',
              body:
                  'Top-ups are processed in Ethiopian Birr (ETB) via Commercial Bank of Ethiopia (CBE / CBE Birr). 1 Coin = 1 Bonus Coin in purchasing power. All coin top-ups are non-refundable.',
            ),
            DescriptionRule(
              title: 'Bonus Coins & wallet tracking',
              body:
                  'Bonus Coins are applied first during episode unlocks. Check your active coin balances and bonus expiration dates in the My Wallet section of the app.',
            ),
            DescriptionRule(
              title: 'Permanent library access',
              body:
                  'Unlocked drama episodes remain permanently accessible in your account library with no recurring charges.',
            ),
          ],
          footerPrefix: 'Recharge means agree to the ',
          footerLink: 'Recharge Agreement',
        );
      },
    );
  }

  Widget _packageCard(CoinPackage pkg) {
    final formattedPrice = Formatters.birr(pkg.priceBirr, withDecimals: false);

    return GestureDetector(
      onTap: () => _onPurchase(pkg),
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0F080A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pkg.isPopular
                ? AppColors.bloodRed
                : AppColors.bloodRed.withValues(alpha: 0.6),
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
                  // LEFT SIDE: CoinStackIcon in glowing circle badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A0A0E),
                      border: Border.all(
                        color: AppColors.bloodRed.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bloodRed.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const CoinStackIcon(
                      size: 24,
                      color: Color(0xFFFFC837),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // CENTER: Title, Coins amount with CoinStackIcon, Bonus subtitle
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
                        Row(
                          children: [
                            const CoinStackIcon(
                              size: 15,
                              color: Color(0xFFFFC837),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${Formatters.thousands(pkg.totalCoins)} coins',
                                style: AppTextStyles.body1.copyWith(
                                  color: const Color(0xFFFFC837),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (pkg.bonusCoins > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+ ${Formatters.thousands(pkg.bonusCoins)} bonus coins',
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

                  // RIGHT SIDE: Pill-shaped glowing Blood Red capsule Buy button with white text
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bloodRed,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE50914),
                          Color(0xFFB00710),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                ],
              ),
            ),
          ],
        ),
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
