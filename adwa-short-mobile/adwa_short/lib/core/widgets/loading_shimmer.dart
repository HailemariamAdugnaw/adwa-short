import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/colors.dart';

class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 10,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemWidth = 130,
  });

  final int itemCount;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LoadingShimmer(
            width: 160,
            height: 18,
            borderRadius: 6,
          ),
        ),
        SizedBox(
          height: itemWidth * 1.5 + 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => SizedBox(
              width: itemWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingShimmer(
                    height: itemWidth * 1.5,
                    borderRadius: 10,
                  ),
                  const SizedBox(height: 8),
                  LoadingShimmer(
                      width: itemWidth * 0.8, height: 12, borderRadius: 4),
                  const SizedBox(height: 4),
                  LoadingShimmer(width: 40, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoadingShimmer(
            width: double.infinity,
            height: 200,
            borderRadius: 14,
          ),
        ),
        const SizedBox(height: 24),
        const ShelfSkeleton(),
        const SizedBox(height: 8),
        const ShelfSkeleton(),
        const SizedBox(height: 8),
        const ShelfSkeleton(),
      ],
    );
  }
}
