import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adwa_button.dart';
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
      appBar: AppBar(title: const Text('Time Passes')),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: p.passes.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _passCard(p.passes[i]),
      ),
    );
  }

  Widget _passCard(TimePass pass) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pass.isPopular ? AppColors.bloodRed : AppColors.border,
          width: pass.isPopular ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bloodRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pass.shortDuration,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.white),
                ),
              ),
              const SizedBox(width: 10),
              Text(pass.name, style: AppTextStyles.h4),
              const Spacer(),
              if (pass.isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('POPULAR',
                      style: AppTextStyles.overline
                          .copyWith(color: AppColors.white, fontSize: 8)),
                ),
            ],
          ),
          if (pass.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(pass.description, style: AppTextStyles.body2),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                Formatters.birr(pass.priceBirr),
                style: AppTextStyles.h3,
              ),
              const SizedBox(width: 6),
              Text('one-time', style: AppTextStyles.body3),
              const Spacer(),
              AdwaButton(
                label: 'Buy',
                onPressed: () => _onPurchase(pass),
                expanded: false,
                size: AdwaButtonSize.sm,
              ),
            ],
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
        child: LoadingShimmer(height: 130, borderRadius: 14),
      ),
    );
  }
}
