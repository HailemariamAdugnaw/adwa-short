import 'package:flutter/material.dart';

import '../../models/series.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'poster_card.dart';

class ShelfRow extends StatelessWidget {
  const ShelfRow({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.onItemTap,
    this.maxItems = 9,
    this.accent = AppColors.bloodRed,
  });

  final String title;
  final List<Series> items;
  final VoidCallback? onSeeAll;
  final void Function(Series)? onItemTap;
  final int maxItems;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final display = items.length > maxItems ? items.sublist(0, maxItems) : items;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          title,
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See All',
                      style: AppTextStyles.caption
                          .copyWith(color: accent, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.48,
            ),
            itemCount: display.length,
            itemBuilder: (_, i) {
              final s = display[i];
              return PosterCard(
                series: s,
                onTap: onItemTap != null ? () => onItemTap!(s) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
