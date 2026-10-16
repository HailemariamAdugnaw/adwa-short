import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color = AppColors.bloodRed,
    this.icon,
    this.onTap,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool outlined;

  const TagChip.hot({super.key, this.label = 'HOT', this.onTap})
      : color = AppColors.bloodRed,
        icon = Icons.whatshot_rounded,
        outlined = false;

  const TagChip.vip({super.key, this.onTap})
      : label = 'VIP',
        color = AppColors.vipGold,
        icon = Icons.workspace_premium_rounded,
        outlined = false;

  const TagChip.exclusive({super.key, this.onTap})
      : label = 'EXCLUSIVE',
        color = AppColors.exclusivePurple,
        icon = Icons.bolt_rounded,
        outlined = false;

  const TagChip.newRelease({super.key, this.onTap})
      : label = 'NEW',
        color = AppColors.bloodRedBright,
        icon = Icons.fiber_new_rounded,
        outlined = false;

  const TagChip.trending({super.key, this.onTap})
      : label = 'TRENDING',
        color = AppColors.bloodRed,
        icon = Icons.trending_up_rounded,
        outlined = false;

  const TagChip.popular({super.key, this.onTap})
      : label = 'POPULAR',
        color = AppColors.bloodRedDark,
        icon = Icons.local_fire_department_rounded,
        outlined = false;

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.transparent : color;
    final fg = outlined ? color : AppColors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: outlined ? Border.all(color: color, width: 1.2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 11),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: AppTextStyles.overline.copyWith(
                  color: fg,
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
