import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../models/episode.dart';
import '../../../models/short_item.dart';
import '../providers/shorts_provider.dart';
import '../widgets/short_video_item.dart';

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({
    super.key,
    this.onWatchNow,
  });

  final void Function(String seriesId)? onWatchNow;

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _pageController =
      PageController(initialPage: 0, viewportFraction: 1.0);
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

  void _openReviews(ShortItem item) {
    final episode = _toEpisode(item);
    ReviewBottomSheet.show(
      context,
      episode: episode,
      seriesTitle: item.seriesTitle,
      defaultEpisodeId: item.episodeId ?? item.id,
    );
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
      averageRating: item.averageRating,
      ratingCount: item.ratingCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShortsProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: _body(p),
      ),
    );
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
        return ShortVideoItem(
          item: item,
          active: i == _current,
          isAccessible: item.isAccessible,
          accessReason: item.accessReason,
          onSave: () => p.toggleSave(i),
          onShowEpisodes: () => _showEpisodesSheet(item),
          onShowReviews: () => _openReviews(item),
          onWatchNow: () {
            if (widget.onWatchNow != null) {
              widget.onWatchNow!(item.seriesId);
            }
          },
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

  void _showEpisodesSheet(ShortItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Episodes', style: AppTextStyles.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.bloodRed),
              title: Text(item.title, style: AppTextStyles.body1),
              subtitle: Text(
                'Open series page to see all episodes',
                style: AppTextStyles.body3,
              ),
              onTap: () {
                Navigator.of(context).pop();
                if (widget.onWatchNow != null) {
                  widget.onWatchNow!(item.seriesId);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
