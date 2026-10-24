import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/token_manager.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';
import '../../../models/short_item.dart';
import '../../shorts/widgets/paywall_overlay.dart';
import '../providers/download_provider.dart';

class DownloadButton extends StatefulWidget {
  const DownloadButton({
    super.key,
    required this.episode,
    required this.series,
    this.size = 18,
    this.color,
    this.onDownloaded,
    this.compact = false,
  });

  final Episode episode;
  final Series series;
  final double size;
  final Color? color;
  final VoidCallback? onDownloaded;
  final bool compact;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool _handling = false;

  int? get _episodeId => int.tryParse(widget.episode.id);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final epId = _episodeId;
    final isDownloaded =
        epId != null && provider.isDownloaded(epId);
    final isThisDownloading = provider.isDownloading &&
        provider.downloadingEpisodeId == epId;

    final Color color = widget.color ?? AppColors.white;
    final double size = widget.size;

    if (isThisDownloading) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
              widget.color ?? AppColors.bloodRed),
        ),
      );
    }

    IconData icon;
    Color iconColor;
    if (isDownloaded) {
      icon = Icons.download_done_rounded;
      iconColor = widget.color ?? AppColors.success;
    } else {
      icon = Icons.download_rounded;
      iconColor = color;
    }

    return GestureDetector(
      onTap: isThisDownloading ? null : _onTap,
      behavior: HitTestBehavior.opaque,
      child: widget.compact
          ? Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: iconColor, size: size),
            )
          : Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: size),
                  const SizedBox(width: 6),
                  Text(
                    isDownloaded ? 'Downloaded' : 'Download',
                    style: AppTextStyles.label.copyWith(
                      color: iconColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _onTap() async {
    if (_handling) return;
    final epId = _episodeId;
    if (epId == null) return;
    final provider = context.read<DownloadProvider>();
    if (provider.isDownloading) return;
    if (provider.isDownloaded(epId)) {
      _showSnack('Already downloaded', AppColors.success);
      return;
    }
    final tokenManager = context.read<TokenManager>();
    final authToken = tokenManager.accessToken;
    if (authToken == null || authToken.isEmpty) {
      _showSnack('Please log in to download', AppColors.error);
      return;
    }
    _handling = true;
    try {
      final ok = await provider.downloadEpisode(
        widget.episode,
        widget.series,
        authToken,
      );
      if (!mounted) return;
      if (ok) {
        _showSnack('Downloaded', AppColors.success);
        widget.onDownloaded?.call();
      } else if (provider.status == DownloadStatus.accessDenied) {
        _showPaywall();
        provider.resetStatus();
      } else {
        _showSnack(
          provider.errorMessage.isNotEmpty
              ? provider.errorMessage
              : 'Download failed',
          AppColors.error,
        );
        provider.resetStatus();
      }
    } finally {
      _handling = false;
    }
  }

  void _showSnack(String message, Color background) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: background,
        content: Text(
          message,
          style: AppTextStyles.body3.copyWith(color: AppColors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPaywall() {
    final item = ShortItem(
      id: widget.episode.id,
      seriesId: widget.series.id,
      episodeId: widget.episode.id,
      title: widget.episode.title,
      verticalVideoUrl: widget.episode.videoUrl ?? '',
      description: widget.episode.description,
      isAccessible: false,
      accessReason: widget.episode.accessReason,
      episodeNumber: widget.episode.number,
      seriesTitle: widget.series.title,
      totalEpisodes: widget.series.totalEpisodes,
      thumbnailUrl: widget.episode.thumbnailUrl,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (innerContext) => Scaffold(
          backgroundColor: AppColors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PaywallOverlay(
                  item: item,
                  onBuyCoins: () => Navigator.of(innerContext)
                      .pushNamed('/wallet/coins'),
                  onBuyPass: () => Navigator.of(innerContext)
                      .pushNamed('/wallet/passes'),
                  onSubscribe: () => Navigator.of(innerContext)
                      .pushNamed('/wallet/subscriptions'),
                  onMaybeLater: () =>
                      Navigator.of(innerContext).maybePop(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.white),
                    onPressed: () =>
                        Navigator.of(innerContext).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
