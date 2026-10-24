import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/download_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../../../core/router/app_router.dart';
import '../providers/download_provider.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().loadDownloads();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<DownloadProvider>().loadDownloads();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear all downloads?', style: AppTextStyles.h3),
        content: const Text(
          'This will remove all downloaded episodes from this device.',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bloodRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<DownloadProvider>().deleteAllDownloads();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('All downloads cleared'),
      ),
    );
  }

  Future<void> _confirmDelete(DownloadedEpisode ep) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove download?', style: AppTextStyles.h3),
        content: Text(
          '"${ep.episodeTitle}" will be removed from this device.',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bloodRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<DownloadProvider>().deleteDownload(ep.episodeId);
  }

  void _playEpisode(DownloadedEpisode ep) {
    final episode = Episode(
      id: ep.episodeId.toString(),
      seriesId: ep.seriesId.toString(),
      number: ep.episodeNumber,
      title: ep.episodeTitle,
      description: '',
      thumbnailUrl: ep.thumbnailUrl,
      videoUrl: ep.fileUri,
      durationSeconds: ep.durationSeconds,
      isFree: true,
      isLocked: false,
      accessible: true,
      isAccessible: true,
    );
    final series = Series(
      id: ep.seriesId.toString(),
      title: ep.seriesTitle ?? 'Downloaded',
      episodes: const [],
      totalEpisodes: 0,
    );
    Navigator.of(context).pushNamed(
      AppRoutes.episodePlayer,
      arguments: {'series': series, 'episode': episode},
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final downloads = provider.downloads;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text('Downloads', style: AppTextStyles.h3),
        centerTitle: false,
        actions: [
          if (downloads.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmClearAll,
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.bloodRed, size: 20),
              label: Text(
                'Clear All',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.bloodRed),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          onRefresh: _onRefresh,
          child: downloads.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.download_for_offline_outlined,
                      title: 'No downloads yet',
                      message:
                          'Download episodes to watch offline. Tap the '
                          'download icon on any unlocked episode.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: downloads.length,
                  separatorBuilder: (_, __) => const Divider(
                      color: AppColors.divider,
                      height: 1,
                      indent: 16,
                      endIndent: 16),
                  itemBuilder: (_, i) {
                    final ep = downloads[i];
                    return _DownloadTile(
                      episode: ep,
                      onTap: () => _playEpisode(ep),
                      onDelete: () => _confirmDelete(ep),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.episode,
    required this.onTap,
    required this.onDelete,
  });

  final DownloadedEpisode episode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final thumb = ApiClient.resolveMediaUrl(episode.thumbnailUrl);
    final durationLabel = episode.durationSeconds > 0
        ? Formatters.shortDuration(episode.durationSeconds ~/ 60)
        : '';
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 72,
          height: 96,
          child: thumb.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const LoadingShimmer(borderRadius: 8),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Icon(Icons.movie_outlined,
                        color: AppColors.textTertiary),
                  ),
                )
              : Container(
                  color: AppColors.surfaceElevated,
                  child: const Icon(Icons.movie_outlined,
                      color: AppColors.textTertiary),
                ),
        ),
      ),
      title: Text(
        episode.episodeTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body1,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (episode.seriesTitle != null &&
              episode.seriesTitle!.isNotEmpty)
            Text(
              episode.seriesTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body3
                  .copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'EP.${episode.episodeNumber}',
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ),
              if (durationLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(durationLabel, style: AppTextStyles.caption),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.download_done_rounded,
                  color: AppColors.success, size: 14),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.textSecondary),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
