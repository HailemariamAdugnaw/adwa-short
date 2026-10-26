import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../features/series/providers/series_provider.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';

class EpisodeSelectorSheet extends StatefulWidget {
  const EpisodeSelectorSheet({
    super.key,
    required this.seriesId,
    this.currentEpisodeId,
    this.currentEpisodeNumber,
    this.onEpisodeSelected,
    this.onSelectEpisode,
  });

  final String seriesId;
  final String? currentEpisodeId;
  final int? currentEpisodeNumber;
  final void Function(Episode episode)? onEpisodeSelected;
  final void Function(Episode episode)? onSelectEpisode;

  static Future<void> show(
    BuildContext context, {
    required String seriesId,
    String? currentEpisodeId,
    int? currentEpisodeNumber,
    void Function(Episode episode)? onEpisodeSelected,
    void Function(Episode episode)? onSelectEpisode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => EpisodeSelectorSheet(
        seriesId: seriesId,
        currentEpisodeId: currentEpisodeId,
        currentEpisodeNumber: currentEpisodeNumber,
        onEpisodeSelected: onEpisodeSelected,
        onSelectEpisode: onSelectEpisode,
      ),
    );
  }

  @override
  State<EpisodeSelectorSheet> createState() => _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends State<EpisodeSelectorSheet> {
  int _activeTab = 0;
  bool _loading = true;
  Series? _series;

  static const int _perPage = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSeries());
  }

  Future<void> _loadSeries() async {
    final provider = context.read<SeriesProvider>();
    await provider.load(widget.seriesId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _series = provider.series;
    });
    _initActiveTab();
  }

  void _initActiveTab() {
    final s = _series;
    if (s == null) return;
    final epNum = widget.currentEpisodeNumber;
    if (epNum == null || epNum <= 0) return;
    final tabIndex = ((epNum - 1) ~/ _perPage).clamp(0, _tabCount(s) - 1);
    if (tabIndex != _activeTab) {
      setState(() => _activeTab = tabIndex);
    }
  }

  int _tabCount(Series s) {
    final total = s.episodes.isNotEmpty
        ? s.episodes.length
        : s.totalEpisodes;
    if (total <= 0) return 1;
    return ((total - 1) ~/ _perPage) + 1;
  }

  List<Episode> _episodesForTab(Series s) {
    if (s.episodes.isEmpty) return const [];
    final start = _activeTab * _perPage;
    final end = (start + _perPage).clamp(0, s.episodes.length);
    if (start >= s.episodes.length) return const [];
    return s.episodes.sublist(start, end);
  }

  String _rangeLabel(int tab) {
    final start = tab * _perPage + 1;
    final total = _series?.episodes.length ??
        _series?.totalEpisodes ??
        0;
    final end = (start + _perPage - 1).clamp(start, total > 0 ? total : start);
    return '$start-$end';
  }

  bool _isCurrent(Episode ep) {
    if (widget.currentEpisodeId != null && ep.id == widget.currentEpisodeId) {
      return true;
    }
    if (widget.currentEpisodeNumber != null &&
        ep.number == widget.currentEpisodeNumber) {
      return true;
    }
    return false;
  }

  bool _isLocked(Episode ep) {
    if (ep.isFree) return false;
    if (ep.isAccessible == true) return false;
    if (ep.accessible) return false;
    if (ep.effectivelyAccessible) return false;
    final freeCount = _series?.freeEpisodeCount ?? 0;
    if (ep.number > 0 && ep.number <= freeCount) return false;
    if (ep.isLocked) return true;
    if (ep.isAccessible == false) return true;
    return ep.number > freeCount;
  }

  String _latestUpdateLabel(Series s) {
    final total = s.episodes.isNotEmpty
        ? s.episodes.length
        : s.totalEpisodes;
    if (total <= 0) return 'No episodes yet';
    return 'Update to EP.$total/EP.$total';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.7;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _grabber(),
          if (_loading || _series == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.bloodRed,
                ),
              ),
            )
          else ...[
            _header(_series!),
            const Divider(color: AppColors.divider, height: 1),
            _tabs(_series!),
            const Divider(color: AppColors.divider, height: 1),
            Flexible(
              child: _episodesGrid(_series!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grabber() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _header(Series s) {
    final posterUrl = ApiClient.resolveMediaUrl(s.posterUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 60,
              height: 90,
              child: posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const LoadingShimmer(borderRadius: 6),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.surfaceElevated),
                    )
                  : Container(color: AppColors.surfaceElevated),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.title,
                  style: AppTextStyles.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _latestUpdateLabel(s),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (s.category != null && s.category!.isNotEmpty)
                      _genreTag(s.category!),
                    if (s.tags.isNotEmpty)
                      _genreTag(s.tags.first),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _genreTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _tabs(Series s) {
    final count = _tabCount(s);
    if (count <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _activeTab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.bloodRed
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: active
                    ? null
                    : Border.all(color: AppColors.border, width: 0.6),
              ),
              child: Center(
                child: Text(
                  _rangeLabel(i),
                  style: AppTextStyles.label.copyWith(
                    color: active ? AppColors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _episodesGrid(Series s) {
    final episodes = _episodesForTab(s);
    if (episodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No episodes in this range',
            style: AppTextStyles.body3,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: episodes.length,
      itemBuilder: (_, i) {
        final ep = episodes[i];
        final isCurrent = _isCurrent(ep);
        final locked = _isLocked(ep);
        return _EpisodeButton(
          episode: ep,
          isCurrent: isCurrent,
          isLocked: locked,
          onTap: () {
            widget.onEpisodeSelected?.call(ep);
            widget.onSelectEpisode?.call(ep);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _EpisodeButton extends StatelessWidget {
  const _EpisodeButton({
    required this.episode,
    required this.isCurrent,
    required this.isLocked,
    required this.onTap,
  });

  final Episode episode;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isCurrent
        ? AppColors.bloodRed
        : AppColors.surfaceElevated;
    final fg = isCurrent ? AppColors.white : AppColors.white;
    final borderColor = isCurrent ? AppColors.bloodRed : AppColors.border;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Stack(
          children: [
            Center(
              child: isCurrent
                  ? const _EqualizerIndicator()
                  : Text(
                      '${episode.number}',
                      style: AppTextStyles.label.copyWith(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (isLocked && !isCurrent)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.textSecondary,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EqualizerIndicator extends StatefulWidget {
  const _EqualizerIndicator();

  @override
  State<_EqualizerIndicator> createState() => _EqualizerIndicatorState();
}

class _EqualizerIndicatorState extends State<_EqualizerIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(0, 0.4, 1.0),
            const SizedBox(width: 3),
            _bar(1, 0.7, 1.0),
            const SizedBox(width: 3),
            _bar(2, 0.3, 0.9),
          ],
        );
      },
    );
  }

  Widget _bar(int index, double startHeight, double endHeight) {
    final phase = (_controller.value + index * 0.33) % 1.0;
    final ping = phase < 0.5 ? phase * 2 : 2 - phase * 2;
    final h = 6.0 + (startHeight + (endHeight - startHeight) * ping) * 12;
    return Container(
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
