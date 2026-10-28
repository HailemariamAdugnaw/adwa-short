import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/series.dart';
import '../network/api_client.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/formatters.dart';
import 'loading_shimmer.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.series,
    this.onTap,
    this.width,
    this.showTitle = true,
  });

  final Series series;
  final VoidCallback? onTap;
  final double? width;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _poster(),
        if (showTitle) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              series.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          if (_categoryLabel().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                _categoryLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ],
    );
    final w = width;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: w == null ? content : SizedBox(width: w, child: content),
    );
  }

  String _categoryLabel() {
    if (series.category != null && series.category!.isNotEmpty) {
      return series.category!;
    }
    if (series.tags.isNotEmpty) {
      return series.tags.first;
    }
    return '';
  }

  Widget _poster() {
    final resolved = ApiClient.resolveMediaUrl(series.posterUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: resolved.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: resolved,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const LoadingShimmer(),
                    errorWidget: (_, __, ___) => _placeholderPoster(),
                  )
                : _placeholderPoster(),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _badge(),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: _viewCountOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _placeholderPoster() {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined,
                color: AppColors.textTertiary, size: 28),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                series.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge() {
    final BadgeSpec? spec = _badgeSpec();
    if (spec == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: spec.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        spec.label,
        style: AppTextStyles.overline.copyWith(
          color: AppColors.white,
          fontSize: 9,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BadgeSpec? _badgeSpec() {
    if (series.isHot) {
      return const BadgeSpec(label: 'HOT', color: AppColors.bloodRed);
    }
    if (series.isExclusive) {
      return const BadgeSpec(label: 'EXCL', color: AppColors.info);
    }
    if (series.isVip) {
      return const BadgeSpec(label: 'VIP', color: AppColors.vipGold);
    }
    if (series.isNewRelease) {
      return const BadgeSpec(label: 'NEW', color: AppColors.bloodRedBright);
    }
    return null;
  }

  Widget _viewCountOverlay() {
    final count = series.viewsCount;
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded,
              color: AppColors.white, size: 10),
          const SizedBox(width: 2),
          Text(
            Formatters.formatCount(count),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeSpec {
  const BadgeSpec({required this.label, required this.color});
  final String label;
  final Color color;
}
