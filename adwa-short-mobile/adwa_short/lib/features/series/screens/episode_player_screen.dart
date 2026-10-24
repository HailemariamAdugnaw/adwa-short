import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/token_manager.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/unified_video_player.dart';
import '../../../features/downloads/providers/download_provider.dart';
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
        providerSeries.id == widget.series.id &&
        providerSeries.episodes.isNotEmpty) {
      return providerSeries.episodes;
    }
    return widget.series.episodes.isNotEmpty
        ? widget.series.episodes
        : [_currentEpisode];
  }

  int _getEpisodeIndex(List<Episode> episodes, Episode current) {
    for (int i = 0; i < episodes.length; i++) {
      if (episodes[i].id == current.id) return i;
    }
    return 0;
  }

  int _getTotalEpisodes(Series? providerSeries, List<Episode> episodes) {
    if (providerSeries != null &&
        providerSeries.id == widget.series.id &&
        providerSeries.totalEpisodes > 0) {
      return providerSeries.totalEpisodes;
    }
    if (widget.series.totalEpisodes > 0) return widget.series.totalEpisodes;
    return episodes.length;
  }

  int _calculateInitialIndex(Episode episode, Series series) {
    for (int i = 0; i < series.episodes.length; i++) {
      if (series.episodes[i].id == episode.id) return i;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    final initialIndex = _calculateInitialIndex(widget.episode, widget.series);
    _pageController = PageController(initialPage: initialIndex);
    final episodeId = _currentEpisode.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SeriesProvider>().load(widget.series.id);
      if (!_ratingsRequested) {
        _ratingsRequested = true;
        context.read<RatingProvider>().getEpisodeRating(episodeId);
        context.read<ReviewProvider>().getEpisodeReviews(episodeId, reset: true);
        context.read<ReviewProvider>().loadSettings();
      }
      if (widget.openEpisodesSheet) {
        _openEpisodes();
      }
    });
    _startEngagementTimer();
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
      onEpisodeSelected: (ep) => _onEpisodeSelected(ep),
      onSelectEpisode: (ep) => _onEpisodeSelected(ep),
    );
  }

  void _onPageChanged(int index) {
    final providerSeries = context.read<SeriesProvider>().series;
    final list = _getEpisodes(providerSeries);
    if (index < 0 || index >= list.length) return;
    final ep = list[index];
    if (ep.id == _currentEpisode.id) return;
    _onEpisodeSelected(ep);
  }

  void _onEpisodeSelected(Episode ep) {
    if (!mounted) return;
    if (ep.id == _currentEpisode.id) return;
    _engagementTimer?.cancel();
    _watchSeconds = 0;
    _completionSent = false;
    _isPlaying = false;
    _ratingsRequested = false;
    setState(() {
      _currentEpisode = ep;
    });

    final providerSeries = context.read<SeriesProvider>().series;
    final episodesList = _getEpisodes(providerSeries);
    final targetIndex = _getEpisodeIndex(episodesList, ep);

    if (_pageController != null && _pageController!.hasClients) {
      if (_pageController!.page?.round() != targetIndex) {
        _pageController!.jumpToPage(targetIndex);
      }
    }
    final episodeId = _currentEpisode.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_ratingsRequested) {
        _ratingsRequested = true;
        context.read<RatingProvider>().getEpisodeRating(episodeId);
        context.read<ReviewProvider>().getEpisodeReviews(episodeId, reset: true);
      }
    });
    _startEngagementTimer();
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

  void _showPaywall() {
    if (!mounted) return;
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
                  onBuyCoins: () => Navigator.of(innerContext)
                      .pushNamed(AppRoutes.coinStore),
                  onBuyPass: () => Navigator.of(innerContext)
                      .pushNamed(AppRoutes.passes),
                  onSubscribe: () => Navigator.of(innerContext)
                      .pushNamed(AppRoutes.subscriptions),
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: itemCount,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          if (index != currentIdx) {
            return Container(color: AppColors.black);
          }
          final ep = episodesList[index];
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

          return UnifiedVideoPlayer(
            key: ValueKey('ep_player_${ep.id}_${ep.videoUrl}'),
            presentation: VideoPlayerPresentation.fullscreen,
            videoUrl: ep.videoUrl ?? '',
            title: ep.title,
            description: ep.description.isNotEmpty
                ? ep.description
                : widget.series.description,
            currentEpisode: 'EP.$activeEpNum',
            totalEpisodes: totalEps,
            ratingCount: ep.ratingCount ?? 0,
            isSaved: _isSaved,
            onRate: _openRating,
            onEpisodes: _openEpisodes,
            onToggleSave: _toggleSave,
            onShare: _shareEpisode,
            onBack: () => Navigator.of(context).maybePop(),
            onSearch: () => Navigator.of(context).pushNamed(AppRoutes.search),
            onReviews: _openReviews,
            isLocked: !ep.effectivelyAccessible,
            onUnlockCoins: () =>
                Navigator.of(context).pushNamed(AppRoutes.coinStore),
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
            autoPlay: true,
            looping: false,
            onDownload: _onDownload,
            downloadStatus: downloadStatus,
            isDownloaded: isDownloaded,
          );
        },
      ),
    );
  }
}
