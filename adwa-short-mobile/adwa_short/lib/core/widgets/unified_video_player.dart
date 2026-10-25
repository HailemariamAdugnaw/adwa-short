import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../features/downloads/providers/download_provider.dart';
import '../../features/shorts/widgets/paywall_overlay.dart';
import '../../features/shorts/widgets/right_action_bar.dart';
import '../../features/shorts/widgets/short_bottom_info.dart';
import '../../models/short_item.dart';
import '../network/api_client.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/formatters.dart';
import '../utils/video_format.dart';

enum VideoPlayerPresentation { embedded, fullscreen }

class UnifiedVideoPlayer extends StatefulWidget {
  const UnifiedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.description,
    required this.currentEpisode,
    required this.totalEpisodes,
    required this.ratingCount,
    required this.isSaved,
    required this.onRate,
    required this.onEpisodes,
    required this.onToggleSave,
    required this.onShare,
    this.presentation = VideoPlayerPresentation.fullscreen,
    this.onWatchFull,
    this.onBack,
    this.onSearch,
    this.onReviews,
    this.isLocked = false,
    this.onUnlockCoins,
    this.onUnlockPass,
    this.onUnlockSubscribe,
    this.onMaybeLater,
    this.posterUrl,
    this.seriesTitle,
    this.episodeId,
    this.accessReason,
    this.averageRating,
    this.knownDuration = Duration.zero,
    this.onPlayingChanged,
    this.onCompleted,
    this.autoPlay = true,
    this.looping = false,
    this.onDownload,
    this.downloadStatus = DownloadStatus.idle,
    this.isDownloaded = false,
  });

  final String videoUrl;
  final String title;
  final String description;
  final String currentEpisode;
  final int totalEpisodes;
  final int ratingCount;
  final bool isSaved;
  final VoidCallback onRate;
  final VoidCallback onEpisodes;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;
  final VideoPlayerPresentation presentation;
  final VoidCallback? onWatchFull;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onReviews;
  final bool isLocked;
  final VoidCallback? onUnlockCoins;
  final VoidCallback? onUnlockPass;
  final VoidCallback? onUnlockSubscribe;
  final VoidCallback? onMaybeLater;
  final String? posterUrl;
  final String? seriesTitle;
  final String? episodeId;
  final String? accessReason;
  final double? averageRating;
  final Duration knownDuration;
  final void Function(bool isPlaying)? onPlayingChanged;
  final void Function()? onCompleted;
  final bool autoPlay;
  final bool looping;
  final VoidCallback? onDownload;
  final DownloadStatus downloadStatus;
  final bool isDownloaded;

  @override
  State<UnifiedVideoPlayer> createState() => _UnifiedVideoPlayerState();
}

class _UnifiedVideoPlayerState extends State<UnifiedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _videoFormat = 'unknown';
  bool _showControls = true;
  bool _completionSent = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _toggleInProgress = false;
  bool _isScrubbing = false;
  double _scrubPositionMs = 0.0;
  bool _isSeeking = false;
  bool _wasPlayingBeforeScrub = false;
  Timer? _seekDebounceTimer;

  bool get _isEmbedded =>
      widget.presentation == VideoPlayerPresentation.embedded;

  Duration get _effectiveDuration {
    final c = _controller;
    final ctrlDur =
        (c != null && c.value.isInitialized) ? c.value.duration : Duration.zero;

    // 1. Controller has a valid duration of at least 1 second
    if (ctrlDur >= const Duration(seconds: 1)) {
      return ctrlDur;
    }
    // 2. Known duration passed from metadata/API is at least 1 second
    if (widget.knownDuration >= const Duration(seconds: 1)) {
      return widget.knownDuration;
    }
    // 3. Stored state duration is at least 1 second
    if (_duration >= const Duration(seconds: 1)) {
      return _duration;
    }

    // 4. Fallbacks if duration is sub-second
    if (ctrlDur > Duration.zero) return ctrlDur;
    if (widget.knownDuration > Duration.zero) return widget.knownDuration;
    if (_duration > Duration.zero) return _duration;

    return Duration.zero;
  }

  String formatDuration(Duration duration) {
    return Formatters.playbackClock(duration);
  }

  @override
  void initState() {
    super.initState();
    _duration = widget.knownDuration;
    if (!widget.isLocked) {
      _initPlayer();
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlChanged = widget.videoUrl != oldWidget.videoUrl;
    final episodeChanged = widget.episodeId != oldWidget.episodeId;
    if (urlChanged || episodeChanged) {
      _switchVideo();
    } else {
      if (widget.isLocked != oldWidget.isLocked) {
        if (!widget.isLocked && (_controller == null || _hasError)) {
          _initPlayer();
        }
      }
      if (widget.knownDuration >= const Duration(seconds: 1) &&
          (_controller == null ||
              _controller!.value.duration < const Duration(seconds: 1)) &&
          _duration != widget.knownDuration) {
        setState(() {
          _duration = widget.knownDuration;
        });
      }
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    _isInitialized = false;
    _stopProgressTimer();
    _hideControlsTimer?.cancel();
    if (c == null) return;

    try {
      c.removeListener(_onControllerChanged);
    } catch (_) {}

    try {
      if (c.value.isInitialized && c.value.isPlaying) {
        await c.pause();
      }
    } catch (_) {}

    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> _switchVideo() async {
    if (_isInitializing) return;
    _isInitializing = true;
    _seekDebounceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _stopProgressTimer();
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isPlaying = false;
        _hasError = false;
        _errorMessage = '';
        _completionSent = false;
        _showControls = true;
        _position = Duration.zero;
        _duration = widget.knownDuration;
        _isScrubbing = false;
        _isSeeking = false;
        _wasPlayingBeforeScrub = false;
        _scrubPositionMs = 0.0;
      });
    }
    await _disposeController();
    if (!_isDisposed && mounted) {
      await _initPlayer();
    }
    _isInitializing = false;
  }

  Future<void> _initPlayer() async {
    if (widget.isLocked || _isDisposed || _isInitializing) return;
    _isInitializing = true;
    final url = ApiClient.resolveMediaUrl(widget.videoUrl);
    _videoFormat = url.isEmpty ? 'unknown' : AdwaVideoFormat.detect(url);
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No video URL provided.';
        });
      }
      _isInitializing = false;
      return;
    }
    try {
      await _disposeController();
      if (_isDisposed) return;

      final VideoPlayerController c;
      if (url.startsWith('http')) {
        c = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (widget.videoUrl.startsWith('file://')) {
        c = VideoPlayerController.file(File(url));
      } else {
        c = VideoPlayerController.asset(url);
      }
      _controller = c;

      c.addListener(_onControllerChanged);

      await c.initialize();
      if (_isDisposed || !mounted) {
        c.removeListener(_onControllerChanged);
        await c.dispose();
        _controller = null;
        _isInitializing = false;
        return;
      }
      if (c.value.hasError) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                c.value.errorDescription ??
                'Playback failed for ${AdwaVideoFormat.label(_videoFormat)}.';
          });
        }
        _isInitializing = false;
        return;
      }
      c.setLooping(widget.looping);

      final ctrlDuration = c.value.duration;
      final actualDuration = ctrlDuration >= const Duration(seconds: 1)
          ? ctrlDuration
          : (widget.knownDuration >= const Duration(seconds: 1)
              ? widget.knownDuration
              : (_duration >= const Duration(seconds: 1)
                  ? _duration
                  : (ctrlDuration > Duration.zero
                      ? ctrlDuration
                      : widget.knownDuration)));

      if (c.value.duration <= Duration.zero && actualDuration > Duration.zero) {
        c.value = c.value.copyWith(duration: actualDuration);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = false;
          _position = c.value.position;
          _duration = actualDuration;
        });
      }

      if (widget.autoPlay && !_isDisposed && c.value.isInitialized) {
        await c.play();
        if (mounted && !_isDisposed) {
          setState(() => _isPlaying = true);
          widget.onPlayingChanged?.call(true);
        }
      }
      _resetHideTimer();
      _startProgressTimer();
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _onControllerChanged() {
    if (_isDisposed) return;
    final c = _controller;
    if (c == null) return;
    if (c.value.hasError && !_hasError) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = c.value.errorDescription ?? 'Playback error';
        });
      }
      return;
    }

    final effDur = _effectiveDuration;
    if (effDur >= const Duration(seconds: 1) &&
        c.value.duration < const Duration(seconds: 1)) {
      c.value = c.value.copyWith(duration: effDur);
    }

    if (!widget.looping &&
        c.value.isInitialized &&
        effDur >= const Duration(seconds: 1) &&
        !c.value.isPlaying &&
        _position.inMilliseconds >= effDur.inMilliseconds - 500 &&
        !_completionSent) {
      _completionSent = true;
      widget.onCompleted?.call();
    }
    if (_position.inMilliseconds < effDur.inMilliseconds - 1000 &&
        _completionSent) {
      _completionSent = false;
    }

    final playingNow = c.value.isPlaying;
    final posNow = c.value.position;
    final durNow = c.value.duration;

    final playingChanged = playingNow != _isPlaying;
    final posChanged = posNow.inSeconds != _position.inSeconds ||
        (posNow - _position).abs().inMilliseconds > 250;
    final durChanged =
        durNow >= const Duration(seconds: 1) && durNow != _duration;

    if (playingChanged) {
      _isPlaying = playingNow;
      widget.onPlayingChanged?.call(playingNow);
    }

    if (!_isScrubbing && !_isSeeking && c.value.isInitialized) {
      // Don't let an uninitialized zero position wipe out an advancing position,
      // unless playback actually reset / looped back to the beginning.
      if (posNow > Duration.zero ||
          _position <= Duration.zero ||
          posNow < _position - const Duration(seconds: 2)) {
        _position = posNow;
      }
      if (durNow >= const Duration(seconds: 1)) {
        _duration = durNow;
      }
    }

    if (mounted &&
        !_isDisposed &&
        (playingChanged ||
            (!_isScrubbing && !_isSeeking && posChanged) ||
            durChanged)) {
      setState(() {});
    }
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !_isInitialized || _toggleInProgress || _isDisposed) return;
    if (!c.value.isInitialized) return;
    _toggleInProgress = true;
    try {
      final wasPlaying = c.value.isPlaying;
      if (wasPlaying) {
        Duration? livePos;
        try {
          livePos = await c.position;
        } catch (_) {}
        final pausePos = (livePos != null && livePos > Duration.zero)
            ? livePos
            : (_position > Duration.zero ? _position : c.value.position);

        await c.pause();
        if (!mounted || _isDisposed) return;
        setState(() {
          _isPlaying = false;
          _position = pausePos;
          _showControls = true;
        });
        _hideControlsTimer?.cancel();
      } else {
        // Resuming playback
        Duration? livePos;
        try {
          livePos = await c.position;
        } catch (_) {}
        final resumePos = _position > Duration.zero
            ? _position
            : ((livePos != null && livePos > Duration.zero)
                ? livePos
                : c.value.position);

        // Before calling c.play(), ensure c.value.duration is non-zero so c.play()
        // does not trigger `if (value.position == value.duration) seekTo(Duration.zero)`.
        final effDur = _effectiveDuration;
        if (effDur >= const Duration(seconds: 1)) {
          c.value = c.value.copyWith(
            duration: effDur,
            position: resumePos,
          );
        }

        await c.play();

        // Guard against internal player reset to 0:
        if (resumePos > const Duration(milliseconds: 500)) {
          final cur = c.value.position;
          if (cur < const Duration(milliseconds: 200)) {
            await c.seekTo(resumePos);
          }
        }

        if (!mounted || _isDisposed) return;
        setState(() {
          _isPlaying = true;
          _position = resumePos;
          _showControls = true;
        });
        _resetHideTimer();
      }
      widget.onPlayingChanged?.call(c.value.isPlaying);
    } catch (_) {
    } finally {
      _toggleInProgress = false;
    }
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (mounted && !_isDisposed) setState(() => _showControls = true);
    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isDisposed && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (_isDisposed || _isScrubbing || _isSeeking) return;
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;

      final effDur = _effectiveDuration;
      if (effDur >= const Duration(seconds: 1) &&
          c.value.duration < const Duration(seconds: 1)) {
        c.value = c.value.copyWith(duration: effDur);
      }

      Duration? realPos;
      try {
        realPos = await c.position;
      } catch (_) {}

      if (_isDisposed || !mounted || _isScrubbing || _isSeeking) return;

      final currentLive = (realPos != null && realPos > Duration.zero)
          ? realPos
          : c.value.position;

      // Ensure controller value position stays up-to-date with hardware playback
      if (realPos != null && realPos > Duration.zero && realPos > c.value.position) {
        c.value = c.value.copyWith(
          position: realPos,
          duration: effDur >= const Duration(seconds: 1) ? effDur : c.value.duration,
        );
      }

      final durNow = c.value.duration;
      if (durNow >= const Duration(seconds: 1)) {
        _duration = durNow;
      }

      if (!_isScrubbing && !_isSeeking) {
        _position = currentLive;
      }

      if (mounted && !_isDisposed && !_isScrubbing && !_isSeeking) {
        setState(() {});
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  int? _parseEpisodeNumber() {
    final digits = widget.currentEpisode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  ShortItem _toShortItem() {
    return ShortItem(
      id: widget.episodeId ?? widget.title,
      seriesId: '',
      episodeId: widget.episodeId,
      title: widget.title,
      verticalVideoUrl: widget.videoUrl,
      description: widget.description,
      isSaved: widget.isSaved,
      isAccessible: !widget.isLocked,
      accessReason: widget.accessReason,
      episodeNumber: _parseEpisodeNumber(),
      seriesTitle: widget.seriesTitle,
      totalEpisodes: widget.totalEpisodes,
      averageRating: widget.averageRating,
      ratingCount: widget.ratingCount,
      thumbnailUrl: widget.posterUrl,
      durationSeconds: _effectiveDuration.inSeconds > 0
          ? _effectiveDuration.inSeconds
          : widget.knownDuration.inSeconds,
    );
  }

  Future<void> _retry() async {
    if (_isDisposed) return;
    _seekDebounceTimer?.cancel();
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isInitialized = false;
      _isPlaying = false;
      _completionSent = false;
      _showControls = true;
      _isScrubbing = false;
      _isSeeking = false;
      _wasPlayingBeforeScrub = false;
      _scrubPositionMs = 0.0;
    });
    _hideControlsTimer?.cancel();
    _stopProgressTimer();
    await _disposeController();
    _position = Duration.zero;
    _duration = widget.knownDuration;
    if (!_isDisposed) {
      await _initPlayer();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _seekDebounceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _stopProgressTimer();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) return _buildLockedView();
    if (_hasError) return _buildErrorView();
    final player = Stack(
      fit: StackFit.expand,
      children: [
        _buildVideo(),
        _buildGradientOverlay(),
        if (_hasTopBar) _buildTopBar(),
        if (_isInitialized && _controller != null && !_hasError) ...[
          _buildRightActionBar(),
          _buildBottomInfo(),
          _buildProgressBar(),
        ],
        if (_showControls &&
            _isInitialized &&
            _controller != null &&
            !_hasError)
          _buildCenterIndicator(),
        if (!_isInitialized && !_hasError) _buildLoading(),
      ],
    );
    if (_isEmbedded) return ColoredBox(color: AppColors.black, child: player);
    return Scaffold(backgroundColor: AppColors.black, body: player);
  }

  bool get _hasTopBar =>
      widget.onBack != null ||
      widget.onSearch != null ||
      widget.onReviews != null;

  Widget _buildVideo() {
    if (!_isInitialized || _controller == null) {
      return GestureDetector(
        onTap: _togglePlayPause,
        behavior: HitTestBehavior.opaque,
        child: Container(color: AppColors.black),
      );
    }
    final size = _controller!.value.size;
    final vw = size.width <= 0 ? 1.0 : size.width.toDouble();
    final vh = size.height <= 0 ? 1.0 : size.height.toDouble();
    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: vw,
              height: vh,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
              ],
              stops: const [0.0, 0.18, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.onBack != null)
            _circleButton(Icons.arrow_back_rounded, widget.onBack!),
          const Spacer(),
          if (widget.onReviews != null) ...[
            _circleButton(Icons.reviews_outlined, widget.onReviews!),
            const SizedBox(width: 8),
          ],
          if (widget.onSearch != null)
            _circleButton(Icons.search_rounded, widget.onSearch!),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.white, size: 22),
      ),
    );
  }

  Widget _buildRightActionBar() {
    final bottomOffset = _isEmbedded
        ? 136.0
        : (MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 130.0
            : 136.0);

    return Positioned(
      bottom: bottomOffset,
      right: 12,
      child: SizedBox(
        width: 64,
        child: RightActionBar(
          item: _toShortItem(),
          onRate: widget.onRate,
          onShowEpisodes: widget.onEpisodes,
          onSave: widget.onToggleSave,
          onShare: widget.onShare,
          onDownload: widget.onDownload,
          downloadStatus: widget.downloadStatus,
          isDownloaded: widget.isDownloaded,
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    final bottomOffset = _isEmbedded
        ? 52.0
        : (MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 46.0
            : 52.0);

    return Positioned(
      bottom: bottomOffset,
      left: 16,
      right: 76,
      child: ShortBottomInfo(
        item: _toShortItem(),
        totalEpisodes: widget.totalEpisodes,
        onShowEpisodes: widget.onEpisodes,
        previewMode: _isEmbedded,
        onWatchFull: widget.onWatchFull,
      ),
    );
  }

  Widget _buildProgressBar() {
    final c = _controller;
    if (!_isInitialized || c == null) return const SizedBox.shrink();

    final bottomPadding = _isEmbedded
        ? 6.0
        : (MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 8.0);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, value, _) {
          final totalDuration = _effectiveDuration;
          final maxMs = totalDuration.inMilliseconds.toDouble();
          final bool hasValidDuration =
              totalDuration >= const Duration(seconds: 1);

          final sliderMax = hasValidDuration ? maxMs : 1.0;
          final sliderValue = hasValidDuration
              ? _position.inMilliseconds.toDouble().clamp(0.0, sliderMax)
              : 0.0;

          return Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) {},
                  onVerticalDragUpdate: (_) {},
                  onVerticalDragEnd: (_) {},
                  child: SizedBox(
                    height: 36,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.0,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0,
                            pressedElevation: 4.0),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16.0),
                        activeTrackColor: AppColors.bloodRed,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppColors.bloodRed,
                        overlayColor:
                            AppColors.bloodRed.withValues(alpha: 0.25),
                      ),
                      child: Slider(
                        value: sliderValue,
                        min: 0.0,
                        max: sliderMax,
                        allowedInteraction: SliderInteraction.tapAndSlide,
                        onChangeStart: hasValidDuration
                            ? (val) {
                                _stopProgressTimer();
                                _seekDebounceTimer?.cancel();
                                _hideControlsTimer?.cancel();
                                _wasPlayingBeforeScrub = c.value.isPlaying;
                                _isScrubbing = true;
                                _isSeeking = false;
                                if (_wasPlayingBeforeScrub) {
                                  c.pause();
                                }
                                setState(() {
                                  _position = Duration(
                                      milliseconds: val
                                          .clamp(0.0, sliderMax)
                                          .round());
                                  _showControls = true;
                                });
                              }
                            : null,
                        onChanged: hasValidDuration
                            ? (val) {
                                setState(() {
                                  _isScrubbing = true;
                                  _position = Duration(
                                      milliseconds: val
                                          .clamp(0.0, sliderMax)
                                          .round());
                                  _showControls = true;
                                });
                              }
                            : null,
                        onChangeEnd: hasValidDuration
                            ? (val) async {
                                final seekTarget = Duration(
                                    milliseconds: val
                                        .clamp(0.0, sliderMax)
                                        .toInt());
                                setState(() {
                                  _isScrubbing = false;
                                  _isSeeking = true;
                                  _position = seekTarget;
                                  _showControls = true;
                                });

                                final effDur = _effectiveDuration;
                                if (effDur >= const Duration(seconds: 1)) {
                                  c.value = c.value.copyWith(
                                    duration: effDur,
                                    position: seekTarget,
                                  );
                                }

                                try {
                                  await _controller?.seekTo(seekTarget);
                                } catch (_) {}

                                if (!mounted || _isDisposed) return;

                                if (_wasPlayingBeforeScrub) {
                                  if (effDur >= const Duration(seconds: 1)) {
                                    c.value = c.value.copyWith(
                                      duration: effDur,
                                      position: seekTarget,
                                    );
                                  }
                                  await c.play();
                                  if (!mounted || _isDisposed) return;
                                  setState(() {
                                    _isPlaying = true;
                                    _position = seekTarget;
                                    _showControls = true;
                                  });
                                  _resetHideTimer();
                                  widget.onPlayingChanged?.call(true);
                                } else {
                                  _resetHideTimer();
                                }

                                _startProgressTimer();

                                _seekDebounceTimer?.cancel();
                                _seekDebounceTimer = Timer(
                                    const Duration(milliseconds: 500), () {
                                  if (mounted && !_isDisposed) {
                                    setState(() {
                                      _isSeeking = false;
                                    });
                                  }
                                });
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(_position),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatDuration(totalDuration),
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterIndicator() {
    return Center(
      child: GestureDetector(
        onTap: _togglePlayPause,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppColors.white,
            size: 42,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.bloodRed,
          ),
        ),
      ),
    );
  }

  Widget _buildLockedView() {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: PaywallOverlay(
        item: _toShortItem(),
        onBuyCoins: widget.onUnlockCoins,
        onBuyPass: widget.onUnlockPass,
        onSubscribe: widget.onUnlockSubscribe,
        onMaybeLater: widget.onMaybeLater,
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Container(
        color: Colors.black.withValues(alpha: 0.75),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text('Video unavailable', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text(
                  AdwaVideoFormat.supportHint(_videoFormat),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body2,
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      _errorMessage,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
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
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
