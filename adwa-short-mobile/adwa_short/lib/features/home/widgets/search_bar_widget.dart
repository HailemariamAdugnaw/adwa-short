import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppColors.bloodRed, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search series, actors, tags…',
                style:
                    AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
              ),
            ),
            const Icon(Icons.tune_rounded,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
