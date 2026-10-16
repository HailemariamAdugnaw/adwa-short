import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/video_format.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/short_item.dart';
import 'paywall_overlay.dart';
import 'right_action_bar.dart';
import 'short_bottom_info.dart';

class ShortVideoItem extends StatefulWidget {
  const ShortVideoItem({
    super.key,
    required this.item,
    required this.active,
    this.totalEpisodes,
    this.isAccessible = true,
    this.accessReason,
    this.onSave,
    this.onShowEpisodes,
    this.onRate,
    this.onShare,
    this.onBuyCoins,
    this.onBuyPass,
    this.onSubscribe,
    this.onMaybeLater,
  });

  final ShortItem item;
  final bool active;
  final int? totalEpisodes;
  final bool isAccessible;
  final String? accessReason;
  final VoidCallback? onSave;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onRate;
  final VoidCallback? onShare;
  final VoidCallback? onBuyCoins;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;
  final VoidCallback? onMaybeLater;

  @override
  State<ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends State<ShortVideoItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _videoFormat = 'unknown';

  bool get _shouldPlay => widget.isAccessible;

  @override
  void initState() {
    super.initState();
    if (widget.active && _shouldPlay) _initPlayer();
  }

  @override
  void didUpdateWidget(covariant ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isAccessible) {
      _pauseAndDispose();
      return;
    }
    if (widget.active && !oldWidget.active) {
      _initPlayer();
    } else if (!widget.active && oldWidget.active) {
      _pauseAndDispose();
    } else if (widget.active &&
        oldWidget.item.verticalVideoUrl != widget.item.verticalVideoUrl) {
      _pauseAndDispose();
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (_initialized || _hasError) return;
    final url = ApiClient.resolveMediaUrl(widget.item.verticalVideoUrl);
    _videoFormat = url.isEmpty ? 'unknown' : AdwaVideoFormat.detect(url);
    if (url.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video URL provided.';
      });
      return;
    }
    try {
      VideoPlayerController c;
      if (url.startsWith('http')) {
        c = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        c = VideoPlayerController.asset(url);
      }
      _controller = c;
      c.addListener(_onControllerChanged);
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
      c.setLooping(true);
      await c.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onControllerChanged() {
    final c = _controller;
    if (c == null) return;
    if (c.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = c.value.errorDescription ?? 'Playback error';
      });
    }
  }

  Future<void> _retry() async {
    final c = _controller;
    c?.removeListener(_onControllerChanged);
    c?.pause();
    c?.dispose();
    _controller = null;
    _initialized = false;
    _hasError = false;
    _errorMessage = '';
    if (mounted) setState(() {});
    await _initPlayer();
  }

  void _pauseAndDispose() {
    final c = _controller;
    _controller = null;
    _initialized = false;
    _hasError = false;
    _errorMessage = '';
    if (c != null) {
      c.removeListener(_onControllerChanged);
      c.pause();
      c.dispose();
    }
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  void dispose() {
    _pauseAndDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAccessible) {
      return PaywallOverlay(
        item: widget.item,
        onBuyCoins: widget.onBuyCoins,
        onBuyPass: widget.onBuyPass,
        onSubscribe: widget.onSubscribe,
        onMaybeLater: widget.onMaybeLater,
      );
    }
    return Container(
      color: AppColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _videoLayer(),
          _bottomGradient(),
          if (_initialized &&
              _controller != null &&
              !_controller!.value.isPlaying)
            _centerPlayIcon(),
          Positioned(
            right: 6,
            bottom: 140,
            child: SizedBox(
              width: 64,
              child: RightActionBar(
                item: widget.item,
                onRate: widget.onRate,
                onShowEpisodes: widget.onShowEpisodes,
                onSave: widget.onSave,
                onShare: widget.onShare,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 76,
            bottom: 24,
            child: ShortBottomInfo(
              item: widget.item,
              totalEpisodes: widget.totalEpisodes,
              onShowEpisodes: widget.onShowEpisodes,
            ),
          ),
          if (_initialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (_, __) {
                  final pos = _controller!.value.position.inMilliseconds;
                  final dur = _controller!.value.duration.inMilliseconds;
                  final p = dur == 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0);
                  return LinearProgressIndicator(
                    value: p,
                    minHeight: 2,
                    color: AppColors.bloodRed,
                    backgroundColor: Colors.black54,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _videoLayer() {
    if (_initialized && _controller != null && !_controller!.value.hasError) {
      final size = _controller!.value.size;
      return GestureDetector(
        onTap: _togglePlayPause,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width <= 0 ? 1 : size.width,
            height: size.height <= 0 ? 1 : size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    if (_hasError) return _errorFallback();
    if (_shouldPlay) {
      return const Center(
        child: LoadingShimmer(width: 60, height: 60, borderRadius: 30),
      );
    }
    return Container(color: AppColors.black);
  }

  Widget _bottomGradient() {
    return Positioned.fill(
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
    );
  }

  Widget _centerPlayIcon() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow_rounded,
            color: AppColors.white, size: 48),
      ),
    );
  }

  Widget _errorFallback() {
    return Container(
      color: AppColors.black,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text('Video unavailable', style: AppTextStyles.h3),
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
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
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
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
