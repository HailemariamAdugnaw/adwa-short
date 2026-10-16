import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.title = 'Nothing here yet',
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String message;
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.textTertiary, size: compact ? 24 : 32),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bloodRed,
                side: const BorderSide(color: AppColors.bloodRed, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(actionLabel!, style: AppTextStyles.label),
            ),
          ],
        ],
      ),
    );
  }
}
