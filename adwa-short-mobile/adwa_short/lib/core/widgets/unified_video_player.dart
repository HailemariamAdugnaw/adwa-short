import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  bool _wasPlayingBeforeScrub = false;
  bool _completionSent = false;
  bool _isScrubbing = false;
  Duration? _scrubPosition;
  double? _scrubValue;
  Timer? _seekThrottler;
  DateTime? _lastSeekTime;
  Timer? _hideControlsTimer;
  Timer? _clockTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _toggleInProgress = false;

  bool get _isEmbedded =>
      widget.presentation == VideoPlayerPresentation.embedded;

  Duration get _effectiveDuration {
    if (_controller != null && _controller!.value.isInitialized) {
      final cd = _controller!.value.duration;
      if (cd > Duration.zero) return cd;
    }
    if (_duration > Duration.zero) return _duration;
    if (widget.knownDuration > Duration.zero) return widget.knownDuration;
    return Duration.zero;
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
    if (widget.videoUrl != oldWidget.videoUrl) {
      _retry();
    } else {
      if (widget.knownDuration > Duration.zero &&
          (_duration == Duration.zero ||
              widget.knownDuration != oldWidget.knownDuration)) {
        setState(() => _duration = widget.knownDuration);
      }
      if (widget.isLocked != oldWidget.isLocked) {
        if (!widget.isLocked && (_controller == null || _hasError)) {
          _initPlayer();
        }
      }
    }
  }

  Future<void> _initPlayer() async {
    if (widget.isLocked) return;
    final url = ApiClient.resolveMediaUrl(widget.videoUrl);
    _videoFormat = url.isEmpty ? 'unknown' : AdwaVideoFormat.detect(url);
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No video URL provided.';
        });
      }
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
            _errorMessage =
                c.value.errorDescription ??
                'Playback failed for ${AdwaVideoFormat.label(_videoFormat)}.';
          });
        }
        return;
      }
      c.setLooping(widget.looping);
      c.addListener(_onPlayerChanged);

      Duration initialDuration = widget.knownDuration;
      if (c.value.duration > Duration.zero) {
        initialDuration = c.value.duration;
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = false;
          _position = c.value.position;
          _duration = initialDuration;
        });
      }

      if (widget.autoPlay) {
        await c.play();
        if (mounted) {
          setState(() => _isPlaying = true);
          widget.onPlayingChanged?.call(true);
        }
      }
      _resetHideTimer();
      _clockTimer?.cancel();
      _clockTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _syncClockFromController(queryPlatform: true);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onPlayerChanged() {
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
    _syncClockFromController(queryPlatform: false);
    if (!widget.looping &&
        c.value.isInitialized &&
        _effectiveDuration > Duration.zero &&
        c.value.position >= _effectiveDuration &&
        !_completionSent) {
      _completionSent = true;
      widget.onCompleted?.call();
    }
    final playingNow = c.value.isPlaying;
    if (playingNow != _isPlaying) {
      if (mounted) {
        setState(() => _isPlaying = playingNow);
      }
      widget.onPlayingChanged?.call(playingNow);
    }
  }

  Future<void> _syncClockFromController({bool queryPlatform = false}) async {
    final c = _controller;
    if (c == null || !mounted || !c.value.isInitialized) return;
    if (_isScrubbing) return;

    Duration position = c.value.position;
    if (queryPlatform) {
      try {
        final live = await c.position;
        if (live != null) {
          position = live;
        }
      } catch (_) {}
    }

    Duration duration = _duration;
    if (c.value.duration > Duration.zero) {
      duration = c.value.duration;
    } else if (widget.knownDuration > Duration.zero) {
      duration = widget.knownDuration;
    }
    if (duration < position && position > Duration.zero) {
      duration = position;
    }

    final isPlaying = c.value.isPlaying;

    if (position != _position ||
        duration != _duration ||
        isPlaying != _isPlaying) {
      if (mounted && !_isScrubbing) {
        setState(() {
          _position = position;
          _duration = duration;
          _isPlaying = isPlaying;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !_isInitialized || _toggleInProgress) return;
    _toggleInProgress = true;
    try {
      final wasPlaying = c.value.isPlaying;
      if (wasPlaying) {
        await c.pause();
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _showControls = true;
        });
        _hideControlsTimer?.cancel();
      } else {
        if (_effectiveDuration > Duration.zero &&
            c.value.position >= _effectiveDuration) {
          await c.seekTo(Duration.zero);
        }
        await c.play();
        if (!mounted) return;
        setState(() {
          _isPlaying = true;
          _showControls = true;
        });
        _resetHideTimer();
      }
      await _syncClockFromController(queryPlatform: true);
      widget.onPlayingChanged?.call(c.value.isPlaying);
    } catch (_) {
    } finally {
      _toggleInProgress = false;
    }
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (mounted) setState(() => _showControls = true);
    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying && !_isScrubbing) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _onScrubStart(double value) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _isScrubbing = true;
    _wasPlayingBeforeScrub = c.value.isPlaying;
    c.pause();
    _hideControlsTimer?.cancel();
    final dur = _effectiveDuration;
    final target = Duration(milliseconds: (value * dur.inMilliseconds).round());
    _scrubPosition = target;
    _scrubValue = value;
    _position = target;
    _isPlaying = false;
    setState(() => _showControls = true);
    widget.onPlayingChanged?.call(false);
  }

  void _onScrubChanged(double value) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = _effectiveDuration;
    if (dur.inMilliseconds == 0) return;
    final target = Duration(milliseconds: (value * dur.inMilliseconds).round());
    setState(() {
      _isScrubbing = true;
      _scrubPosition = target;
      _scrubValue = value;
      _position = target;
    });
    _throttleSeek(target);
  }

  void _throttleSeek(Duration target) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final now = DateTime.now();
    if (_lastSeekTime == null ||
        now.difference(_lastSeekTime!) > const Duration(milliseconds: 100)) {
      _lastSeekTime = now;
      c.seekTo(target);
    } else {
      _seekThrottler?.cancel();
      _seekThrottler = Timer(const Duration(milliseconds: 100), () {
        if (mounted && _controller != null) {
          _controller!.seekTo(target);
        }
      });
    }
  }

  Future<void> _onScrubEnd(double value) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _seekThrottler?.cancel();
    final dur = _effectiveDuration;
    final target = dur.inMilliseconds > 0
        ? Duration(milliseconds: (value * dur.inMilliseconds).round())
        : Duration.zero;
    await c.seekTo(target);
    if (!mounted) return;
    _position = target;
    _isScrubbing = false;
    _scrubPosition = null;
    _scrubValue = null;
    if (_wasPlayingBeforeScrub) {
      await c.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
      widget.onPlayingChanged?.call(true);
    } else {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
    _resetHideTimer();
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
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isInitialized = false;
      _isPlaying = false;
      _completionSent = false;
      _showControls = true;
      _isScrubbing = false;
      _scrubPosition = null;
      _scrubValue = null;
    });
    _hideControlsTimer?.cancel();
    _clockTimer?.cancel();
    _seekThrottler?.cancel();
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    _controller = null;
    _position = Duration.zero;
    _duration = widget.knownDuration;
    await _initPlayer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _clockTimer?.cancel();
    _seekThrottler?.cancel();
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
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
    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width <= 0 ? 1 : size.width,
            height: size.height <= 0 ? 1 : size.height,
            child: VideoPlayer(_controller!),
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
    final dur = _effectiveDuration;
    final pos = _isScrubbing && _scrubPosition != null
        ? _scrubPosition!
        : _position;
    final p = _isScrubbing && _scrubValue != null
        ? _scrubValue!.clamp(0.0, 1.0)
        : (dur.inMilliseconds == 0
            ? 0.0
            : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0));

    final bottomPadding = _isEmbedded
        ? 6.0
        : (MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 8.0);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
        child: Row(
          children: [
            Text(
              Formatters.playbackClock(pos),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 3,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: AppColors.bloodRed,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: AppColors.bloodRed,
                ),
                child: Slider(
                  value: p,
                  onChanged: _onScrubChanged,
                  onChangeStart: _onScrubStart,
                  onChangeEnd: _onScrubEnd,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.playbackClock(dur),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
