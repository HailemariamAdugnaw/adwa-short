import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../models/series.dart';
import '../providers/my_list_provider.dart';

class SavedTab extends StatelessWidget {
  const SavedTab({super.key, this.onOpenSeries, this.onUnsave});

  final void Function(Series series)? onOpenSeries;
  final void Function(Series series)? onUnsave;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MyListProvider>();
    switch (p.savedStatus) {
      case MyListStatus.idle:
      case MyListStatus.loading:
        return _skeleton();
      case MyListStatus.error:
        return ErrorView(
          message: p.savedError ?? 'Failed to load saved series',
          onRetry: () => p.loadSaved(refresh: true),
        );
      case MyListStatus.refreshing:
      case MyListStatus.success:
        if (p.saved.isEmpty) {
          return const EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved series yet',
            message: 'Bookmark series from the home screen to find them here',
          );
        }
        break;
    }
    return RefreshIndicator(
      color: AppColors.bloodRed,
      onRefresh: () => p.loadSaved(refresh: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.48,
        ),
        itemCount: p.saved.length,
        itemBuilder: (_, i) {
          final s = p.saved[i];
          return Stack(
            children: [
              PosterCard(
                series: s,
                width: double.infinity,
                onTap: onOpenSeries != null ? () => onOpenSeries!(s) : null,
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onUnsave != null ? () => onUnsave!(s) : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_remove_outlined,
                        color: AppColors.bloodRed, size: 18),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _skeleton() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.48,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => const LoadingShimmer(
        borderRadius: 10,
      ),
    );
  }
}
