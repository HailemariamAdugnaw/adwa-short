import 'package:flutter/material.dart';

import '../../../core/widgets/unified_video_player.dart';
import '../../../models/short_item.dart';

class ShortVideoItem extends StatelessWidget {
  const ShortVideoItem({
    super.key,
    required this.item,
    this.totalEpisodes,
    this.isAccessible = true,
    this.accessReason,
    this.onSave,
    this.onShowEpisodes,
    this.onRate,
    this.onReviews,
    this.onShare,
    this.onSearch,
    this.onWatchFull,
    this.onUnlockAds,
    this.onBuyCoins,
    this.onBuyPass,
    this.onSubscribe,
    this.onMaybeLater,
  });

  final ShortItem item;
  final int? totalEpisodes;
  final bool isAccessible;
  final String? accessReason;
  final VoidCallback? onSave;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onRate;
  final VoidCallback? onReviews;
  final VoidCallback? onShare;
  final VoidCallback? onSearch;
  final VoidCallback? onWatchFull;
  final VoidCallback? onUnlockAds;
  final VoidCallback? onBuyCoins;
  final VoidCallback? onBuyPass;
  final VoidCallback? onSubscribe;
  final VoidCallback? onMaybeLater;

  @override
  Widget build(BuildContext context) {
    return UnifiedVideoPlayer(
      key: ValueKey('short_${item.id}_${item.verticalVideoUrl}_$isAccessible'),
      presentation: VideoPlayerPresentation.embedded,
      videoUrl: item.verticalVideoUrl,
      title: item.title,
      description: item.description,
      currentEpisode: 'EP.${item.episodeNumber ?? 0}',
      totalEpisodes: totalEpisodes ?? item.totalEpisodes,
      ratingCount: item.ratingCount ?? 0,
      isSaved: item.isSaved,
      onRate: onRate ?? () {},
      onReviews: onReviews,
      onEpisodes: onShowEpisodes ?? () {},
      onToggleSave: onSave ?? () {},
      onShare: onShare ?? () {},
      onWatchFull: onWatchFull,
      onSearch: onSearch,
      isLocked: !isAccessible,
      coinCost: item.coinCost,
      onUnlockAds: onUnlockAds,
      onUnlockCoins: onBuyCoins,
      onUnlockPass: onBuyPass,
      onUnlockSubscribe: onSubscribe,
      onMaybeLater: onMaybeLater,
      posterUrl: item.thumbnailUrl,
      seriesTitle: item.seriesTitle,
      episodeId: item.episodeId ?? item.id,
      accessReason: accessReason ?? item.accessReason,
      averageRating: item.averageRating,
      knownDuration: Duration(seconds: item.durationSeconds),
      autoPlay: true,
      looping: true,
    );
  }
}
