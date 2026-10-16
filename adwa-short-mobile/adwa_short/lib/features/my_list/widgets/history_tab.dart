import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/access_check.dart';
import '../providers/my_list_provider.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, this.onOpenEpisode});

  final void Function(String seriesId, String episodeId)? onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MyListProvider>();
    switch (p.historyStatus) {
      case MyListStatus.idle:
      case MyListStatus.loading:
        return _skeleton();
      case MyListStatus.error:
        return ErrorView(
          message: p.historyError ?? 'Failed to load history',
          onRetry: () => p.loadHistory(refresh: true),
        );
      case MyListStatus.refreshing:
      case MyListStatus.success:
        if (p.history.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No watch history yet',
            message: 'Episodes you watch will show up here',
          );
        }
        break;
    }
    return RefreshIndicator(
      color: AppColors.bloodRed,
      onRefresh: () => p.loadHistory(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
        itemCount: p.history.length,
        separatorBuilder: (_, __) =>
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
        itemBuilder: (_, i) {
          final entry = p.history[i];
          final ep = entry.episode;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumb(ep.thumbnailUrl),
                    if (entry.progress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: entry.progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          color: AppColors.bloodRed,
                          backgroundColor: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            title: Text(
              ep.title,
              style: AppTextStyles.body1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Episode ${ep.number} · ${Formatters.clockFromSeconds(entry.lastPositionSeconds)} watched · ${(entry.progress * 100).round()}%',
              style: AppTextStyles.body3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.bloodRed, size: 32),
            onTap: () {
              onOpenEpisode?.call(ep.seriesId, ep.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildThumb(String? url) {
    final resolved = ApiClient.resolveMediaUrl(url);
    if (resolved.isEmpty) return Container(color: AppColors.surfaceElevated);
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      placeholder: (_, __) => const LoadingShimmer(),
      errorWidget: (_, __, ___) => Container(color: AppColors.surfaceElevated),
    );
  }

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            LoadingShimmer(width: 56, height: 100, borderRadius: 8),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingShimmer(width: 180, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  LoadingShimmer(width: 100, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
