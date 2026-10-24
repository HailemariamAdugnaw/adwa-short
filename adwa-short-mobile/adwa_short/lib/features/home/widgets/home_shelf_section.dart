import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/shelf_banner.dart';
import '../../../core/widgets/shelf_row.dart';
import '../../../models/shelf.dart';
import '../../../models/series.dart';

class HomeShelfSection extends StatelessWidget {
  const HomeShelfSection({
    super.key,
    required this.shelf,
    this.onItemTap,
    this.onWatchNow,
    this.onSeeAll,
  });

  final Shelf shelf;
  final void Function(Series series)? onItemTap;
  final void Function(Series series)? onWatchNow;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (shelf.items.isEmpty) return const SizedBox.shrink();
    final isBanner = shelf.type == ShelfType.banner || shelf.key == ShelfKeys.hot;
    if (isBanner) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bloodRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(shelf.title, style: AppTextStyles.h3),
                  const Spacer(),
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.bloodRed, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShelfBanner(
              items: shelf.items,
              onItemTap: onItemTap,
              onWatchNow: onWatchNow,
            ),
          ],
        ),
      );
    }
    return ShelfRow(
      title: shelf.title,
      items: shelf.items,
      onItemTap: onItemTap,
      onSeeAll: onSeeAll,
    );
  }
}
