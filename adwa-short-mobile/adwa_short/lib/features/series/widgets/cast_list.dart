import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/series.dart';

class CastList extends StatelessWidget {
  const CastList({super.key, required this.cast});

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.bloodRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Cast & Crew', style: AppTextStyles.h4),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final c = cast[i];
              final resolved = ApiClient.resolveMediaUrl(c.avatarUrl);
              return SizedBox(
                width: 76,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: resolved.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: resolved,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const LoadingShimmer(
                                        borderRadius: 32),
                                errorWidget: (_, __, ___) =>
                                    _avatarFallback(c.name),
                              )
                            : _avatarFallback(c.name),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (c.role != null && c.role!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          c.role!,
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
