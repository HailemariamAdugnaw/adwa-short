import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/star_rating.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../models/short_item.dart';

class ShortOverlayButtons extends StatelessWidget {
  const ShortOverlayButtons({
    super.key,
    required this.item,
    this.onRate,
    this.onSave,
    this.onShowEpisodes,
    this.onShowReviews,
  });

  final ShortItem item;
  final void Function(int rating)? onRate;
  final VoidCallback? onSave;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onShowReviews;

  @override
  Widget build(BuildContext context) {
    final ratingProvider = context.watch<RatingProvider>();
    final episodeId = item.episodeId ?? item.id;
    final summary = ratingProvider.summaryFor(episodeId);
    final userRating = ratingProvider.userRatingFor(episodeId);
    final avg = summary?.average ?? item.averageRating;
    final count = summary?.count ?? item.ratingCount ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(
          icon: userRating > 0
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: userRating > 0 ? AppColors.bloodRed : AppColors.white,
          label: avg != null ? avg.toStringAsFixed(1) : 'Rate',
          onTap: () => _openRatingSheet(context),
        ),
        const SizedBox(height: 18),
        _action(
          icon: item.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: item.isSaved ? AppColors.bloodRedBright : AppColors.white,
          label: 'Save',
          onTap: onSave,
        ),
        const SizedBox(height: 18),
        _action(
          icon: Icons.reviews_outlined,
          color: AppColors.white,
          label: count > 0 ? Formatters.compact(count) : 'Reviews',
          onTap: onShowReviews,
        ),
        const SizedBox(height: 18),
        _action(
          icon: Icons.video_library_outlined,
          color: AppColors.white,
          label: 'Episodes',
          onTap: onShowEpisodes,
        ),
        const SizedBox(height: 18),
        _action(
          icon: Icons.share_outlined,
          color: AppColors.white,
          label: 'Share',
          onTap: () {},
        ),
      ],
    );
  }

  void _openRatingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RatingSheet(
        item: item,
        onRate: onRate,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
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

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.item, this.onRate});

  final ShortItem item;
  final void Function(int rating)? onRate;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final episodeId = widget.item.episodeId ?? widget.item.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<RatingProvider>();
      _selected = p.userRatingFor(episodeId);
      p.getEpisodeRating(episodeId);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final episodeId = widget.item.episodeId ?? widget.item.id;
    final p = context.watch<RatingProvider>();
    final summary = p.summaryFor(episodeId);
    final userRating = p.userRatingFor(episodeId);
    final displayRating = _selected > 0 ? _selected : userRating;
    final avg = summary?.average ?? widget.item.averageRating;
    final count = summary?.count ?? widget.item.ratingCount ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.bloodRed, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Rate this episode', style: AppTextStyles.h3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.item.title,
              style: AppTextStyles.body2,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Center(
              child: StarRating(
                currentRating: displayRating,
                interactive: true,
                size: 44,
                onRatingChanged: (v) {
                  setState(() => _selected = v);
                  context.read<RatingProvider>().rateEpisode(episodeId, v);
                  widget.onRate?.call(v);
                },
              ),
            ),
            const SizedBox(height: 14),
            if (avg != null)
              Center(
                child: Text(
                  '$count ${count == 1 ? 'rating' : 'ratings'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            if (avg != null) ...[
              const SizedBox(height: 6),
              Center(
                child: StarRating(
                  averageRating: avg,
                  size: 18,
                  spacing: 2,
                  showNumeric: true,
                  ratingCount: count,
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
