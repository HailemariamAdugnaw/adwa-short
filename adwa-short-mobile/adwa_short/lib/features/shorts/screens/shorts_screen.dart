import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../features/profile/providers/wallet_provider.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../features/series/providers/series_provider.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../../../models/short_item.dart';
import '../providers/shorts_provider.dart';
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
  final void Function(Series series, Episode episode,
      {bool openEpisodesSheet})? onPlayEpisode;

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

  Future<void> _handleCoinUnlock(ShortItem item, int index) async {
    final walletProvider = context.read<WalletProvider>();
    final seriesProvider = context.read<SeriesProvider>();
    final shortsProvider = context.read<ShortsProvider>();

    if (walletProvider.wallet == null) {
      await walletProvider.loadWallet();
    }

    final currentCoins = walletProvider.wallet?.balanceCoins.toInt() ?? 0;
    final requiredCoins = item.coinCost > 0 ? item.coinCost : 10;
    final epId = item.episodeId ?? item.id;

    if (!mounted) return;

    if (currentCoins < requiredCoins) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.monetization_on_outlined, color: AppColors.bloodRed, size: 24),
              const SizedBox(width: 8),
              Text('Insufficient Coins', style: AppTextStyles.h3),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You need $requiredCoins coins to unlock ${item.title}.',
                style: AppTextStyles.body1,
              ),
              const SizedBox(height: 8),
              Text(
                'Current Balance: $currentCoins coins\nNeeded: ${requiredCoins - currentCoins} more coins',
                style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary)),
            ),
            AdwaButton(
              label: 'Buy Coins',
              size: AdwaButtonSize.sm,
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamed(AppRoutes.coinStore).then((_) {
                  walletProvider.loadWallet(refresh: true);
                });
              },
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppColors.bloodRed, size: 24),
            const SizedBox(width: 8),
            Text('Unlock Episode', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Unlock ${item.title} for $requiredCoins coins?\n\n'
          'Current Balance: $currentCoins coins\n'
          'Balance After: ${currentCoins - requiredCoins} coins',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary)),
          ),
          AdwaButton(
            label: 'Unlock ($requiredCoins Coins)',
            size: AdwaButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await seriesProvider.unlockWithCoinsDetailed(
      episodeId: epId,
      coinCost: requiredCoins,
    );

    if (res.success && mounted) {
      if (res.newBalanceCoins != null) {
        walletProvider.setCoinBalance(res.newBalanceCoins!);
      } else {
        walletProvider.deductCoins(res.coinsDeducted);
      }

      shortsProvider.markAccessible(index);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message ?? '${item.title} unlocked! ${res.coinsDeducted} coins deducted.',
            style: AppTextStyles.body3.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to unlock episode with coins. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
    final episode = _toEpisode(item);
    if (episode == null || widget.onPlayEpisode == null) return;
    final series = _toSeries(item, episode);
    widget.onPlayEpisode!(series, episode, openEpisodesSheet: true);
  }

  Series _toSeries(ShortItem item, Episode episode) {
    return Series(
      id: item.seriesId,
      title: item.seriesTitle ?? item.title,
      description: item.description,
      posterUrl: item.thumbnailUrl,
      totalEpisodes: item.totalEpisodes,
      episodes: [episode],
    );
  }

  void _watchFull(ShortItem item) {
    final episode = _toEpisode(item);
    if (episode == null || widget.onPlayEpisode == null) return;
    final series = _toSeries(item, episode);
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
          onUnlockAds: () async {
            final adService = context.read<AdService>();
            final ok = await adService.showRewardedAd(
              context,
              episodeId: item.episodeId ?? item.id,
              episodeTitle: item.title,
            );
            if (ok && mounted) {
              p.markAccessible(i);
              setState(() {});
            }
          },
          onBuyCoins: () => _handleCoinUnlock(item, i),
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
