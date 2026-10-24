import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../downloads/providers/download_provider.dart';
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
    this.onOpenDownloads,
    this.onEditProfile,
  });

  final VoidCallback? onOpenWallet;
  final VoidCallback? onOpenCoinStore;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;
  final VoidCallback? onOpenLoyalty;
  final VoidCallback? onOpenDevices;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenDownloads;
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
      context.read<DownloadProvider>().loadDownloads();
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<AuthProvider>().refreshUser(),
      context.read<WalletProvider>().loadWallet(refresh: true),
      context.read<DownloadProvider>().loadDownloads(),
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
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Profile',
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
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _userHeaderCard(user),
              const SizedBox(height: 14),
              _balanceAndTopUpCard(w?.balanceBirr ?? 745, w?.balanceCoins ?? 1200),
              const SizedBox(height: 12),
              _sectionHeader('WALLET'),
              _groupedCard(
                children: [
                  _menuTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Wallet',
                    subtitle: 'Balance, deposit & transactions',
                    onTap: widget.onOpenWallet,
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  _menuTile(
                    icon: Icons.access_time_filled_rounded,
                    title: 'Buy Time Pass',
                    subtitle: 'Unlimited access for a limited time',
                    onTap: widget.onBuyPass,
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  _menuTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Subscriptions',
                    subtitle: 'Best value for binge-watchers',
                    onTap: widget.onSubscribe,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionHeader('ACCOUNT'),
              _groupedCard(
                children: [
                  _menuTile(
                    icon: Icons.card_giftcard_outlined,
                    title: 'Loyalty Rewards',
                    subtitle: 'Free episodes, coins & passes',
                    onTap: widget.onOpenLoyalty,
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  _downloadsTile(),
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  _menuTile(
                    icon: Icons.devices_other_rounded,
                    title: 'My Devices',
                    subtitle: 'Manage active sessions',
                    onTap: widget.onOpenDevices,
                  ),
                  const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                  _menuTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Language, quality & cache',
                    onTap: widget.onOpenSettings,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _groupedCard(
                children: [
                  _menuTile(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    subtitle: '',
                    isDanger: true,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  'ADWA SHORT v1.0.0',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF666666),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userHeaderCard(User? user) {
    final name = (user?.displayName.trim().isNotEmpty == true)
        ? user!.displayName
        : 'Haile';
    final phone = (user?.phone.trim().isNotEmpty == true)
        ? user!.phone
        : '1234567890';
    final userId = (user?.id.trim().isNotEmpty == true)
        ? user!.id
        : '3';
    final avatarUrl = user?.avatarUrl;
    final resolvedAvatar = ApiClient.resolveMediaUrl(avatarUrl);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';

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
          Positioned(
            bottom: -25,
            right: -25,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.bloodRed.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Avatar with glowing red border
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bloodRed, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bloodRed.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: resolvedAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: resolvedAvatar,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const LoadingShimmer(borderRadius: 34),
                            errorWidget: (_, __, ___) => _avatarFallback(initial),
                          )
                        : _avatarFallback(initial),
                  ),
                ),
                const SizedBox(width: 16),
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: AppTextStyles.body2.copyWith(
                          color: const Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ID: #$userId',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF8E8E93),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Edit Profile Button
                GestureDetector(
                  onTap: widget.onEditProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181014),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.white,
                      size: 18,
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

  Widget _avatarFallback(String initial) {
    return Container(
      color: const Color(0xFF140A0D),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.h1.copyWith(
          color: AppColors.bloodRedBright,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      ),
    );
  }

  Widget _balanceAndTopUpCard(num birr, num coins) {
    final birrDisplay = Formatters.birr(birr, withDecimals: false)
        .replaceAll('Birr ', '')
        .trim();
    final coinsDisplay = Formatters.thousands(coins.toInt());

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Row: Birr & Coins Balance
            Row(
              children: [
                // Birr
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            birrDisplay,
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Birr',
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                // Coins
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFFFB800), width: 1.5),
                        ),
                        child: const Center(
                          child: Text(
                            '\$',
                            style: TextStyle(
                              color: Color(0xFFFFB800),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coinsDisplay,
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Coins',
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bottom Pill Button: Coin Top-Up >
            GestureDetector(
              onTap: widget.onOpenCoinStore,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bloodRed,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bloodRed.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: AppColors.bloodRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Coin Top-Up',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.bloodRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupedCard({required List<Widget> children}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F080A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bloodRed.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bloodRed.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    final iconColor = isDanger ? AppColors.bloodRed : AppColors.bloodRed;
    final titleColor = isDanger ? AppColors.bloodRed : AppColors.white;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.bloodRed.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Red icon inside rounded square container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.bloodRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.bloodRed.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Title & Subtitle Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body1.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.body3.copyWith(
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
            const SizedBox(width: 8),
            // Trailing widget (badge + chevron or chevron right)
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDanger ? AppColors.bloodRed : Colors.white54,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  Widget _downloadsTile() {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final count = provider.downloads.length;
        final subtitleText = count > 0
            ? '$count episode${count == 1 ? '' : 's'} available offline'
            : 'Watch episodes without a connection';

        return _menuTile(
          icon: Icons.download_for_offline_outlined,
          title: 'Downloads',
          subtitle: subtitleText,
          onTap: widget.onOpenDownloads,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.bloodRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
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
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}
