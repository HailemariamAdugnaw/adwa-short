import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/series.dart';
import '../network/api_client.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'loading_shimmer.dart';
import 'tag_chip.dart';

class ShelfBanner extends StatefulWidget {
  const ShelfBanner({
    super.key,
    required this.items,
    this.onItemTap,
    this.onWatchNow,
    this.autoPlay = true,
    this.duration = const Duration(seconds: 5),
    this.immersive = false,
    this.height,
  });

  final List<Series> items;
  final void Function(Series)? onItemTap;
  final void Function(Series)? onWatchNow;
  final bool autoPlay;
  final Duration duration;
  final bool immersive;
  final double? height;

  @override
  State<ShelfBanner> createState() => _ShelfBannerState();
}

class _ShelfBannerState extends State<ShelfBanner> {
  late final PageController _controller;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.immersive ? 1.0 : 0.92);
    if (widget.autoPlay) _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!mounted || !widget.autoPlay || widget.items.length < 2) return;
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final height = widget.height ??
        (widget.immersive
            ? 440.0
            : MediaQuery.of(context).size.width * 9 / 16 + 24);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _scheduleNext();
            },
            itemBuilder: (_, i) {
              final s = widget.items[i];
              return widget.immersive
                  ? _BannerCard(
                      series: s,
                      immersive: true,
                      onTap: widget.onItemTap != null
                          ? () => widget.onItemTap!(s)
                          : null,
                      onWatchNow: widget.onWatchNow != null
                          ? () => widget.onWatchNow!(s)
                          : null,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _BannerCard(
                        series: s,
                        immersive: false,
                        onTap: widget.onItemTap != null
                            ? () => widget.onItemTap!(s)
                            : null,
                        onWatchNow: widget.onWatchNow != null
                            ? () => widget.onWatchNow!(s)
                            : null,
                      ),
                    );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.immersive ? 14 : 0,
            child: _dots(),
          ),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.items.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.bloodRed
                : (widget.immersive
                    ? Colors.white.withValues(alpha: 0.35)
                    : AppColors.surfaceElevated),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.series,
    required this.immersive,
    this.onTap,
    this.onWatchNow,
  });

  final Series series;
  final bool immersive;
  final VoidCallback? onTap;
  final VoidCallback? onWatchNow;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = ApiClient.resolveMediaUrl(series.bannerUrl);
    final card = Stack(
      fit: StackFit.expand,
      children: [
        bannerUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const LoadingShimmer(),
                errorWidget: (_, __, ___) => _fallback(series),
              )
            : _fallback(series),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: immersive
                    ? [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ]
                    : [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        if (!immersive)
          Positioned(
            top: 12,
            left: 12,
            child: Wrap(
              spacing: 6,
              children: [
                if (series.isHot) const TagChip.hot(),
                if (series.isVip) const TagChip.vip(),
                if (series.isExclusive) const TagChip.exclusive(),
                if (series.isNewRelease) const TagChip.newRelease(),
              ],
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: immersive ? 36 : 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                series.title,
                style: immersive
                    ? const TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      )
                    : AppTextStyles.h1,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onWatchNow != null) _WatchNowButton(onTap: onWatchNow!),
                  if (series.totalEpisodes > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${series.totalEpisodes} EP',
                      style: AppTextStyles.caption.copyWith(
                        color: immersive
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: immersive
          ? card
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: card,
            ),
    );
  }

  Widget _fallback(Series s) {
    final posterUrl = ApiClient.resolveMediaUrl(s.posterUrl);
    if (posterUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: posterUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const LoadingShimmer(),
        errorWidget: (_, __, ___) =>
            Container(color: AppColors.surfaceElevated),
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.walletCardGradient,
      ),
      child: Center(
        child: Icon(Icons.movie_outlined,
            color: AppColors.textTertiary, size: 48),
      ),
    );
  }
}

class _WatchNowButton extends StatelessWidget {
  const _WatchNowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.bloodRed,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.bloodRedGlow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded,
                color: AppColors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              'Watch Now',
              style: AppTextStyles.label.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
