import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/unified_video_player.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../features/reviews/providers/review_provider.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../features/series/providers/series_provider.dart';
import '../../../features/shorts/widgets/episode_selector_sheet.dart';
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
  });

  final Series series;
  final Episode episode;
  final Episode? Function(Series series, Episode current)? onNextEpisode;

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

  bool get _isAccessible => widget.episode.effectivelyAccessible;

  int get _totalEpisodes => widget.series.totalEpisodes > 0
      ? widget.series.totalEpisodes
      : widget.series.episodes.length;

  @override
  void initState() {
    super.initState();
    final episodeId = widget.episode.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ratingsRequested) return;
      _ratingsRequested = true;
      context.read<RatingProvider>().getEpisodeRating(episodeId);
      context.read<ReviewProvider>().getEpisodeReviews(episodeId, reset: true);
      context.read<ReviewProvider>().loadSettings();
    });
    _startEngagementTimer();
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
          episodeId: widget.episode.id,
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
    EpisodeSelectorSheet.show(
      context,
      seriesId: widget.series.id,
      currentEpisodeId: widget.episode.id,
      currentEpisodeNumber: widget.episode.number,
      onEpisodeSelected: (ep) => _navigateToEpisode(ep),
    );
  }

  void _openReviews() {
    ReviewBottomSheet.show(
      context,
      episode: widget.episode,
      seriesTitle: widget.series.title,
      defaultEpisodeId: widget.episode.id,
    );
  }

  void _navigateToEpisode(Episode ep) {
    _engagementTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EpisodePlayerScreen(
          series: widget.series,
          episode: ep,
          onNextEpisode: widget.onNextEpisode,
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    final provider = context.read<SeriesProvider>();
    final wasSaved = _isSaved;
    final ok = await provider.toggleSave(
      episodeId: widget.episode.id,
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
    final url =
        'https://adwashort.app/series/${widget.series.id}/episode/${widget.episode.id}';
    final text =
        '${widget.series.title} - EP.${widget.episode.number}\nWatch on ADWA SHORT: $url';
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
    return ShortItem(
      id: widget.episode.id,
      seriesId: widget.series.id,
      episodeId: widget.episode.id,
      title: widget.episode.title,
      verticalVideoUrl: widget.episode.videoUrl ?? '',
      description: widget.episode.description,
      tags: widget.series.tags,
      isAccessible: widget.episode.effectivelyAccessible,
      accessReason: widget.episode.accessReason,
      episodeNumber: widget.episode.number,
      seriesTitle: widget.series.title,
      totalEpisodes: _totalEpisodes,
      averageRating: widget.episode.averageRating,
      ratingCount: widget.episode.ratingCount,
      thumbnailUrl: widget.episode.thumbnailUrl,
      isSaved: _isSaved,
    );
  }

  @override
  void dispose() {
    _engagementTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnifiedVideoPlayer(
      presentation: VideoPlayerPresentation.fullscreen,
      videoUrl: widget.episode.videoUrl ?? '',
      title: widget.episode.title,
      description: widget.episode.description.isNotEmpty
          ? widget.episode.description
          : widget.series.description,
      currentEpisode: 'EP.${widget.episode.number}',
      totalEpisodes: _totalEpisodes,
      ratingCount: widget.episode.ratingCount ?? 0,
      isSaved: _isSaved,
      onRate: _openRating,
      onEpisodes: _openEpisodes,
      onToggleSave: _toggleSave,
      onShare: _shareEpisode,
      onBack: () => Navigator.of(context).maybePop(),
      onSearch: () => Navigator.of(context).pushNamed(AppRoutes.search),
      onReviews: _openReviews,
      isLocked: !_isAccessible,
      onUnlockCoins: () =>
          Navigator.of(context).pushNamed(AppRoutes.coinStore),
      onUnlockPass: () => Navigator.of(context).pushNamed(AppRoutes.passes),
      onUnlockSubscribe: () =>
          Navigator.of(context).pushNamed(AppRoutes.subscriptions),
      onMaybeLater: () => Navigator.of(context).maybePop(),
      posterUrl: widget.episode.thumbnailUrl ?? widget.series.posterUrl,
      seriesTitle: widget.series.title,
      episodeId: widget.episode.id,
      accessReason: widget.episode.accessReason,
      averageRating: widget.episode.averageRating,
      knownDuration: Duration(seconds: widget.episode.durationSeconds),
      onPlayingChanged: _onPlayingChanged,
      onCompleted: _onCompleted,
      autoPlay: true,
      looping: false,
    );
  }
}
