import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/category.dart';

class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.overlay = false,
  });

  final List<AdwaCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final bool overlay;

  static const _allId = 'all';

  @override
  Widget build(BuildContext context) {
    final items = <_TabItem>[
      const _TabItem(id: _allId, label: 'All'),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          final active = item.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.bloodRed
                    : (overlay
                        ? Colors.black.withValues(alpha: 0.4)
                        : AppColors.surfaceElevated),
                borderRadius: BorderRadius.circular(20),
                border: active
                    ? null
                    : Border.all(
                        color: overlay
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.border,
                        width: 1,
                      ),
              ),
              alignment: Alignment.center,
              child: Text(
                item.label,
                style: AppTextStyles.label.copyWith(
                  color: active
                      ? AppColors.white
                      : (overlay
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary),
                  fontSize: 13,
                ),
              ),
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
