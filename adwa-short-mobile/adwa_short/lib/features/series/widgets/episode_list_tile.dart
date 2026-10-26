import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/episode.dart';

class EpisodeListTile extends StatelessWidget {
  const EpisodeListTile({
    super.key,
    required this.episode,
    required this.index,
    this.onTap,
  });

  final Episode episode;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLocked = !episode.effectivelyAccessible;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 100,
                      child: _buildThumb(),
                    ),
                    if (episode.watchedProgress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: episode.watchedProgress.clamp(0.0, 1.0),
                          minHeight: 3,
                          color: AppColors.bloodRed,
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    if (isLocked)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          alignment: Alignment.center,
                          child: const Icon(Icons.lock_rounded,
                              color: AppColors.white, size: 22),
                        ),
                      ),
                    if (!isLocked)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: AppColors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Episode ${episode.number}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.bloodRedBright,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (episode.isFree) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.bloodRed.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.bloodRed,
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'FREE',
                              style: AppTextStyles.overline.copyWith(
                                color: AppColors.bloodRedBright,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (episode.durationSeconds > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ${Formatters.clockFromSeconds(episode.durationSeconds)}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode.title,
                      style: AppTextStyles.body1.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        episode.description,
                        style: AppTextStyles.body3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLocked ? Icons.lock_outline_rounded : Icons.chevron_right,
                color: isLocked
                    ? AppColors.bloodRed
                    : AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb() {
    final resolved = ApiClient.resolveMediaUrl(episode.thumbnailUrl);
    if (resolved.isEmpty) return _thumbPlaceholder();
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      placeholder: (_, __) => const LoadingShimmer(),
      errorWidget: (_, __, ___) => _thumbPlaceholder(),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined,
          color: AppColors.textTertiary, size: 22),
    );
  }
}
