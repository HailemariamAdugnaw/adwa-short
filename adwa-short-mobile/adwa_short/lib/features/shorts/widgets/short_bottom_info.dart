import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/short_item.dart';

class ShortBottomInfo extends StatefulWidget {
  const ShortBottomInfo({
    super.key,
    required this.item,
    this.totalEpisodes,
    this.onShowEpisodes,
    this.previewMode = false,
    this.onWatchFull,
  });

  final ShortItem item;
  final int? totalEpisodes;
  final VoidCallback? onShowEpisodes;
  final bool previewMode;
  final VoidCallback? onWatchFull;

  @override
  State<ShortBottomInfo> createState() => _ShortBottomInfoState();
}

class _ShortBottomInfoState extends State<ShortBottomInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasDescription = item.description.trim().isNotEmpty;
    final currentEp = item.episodeNumber ?? 0;
    final total = widget.totalEpisodes ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.seriesTitle != null && item.seriesTitle!.isNotEmpty) ...[
          Text(
            item.seriesTitle!,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.bloodRedBright,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],
        Text(
          item.title,
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasDescription) ...[
          const SizedBox(height: 6),
          _descriptionRow(item.description),
        ],
        if (widget.previewMode || currentEp > 0 || total > 0) ...[
          const SizedBox(height: 12),
          widget.previewMode
              ? _watchFullButton()
              : _episodeBar(currentEp, total),
        ],
      ],
    );
  }

  Widget _watchFullButton() {
    return GestureDetector(
      onTap: widget.onWatchFull,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bloodRed,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Watch Full',
              style: AppTextStyles.label.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionRow(String description) {
    final maxLines = _expanded ? 6 : 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            description,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.white.withValues(alpha: 0.92),
              shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              _expanded ? 'Less' : 'More',
              style: AppTextStyles.label.copyWith(
                color: AppColors.bloodRedBright,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _episodeBar(int current, int total) {
    return GestureDetector(
      onTap: widget.onShowEpisodes,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.layers_rounded,
              color: AppColors.bloodRedBright,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'EP.$current / ${total > 0 ? total : '?'} EP',
              style: AppTextStyles.label.copyWith(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
