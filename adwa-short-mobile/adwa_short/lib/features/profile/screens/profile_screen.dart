import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/user.dart';
import '../../../providers/app_state_provider.dart';
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
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        auth.refreshUser();
        context.read<WalletProvider>().loadWallet(refresh: false);
        context.read<WalletProvider>().loadAccessDashboard(refresh: false);
        context.read<DownloadProvider>().loadDownloads();
      }
    });
  }

  Future<void> _onRefresh() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      await Future.wait([
        auth.refreshUser(),
        context.read<WalletProvider>().loadWallet(refresh: true),
        context.read<WalletProvider>().loadAccessDashboard(refresh: true),
        context.read<DownloadProvider>().loadDownloads(),
      ]);
    }
  }

  Future<void> _promptAuth({String? title, String? message}) async {
    if (!mounted) return;
    final ok = await GuestAuthPrompt.show(
      context,
      title: title,
      message: message,
    );
    if (ok && mounted) {
      await _onRefresh();
    }
  }

  Future<void> _guardAuth(
      VoidCallback? action, String title, String message) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final ok = await GuestAuthPrompt.show(
        context,
        title: title,
        message: message,
      );
      if (!ok || !mounted) return;
      await _onRefresh();
    }
    if (!mounted) return;
    action?.call();
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
            children: auth.isAuthenticated
                ? [
                    _userHeaderCard(user),
                    const SizedBox(height: 14),
                    _balanceAndTopUpCard(
                      w?.balanceBirr ?? 0,
                      w?.balanceCoins ?? 0,
                    ),
                    const SizedBox(height: 14),
                    _activeAccessDashboardCard(wallet),
                    const SizedBox(height: 12),
                    _sectionHeader('WALLET'),
                    _groupedCard(
                      children: [
                        _menuTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'My Wallet',
                          subtitle: 'CBE balance, deposit & transactions',
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
                    _buildVersionFooter(),
                  ]
                : [
                    _guestHeaderCard(),
                    const SizedBox(height: 14),
                    _guestCtaBanner(),
                    const SizedBox(height: 16),
                    _sectionHeader('APP SETTINGS & OFFLINE'),
                    _groupedCard(
                      children: [
                        _downloadsTile(),
                        const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                        _menuTile(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Language, streaming quality & cache',
                          onTap: widget.onOpenSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionHeader('PREMIUM & WALLET'),
                    _groupedCard(
                      children: [
                        _menuTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'My Wallet',
                          subtitle: 'CBE balance, deposit & transactions',
                          onTap: () => _guardAuth(
                            widget.onOpenWallet,
                            'Sign In to Access Wallet',
                            'Please sign in or register to manage your CBE Birr wallet and add funds.',
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                        _menuTile(
                          icon: Icons.access_time_filled_rounded,
                          title: 'Buy Time Pass',
                          subtitle: 'Unlimited access for a limited time',
                          onTap: () => _guardAuth(
                            widget.onBuyPass,
                            'Sign In to Buy Pass',
                            'Please sign in or register to buy time passes and enjoy unlimited access.',
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                        _menuTile(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Subscriptions',
                          subtitle: 'Best value for binge-watchers',
                          onTap: () => _guardAuth(
                            widget.onSubscribe,
                            'Sign In to Subscribe',
                            'Please sign in or register to activate a subscription and enjoy unlimited access.',
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                        _menuTile(
                          icon: Icons.card_giftcard_outlined,
                          title: 'Loyalty Rewards',
                          subtitle: 'Free episodes, coins & passes',
                          onTap: () => _guardAuth(
                            widget.onOpenLoyalty,
                            'Sign In for Loyalty Rewards',
                            'Please sign in or register to view and claim your loyalty rewards.',
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                        _menuTile(
                          icon: Icons.devices_other_rounded,
                          title: 'My Devices',
                          subtitle: 'Manage active sessions',
                          onTap: () => _guardAuth(
                            widget.onOpenDevices,
                            'Sign In to Manage Devices',
                            'Please sign in or register to manage your active device sessions.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _groupedCard(
                      children: [
                        _menuTile(
                          icon: Icons.login_rounded,
                          title: 'Sign In / Register',
                          subtitle: 'Access your saved progress & subscriptions',
                          onTap: () => _promptAuth(
                            title: 'Sign In to Your Account',
                            message:
                                'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildVersionFooter(),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionFooter() {
    return Center(
      child: Text(
        'ADWA SHORT v1.0.0',
        style: AppTextStyles.caption.copyWith(
          color: const Color(0xFF666666),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _guestHeaderCard() {
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
            color: AppColors.bloodRed.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF181014),
                    border: Border.all(color: AppColors.bloodRed, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bloodRed.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Guest Account',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF240D13),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    AppColors.bloodRed.withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'Guest Mode • #GUEST',
                              style: TextStyle(
                                color: AppColors.bloodRedBright,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browsing locally without an account',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestCtaBanner() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF14080B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bloodRed,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44C8102E),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x55C8102E),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.bloodRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Unlock Full Access',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign in or register to sync your wallet, track time passes, and unlock premium episodes',
                  style: TextStyle(
                    color: Color(0xFFEEEEEE),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Sign In button
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.of(context, rootNavigator: true)
                              .pushNamed(AppRoutes.login);
                          if (mounted) {
                            await _onRefresh();
                          }
                        },
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF1A2B),
                                AppColors.bloodRed,
                                AppColors.bloodRedDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66E50914),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded,
                                  color: AppColors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Register button
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.of(context, rootNavigator: true)
                              .pushNamed(AppRoutes.register);
                          if (mounted) {
                            await _onRefresh();
                          }
                        },
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E0C12),
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(
                              color: AppColors.bloodRed,
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_alt_1_rounded,
                                  color: AppColors.bloodRedBright, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Register',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userHeaderCard(User? user) {
    if (user == null) {
      return _guestHeaderCard();
    }

    final name = (user.displayName.trim().isNotEmpty == true)
        ? user.displayName
        : 'User';
    final phone = (user.phone.trim().isNotEmpty == true)
        ? user.phone
        : '';
    final userId = (user.id.trim().isNotEmpty == true)
        ? user.id
        : '';
    final avatarUrl = user.avatarUrl;
    final resolvedAvatar = ApiClient.resolveMediaUrl(avatarUrl);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

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
              onTap: () => _guardAuth(
                widget.onOpenCoinStore,
                'Sign In to Buy Coins',
                'Please sign in or register to buy coins, unlock episodes, and access subscriptions.',
              ),
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

  Widget _activeAccessDashboardCard(WalletProvider wallet) {
    final sub = wallet.activeSubscription;
    final pass = wallet.activePass;
    final bool hasSub = sub != null && sub.hasActiveSubscription && sub.remainingSeconds > 0;
    final bool hasPass = pass != null && pass.hasActivePass && pass.remainingSeconds > 0;

    if (!hasSub && !hasPass) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F080A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: Color(0xFF8E8E93),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Active Pass or Subscription',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlock unlimited streaming anytime',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _guardAuth(
                widget.onSubscribe ?? widget.onBuyPass,
                'Sign In to Access Plans',
                'Please sign in or register to activate passes and subscriptions.',
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bloodRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Explore',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F080A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bloodRed,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bloodRed.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Corner radial glow
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 110,
              height: 110,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.bloodRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bloodRed, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppColors.bloodRed,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE ACCESS STATUS',
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00C853), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00C853),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'UNLOCKED',
                            style: TextStyle(
                              color: Color(0xFF00C853),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Active Subscription Block
                if (hasSub) ...[
                  _accessSubscriptionRow(
                    title: sub.planName ?? 'VIP Subscription',
                    subtitle: 'Tier: ${sub.billingCycle?.toUpperCase() ?? "MONTHLY"}',
                    renewsAtText: sub.formattedExpiresAt,
                    onManage: widget.onSubscribe,
                  ),
                ],

                // Divider if both active
                if (hasSub && hasPass)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Colors.white12, height: 1),
                  ),

                // Active Time Pass Block
                if (hasPass) ...[
                  _accessItemRow(
                    icon: Icons.access_time_filled_rounded,
                    title: pass.name ?? 'Time Pass',
                    subtitle: 'Duration: ${pass.durationHours ?? 24} Hours',
                    remainingText: pass.formattedRemaining,
                    expiresAtText: pass.formattedExpiresAt,
                    onManage: widget.onBuyPass,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessSubscriptionRow({
    required String title,
    required String subtitle,
    required String renewsAtText,
    VoidCallback? onManage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB800), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF8E8E93),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onManage != null)
              GestureDetector(
                onTap: onManage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    'Manage',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Auto-Renewing Status Card (No countdown timer for auto-renewing subscriptions)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.autorenew_rounded,
                    color: AppColors.bloodRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Billing Status:',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bloodRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.bloodRed, width: 1),
                ),
                child: const Text(
                  'AUTO-RENEWS',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (renewsAtText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Next billing date: $renewsAtText',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFF8E8E93),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _accessItemRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String remainingText,
    required String expiresAtText,
    VoidCallback? onManage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFFB800), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF8E8E93),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onManage != null)
              GestureDetector(
                onTap: onManage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    'Manage',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Live Countdown Display Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppColors.bloodRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Remaining:',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                remainingText,
                style: AppTextStyles.body2.copyWith(
                  color: const Color(0xFFE50914),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        if (expiresAtText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Expires: $expiresAtText',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFF666666),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
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
    context.read<AppStateProvider>().setUser(null);
    context.read<WalletProvider>().reset();
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }
}
