import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/star_rating.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../models/episode.dart';
import '../providers/review_provider.dart';
import 'review_input.dart';
import 'review_list.dart';

class ReviewBottomSheet extends StatefulWidget {
  const ReviewBottomSheet({
    super.key,
    required this.episode,
    this.seriesTitle,
    this.defaultEpisodeId,
  });

  final Episode? episode;
  final String? seriesTitle;
  final String? defaultEpisodeId;

  static Future<void> show(
    BuildContext context, {
    Episode? episode,
    String? seriesTitle,
    String? defaultEpisodeId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReviewBottomSheet(
        episode: episode,
        seriesTitle: seriesTitle,
        defaultEpisodeId: defaultEpisodeId,
      ),
    );
  }

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  String get _episodeId =>
      widget.episode?.id ?? widget.defaultEpisodeId ?? '';

  @override
  void initState() {
    super.initState();
    final epId = _episodeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (epId.isEmpty) return;
      final rating = context.read<RatingProvider>();
      final reviews = context.read<ReviewProvider>();
      rating.getEpisodeRating(epId);
      reviews.loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.9 - mediaQuery.viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + mediaQuery.viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.max,
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
                const Icon(Icons.reviews_rounded,
                    color: AppColors.bloodRed, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Reviews & Ratings', style: AppTextStyles.h3),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (widget.seriesTitle != null || widget.episode != null) ...[
              const SizedBox(height: 4),
              Text(
                _subtitle(),
                style: AppTextStyles.body3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            _ratingSummary(),
            const SizedBox(height: 12),
            if (_episodeId.isNotEmpty)
              ReviewInput(episodeId: _episodeId)
            else
              Text(
                'Select an episode to review.',
                style: AppTextStyles.body3,
              ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 8),
            if (_episodeId.isNotEmpty)
              Expanded(child: _reviewListSection())
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'No episode selected',
                    style: AppTextStyles.body3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (widget.seriesTitle != null) parts.add(widget.seriesTitle!);
    if (widget.episode != null) {
      parts.add('Episode ${widget.episode!.number}');
    }
    return parts.join(' · ');
  }

  Widget _ratingSummary() {
    if (_episodeId.isEmpty) {
      return const SizedBox.shrink();
    }
    final rating = context.watch<RatingProvider>();
    final summary = rating.summaryFor(_episodeId);
    if (summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.bloodRed,
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Text(
            summary.average.toStringAsFixed(1),
            style: AppTextStyles.display3.copyWith(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                StarRating(
                  averageRating: summary.average,
                  size: 18,
                  spacing: 2,
                  showNumeric: false,
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.count} ${summary.count == 1 ? 'rating' : 'ratings'}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          _distributionBar(summary.distribution),
        ],
      ),
    );
  }

  Widget _distributionBar(List<int> dist) {
    if (dist.length != 5) {
      return const SizedBox.shrink();
    }
    final total = dist.fold<int>(0, (a, b) => a + b);
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 5; i >= 1; i--)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$i',
                    style: AppTextStyles.caption.copyWith(fontSize: 9),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : dist[i - 1] / total,
                        minHeight: 4,
                        color: AppColors.bloodRed,
                        backgroundColor: AppColors.surfaceHover,
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

  Widget _reviewListSection() {
    final p = context.watch<ReviewProvider>();
    final count = p.countFor(_episodeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Text('Reviews', style: AppTextStyles.label),
              const SizedBox(width: 6),
              if (count > 0)
                Text(
                  '($count)',
                  style: AppTextStyles.caption,
                ),
              const Spacer(),
              if (p.errorMessage != null)
                Text(
                  'Failed to load',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error, fontSize: 10),
                ),
            ],
          ),
        ),
        Expanded(
          child: ReviewList(
            episodeId: _episodeId,
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        ),
      ],
    );
  }
}
