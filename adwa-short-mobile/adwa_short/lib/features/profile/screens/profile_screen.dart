import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onOpenWallet,
    this.onOpenCoinStore,
    this.onBuyPass,
    this.onSubscribe,
    this.onOpenLoyalty,
    this.onOpenDevices,
    this.onOpenSettings,
    this.onEditProfile,
  });

  final VoidCallback? onOpenWallet;
  final VoidCallback? onOpenCoinStore;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;
  final VoidCallback? onOpenLoyalty;
  final VoidCallback? onOpenDevices;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onEditProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshUser();
      context.read<WalletProvider>().loadWallet(refresh: false);
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<AuthProvider>().refreshUser(),
      context.read<WalletProvider>().loadWallet(refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final user = auth.user;
    final w = wallet.wallet;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          onRefresh: _onRefresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _header(user?.displayName ?? 'User',
                  user?.phone ?? '', user?.id ?? '', user?.avatarUrl),
              _balanceCard(w?.balanceBirr ?? 0, w?.balanceCoins ?? 0),
              const SizedBox(height: 16),
              AdwaButton(
                label: 'Coin Top-Up',
                icon: Icons.monetization_on_outlined,
                iconRight: Icons.chevron_right,
                onPressed: widget.onOpenCoinStore,
              ),
              const SizedBox(height: 16),
              _menuSection('Wallet'),
              _menuTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'My Wallet',
                subtitle: 'Balance, deposit & transactions',
                onTap: widget.onOpenWallet,
              ),
              _menuTile(
                icon: Icons.access_time_filled_rounded,
                title: 'Buy Time Pass',
                subtitle: 'Unlimited access for a limited time',
                onTap: widget.onBuyPass,
              ),
              _menuTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Subscriptions',
                subtitle: 'Best value for binge-watchers',
                onTap: widget.onSubscribe,
              ),
              const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
              _menuSection('Account'),
              _menuTile(
                icon: Icons.card_giftcard_outlined,
                title: 'Loyalty Rewards',
                subtitle: 'Free episodes, coins & passes',
                onTap: widget.onOpenLoyalty,
              ),
              _menuTile(
                icon: Icons.devices_other_rounded,
                title: 'My Devices',
                subtitle: 'Manage active sessions',
                onTap: widget.onOpenDevices,
              ),
              _menuTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Language, quality & cache',
                onTap: widget.onOpenSettings,
              ),
              const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
              _logoutTile(),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'ADWA SHORT v1.0.0',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
      String name, String phone, String userId, String? avatarUrl) {
    final resolved = ApiClient.resolveMediaUrl(avatarUrl);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bloodRedDark, AppColors.black],
          stops: [0.0, 0.7],
        ),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 72,
              height: 72,
              child: resolved.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: resolved,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const LoadingShimmer(
                          borderRadius: 36),
                      errorWidget: (_, __, ___) =>
                          _avatarFallback(name),
                    )
                  : _avatarFallback(name),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: AppTextStyles.h2),
                const SizedBox(height: 2),
                Text(phone, style: AppTextStyles.body3),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('User ID:',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        userId.isEmpty ? '—' : '#$userId',
                        style: AppTextStyles.userIdMonospace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.white),
            onPressed: widget.onEditProfile,
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: AppTextStyles.h2.copyWith(color: AppColors.bloodRedBright),
      ),
    );
  }

  Widget _balanceCard(num birr, num coins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _balanceItem(
                'Birr',
                Formatters.birr(birr, withDecimals: false)
                    .replaceAll('Birr ', ''),
                Icons.account_balance_wallet_outlined,
                AppColors.white,
              ),
            ),
            Container(
                width: 1, height: 38, color: AppColors.divider),
            Expanded(
              child: _balanceItem(
                'Coins',
                Formatters.thousands(coins.toInt()),
                Icons.monetization_on_rounded,
                AppColors.vipGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceItem(
      String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppTextStyles.h3),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ],
    );
  }

  Widget _menuSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.bloodRed, size: 20),
      ),
      title: Text(title, style: AppTextStyles.body1),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTextStyles.body3)
          : null,
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _logoutTile() {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.bloodRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.logout_rounded, color: AppColors.bloodRed, size: 20),
      ),
      title: Text('Log Out',
          style: AppTextStyles.body1.copyWith(color: AppColors.bloodRed)),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Log out?', style: AppTextStyles.h3),
            content: Text(
              'Are you sure you want to log out?',
              style: AppTextStyles.body2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodRed,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Log Out'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await context.read<AuthProvider>().logout();
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (_) => false);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
