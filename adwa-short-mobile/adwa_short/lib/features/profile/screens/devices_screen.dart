import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/device.dart';
import '../../../models/wallet.dart';
import '../../../providers/app_state_provider.dart';
import '../providers/device_provider.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().load();
    });
  }

  bool _isPaidTier(Wallet? wallet) {
    if (wallet == null) return false;
    return wallet.balanceCoins > 0 || wallet.balanceBirr > 0;
  }

  Future<void> _onRevoke(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Revoke device?', style: AppTextStyles.h3),
        content: Text(
          'Revoke access for "${device.name}"? '
          'The user will be logged out immediately.',
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
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await context.read<DeviceProvider>().revoke(device.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Device revoked' : 'Could not revoke device'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DeviceProvider>();
    final appState = context.watch<AppStateProvider>();
    final wallet = appState.user?.wallet;
    final paidTier = _isPaidTier(wallet);
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: const Text('My Devices')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          onRefresh: () => p.load(),
          child: ListView(
            children: [
              _tierBanner(paidTier),
              switch (p.status) {
                DeviceStatus.idle || DeviceStatus.loading => _skeleton(),
                DeviceStatus.error => ErrorView(
                    message: p.errorMessage ?? 'Failed to load devices',
                    onRetry: () => p.load(),
                    compact: true,
                  ),
                DeviceStatus.success => _content(p),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _tierBanner(bool paidTier) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paidTier
            ? AppColors.bloodRed.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paidTier ? AppColors.bloodRed : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            paidTier ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
            color: paidTier ? AppColors.bloodRed : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paidTier ? 'Paid tier' : 'Free tier',
                  style: AppTextStyles.label.copyWith(
                    color: paidTier ? AppColors.bloodRed : AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paidTier
                      ? 'Device limits apply. Log out from another device if you reach the limit.'
                      : 'Free-tier users can log in from any device. Device limits apply only to paid subscribers.',
                  style: AppTextStyles.body3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(DeviceProvider p) {
    if (p.devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: EmptyState(
          icon: Icons.devices_other_rounded,
          title: 'No active devices',
          message: 'Sessions you log in to will appear here',
          compact: true,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < p.devices.length; i++) ...[
          _deviceTile(p.devices[i]),
          if (i != p.devices.length - 1)
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _deviceTile(Device d) {
    final platformIcon = _platformIcon(d.platform);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: d.isCurrent
              ? AppColors.bloodRed.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(platformIcon,
            color:
                d.isCurrent ? AppColors.bloodRed : AppColors.textSecondary,
            size: 22),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(d.name, style: AppTextStyles.body1),
          ),
          if (d.isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bloodRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('THIS DEVICE',
                  style: AppTextStyles.overline
                      .copyWith(color: AppColors.white, fontSize: 8)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${d.platform} · last active ${Formatters.date(d.lastActiveAt)}'
        '${d.location != null ? ' · ${d.location}' : ''}',
        style: AppTextStyles.body3,
      ),
      trailing: d.isCurrent
          ? null
          : IconButton(
              icon: const Icon(Icons.logout_rounded,
                  color: AppColors.bloodRed),
              onPressed: () => _onRevoke(d),
            ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'web':
        return Icons.language_rounded;
      case 'windows':
        return Icons.desktop_windows_rounded;
      case 'macos':
      case 'mac':
        return Icons.laptop_mac_rounded;
      case 'linux':
        return Icons.computer_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  Widget _skeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: LoadingShimmer(height: 64, borderRadius: 10),
        ),
      ),
    );
  }
}
