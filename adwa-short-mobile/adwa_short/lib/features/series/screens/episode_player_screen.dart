import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/token_manager.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../core/widgets/smooth_video_snap_scroll_physics.dart';
import '../../../core/widgets/unified_video_player.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/downloads/providers/download_provider.dart';
import '../../../features/profile/providers/wallet_provider.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../features/reviews/providers/review_provider.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../features/series/providers/series_provider.dart';
import '../../../features/shorts/widgets/episode_selector_sheet.dart';
import '../../../features/shorts/widgets/paywall_overlay.dart';
import '../../../features/shorts/widgets/rating_sheet.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../../../models/short_item.dart';

class EpisodePlayerScreen extends StatefulWidget {
  const EpisodePlayerScreen({
    super.key,
    required this.series,
    required this.episode,
    this.onNextEpisode,
    this.openEpisodesSheet = false,
  });

  final Series series;
  final Episode episode;
  final Episode? Function(Series series, Episode current)? onNextEpisode;
  final bool openEpisodesSheet;

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen> {
  Timer? _engagementTimer;
  int _watchSeconds = 0;
  bool _completionSent = false;
  bool _isPlaying = false;
  bool _ratingsRequested = false;
  bool _isSaved = false;
  late Episode _currentEpisode;
  bool _handlingDownload = false;
  PageController? _pageController;

  List<Episode> _getEpisodes(Series? providerSeries) {
    if (providerSeries != null &&
        (providerSeries.id == widget.series.id || widget.series.id.isEmpty) &&
        providerSeries.episodes.isNotEmpty) {
      return providerSeries.episodes;
    }
    if (widget.series.episodes.isNotEmpty) {
      return widget.series.episodes;
    }
    return [_currentEpisode];
  }

  int _getEpisodeIndex(List<Episode> episodes, Episode current) {
    if (episodes.isEmpty) return 0;
    for (int i = 0; i < episodes.length; i++) {
      if (episodes[i].id == current.id) return i;
    }
    final curIdInt = int.tryParse(current.id);
    if (curIdInt != null) {
      for (int i = 0; i < episodes.length; i++) {
        if (int.tryParse(episodes[i].id) == curIdInt) return i;
      }
    }
    if (current.number > 0) {
      for (int i = 0; i < episodes.length; i++) {
        if (episodes[i].number == current.number) return i;
      }
    }
    return 0;
  }

  int _getTotalEpisodes(Series? providerSeries, List<Episode> episodes) {
    int total = 0;
    if (providerSeries != null &&
        (providerSeries.id == widget.series.id || widget.series.id.isEmpty)) {
      total = providerSeries.totalEpisodes;
      if (providerSeries.episodes.length > total) {
        total = providerSeries.episodes.length;
      }
    }
    if (total <= 0) {
      total = widget.series.totalEpisodes;
      if (widget.series.episodes.length > total) {
        total = widget.series.episodes.length;
      }
    }
    if (episodes.length > total) {
      total = episodes.length;
    }
    return total > 0 ? total : episodes.length;
  }

  int _calculateInitialIndex(Episode episode, Series series,
      [List<Episode>? fullEpisodes]) {
    final list = (fullEpisodes != null && fullEpisodes.isNotEmpty)
        ? fullEpisodes
        : series.episodes;
    return _getEpisodeIndex(list, episode);
  }

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    final initialProviderSeries = context.read<SeriesProvider>().series;
    final initialEpisodes = _getEpisodes(initialProviderSeries);
    final initialIndex = _calculateInitialIndex(
      widget.episode,
      widget.series,
      initialEpisodes,
    );
    _pageController = PageController(initialPage: initialIndex);
    final episodeId = _currentEpisode.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<SeriesProvider>().load(widget.series.id);
      if (!mounted) return;
      final loadedSeries = context.read<SeriesProvider>().series;
      if (loadedSeries != null &&
          (loadedSeries.id == widget.series.id || widget.series.id.isEmpty) &&
          loadedSeries.episodes.isNotEmpty) {
        final targetIdx = _getEpisodeIndex(
          loadedSeries.episodes,
          _currentEpisode,
        );
        if (targetIdx >= 0 && targetIdx < loadedSeries.episodes.length) {
          final matchedEp = loadedSeries.episodes[targetIdx];
          if (mounted) {
            setState(() {
              _currentEpisode = matchedEp;
            });
          }
        }
        if (_pageController != null && _pageController!.hasClients) {
          if (_pageController!.page?.round() != targetIdx) {
            _pageController!.jumpToPage(targetIdx);
          }
        }
      }
      _verifyServerAccess(_currentEpisode);
      if (!_ratingsRequested) {
        _ratingsRequested = true;
        context.read<RatingProvider>().getEpisodeRating(_currentEpisode.id);
        context.read<ReviewProvider>().getEpisodeReviews(_currentEpisode.id, reset: true);
        context.read<ReviewProvider>().loadSettings();
      }
      if (widget.openEpisodesSheet) {
        _openEpisodes();
      }
    });
    _startEngagementTimer();
  }

  void _goToNextEpisode([int? count]) {
    if (_pageController == null || !_pageController!.hasClients) return;
    final maxCount = count ??
        _getEpisodes(context.read<SeriesProvider>().series).length;
    final current = _pageController!.page?.round() ??
        _getEpisodeIndex(
          _getEpisodes(context.read<SeriesProvider>().series),
          _currentEpisode,
        );
    final target = current + 1;
    if (target < maxCount) {
      _pageController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToPreviousEpisode() {
    if (_pageController == null || !_pageController!.hasClients) return;
    final current = _pageController!.page?.round() ??
        _getEpisodeIndex(
          _getEpisodes(context.read<SeriesProvider>().series),
          _currentEpisode,
        );
    final target = current - 1;
    if (target >= 0) {
      _pageController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _engagementTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _startEngagementTimer() {
    _engagementTimer?.cancel();
    _engagementTimer =
        Timer.periodic(AppConstants.engagementPingInterval, (_) {
      if (!_isPlaying) return;
      _watchSeconds += AppConstants.engagementPingInterval.inSeconds;
      _sendViewPing(completed: false);
    });
  }

  Future<void> _sendViewPing({required bool completed}) async {
    await context.read<SeriesProvider>().pingView(
          episodeId: _currentEpisode.id,
          watchTimeSeconds: _watchSeconds,
          completed: completed,
        );
  }

  void _onPlayingChanged(bool isPlaying) {
    _isPlaying = isPlaying;
  }

  void _onCompleted() {
    if (_completionSent) return;
    _completionSent = true;
    _sendViewPing(completed: true);
    _goToNextEpisode();
  }

  void _openRating() {
    RatingSheet.show(context, item: _toShortItem());
  }

  void _openEpisodes() {
    final providerSeries = context.read<SeriesProvider>().series;
    final episodesList = _getEpisodes(providerSeries);
    final currentIdx = _getEpisodeIndex(episodesList, _currentEpisode);
    final epNum = _currentEpisode.number > 0 ? _currentEpisode.number : currentIdx + 1;

    EpisodeSelectorSheet.show(
      context,
      seriesId: widget.series.id,
      currentEpisodeId: _currentEpisode.id,
      currentEpisodeNumber: epNum,
      initialSeries: (providerSeries != null &&
              (providerSeries.id == widget.series.id || widget.series.id.isEmpty))
          ? providerSeries
          : widget.series,
      onEpisodeSelected: (ep) => _onEpisodeSelected(ep),
    );
  }

  void _onPageChanged(int index) {
    final providerSeries = context.read<SeriesProvider>().series;
    final list = _getEpisodes(providerSeries);
    if (index < 0 || index >= list.length) return;
    final ep = list[index];
    if (ep.id == _currentEpisode.id && ep.number == _currentEpisode.number) return;

    _engagementTimer?.cancel();
    _watchSeconds = 0;
    _completionSent = false;
    _isPlaying = false;
    _ratingsRequested = false;

    setState(() {
      _currentEpisode = ep;
    });

    final episodeId = ep.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _verifyServerAccess(ep);
      if (!_ratingsRequested) {
        _ratingsRequested = true;
        context.read<RatingProvider>().getEpisodeRating(episodeId);
        context.read<ReviewProvider>().getEpisodeReviews(episodeId, reset: true);
      }
    });
    _startEngagementTimer();
  }

  void _onEpisodeSelected(Episode ep) {
    if (!mounted) return;
    final providerSeries = context.read<SeriesProvider>().series;
    final episodesList = _getEpisodes(providerSeries);
    final targetIndex = _getEpisodeIndex(episodesList, ep);

    final resolvedEp = (targetIndex >= 0 && targetIndex < episodesList.length)
        ? episodesList[targetIndex]
        : ep;

    _engagementTimer?.cancel();
    _watchSeconds = 0;
    _completionSent = false;
    _isPlaying = false;
    _ratingsRequested = false;

    setState(() {
      _currentEpisode = resolvedEp;
    });

    if (_pageController != null && _pageController!.hasClients) {
      if (_pageController!.page?.round() != targetIndex) {
        _pageController!.jumpToPage(targetIndex);
      }
    }

    final episodeId = resolvedEp.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _verifyServerAccess(resolvedEp);
      if (!_ratingsRequested) {
        _ratingsRequested = true;
        context.read<RatingProvider>().getEpisodeRating(episodeId);
        context.read<ReviewProvider>().getEpisodeReviews(episodeId, reset: true);
      }
    });
    _startEngagementTimer();
  }

  Future<void> _verifyServerAccess(Episode ep) async {
    if (ep.isFree) return;
    try {
      final wallet = context.read<WalletProvider>();
      final check = await context.read<SeriesProvider>().accessCheck(ep.id);
      if (!mounted) return;
      final bool serverUnlocked = check.accessible || wallet.hasActiveAccess;
      if (_currentEpisode.id == ep.id) {
        setState(() {
          _currentEpisode = _currentEpisode.copyWith(
            isLocked: !serverUnlocked,
            accessible: serverUnlocked,
            isAccessible: serverUnlocked,
            accessReason: check.reason.name,
          );
        });
        if (serverUnlocked) {
          _checkAccessAndPlay();
        }
      }
    } catch (_) {
      final wallet = context.read<WalletProvider>();
      if (wallet.hasActiveAccess && _currentEpisode.id == ep.id) {
        setState(() {
          _currentEpisode = _currentEpisode.copyWith(
            isLocked: false,
            accessible: true,
            isAccessible: true,
          );
        });
        _checkAccessAndPlay();
      }
    }
  }

  void _openReviews() {
    ReviewBottomSheet.show(
      context,
      episode: _currentEpisode,
      seriesTitle: widget.series.title,
      defaultEpisodeId: _currentEpisode.id,
    );
  }

  Future<void> _toggleSave() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final loggedIn = await GuestAuthPrompt.show(
        context,
        title: 'Sign In to Save',
        message:
            'Please sign in or register to save series and episodes to your list.',
      );
      if (!loggedIn || !mounted) return;
    }

    final provider = context.read<SeriesProvider>();
    final wasSaved = _isSaved;
    final ok = await provider.toggleSave(
      episodeId: _currentEpisode.id,
      currentlySaved: wasSaved,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _isSaved = !wasSaved);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            _isSaved ? 'Saved to My List' : 'Removed from My List',
            style: AppTextStyles.body3.copyWith(color: AppColors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareEpisode() {
    final epNum = _currentEpisode.number > 0 ? _currentEpisode.number : 1;
    final url =
        'https://adwashort.app/series/${widget.series.id}/episode/${_currentEpisode.id}';
    final text =
        '${widget.series.title} - EP.$epNum\nWatch on ADWA SHORT: $url';
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

  ShortItem _toShortItem() {
    final providerSeries = context.read<SeriesProvider>().series;
    final episodesList = _getEpisodes(providerSeries);
    final currentIdx = _getEpisodeIndex(episodesList, _currentEpisode);
    final epNum = _currentEpisode.number > 0 ? _currentEpisode.number : currentIdx + 1;
    final totalEps = _getTotalEpisodes(providerSeries, episodesList);

    return ShortItem(
      id: _currentEpisode.id,
      seriesId: widget.series.id,
      episodeId: _currentEpisode.id,
      title: _currentEpisode.title,
      verticalVideoUrl: _currentEpisode.videoUrl ?? '',
      description: _currentEpisode.description,
      tags: widget.series.tags,
      isAccessible: _currentEpisode.effectivelyAccessible,
      accessReason: _currentEpisode.accessReason,
      episodeNumber: epNum,
      seriesTitle: widget.series.title,
      totalEpisodes: totalEps,
      averageRating: _currentEpisode.averageRating,
      ratingCount: _currentEpisode.ratingCount,
      thumbnailUrl: _currentEpisode.thumbnailUrl,
      isSaved: _isSaved,
      coinCost: context.read<SeriesProvider>().resolveCoinCost(
        episode: _currentEpisode,
        series: widget.series,
      ),
    );
  }

  Future<void> _onDownload() async {
    if (_handlingDownload) return;
    final epId = int.tryParse(_currentEpisode.id);
    if (epId == null) return;
    final provider = context.read<DownloadProvider>();
    if (provider.isDownloading) return;
    if (provider.isDownloaded(epId)) {
      _showSnack('Already downloaded', AppColors.success);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final loggedIn = await GuestAuthPrompt.show(
        context,
        title: 'Sign In to Download',
        message:
            'Please sign in or register to download episodes for offline viewing.',
      );
      if (!loggedIn || !mounted) return;
    }
    if (!_currentEpisode.effectivelyAccessible) {
      _showPaywall();
      return;
    }
    final tokenManager = context.read<TokenManager>();
    final authToken = tokenManager.accessToken;
    if (authToken == null || authToken.isEmpty) {
      _showSnack('Please log in to download', AppColors.error);
      return;
    }
    _handlingDownload = true;
    try {
      final ok = await provider.downloadEpisode(
        _currentEpisode,
        widget.series,
        authToken,
      );
      if (!mounted) return;
      if (ok) {
        _showSnack('Downloaded', AppColors.success);
      } else if (provider.status == DownloadStatus.accessDenied) {
        _showPaywall();
        provider.resetStatus();
      } else {
        _showSnack(
          provider.errorMessage.isNotEmpty
              ? provider.errorMessage
              : 'Download failed',
          AppColors.error,
        );
        provider.resetStatus();
      }
    } finally {
      _handlingDownload = false;
    }
  }

  void _showSnack(String message, Color background) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: background,
        content: Text(
          message,
          style: AppTextStyles.body3.copyWith(color: AppColors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkAccessAndPlay() async {
    final provider = context.read<SeriesProvider>();
    await provider.refreshAfterUnlock();
    if (!mounted) return;
    final updatedSeries = provider.series;
    if (updatedSeries != null) {
      final updatedList = _getEpisodes(updatedSeries);
      for (final ep in updatedList) {
        if (ep.id == _currentEpisode.id) {
          setState(() {
            _currentEpisode = ep;
          });
          break;
        }
      }
    }
  }

  Future<void> _handleCoinUnlock(BuildContext innerContext) async {
    final auth = innerContext.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final loggedIn = await GuestAuthPrompt.show(
        innerContext,
        title: 'Sign In to Unlock',
        message:
            'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
      );
      if (!loggedIn || !innerContext.mounted) return;
      await innerContext.read<WalletProvider>().loadWallet(refresh: true);
      await innerContext.read<WalletProvider>().loadAccessDashboard(refresh: true);
    }

    final walletProvider = innerContext.read<WalletProvider>();
    final seriesProvider = innerContext.read<SeriesProvider>();

    if (walletProvider.wallet == null) {
      await walletProvider.loadWallet();
    }

    final currentCoins = walletProvider.wallet?.balanceCoins.toInt() ?? 0;
    final requiredCoins = seriesProvider.resolveCoinCost(
      episode: _currentEpisode,
      series: widget.series,
    );

    if (!innerContext.mounted) return;

    if (currentCoins < requiredCoins) {
      await showDialog<void>(
        context: innerContext,
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
                'You need $requiredCoins coins to unlock Episode ${_currentEpisode.number}.',
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
                Navigator.of(innerContext).pushNamed(AppRoutes.coinStore).then((_) {
                  walletProvider.loadWallet(refresh: true);
                });
              },
            ),
          ],
        ),
      );
      return;
    }

    // User has sufficient coins: show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: innerContext,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deduct $requiredCoins coins to unlock this episode?',
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Episode: Episode ${_currentEpisode.number} · ${_currentEpisode.title}',
              style: AppTextStyles.body3.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Current Balance: $currentCoins coins\nBalance After: ${currentCoins - requiredCoins} coins',
              style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.body3.copyWith(color: AppColors.textSecondary)),
          ),
          AdwaButton(
            label: 'Confirm Unlock',
            size: AdwaButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !innerContext.mounted) return;

    final res = await seriesProvider.unlockWithCoinsDetailed(
      episodeId: _currentEpisode.id,
      coinCost: requiredCoins,
    );

    if (res.success && innerContext.mounted) {
      if (res.newBalanceCoins != null) {
        walletProvider.setCoinBalance(res.newBalanceCoins!);
      } else {
        walletProvider.deductCoins(res.coinsDeducted);
      }

      Navigator.of(innerContext).maybePop(); // dismiss paywall

      setState(() {
        _currentEpisode = _currentEpisode.copyWith(
          isFree: false,
          isLocked: false,
          accessible: true,
          isAccessible: true,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message ?? 'Episode ${_currentEpisode.number} unlocked! ${res.coinsDeducted} coins deducted.',
            style: AppTextStyles.body3.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 2),
        ),
      );

      _checkAccessAndPlay();
    } else if (innerContext.mounted) {
      ScaffoldMessenger.of(innerContext).showSnackBar(
        const SnackBar(
          content: Text('Failed to unlock episode with coins. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showPaywall() {
    if (!mounted) return;
    final wallet = context.read<WalletProvider>();
    if (wallet.hasActiveAccess) {
      // User has active unexpired time pass or subscription: bypass paywall entirely
      return;
    }
    final item = _toShortItem();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (innerContext) => Scaffold(
          backgroundColor: AppColors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PaywallOverlay(
                  item: item,
                  onUnlockAds: () async {
                    final auth = innerContext.read<AuthProvider>();
                    if (!auth.isAuthenticated) {
                      final loggedIn = await GuestAuthPrompt.show(
                        innerContext,
                        title: 'Sign In to Unlock',
                        message:
                            'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
                      );
                      if (!loggedIn || !innerContext.mounted) return;
                      await innerContext
                          .read<WalletProvider>()
                          .loadWallet(refresh: true);
                    }
                    final adService = innerContext.read<AdService>();
                    final ok = await adService.showRewardedAd(
                      innerContext,
                      episodeId: _currentEpisode.id,
                      episodeTitle:
                          'Episode ${_currentEpisode.number} · ${_currentEpisode.title}',
                    );
                    if (ok && innerContext.mounted) {
                      Navigator.of(innerContext).maybePop();
                      _checkAccessAndPlay();
                    }
                  },
                  onBuyCoins: () => _handleCoinUnlock(innerContext),
                  onBuyPass: () async {
                    final auth = innerContext.read<AuthProvider>();
                    if (!auth.isAuthenticated) {
                      final loggedIn = await GuestAuthPrompt.show(
                        innerContext,
                        title: 'Sign In to Buy Pass',
                        message:
                            'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
                      );
                      if (!loggedIn || !innerContext.mounted) return;
                    }
                    if (!innerContext.mounted) return;
                    Navigator.of(innerContext).pushNamed(AppRoutes.passes);
                  },
                  onSubscribe: () async {
                    final auth = innerContext.read<AuthProvider>();
                    if (!auth.isAuthenticated) {
                      final loggedIn = await GuestAuthPrompt.show(
                        innerContext,
                        title: 'Sign In to Subscribe',
                        message:
                            'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
                      );
                      if (!loggedIn || !innerContext.mounted) return;
                    }
                    if (!innerContext.mounted) return;
                    Navigator.of(innerContext)
                        .pushNamed(AppRoutes.subscriptions);
                  },
                  onMaybeLater: () =>
                      Navigator.of(innerContext).maybePop(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.white),
                    onPressed: () =>
                        Navigator.of(innerContext).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadProvider = context.watch<DownloadProvider>();
    final seriesProvider = context.watch<SeriesProvider>();
    final providerSeries = seriesProvider.series;

    final episodesList = _getEpisodes(providerSeries);
    final itemCount = episodesList.length;
    final currentIdx = _getEpisodeIndex(episodesList, _currentEpisode);
    final activeEpNum = _currentEpisode.number > 0
        ? _currentEpisode.number
        : currentIdx + 1;
    final totalEps = _getTotalEpisodes(providerSeries, episodesList);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0.0;
            if (v < -250) {
              _goToNextEpisode(itemCount);
            } else if (v > 250) {
              _goToPreviousEpisode();
            }
          },
          child: PageView.builder(
            controller: _pageController,
            dragStartBehavior: DragStartBehavior.down,
            physics: const SmoothVideoSnapScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
            ),
            scrollDirection: Axis.vertical,
            itemCount: itemCount,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
          final ep = episodesList[index];
          final isCurrent = index == currentIdx;
          final isAdjacent = (index == currentIdx - 1 || index == currentIdx + 1);

          if (!isCurrent && !isAdjacent) {
            return const ColoredBox(color: AppColors.black);
          }
          final epIdInt = int.tryParse(ep.id);
          final isDownloaded =
              epIdInt != null && downloadProvider.isDownloaded(epIdInt);
          final isThisDownloading = downloadProvider.isDownloading &&
              downloadProvider.downloadingEpisodeId == epIdInt;
          final DownloadStatus downloadStatus = isDownloaded
              ? DownloadStatus.success
              : (isThisDownloading
                  ? DownloadStatus.downloading
                  : DownloadStatus.idle);

          final wallet = context.watch<WalletProvider>();
          final bool isAccessible =
              ep.effectivelyAccessible || wallet.hasActiveAccess;
          final epNum = ep.number > 0 ? ep.number : index + 1;

          return UnifiedVideoPlayer(
            key: ValueKey('ep_player_${ep.id}_${ep.videoUrl}'),
            presentation: VideoPlayerPresentation.fullscreen,
            videoUrl: ep.videoUrl ?? '',
            title: ep.title,
            description: ep.description.isNotEmpty
                ? ep.description
                : widget.series.description,
            currentEpisode: 'EP.$epNum',
            totalEpisodes: totalEps,
            seriesId: widget.series.id,
            ratingCount: ep.ratingCount ?? 0,
            isSaved: _isSaved,
            onRate: _openRating,
            onEpisodes: _openEpisodes,
            onToggleSave: _toggleSave,
            onShare: _shareEpisode,
            onBack: () => Navigator.of(context).maybePop(),
            onSearch: () => Navigator.of(context).pushNamed(AppRoutes.search),
            onReviews: _openReviews,
            isLocked: !isAccessible,
            onUnlockAds: () async {
              final adService = context.read<AdService>();
              final ok = await adService.showRewardedAd(
                context,
                episodeId: ep.id,
                episodeTitle: 'Episode ${ep.number} · ${ep.title}',
              );
              if (ok && mounted) {
                _checkAccessAndPlay();
              }
            },
            onUnlockCoins: () => _handleCoinUnlock(context),
            onUnlockPass: () =>
                Navigator.of(context).pushNamed(AppRoutes.passes),
            onUnlockSubscribe: () =>
                Navigator.of(context).pushNamed(AppRoutes.subscriptions),
            onMaybeLater: () => Navigator.of(context).maybePop(),
            posterUrl: ep.thumbnailUrl ?? widget.series.posterUrl,
            seriesTitle: widget.series.title,
            episodeId: ep.id,
            accessReason: ep.accessReason,
            averageRating: ep.averageRating,
            knownDuration: Duration(seconds: ep.durationSeconds),
            onPlayingChanged: _onPlayingChanged,
            onCompleted: _onCompleted,
            autoPlay: isCurrent,
            looping: false,
            onDownload: _onDownload,
            downloadStatus: downloadStatus,
            isDownloaded: isDownloaded,
          );
        },
      ),
      ),
      ),
    );
  }
}
