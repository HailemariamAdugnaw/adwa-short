import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/downloads/providers/download_provider.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../models/short_item.dart';

class RightActionBar extends StatelessWidget {
  const RightActionBar({
    super.key,
    required this.item,
    this.onRate,
    this.onShowEpisodes,
    this.onSave,
    this.onShare,
    this.onDownload,
    this.downloadStatus = DownloadStatus.idle,
    this.isDownloaded = false,
  });

  final ShortItem item;
  final VoidCallback? onRate;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final DownloadStatus downloadStatus;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    RatingProvider? ratingProvider;
    try {
      ratingProvider = Provider.of<RatingProvider>(context, listen: true);
    } catch (_) {
      ratingProvider = null;
    }
    final episodeId = item.episodeId ?? item.id;
    final summary = ratingProvider?.summaryFor(episodeId);
    final userRating = ratingProvider?.userRatingFor(episodeId) ?? 0;
    final count = summary?.count ?? item.ratingCount ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(
          icon: userRating > 0
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: userRating > 0 ? AppColors.bloodRed : AppColors.white,
          label: Formatters.formatCount(count),
          onTap: onRate,
        ),
        const SizedBox(height: 16),
        _action(
          icon: Icons.layers_rounded,
          color: AppColors.white,
          label: 'Episodes',
          onTap: onShowEpisodes,
        ),
        const SizedBox(height: 16),
        _action(
          icon: item.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: item.isSaved ? AppColors.bloodRedBright : AppColors.white,
          label: 'Save',
          onTap: onSave,
        ),
        const SizedBox(height: 16),
        _action(
          icon: Icons.share_outlined,
          color: AppColors.white,
          label: 'Share',
          onTap: onShare,
        ),
        if (onDownload != null) ...[
          const SizedBox(height: 16),
          _downloadAction(),
        ],
      ],
    );
  }

  Widget _downloadAction() {
    final bool isDownloading = downloadStatus == DownloadStatus.downloading;
    final bool downloaded =
        isDownloaded || downloadStatus == DownloadStatus.success;
    final String label;
    final Color labelColor;
    final Color iconColor;
    final IconData icon;
    if (isDownloading) {
      label = 'Downloading';
      labelColor = AppColors.white;
      iconColor = AppColors.bloodRed;
      icon = Icons.downloading_rounded;
    } else if (downloaded) {
      label = 'Downloaded';
      labelColor = AppColors.success;
      iconColor = AppColors.success;
      icon = Icons.download_done_rounded;
    } else {
      label = 'Download';
      labelColor = AppColors.white;
      iconColor = AppColors.white;
      icon = Icons.download_rounded;
    }
    return GestureDetector(
      onTap: isDownloading ? null : onDownload,
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isDownloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.bloodRed,
                    ),
                  )
                : Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
