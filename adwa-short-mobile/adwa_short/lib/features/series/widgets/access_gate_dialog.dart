import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../models/access_check.dart';
import '../../../models/episode.dart';

class AccessGateDialog extends StatefulWidget {
  const AccessGateDialog({
    super.key,
    required this.episode,
    required this.accessCheck,
    this.onWatchAd,
    this.onPayWithCoins,
    this.onBuyPass,
    this.onSubscribe,
  });

  final Episode episode;
  final AccessCheck accessCheck;
  final Future<bool> Function()? onWatchAd;
  final Future<bool> Function()? onPayWithCoins;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;

  static Future<void> show(
    BuildContext context, {
    required Episode episode,
    required AccessCheck accessCheck,
    Future<bool> Function()? onWatchAd,
    Future<bool> Function()? onPayWithCoins,
    VoidCallback? onBuyPass,
    VoidCallback? onSubscribe,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AccessGateDialog(
        episode: episode,
        accessCheck: accessCheck,
        onWatchAd: onWatchAd,
        onPayWithCoins: onPayWithCoins,
        onBuyPass: onBuyPass,
        onSubscribe: onSubscribe,
      ),
    );
  }

  @override
  State<AccessGateDialog> createState() => _AccessGateDialogState();
}

class _AccessGateDialogState extends State<AccessGateDialog> {
  bool _busy = false;
  int? _selected;

  Future<void> _runOption(int idx) async {
    setState(() {
      _busy = true;
      _selected = idx;
    });
    bool? ok;
    try {
      if (idx == 0 && widget.onWatchAd != null) {
        ok = await widget.onWatchAd!();
      } else if (idx == 1 && widget.onPayWithCoins != null) {
        ok = await widget.onPayWithCoins!();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    } else if (ok == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not complete the action. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.accessCheck;
    final coinCost = access.coinCost ?? widget.episode.coinCost ?? 1;
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + mediaQuery.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.85 -
              mediaQuery.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: AppColors.bloodRed, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Unlock this Episode',
                            style: AppTextStyles.h3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Episode ${widget.episode.number} · ${widget.episode.title}',
                      style: AppTextStyles.body2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose how you want to continue watching',
                      style: AppTextStyles.body3,
                    ),
                    const SizedBox(height: 18),
                    _option(
                      index: 0,
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Watch Ad to Unlock',
                      subtitle:
                          'Watch a short ad and continue watching for free',
                      enabled: widget.onWatchAd != null,
                      badge: 'FREE',
                    ),
                    const SizedBox(height: 10),
                    _option(
                      index: 1,
                      icon: Icons.monetization_on_outlined,
                      title: 'Pay with Coins',
                      subtitle: 'Deduct $coinCost coins from your balance',
                      enabled: widget.onPayWithCoins != null,
                      badge: '$coinCost coins',
                    ),
                    const SizedBox(height: 10),
                    _option(
                      index: 2,
                      icon: Icons.access_time_filled_rounded,
                      title: 'Buy a Time Pass',
                      subtitle: 'Unlimited access for a limited time',
                      enabled: widget.onBuyPass != null,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onBuyPass?.call();
                      },
                    ),
                    const SizedBox(height: 10),
                    _option(
                      index: 3,
                      icon: Icons.workspace_premium_outlined,
                      title: 'Subscribe',
                      subtitle:
                          'Best value for binge-watchers — unlock everything',
                      enabled: widget.onSubscribe != null,
                      badge: 'BEST',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSubscribe?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AdwaButton(
              label: 'Cancel',
              variant: AdwaButtonVariant.secondary,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final isLoading = _busy && _selected == index;
    final color = enabled ? AppColors.bloodRed : AppColors.textDisabled;
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: !enabled || _busy
            ? null
            : () {
                if (onTap != null) {
                  onTap();
                } else {
                  _runOption(index);
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bloodRed),
                      )
                    : Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.body1),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.body3),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: AppTextStyles.overline.copyWith(
                      color: AppColors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
