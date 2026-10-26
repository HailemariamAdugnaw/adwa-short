import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../models/short_item.dart';

class PaywallOverlay extends StatelessWidget {
  const PaywallOverlay({
    super.key,
    required this.item,
    this.onUnlockAds,
    this.onBuyCoins,
    this.onBuyPass,
    this.onSubscribe,
    this.onMaybeLater,
  });

  final ShortItem item;
  final VoidCallback? onUnlockAds;
  final VoidCallback? onBuyCoins;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;
  final VoidCallback? onMaybeLater;

  @override
  Widget build(BuildContext context) {
    final posterUrl = ApiClient.resolveMediaUrl(item.thumbnailUrl);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.black),
            errorWidget: (_, __, ___) => Container(color: AppColors.black),
          )
        else
          Container(color: AppColors.black),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bloodRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.bloodRed,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bloodRed.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'This Episode is Locked',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _episodeInfo(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _reasonText(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (onUnlockAds != null) ...[
                    AdwaButton(
                      label: 'Unlock via Ads (Watch Ad)',
                      icon: Icons.play_circle_outline_rounded,
                      onPressed: onUnlockAds,
                      expanded: true,
                      size: AdwaButtonSize.md,
                    ),
                    const SizedBox(height: 10),
                  ],
                  AdwaButton(
                    label: 'Unlock with Coins (${item.coinCost > 0 ? item.coinCost : 10} Coins)',
                    icon: Icons.monetization_on_rounded,
                    onPressed: onBuyCoins,
                    expanded: true,
                    variant: onUnlockAds != null ? AdwaButtonVariant.secondary : AdwaButtonVariant.primary,
                    size: AdwaButtonSize.md,
                  ),
                  const SizedBox(height: 10),
                  AdwaButton(
                    label: 'Buy Time Pass',
                    icon: Icons.access_time_filled_rounded,
                    onPressed: onBuyPass,
                    expanded: true,
                    variant: AdwaButtonVariant.secondary,
                    size: AdwaButtonSize.md,
                  ),
                  const SizedBox(height: 10),
                  AdwaButton(
                    label: 'Subscribe',
                    icon: Icons.workspace_premium_outlined,
                    onPressed: onSubscribe,
                    expanded: true,
                    variant: AdwaButtonVariant.secondary,
                    size: AdwaButtonSize.md,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: onMaybeLater,
                      child: Text(
                        'Maybe later',
                        style: AppTextStyles.body3
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (item.title.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.bloodRed, width: 1),
              ),
              child: Text(
                'Episode ${item.episodeNumber ?? ''} · Locked',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.bloodRedBright,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _episodeInfo() {
    final parts = <String>[];
    if (item.seriesTitle != null && item.seriesTitle!.isNotEmpty) {
      parts.add(item.seriesTitle!);
    }
    parts.add(item.title);
    return parts.join(' · ');
  }

  String _reasonText() {
    switch (item.accessReason) {
      case 'need_coins':
        return 'Unlock with coins to watch this episode.';
      case 'need_pass':
        return 'Buy a time pass for unlimited access.';
      case 'need_subscription':
        return 'Subscribe to unlock all episodes.';
      case 'need_ad':
      case 'ad_required':
        return 'Watch an ad to unlock this episode.';
      default:
        return 'Choose an option below to keep watching.';
    }
  }
}
