import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../models/category.dart';

class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AdwaCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <_TabItem>[
      const _TabItem(id: 'popular', label: 'Popular'),
      const _TabItem(id: 'hot', label: 'Hot 🔥'),
      const _TabItem(id: 'new', label: 'New'),
      ...categories.map((AdwaCategory c) => _TabItem(id: c.id, label: c.name)),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 22),
        itemBuilder: (_, i) {
          final item = items[i];
          final active = item.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(item.id),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: active
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.6),
                    fontWeight:
                        active ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.bloodRed
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.id, required this.label});
  final String id;
  final String label;
}
