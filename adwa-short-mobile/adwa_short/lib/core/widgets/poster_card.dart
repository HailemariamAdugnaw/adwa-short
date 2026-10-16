import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/series.dart';
import '../network/api_client.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'loading_shimmer.dart';
import 'tag_chip.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.series,
    this.onTap,
    this.width = 130,
    this.showTitle = true,
  });

  final Series series;
  final VoidCallback? onTap;
  final double width;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _poster(),
            if (showTitle) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  series.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
              ),
              if (series.totalEpisodes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text(
                    '${series.totalEpisodes} Eps',
                    style: AppTextStyles.caption,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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
          Positioned(
            top: 8,
            left: 8,
            child: _badges(),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
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
                color: AppColors.textTertiary, size: 32),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                series.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badges() {
    final chips = <Widget>[];
    if (series.isHot) {
      chips.add(const TagChip.hot(label: 'HOT'));
    }
    if (series.isVip) {
      chips.add(const TagChip.vip());
    }
    if (series.isExclusive) {
      chips.add(const TagChip.exclusive());
    }
    if (series.isNewRelease) {
      chips.add(const TagChip.newRelease());
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      direction: Axis.vertical,
      spacing: 4,
      runSpacing: 0,
      children: chips,
    );
  }
}
