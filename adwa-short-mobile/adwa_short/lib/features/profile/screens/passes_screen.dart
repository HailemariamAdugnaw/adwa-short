import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/time_pass.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/cbe_checkout_sheet.dart';

class PassesScreen extends StatefulWidget {
  const PassesScreen({super.key});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
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
      if (p.passesStatus == WalletLoadStatus.idle) p.loadPasses();
      if (_isAuth(context)) {
        p.loadAccessDashboard();
      }
    });
  }

  Future<void> _onPurchase(TimePass pass) async {
    if (!_isAuth(context)) {
      final loggedIn = await GuestAuthPrompt.show(
        context,
        title: 'Sign In to Buy Pass',
        message:
            'Please sign in or register to buy time passes and enjoy unlimited access.',
      );
      if (!loggedIn || !mounted) return;
      await context.read<WalletProvider>().loadWallet(refresh: true);
      await context.read<WalletProvider>().loadAccessDashboard(refresh: true);
    }

    final wp = context.read<WalletProvider>();
    final hasActive = wp.activePass?.hasActivePass == true && (wp.activePass?.remainingSeconds ?? 0) > 0;

    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
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
                hasActive
                    ? 'Extend Pass (+${pass.shortDuration})'
                    : 'Unlock "${pass.name}" (${pass.shortDuration})',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasActive
                    ? 'Stacks +${pass.shortDuration} onto your current pass · Price: ${Formatters.birr(pass.priceBirr)}'
                    : 'Price: ${Formatters.birr(pass.priceBirr)}',
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
                                Text(
                                  'CBE / CBE Birr',
                                  style: AppTextStyles.body1.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
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
        itemType: 'time_pass',
        itemId: pass.id,
        amountBirr: pass.priceBirr,
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
        title: pass.name,
        amountBirr: pass.priceBirr,
      );
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasActive
                ? 'Pass extended (+${pass.shortDuration}) — duration stacked successfully!'
                : 'Pass activated instantly — enjoy unlimited access!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).maybePop();
      }
    } else if (method == 'wallet') {
      final ok = await context.read<WalletProvider>().purchasePass(pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? (hasActive
                  ? 'Pass extended (+${pass.shortDuration}) — duration stacked successfully!'
                  : 'Pass activated — enjoy unlimited access')
              : 'Purchase failed. Insufficient Birr balance or server error.'),
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
          'Time Passes',
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
          onRefresh: () => p.loadPasses(),
          child: _body(p),
        ),
      ),
    );
  }

  Widget _body(WalletProvider p) {
    switch (p.passesStatus) {
      case WalletLoadStatus.idle:
      case WalletLoadStatus.loading:
        return _skeleton();
      case WalletLoadStatus.error:
        return ErrorView(
          message: p.passesError ?? 'Failed to load passes',
          onRetry: () => p.loadPasses(),
        );
      case WalletLoadStatus.refreshing:
      case WalletLoadStatus.success:
        if (p.passes.isEmpty) {
          return const EmptyState(
            icon: Icons.access_time_outlined,
            title: 'No time passes available',
            message: 'Please check back later',
          );
        }
        break;
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: p.passes.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _passCard(p.passes[i]),
      ),
    );
  }

  Widget _passCard(TimePass pass) {
    final wp = context.watch<WalletProvider>();
    final hasActive = wp.activePass?.hasActivePass == true && (wp.activePass?.remainingSeconds ?? 0) > 0;
    final days = pass.durationHours ~/ 24;
    final isHourly = pass.durationHours < 24;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F080A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bloodRed.withValues(alpha: 0.7),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT SIDE: Duration badge + Name, Birr Price + one-time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppColors.bloodRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pass.shortDuration,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              pass.name,
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Formatters.birr(pass.priceBirr),
                                style: AppTextStyles.h3.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'one-time',
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF8E8E93),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // CENTER: Dynamic Custom Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _centerPassIcon(pass, isHourly, days),
                  ),
                ),

                const SizedBox(width: 4),

                // RIGHT SIDE: Pill-shaped Red 'Buy >' button
                GestureDetector(
                  onTap: () => _onPurchase(pass),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.bloodRed,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bloodRed.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasActive ? 'Extend' : 'Buy',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.white,
                          size: 16,
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

  Widget _centerPassIcon(TimePass pass, bool isHourly, int days) {
    if (isHourly) {
      return _buildClockIcon();
    }
    if (days == 1) {
      return _buildDailyCalendarIcon();
    }
    final displayDays = days > 0 ? days : (pass.durationHours ~/ 24);
    return _buildNumberCalendarIcon(displayDays > 0 ? displayDays : 1);
  }

  Widget _buildClockIcon() {
    return SizedBox(
      width: 62,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Motion speed lines on left side
          Positioned(
            left: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 12,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 18,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 10,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          // Red glowing clock circle
          Positioned(
            right: 2,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F0A0D),
                border: Border.all(color: AppColors.bloodRed, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bloodRed.withValues(alpha: 0.65),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Transform.rotate(
                    angle: -0.8,
                    child: Container(
                      width: 2,
                      height: 10,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: 0.6,
                    child: Container(
                      width: 2,
                      height: 12,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCalendarIcon() {
    return SizedBox(
      width: 62,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.bloodRed.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF18181C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85), width: 1.8),
            ),
            child: Column(
              children: [
                Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(
                        6,
                        (_) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 1,
            left: 17,
            child: Container(
                width: 3,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5))),
          ),
          Positioned(
            top: 1,
            right: 17,
            child: Container(
                width: 3,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5))),
          ),
          Positioned(
            bottom: 2,
            right: 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.bloodRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberCalendarIcon(int days) {
    final isYearly = days >= 365;
    return SizedBox(
      width: 62,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.bloodRed.withValues(alpha: 0.55),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          if (isYearly)
            Positioned(
              bottom: -2,
              child: Container(
                width: 52,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(52, 18)),
                  border: Border.all(color: AppColors.bloodRed, width: 2.2),
                ),
              ),
            ),
          Container(
            width: 42,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF140A0D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85), width: 1.8),
            ),
            child: Column(
              children: [
                Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$days',
                      style: TextStyle(
                        color: AppColors.bloodRedBright,
                        fontSize: days >= 100 ? 11 : 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 2,
            left: 17,
            child: Container(
                width: 3,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5))),
          ),
          Positioned(
            top: 2,
            right: 17,
            child: Container(
                width: 3,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5))),
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
        child: LoadingShimmer(height: 100, borderRadius: 16),
      ),
    );
  }
}
