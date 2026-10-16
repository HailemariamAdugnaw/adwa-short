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
  });

  final List<AdwaCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  static const _allId = 'all';

  @override
  Widget build(BuildContext context) {
    final items = <_TabItem>[
      const _TabItem(id: _allId, label: 'All'),
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
                color: active ? AppColors.bloodRed : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: active
                    ? null
                    : Border.all(color: AppColors.border, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                item.label,
                style: AppTextStyles.label.copyWith(
                  color: active ? AppColors.white : AppColors.textSecondary,
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
