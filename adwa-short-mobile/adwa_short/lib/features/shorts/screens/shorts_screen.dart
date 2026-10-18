import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../../../models/short_item.dart';
import '../providers/shorts_provider.dart';
import '../widgets/episode_selector_sheet.dart';
import '../widgets/rating_sheet.dart';
import '../widgets/short_video_item.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({
    super.key,
    this.onBack,
    this.active = true,
    this.onWatchNow,
    this.onOpenSearch,
    this.onOpenSeries,
    this.onPlayEpisode,
  });

  final VoidCallback? onBack;
  final bool active;
  final void Function(String seriesId)? onWatchNow;
  final VoidCallback? onOpenSearch;
  final void Function(String seriesId)? onOpenSeries;
  final void Function(Series series, Episode episode)? onPlayEpisode;

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _pageController = PageController(
    initialPage: 0,
    viewportFraction: 1.0,
  );
  int _current = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ShortsProvider>();
      if (p.status == ShortsLoadStatus.idle) p.load();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _current = i);
    final p = context.read<ShortsProvider>();
    if (p.hasMore && i >= p.items.length - 3) {
      p.load();
    }
  }

  Future<void> _openCoins() async {
    await Navigator.of(context).pushNamed(AppRoutes.coinStore);
    if (!mounted) return;
    await _refreshAfterPayment();
  }

  Future<void> _openPasses() async {
    await Navigator.of(context).pushNamed(AppRoutes.passes);
    if (!mounted) return;
    await _refreshAfterPayment();
  }

  Future<void> _openSubscriptions() async {
    await Navigator.of(context).pushNamed(AppRoutes.subscriptions);
    if (!mounted) return;
    await _refreshAfterPayment();
  }

  Future<void> _refreshAfterPayment() async {
    final p = context.read<ShortsProvider>();
    await p.refresh();
  }

  void _openRating(ShortItem item) {
    RatingSheet.show(context, item: item);
  }

  void _openReviews(ShortItem item) {
    final episode = _toEpisode(item);
    ReviewBottomSheet.show(
      context,
      episode: episode,
      seriesTitle: item.seriesTitle,
      defaultEpisodeId: item.episodeId ?? item.id,
    );
  }

  void _openSearch() {
    widget.onOpenSearch?.call();
  }

  void _showShareToast(ShortItem item) {
    final url =
        'https://adwashort.app/series/${item.seriesId}/episode/${item.episodeId ?? item.id}';
    final text =
        '${item.seriesTitle ?? item.title} - EP.${item.episodeNumber ?? ''}\nWatch on ADWA SHORT: $url';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          'Link copied to clipboard',
          style: AppTextStyles.body3.copyWith(color: AppColors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEpisodesSheet(ShortItem item) {
    EpisodeSelectorSheet.show(
      context,
      seriesId: item.seriesId,
      currentEpisodeId: item.episodeId,
      currentEpisodeNumber: item.episodeNumber,
      onEpisodeSelected: (episode) => _playEpisodeInFeed(item, episode),
    );
  }

  void _playEpisodeInFeed(ShortItem current, Episode episode) {
    final videoUrl = episode.videoUrl;
    context.read<ShortsProvider>().replaceItem(
      _current,
      current.copyWith(
        id: episode.id,
        episodeId: episode.id,
        title: episode.title.isNotEmpty ? episode.title : current.title,
        verticalVideoUrl: (videoUrl != null && videoUrl.isNotEmpty)
            ? videoUrl
            : current.verticalVideoUrl,
        description: episode.description.isNotEmpty
            ? episode.description
            : current.description,
        episodeNumber: episode.number,
        thumbnailUrl: episode.thumbnailUrl ?? current.thumbnailUrl,
        isAccessible: episode.effectivelyAccessible,
        accessReason: episode.accessReason ?? current.accessReason,
        averageRating: episode.averageRating ?? current.averageRating,
        ratingCount: episode.ratingCount ?? current.ratingCount,
      ),
    );
  }

  void _watchFull(ShortItem item) {
    final episode = _toEpisode(item);
    if (episode == null || widget.onPlayEpisode == null) return;
    final series = Series(
      id: item.seriesId,
      title: item.seriesTitle ?? item.title,
      description: item.description,
      posterUrl: item.thumbnailUrl,
      totalEpisodes: item.totalEpisodes,
      episodes: [episode],
    );
    widget.onPlayEpisode!(series, episode);
  }

  Episode? _toEpisode(ShortItem item) {
    if (item.episodeId == null && item.id.isEmpty) return null;
    return Episode(
      id: item.episodeId ?? item.id,
      seriesId: item.seriesId,
      number: item.episodeNumber ?? 0,
      title: item.title,
      description: item.description,
      thumbnailUrl: item.thumbnailUrl,
      videoUrl: item.verticalVideoUrl,
      durationSeconds: item.durationSeconds,
      averageRating: item.averageRating,
      ratingCount: item.ratingCount,
      isAccessible: item.isAccessible,
      accessReason: item.accessReason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShortsProvider>();
    return ColoredBox(color: AppColors.black, child: _body(p));
  }

  Widget _body(ShortsProvider p) {
    switch (p.status) {
      case ShortsLoadStatus.idle:
      case ShortsLoadStatus.loading:
        return const Center(
          child: LoadingShimmer(width: 60, height: 60, borderRadius: 30),
        );
      case ShortsLoadStatus.error:
        if (p.items.isEmpty) {
          return ErrorView(
            message: p.errorMessage ?? 'Failed to load shorts',
            onRetry: () => p.load(),
          );
        }
        break;
      case ShortsLoadStatus.loadingMore:
      case ShortsLoadStatus.success:
        break;
    }
    if (p.items.isEmpty) {
      return EmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'No shorts available right now',
        message: 'Pull down to refresh',
        actionLabel: 'Refresh',
        onAction: () => p.refresh(),
      );
    }
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: p.items.length + (p.hasMore ? 1 : 0),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) {
        if (i >= p.items.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => p.load());
          return const Center(
            child: LoadingShimmer(width: 40, height: 40, borderRadius: 20),
          );
        }
        final item = p.items[i];
        if (!widget.active || i != _current) {
          return Container(color: AppColors.black);
        }
        return ShortVideoItem(
          item: item,
          totalEpisodes: item.totalEpisodes,
          isAccessible: item.isAccessible,
          accessReason: item.accessReason,
          onSave: () => p.toggleSave(i),
          onShowEpisodes: () => _showEpisodesSheet(item),
          onRate: () => _openRating(item),
          onReviews: () => _openReviews(item),
          onShare: () => _showShareToast(item),
          onSearch: _openSearch,
          onWatchFull: () => _watchFull(item),
          onBuyCoins: _openCoins,
          onBuyPass: _openPasses,
          onSubscribe: _openSubscriptions,
          onMaybeLater: () {
            if (_current < p.items.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            }
          },
        );
      },
    );
  }
}
