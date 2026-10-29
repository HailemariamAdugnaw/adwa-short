import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../models/intro_poster_config.dart';

class IntroPosterScreen extends StatefulWidget {
  const IntroPosterScreen({
    super.key,
    this.config,
    this.targetRoute = AppRoutes.welcome,
    this.onSkip,
    this.onWatchNow,
    this.onWatchSeries,
  });

  final IntroPosterConfig? config;
  final String targetRoute;
  final VoidCallback? onSkip;
  final VoidCallback? onWatchNow;
  final void Function(String seriesId)? onWatchSeries;

  @override
  State<IntroPosterScreen> createState() => _IntroPosterScreenState();
}

class _IntroPosterScreenState extends State<IntroPosterScreen> {
  late IntroPosterConfig _config;
  late int _countdown;
  Timer? _timer;
  bool _proceeded = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? const IntroPosterConfig();
    _countdown = _config.countdownSeconds > 0 ? _config.countdownSeconds : 5;

    final rawUrl = _config.posterUrl ?? _config.bannerUrl;
    if (!_config.enabled || rawUrl == null || rawUrl.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _proceedToTarget();
      });
      return;
    }

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
        _proceedToTarget();
      }
    });
  }

  void _proceedToTarget() {
    if (_proceeded) return;
    _proceeded = true;
    _timer?.cancel();
    if (widget.onSkip != null) {
      widget.onSkip!();
      return;
    }
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(widget.targetRoute);
    }
  }

  void _onWatchNowTapped() {
    if (_proceeded) return;
    _proceeded = true;
    _timer?.cancel();
    final seriesId = _config.seriesId;
    if (widget.onWatchSeries != null && seriesId != null && seriesId.isNotEmpty) {
      widget.onWatchSeries!(seriesId);
      return;
    }
    if (widget.onWatchNow != null) {
      widget.onWatchNow!();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(widget.targetRoute);
    if (seriesId != null && seriesId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.seriesDetail,
        arguments: seriesId,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0 ? mediaQuery.padding.top : 24.0;
    final bottomPadding = mediaQuery.padding.bottom > 0 ? mediaQuery.padding.bottom : 20.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-screen Cinematic Poster Artwork
          _buildPosterImage(),

          // 2. Subtle Vignette Overlays for readability and contrast
          _buildVignetteOverlay(),

          // 3. Top-Right Skip Button with dynamic countdown
          Positioned(
            top: topPadding + 10,
            right: 16,
            child: _buildSkipBadge(),
          ),

          // 4. Dynamic Title & "Watch Now" Call-To-Action Button
          Positioned(
            bottom: bottomPadding + 32,
            left: 28,
            right: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_config.title.trim().isNotEmpty) ...[
                  Text(
                    _config.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildWatchNowButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterImage() {
    final rawUrl = _config.posterUrl ?? _config.bannerUrl;
    final hasRemoteUrl = rawUrl != null && rawUrl.trim().isNotEmpty;
    final resolvedUrl = hasRemoteUrl ? ApiClient.resolveMediaUrl(rawUrl) : '';

    if (resolvedUrl.isNotEmpty && resolvedUrl.startsWith('http')) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient blurred backdrop fill to eliminate harsh borders & cropping artifacts
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.68),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, __) => Container(color: AppColors.black),
                errorWidget: (_, __, ___) => Container(color: AppColors.black),
              ),
            ),
          ),

          // 2. Main sharp promotional poster with BoxFit.contain for true proportions
          Center(
            child: CachedNetworkImage(
              imageUrl: resolvedUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              placeholder: (_, __) => Container(
                color: AppColors.transparent,
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.bloodRed),
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) =>
                  Container(color: AppColors.transparent),
            ),
          ),
        ],
      );
    }

    return Container(color: AppColors.black);
  }

  Widget _buildVignetteOverlay() {
    return IgnorePointer(
      child: Column(
        children: [
          // Top gradient for status bar / skip button
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Spacer(),
          // Bottom subtle gradient for Watch Now button
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipBadge() {
    return GestureDetector(
      key: const ValueKey('intro_poster_skip_button'),
      onTap: _proceedToTarget,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_countdown Skip',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchNowButton() {
    return Center(
      child: GestureDetector(
        key: const ValueKey('intro_poster_watch_now_button'),
        onTap: _onWatchNowTapped,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 260,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF140508), // sleek dark container with subtle crimson gloss
                Color(0xFF000000), // deep pitch black
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.bloodRedBright,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bloodRed.withValues(alpha: 0.52),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bloodRed,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bloodRedGlow,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _config.actionText.isNotEmpty ? _config.actionText : 'Watch Now',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
