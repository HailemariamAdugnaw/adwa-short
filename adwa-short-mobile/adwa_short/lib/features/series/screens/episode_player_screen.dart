import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/video_format.dart';
import '../../../core/widgets/star_rating.dart';
import '../../../features/ratings/providers/rating_provider.dart';
import '../../../features/reviews/providers/review_provider.dart';
import '../../../features/reviews/widgets/review_bottom_sheet.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../providers/series_provider.dart';

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
  VideoPlayerController? _controller;
  Timer? _engagementTimer;
  Timer? _hideControlsTimer;
  int _watchSeconds = 0;
  bool _completionSent = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _videoUrl = '';
  String _videoFormat = 'unknown';
  bool _showControls = true;
  bool _ratingsRequested = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    final episodeId = widget.episode.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ratingsRequested) return;
      _ratingsRequested = true;
      context.read<RatingProvider>().getEpisodeRating(episodeId);
      context.read<ReviewProvider>().getEpisodeReviews(episodeId, reset: true);
      context.read<ReviewProvider>().loadSettings();
    });
  }

  Future<void> _initPlayer() async {
    final rawUrl = widget.episode.videoUrl ?? '';
    final url = ApiClient.resolveMediaUrl(rawUrl);
    _videoUrl = url;
    _videoFormat = url.isEmpty ? 'unknown' : AdwaVideoFormat.detect(url);
    if (url.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video URL provided for this episode.';
      });
      return;
    }
    try {
      final VideoPlayerController c = url.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(url))
          : VideoPlayerController.asset(url);
      _controller = c;
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      if (c.value.hasError) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = c.value.errorDescription ??
                'Playback failed for ${AdwaVideoFormat.label(_videoFormat)}.';
          });
        }
        return;
      }
      c.setLooping(false);
      c.addListener(_onPlayerChanged);
      await c.play();
      _startEngagementPings();
      _resetHideTimer();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    _controller = null;
    _engagementTimer?.cancel();
    _hideControlsTimer?.cancel();
    _watchSeconds = 0;
    _completionSent = false;
    await _initPlayer();
  }

  void _onPlayerChanged() {
    final c = _controller;
    if (c == null) return;
    if (c.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = c.value.errorDescription ?? 'Playback error';
      });
      return;
    }
    if (c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero &&
        !_completionSent) {
      _completionSent = true;
      _sendViewPing(completed: true);
    }
    setState(() {});
  }

  void _startEngagementPings() {
    _engagementTimer?.cancel();
    _engagementTimer =
        Timer.periodic(AppConstants.engagementPingInterval, (_) {
      final c = _controller;
      if (c == null || !c.value.isPlaying) return;
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

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
    _resetHideTimer();
  }

  void _seek(int deltaSeconds) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final raw = c.value.position + Duration(seconds: deltaSeconds);
    final Duration target;
    if (raw < Duration.zero) {
      target = Duration.zero;
    } else if (raw > c.value.duration) {
      target = c.value.duration;
    } else {
      target = raw;
    }
    c.seekTo(target);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    setState(() => _showControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _engagementTimer?.cancel();
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _appBar(),
            Expanded(child: _playerArea()),
            _rateThisEpisodeBar(),
            _nextEpisodeBar(),
          ],
        ),
      ),
    );
  }

  Widget _rateThisEpisodeBar() {
    final rating = context.watch<RatingProvider>();
    final reviews = context.watch<ReviewProvider>();
    final episodeId = widget.episode.id;
    final summary = rating.summaryFor(episodeId);
    final userRating = rating.userRatingFor(episodeId);
    final avg = widget.episode.averageRating ?? summary?.average;
    final ratingCount = widget.episode.ratingCount ?? summary?.count ?? 0;
    final reviewCount = widget.episode.reviewCount ??
        reviews.countFor(episodeId) ??
        0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rate this episode', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StarRating(
                      currentRating: userRating,
                      interactive: true,
                      size: 22,
                      onRatingChanged: (v) {
                        rating.rateEpisode(episodeId, v);
                      },
                    ),
                    const SizedBox(width: 8),
                    if (avg != null)
                      Flexible(
                        child: Text(
                          '${avg.toStringAsFixed(1)} ★ (${Formatters.compact(ratingCount)})',
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ReviewBottomSheet.show(
                context,
                episode: widget.episode,
                seriesTitle: widget.series.title,
                defaultEpisodeId: episodeId,
              );
            },
            icon: const Icon(Icons.reviews_outlined,
                color: AppColors.bloodRed, size: 18),
            label: Text(
              'Reviews${reviewCount > 0 ? ' ($reviewCount)' : ''}',
              style: AppTextStyles.label.copyWith(color: AppColors.bloodRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.series.title,
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode ${widget.episode.number} · ${widget.episode.title}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerArea() {
    if (_hasError) {
      return _errorView();
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.hasError) {
      if (c != null && c.value.hasError) {
        return _errorView();
      }
      return const Center(
        child: CircularProgressIndicator(color: AppColors.bloodRed),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _resetHideTimer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: VideoPlayer(c),
            ),
          ),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showControls ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                fit: StackFit.expand,
                children: [

                  Container(color: Colors.black.withValues(alpha: 0.35)),

                  Center(
                    child: IconButton(
                      iconSize: 64,
                      icon: Icon(
                        c.value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppColors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _progressBar(c),
                  ),

                  Positioned(
                    left: 16,
                    top: 8,
                    child: Text(
                      'Episode ${widget.episode.number}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text('Video unavailable', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            AdwaVideoFormat.supportHint(_videoFormat),
            textAlign: TextAlign.center,
            style: AppTextStyles.body2,
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                _errorMessage,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (_videoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Video URL', style: AppTextStyles.label),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: SelectableText(
                _videoUrl,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodRed,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _progressBar(VideoPlayerController c) {
    final pos = c.value.position;
    final dur = c.value.duration;
    final p = dur.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                Formatters.clockFromSeconds(pos.inSeconds),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.white, fontSize: 10),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppColors.bloodRed,
                    inactiveTrackColor: AppColors.surfaceHover,
                    thumbColor: AppColors.bloodRedBright,
                  ),
                  child: Slider(
                    value: p,
                    onChanged: (v) {
                      c.seekTo(Duration(
                          milliseconds: (v * dur.inMilliseconds).toInt()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.clockFromSeconds(dur.inSeconds),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.white, fontSize: 10),
              ),
              const SizedBox(width: 4),
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.replay_10_rounded,
                    color: AppColors.white),
                onPressed: () => _seek(-10),
              ),
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.forward_10_rounded,
                    color: AppColors.white),
                onPressed: () => _seek(10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nextEpisodeBar() {
    final next = widget.onNextEpisode?.call(widget.series, widget.episode);
    if (next == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You've reached the latest episode",
                style: AppTextStyles.body3,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.skip_next_rounded,
              color: AppColors.bloodRed, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next: Episode ${next.number}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.bloodRedBright),
                ),
                Text(
                  next.title,
                  style: AppTextStyles.body1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (next.durationSeconds > 0)
                  Text(
                    Formatters.clockFromSeconds(next.durationSeconds),
                    style: AppTextStyles.body3,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _engagementTimer?.cancel();
              _controller?.dispose();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => EpisodePlayerScreen(
                    series: widget.series,
                    episode: next,
                    onNextEpisode: widget.onNextEpisode,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.bloodRed,
            ),
            child: const Text('Play Next'),
          ),
        ],
      ),
    );
  }
}
