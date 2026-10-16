import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/star_rating.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../models/short_item.dart';

class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key, required this.item, this.onRate});

  final ShortItem item;
  final void Function(int rating)? onRate;

  static Future<void> show(
    BuildContext context, {
    required ShortItem item,
    void Function(int rating)? onRate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RatingSheet(item: item, onRate: onRate),
    );
  }

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
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
