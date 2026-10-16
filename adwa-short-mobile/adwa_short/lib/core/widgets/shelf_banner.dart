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
    this.autoPlay = true,
    this.duration = const Duration(seconds: 6),
  });

  final List<Series> items;
  final void Function(Series)? onItemTap;
  final bool autoPlay;
  final Duration duration;

  @override
  State<ShelfBanner> createState() => _ShelfBannerState();
}

class _ShelfBannerState extends State<ShelfBanner> {
  late final PageController _controller;
  int _index = 0;
  int _nextPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    if (widget.autoPlay) _scheduleNext();
  }

  void _scheduleNext() {
    if (!mounted || !widget.autoPlay || widget.items.length < 2) return;
    Future.delayed(widget.duration, () {
      if (!mounted) return;
      _nextPage = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        _nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final height = MediaQuery.of(context).size.width * 9 / 16 + 24;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _scheduleNext();
            },
            itemBuilder: (_, i) {
              final s = widget.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _BannerCard(
                  series: s,
                  onTap: widget.onItemTap != null
                      ? () => widget.onItemTap!(s)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _dots(),
      ],
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
            color: active ? AppColors.bloodRed : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.series, this.onTap});

  final Series series;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bannerUrl = ApiClient.resolveMediaUrl(series.bannerUrl);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
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
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
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
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    series.title,
                    style: AppTextStyles.h1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (series.description.isNotEmpty)
                    Text(
                      series.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body2,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
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
                            Text(
                              'Watch Now',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.white),
                            ),
                          ],
                        ),
                      ),
                      if (series.totalEpisodes > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${series.totalEpisodes} Episodes',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.walletCardGradient,
      ),
      child: Center(
        child: Icon(Icons.movie_outlined,
            color: AppColors.textTertiary, size: 48),
      ),
    );
  }
}
