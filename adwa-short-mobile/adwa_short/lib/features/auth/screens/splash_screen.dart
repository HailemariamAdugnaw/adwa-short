import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/intro_poster_config.dart';
import '../providers/auth_provider.dart';
import 'intro_poster_screen.dart';

enum SplashPhase {
  loading,
  poster,
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  SplashPhase _phase = SplashPhase.loading;
  IntroPosterConfig? _introConfig;
  String _targetRoute = AppRoutes.welcome;
  bool _proceeded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Hold smooth branded splash state for at least 1.2s to prevent microsecond flash
    final minDisplayFuture = Future.delayed(const Duration(milliseconds: 1200));

    if (widget.onDone != null) {
      await minDisplayFuture;
      if (!mounted) return;
      widget.onDone!();
      return;
    }

    final initFuture = _runInitialization();

    // Await both minimum display and async data/image initialization
    await Future.wait([minDisplayFuture, initFuture]);

    if (!mounted || _proceeded) return;

    final rawUrl = _introConfig?.posterUrl ?? _introConfig?.bannerUrl;
    final hasActivePoster = _introConfig != null &&
        _introConfig!.enabled &&
        rawUrl != null &&
        rawUrl.trim().isNotEmpty;

    if (hasActivePoster) {
      // Seamlessly transition to the promotional poster once data and image are ready
      setState(() {
        _phase = SplashPhase.poster;
      });
    } else {
      // Fallback: gracefully bypass directly into main app entry flow
      _proceedToTarget();
    }
  }

  Future<void> _runInitialization() async {
    try {
      final auth = context.read<AuthProvider>();
      await auth.bootstrap();
      if (!mounted) return;

      _targetRoute = (auth.isAuthenticated || auth.isGuest)
          ? AppRoutes.main
          : AppRoutes.welcome;

      final client = context.read<ApiClient>();
      IntroPosterConfig? config;

      try {
        config = await _fetchPosterConfig(client)
            .timeout(const Duration(milliseconds: 3500));
      } catch (_) {
        config = null;
      }

      if (config == null || !config.enabled) {
        _introConfig = null;
        return;
      }

      final rawUrl = config.posterUrl ?? config.bannerUrl;
      if (rawUrl == null || rawUrl.trim().isEmpty) {
        _introConfig = null;
        return;
      }

      final resolvedUrl = ApiClient.resolveMediaUrl(rawUrl);
      if (resolvedUrl.isEmpty || !resolvedUrl.startsWith('http')) {
        _introConfig = null;
        return;
      }

      // Pre-cache remote image into GPU/memory so it renders instantly with 0ms delay
      if (mounted) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(resolvedUrl),
            context,
          ).timeout(const Duration(milliseconds: 2500));
          _introConfig = config;
        } catch (_) {
          // If image pre-caching fails, bypass directly to avoid broken screen
          _introConfig = null;
        }
      }
    } catch (_) {
      _introConfig = null;
    }
  }

  Future<IntroPosterConfig?> _fetchPosterConfig(ApiClient client) async {
    try {
      final res = await client.get(
        ApiConstants.promotionsSplash,
        requireAuth: false,
        parser: (json) => json is Map<String, dynamic>
            ? IntroPosterConfig.fromJson(json)
            : null,
      );
      if (res != null && res.enabled) return res;
    } catch (_) {}

    try {
      final fallback = await client.get(
        ApiConstants.featuredPoster,
        requireAuth: false,
        parser: (json) => json is Map<String, dynamic>
            ? IntroPosterConfig.fromJson(json)
            : null,
      );
      if (fallback != null && fallback.enabled) return fallback;
    } catch (_) {}

    return null;
  }

  void _proceedToTarget() {
    if (_proceeded || !mounted) return;
    _proceeded = true;
    Navigator.of(context).pushReplacementNamed(_targetRoute);
  }

  void _onWatchSeries(String seriesId) {
    if (_proceeded || !mounted) return;
    _proceeded = true;
    Navigator.of(context).pushReplacementNamed(_targetRoute);
    if (seriesId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.seriesDetail,
        arguments: seriesId,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _phase == SplashPhase.poster && _introConfig != null
          ? IntroPosterScreen(
              key: const ValueKey('splash_intro_poster_view'),
              config: _introConfig,
              targetRoute: _targetRoute,
              onSkip: _proceedToTarget,
              onWatchSeries: (seriesId) => _onWatchSeries(seriesId),
            )
          : _buildSplashLoading(context),
    );
  }

  Widget _buildSplashLoading(BuildContext context) {
    return Scaffold(
      key: const ValueKey('splash_loading_view'),
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.2,
              colors: [AppColors.bloodRedDark, AppColors.black],
              stops: [0.0, 0.7],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: _logo(),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  AppStrings.tagline,
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.bloodRedBright,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 80),
              const SizedBox(
                width: 26,
                height: 26,
                child: LoadingShimmer(
                  width: 26,
                  height: 26,
                  borderRadius: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: AppColors.bloodRed,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.bloodRedGlow,
                blurRadius: 36,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.white,
            size: 54,
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: AppTextStyles.brandLogo,
            children: [
              TextSpan(text: 'ADWA', style: TextStyle(color: AppColors.white)),
              TextSpan(
                  text: ' SHORT',
                  style: TextStyle(color: AppColors.bloodRedBright)),
            ],
          ),
        ),
      ],
    );
  }
}
