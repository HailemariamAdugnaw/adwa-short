import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';

class OverlaySearchBar extends StatelessWidget {
  const OverlaySearchBar({
    super.key,
    this.onTap,
    this.onFilterTap,
  });

  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.search,
                      color: Colors.white.withValues(alpha: 0.85), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search series, actors, tags...',
                      style: AppTextStyles.body2.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onFilterTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.tune,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
