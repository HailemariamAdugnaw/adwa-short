import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/video_format.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/short_item.dart';
import 'paywall_overlay.dart';
import 'short_overlay_buttons.dart';

class ShortVideoItem extends StatefulWidget {
  const ShortVideoItem({
    super.key,
    required this.item,
    required this.active,
    this.isAccessible = true,
    this.accessReason,
    this.onSave,
    this.onShowEpisodes,
    this.onShowReviews,
    this.onWatchNow,
    this.onBuyCoins,
    this.onBuyPass,
    this.onSubscribe,
    this.onMaybeLater,
  });

  final ShortItem item;
  final bool active;
  final bool isAccessible;
  final String? accessReason;

  // These are now successfully marked as optional
  final VoidCallback? onSave;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onShowReviews;
  final VoidCallback? onWatchNow;

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
  String _videoUrl = '';
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
    _videoUrl = url;
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
      return _lockedView();
    }
    return Container(
      color: AppColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized && _controller != null && !_controller!.value.hasError)
            GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_hasError)
            _errorFallback()
          else
            const Center(
                child: LoadingShimmer(
                    width: 60, height: 60, borderRadius: 30)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.2, 0.55, 1.0],
                ),
              ),
            ),
          ),
          if (_initialized &&
              _controller != null &&
              !_controller!.value.isPlaying)
            Center(
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
            ),
          Positioned(
            right: 12,
            bottom: 96,
            child: ShortOverlayButtons(
              item: widget.item,
              onSave: widget.onSave,
              onShowEpisodes: widget.onShowEpisodes,
              onShowReviews: widget.onShowReviews,
            ),
          ),
          Positioned(
            left: 16,
            right: 84,
            bottom: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.item.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.item.tags
                          .take(3)
                          .map((t) => _TagChip(label: t.toUpperCase()))
                          .toList(),
                    ),
                  ),
                if (widget.item.seriesTitle != null) ...[
                  Text(
                    widget.item.seriesTitle!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.bloodRedBright),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  widget.item.title,
                  style: AppTextStyles.h2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.item.description,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: widget.onWatchNow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bloodRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: AppColors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Watch Now',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_initialized && _controller != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined,
                      color: AppColors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _freePreviewLabel(),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _freePreviewLabel() {
    final epNum = widget.item.episodeNumber;
    if (epNum != null) {
      return 'Episode $epNum · Free Preview';
    }
    return 'Free Preview';
  }

  Widget _lockedView() {
    return PaywallOverlay(
      item: widget.item,
      onBuyCoins: widget.onBuyCoins,
      onBuyPass: widget.onBuyPass,
      onSubscribe: widget.onSubscribe,
      onMaybeLater: widget.onMaybeLater,
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
            if (_videoUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bloodRed.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(
          color: AppColors.white,
          fontSize: 9,
        ),
      ),
    );
  }
}
