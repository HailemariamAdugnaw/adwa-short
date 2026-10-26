import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/star_rating.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../features/profile/providers/wallet_provider.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../features/reviews/providers/review_provider.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../providers/series_provider.dart';
import '../widgets/access_gate_dialog.dart';
import '../widgets/cast_list.dart';
import '../widgets/episode_list_tile.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    this.onPlayEpisode,
    this.onOpenWallet,
    this.onOpenPasses,
    this.onOpenSubscriptions,
  });

  final String seriesId;
  final void Function(Series series, Episode episode)? onPlayEpisode;
  final VoidCallback? onOpenWallet;
  final VoidCallback? onOpenPasses;
  final VoidCallback? onOpenSubscriptions;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  String? _ratingsLoadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SeriesProvider>().load(widget.seriesId);
    });
  }

  void _maybeLoadRatings(Episode? firstEp) {
    if (firstEp == null) return;
    if (_ratingsLoadedFor == firstEp.id) return;
    _ratingsLoadedFor = firstEp.id;
    final rating = context.read<RatingProvider>();
    final reviews = context.read<ReviewProvider>();
    final episodeId = firstEp.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rating.getEpisodeRating(episodeId);
      reviews.getEpisodeReviews(episodeId, reset: true);
      reviews.loadSettings();
    });
  }

  Episode? _firstEpisode(Series s) =>
      s.episodes.isNotEmpty ? s.episodes.first : null;

  Future<void> _onEpisodeTap(Episode episode) async {
    final provider = context.read<SeriesProvider>();
    final series = provider.series;
    if (series == null) return;

    if (episode.isFree || episode.accessible || episode.effectivelyAccessible) {
      widget.onPlayEpisode?.call(series, episode);
      return;
    }

    try {
      final check = await provider.accessCheck(episode.id);
      if (check.accessible) {
        widget.onPlayEpisode?.call(series, episode);
        return;
      }
      if (!mounted) return;
      await AccessGateDialog.show(
        context,
        episode: episode,
        accessCheck: check,
        onWatchAd: () async {
          final adService = context.read<AdService>();
          final ok = await adService.showRewardedAd(
            context,
            episodeId: episode.id,
            episodeTitle: 'Episode ${episode.number} · ${episode.title}',
          );
          if (ok) {
            await provider.refreshAfterUnlock();
            if (mounted) {
              widget.onPlayEpisode?.call(series, episode);
            }
          }
          return ok;
        },
        onPayWithCoins: () async {
          final walletProvider = context.read<WalletProvider>();
          final cost = check.coinCost ?? episode.coinCost ?? 10;
          final res = await provider.unlockWithCoinsDetailed(
            episodeId: episode.id,
            coinCost: cost,
          );
          if (res.success) {
            if (res.newBalanceCoins != null) {
              walletProvider.setCoinBalance(res.newBalanceCoins!);
            } else {
              walletProvider.deductCoins(res.coinsDeducted);
            }
            await provider.refreshAfterUnlock();
            return true;
          }
          return false;
        },
        onBuyPass: widget.onOpenPasses,
        onSubscribe: widget.onOpenSubscriptions,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check access: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openReviews(Series series) {
    final ep = _firstEpisode(series);
    ReviewBottomSheet.show(
      context,
      episode: ep,
      seriesTitle: series.title,
      defaultEpisodeId: ep?.id ?? widget.seriesId,
    );
  }

  Future<void> _onRateSeries(Series series, int rating) async {
    final ep = _firstEpisode(series);
    if (ep == null) return;
    await context.read<RatingProvider>().rateEpisode(ep.id, rating);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SeriesProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: _body(provider),
      ),
    );
  }

  Widget _body(SeriesProvider provider) {
    switch (provider.status) {
      case SeriesDetailStatus.idle:
      case SeriesDetailStatus.loading:
        return _loadingView();
      case SeriesDetailStatus.error:
        return ErrorView(
          message: provider.errorMessage ?? 'Failed to load series',
          onRetry: () => provider.load(widget.seriesId),
        );
      case SeriesDetailStatus.success:
        final s = provider.series!;
        return _content(s, provider);
    }
  }

  Widget _loadingView() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const LoadingShimmer(
          width: double.infinity,
          height: 240,
          borderRadius: 0,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoadingShimmer(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 22,
              borderRadius: 6),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: LoadingShimmer(
              width: double.infinity, height: 60, borderRadius: 8),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          5,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LoadingShimmer(
                width: double.infinity, height: 66, borderRadius: 10),
          ),
        ),
      ],
    );
  }

  Widget _content(Series series, SeriesProvider provider) {
    final rating = context.watch<RatingProvider>();
    final reviews = context.watch<ReviewProvider>();
    final firstEp = _firstEpisode(series);
    final summary =
        firstEp != null ? rating.summaryFor(firstEp.id) : null;
    final userRating = firstEp != null ? rating.userRatingFor(firstEp.id) : 0;
    final avg = series.averageRating ?? summary?.average;
    final ratingCount = series.ratingCount ?? summary?.count;
    final reviewCount = series.reviewCount ??
        (firstEp != null ? reviews.countFor(firstEp.id) : null) ??
        0;

    _maybeLoadRatings(firstEp);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner(series, provider, avg, ratingCount)),
        SliverToBoxAdapter(child: _info(series)),
        SliverToBoxAdapter(child: _ratingSection(
          series: series,
          avg: avg,
          ratingCount: ratingCount,
          reviewCount: reviewCount,
          userRating: userRating,
        )),
        if (series.cast.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: CastList(cast: series.cast),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('Episodes', style: AppTextStyles.h3),
                const SizedBox(width: 8),
                Text(
                  '(${series.episodes.length})',
                  style: AppTextStyles.body3,
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: series.episodes.length,
          itemBuilder: (_, i) {
            final ep = series.episodes[i];
            return Column(
              children: [
                EpisodeListTile(
                  episode: ep,
                  index: i,
                  onTap: () => _onEpisodeTap(ep),
                ),
                if (i != series.episodes.length - 1)
                  const Divider(color: AppColors.divider, height: 1, indent: 16, endIndent: 16),
              ],
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _banner(
      Series series, SeriesProvider provider, double? avg, int? ratingCount) {
    final resolved =
        ApiClient.resolveMediaUrl(series.bannerUrl ?? series.posterUrl);
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: resolved.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const LoadingShimmer(borderRadius: 0),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.surfaceElevated),
                )
              : Container(color: AppColors.surfaceElevated),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined,
                    color: AppColors.white),
                onPressed: () async {
                  if (series.episodes.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No episodes available to save'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  final ok = await provider.toggleSave(
                    episodeId: series.episodes.first.id,
                    currentlySaved: false,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Saved to your list'
                          : 'Could not save series'),
                      backgroundColor:
                          ok ? AppColors.success : AppColors.error,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined,
                    color: AppColors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (series.isHot) const TagChip.hot(),
                  if (series.isVip) const TagChip.vip(),
                  if (series.isExclusive) const TagChip.exclusive(),
                  if (series.isNewRelease) const TagChip.newRelease(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                series.title,
                style: AppTextStyles.display3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (series.creatorName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'by ${series.creatorName}',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (series.totalEpisodes > 0)
                    Text(
                      '${series.episodes.length}/${series.totalEpisodes} Episodes',
                      style: AppTextStyles.caption,
                    ),
                  if (series.totalEpisodes > 0 &&
                      series.freeEpisodeCount > 0) ...[
                    const SizedBox(width: 8),
                    Text('· ${series.freeEpisodeCount} Free',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.success)),
                  ],
                  if (avg != null) ...[
                    const SizedBox(width: 8),
                    StarRating(
                      averageRating: avg,
                      size: 14,
                      spacing: 1,
                      showNumeric: true,
                      ratingCount: ratingCount,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _info(Series series) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (series.description.isNotEmpty)
            Text(
              series.description,
              style: AppTextStyles.body2,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          if (series.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: series.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Text(
                          '# $t',
                          style: AppTextStyles.caption,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratingSection({
    required Series series,
    required double? avg,
    required int? ratingCount,
    required int reviewCount,
    required int userRating,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bloodRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rate this series',
                    style: AppTextStyles.h4,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openReviews(series),
                  icon: const Icon(Icons.reviews_outlined,
                      color: AppColors.bloodRed, size: 18),
                  label: Text(
                    'Reviews${reviewCount > 0 ? ' ($reviewCount)' : ''}',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.bloodRed),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  avg != null ? avg.toStringAsFixed(1) : '—',
                  style: AppTextStyles.display3.copyWith(fontSize: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StarRating(
                        averageRating: avg,
                        size: 16,
                        spacing: 2,
                        showNumeric: true,
                        ratingCount: ratingCount,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ratingCount ?? 0} ${ratingCount == 1 ? 'rating' : 'ratings'} · $reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            Text(
              userRating > 0
                  ? 'Your rating: $userRating star${userRating == 1 ? '' : 's'}'
                  : 'Tap a star to rate',
              style: AppTextStyles.body3,
            ),
            const SizedBox(height: 8),
            Center(
              child: StarRating(
                currentRating: userRating,
                interactive: true,
                size: 36,
                onRatingChanged: (v) => _onRateSeries(series, v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
