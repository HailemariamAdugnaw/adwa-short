import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/series.dart';
import '../network/api_client.dart';
import '../theme/colors.dart';
import 'loading_shimmer.dart';

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
            ? 340.0
            : MediaQuery.of(context).size.width * 9 / 16 + 24);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            dragStartBehavior: DragStartBehavior.down,
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
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _BannerCard(
                        series: s,
                        immersive: false,
                        onTap: widget.onItemTap != null
                            ? () => widget.onItemTap!(s)
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
  });

  final Series series;
  final bool immersive;
  final VoidCallback? onTap;

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
      ],
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
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
