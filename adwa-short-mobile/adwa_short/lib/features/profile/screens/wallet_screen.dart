import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/wallet.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/cbe_checkout_sheet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    this.onBuyCoins,
    this.onBuyPass,
    this.onSubscribe,
  });

  final VoidCallback? onBuyCoins;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isAuth(BuildContext context, {bool listen = false}) {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: listen);
      return auth.isAuthenticated;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAuth(context, listen: false)) {
        context.read<WalletProvider>().loadWallet(refresh: false);
      }
    });
  }

  Future<void> _onRefresh() async {
    if (_isAuth(context, listen: false)) {
      await context.read<WalletProvider>().loadWallet(refresh: true);
    }
  }

  Future<void> _onDeposit() async {
    if (!_isAuth(context, listen: false)) {
      final loggedIn = await GuestAuthPrompt.show(
        context,
        title: 'Sign In to Deposit',
        message:
            'Please sign in or register to manage your CBE Birr wallet and add funds.',
      );
      if (!loggedIn || !mounted) return;
      await context.read<WalletProvider>().loadWallet(refresh: true);
    }

    final amount = await _showDepositDialog();
    if (amount == null || amount <= 0 || !mounted) return;

    final wp = context.read<WalletProvider>();
    final initRes = await wp.initiateCbePayment(
      itemType: 'wallet_deposit',
      amountBirr: amount,
    );
    if (!mounted) return;
    if (initRes == null) {
      // Fallback to direct deposit
      final ok = await wp.deposit(amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Deposit of ${Formatters.birr(amount)} successful'
              : 'Deposit failed. Please try again.'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
      return;
    }

    final success = await CbeCheckoutSheet.show(
      context,
      initResult: initRes,
      title: 'Wallet Deposit',
      amountBirr: amount,
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deposit of ${Formatters.birr(amount)} confirmed instantly!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<num?> _showDepositDialog() async {
    final controller = TextEditingController(text: '100');
    return showDialog<num>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              const Icon(Icons.account_balance_rounded, color: AppColors.bloodRed, size: 24),
              const SizedBox(width: 10),
              Text('Deposit via CBE Birr', style: AppTextStyles.h3),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top up your wallet automatically with Commercial Bank of Ethiopia (CBE Birr). '
                'Instant confirmation without receipt uploads.',
                style: AppTextStyles.body3.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: 'ETB ',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.bloodRed),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final v = num.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(v);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bloodRed,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Continue to CBE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = _isAuth(context, listen: true);
    if (!isAuth) {
      return Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('My Wallet'),
        ),
        body: SafeArea(
          child: _guestView(context),
        ),
      );
    }
    final p = context.watch<WalletProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('My Wallet'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          onRefresh: _onRefresh,
          child: switch (p.walletStatus) {
            WalletLoadStatus.idle ||
            WalletLoadStatus.loading =>
              _loading(),
            WalletLoadStatus.error => ErrorView(
                message: p.walletError ?? 'Failed to load wallet',
                onRetry: _onRefresh,
              ),
            WalletLoadStatus.refreshing ||
            WalletLoadStatus.success =>
              _content(p),
          },
        ),
      ),
    );
  }

  Widget _guestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bloodRed.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.bloodRed, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66C8102E),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign In to Access Wallet',
              style: AppTextStyles.h2.copyWith(color: AppColors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your CBE Birr balance, coin top-ups, and transaction history are linked to your registered account.',
              style:
                  AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AdwaButton(
              label: 'Sign In / Register',
              icon: Icons.login_rounded,
              expanded: true,
              onPressed: () async {
                final ok = await GuestAuthPrompt.show(
                  context,
                  title: 'Sign In to Access Wallet',
                  message:
                      'Please sign in or register to manage your CBE Birr wallet and add funds.',
                );
                if (ok && mounted) {
                  context.read<WalletProvider>().loadWallet(refresh: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const LoadingShimmer(height: 180, borderRadius: 16),
        const SizedBox(height: 24),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LoadingShimmer(height: 56, borderRadius: 10),
          ),
        ),
      ],
    );
  }

  Widget _content(WalletProvider p) {
    final wallet = p.wallet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _balanceCard(wallet?.balanceBirr ?? 0, wallet?.balanceCoins ?? 0),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionTile(
                icon: Icons.monetization_on_outlined,
                title: 'Buy Coins',
                onTap: widget.onBuyCoins,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionTile(
                icon: Icons.access_time_filled_rounded,
                title: 'Buy Pass',
                onTap: widget.onBuyPass,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Subscribe',
                onTap: widget.onSubscribe,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _onDeposit,
          icon: const Icon(Icons.account_balance_rounded,
              color: AppColors.bloodRed),
          label: const Text(
            'Deposit via Commercial Bank of Ethiopia (CBE)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.bloodRed, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 24),
        Text('Transaction History', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        if (wallet == null || wallet.recentTransactions.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message: 'Your purchases and deposits will appear here',
          )
        else
          ...wallet.recentTransactions.map(_transactionTile),
      ],
    );
  }

  Widget _balanceCard(num birr, num coins) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceElevated, AppColors.bloodRedDark],
        ),
        border: Border.all(color: AppColors.bloodRedMuted, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.bloodRedGlow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.white, size: 22),
              const SizedBox(width: 8),
              Text('Wallet Balance',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Formatters.birr(birr),
            style: AppTextStyles.display2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: AppColors.vipGold, size: 18),
              const SizedBox(width: 6),
              Text(
                Formatters.thousands(coins.toInt()),
                style: AppTextStyles.h3
                    .copyWith(color: AppColors.vipGold),
              ),
              const SizedBox(width: 6),
              Text('coins', style: AppTextStyles.body3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.bloodRed, size: 26),
              const SizedBox(height: 6),
              Text(
                title,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionTile(Transaction tx) {
    final isCredit = tx.isCredit;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (isCredit ? AppColors.success : AppColors.bloodRed)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          isCredit ? Icons.add_rounded : Icons.remove_rounded,
          color: isCredit ? AppColors.success : AppColors.bloodRed,
          size: 18,
        ),
      ),
      title: Text(
        tx.description.isNotEmpty ? tx.description : tx.type,
        style: AppTextStyles.body1,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${Formatters.date(tx.createdAt)} · ${tx.type}',
        style: AppTextStyles.body3,
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}${tx.currency == 'coins' ? '${Formatters.thousands(tx.amount.toInt())} coins' : Formatters.birr(tx.amount)}',
        style: AppTextStyles.label.copyWith(
          color: isCredit ? AppColors.success : AppColors.bloodRedBright,
        ),
      ),
    );
  }
}
