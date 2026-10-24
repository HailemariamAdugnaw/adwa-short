import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/star_rating.dart';
import '../../../models/review.dart';
import '../providers/review_provider.dart';
import 'review_input.dart';

class ReviewList extends StatefulWidget {
  const ReviewList({
    super.key,
    required this.episodeId,
    this.shrinkWrap = false,
    this.physics,
  });

  final String episodeId;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  final ScrollController _controller = ScrollController();
  bool _initialRequested = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    final episodeId = widget.episodeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_initialRequested) return;
      _initialRequested = true;
      final p = context.read<ReviewProvider>();
      if (p.reviewsFor(episodeId).isEmpty) {
        p.getEpisodeReviews(episodeId, reset: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final maxScroll = _controller.position.maxScrollExtent;
    final currentScroll = _controller.position.pixels;
    if (maxScroll - currentScroll < 200) {
      final p = context.read<ReviewProvider>();
      if (p.hasMoreFor(widget.episodeId) && !p.isLoading(widget.episodeId)) {
        p.getEpisodeReviews(widget.episodeId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReviewProvider>();
    final reviews = p.reviewsFor(widget.episodeId);
    final loading = p.isLoading(widget.episodeId);
    final hasMore = p.hasMoreFor(widget.episodeId);
    if (reviews.isEmpty && loading) {
      return ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LoadingShimmer(height: 88, borderRadius: 12),
        ),
      );
    }
    if (reviews.isEmpty) {
      return EmptyState(
        icon: Icons.reviews_outlined,
        title: 'No reviews yet',
        message: 'Be the first to review!',
        compact: true,
      );
    }
    return ListView.separated(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: reviews.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.divider, height: 1, indent: 56),
      itemBuilder: (_, i) {
        if (i >= reviews.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
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
        return _reviewTile(reviews[i]);
      },
    );
  }

  Widget _reviewTile(Review review) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          reviewAvatar(review.userAvatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        review.userName,
                        style: AppTextStyles.body1.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.date(review.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                if (review.rating != null) ...[
                  const SizedBox(height: 4),
                  StarRating(
                    currentRating: review.rating ?? 0,
                    size: 14,
                    spacing: 1,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  review.text,
                  style: AppTextStyles.body2.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
