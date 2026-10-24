import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/time_pass.dart';
import '../providers/wallet_provider.dart';

class PassesScreen extends StatefulWidget {
  const PassesScreen({super.key});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WalletProvider>();
      if (p.passesStatus == WalletLoadStatus.idle) p.loadPasses();
    });
  }

  Future<void> _onPurchase(TimePass pass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Confirm purchase', style: AppTextStyles.h3),
        content: Text(
          'Buy "${pass.name}" (${pass.shortDuration}) for '
          '${Formatters.birr(pass.priceBirr)}?',
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
    if (confirmed != true) return;
    final ok = await context.read<WalletProvider>().purchasePass(pass);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Pass activated — enjoy unlimited access'
            : 'Purchase failed. Please try again.'),
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
                          'Buy',
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
