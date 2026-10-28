import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/series.dart';
import '../providers/search_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.onOpenSeries,
  });

  final void Function(Series series)? onOpenSeries;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focus.requestFocus();
  }

  void _onTextChanged() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
    final p = context.read<SearchProvider>();
    p.debouncedSearch(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSubmit(String v) {
    final query = v.trim();
    if (query.isEmpty) return;
    context.read<SearchProvider>().search(query);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SearchProvider>();
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        titleSpacing: 0,
        title: _searchField(),
      ),
      body: SafeArea(
        child: _body(p),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.bloodRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: AppTextStyles.body1,
              cursorColor: AppColors.bloodRed,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSubmit,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                hintText: 'Search series, actors, tags…',
                hintStyle: AppTextStyles.body2
                    .copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_hasText)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textTertiary, size: 18),
              onPressed: () {
                _controller.clear();
                context.read<SearchProvider>().clear();
                _focus.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _body(SearchProvider p) {
    if (p.status == SearchStatus.idle) {
      return _idleView(p);
    }
    if (p.status == SearchStatus.loading) {
      return _loading();
    }
    if (p.status == SearchStatus.error) {
      return ErrorView(
        message: p.errorMessage ?? 'Search failed',
        onRetry: () => p.search(p.query),
      );
    }
    final r = p.result;
    if (r.series.isEmpty && r.actors.isEmpty && r.tags.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results for "${p.query}"',
        message: 'Try a different keyword or spelling',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (r.series.isNotEmpty) ...[
          _sectionHeader('Series', '${r.series.length}'),
          const SizedBox(height: 10),
          ...r.series.map(_seriesTile),
          const SizedBox(height: 12),
        ],
        if (r.actors.isNotEmpty) ...[
          _sectionHeader('Actors', '${r.actors.length}'),
          const SizedBox(height: 10),
          ...r.actors.map(_actorTile),
          const SizedBox(height: 12),
        ],
        if (r.tags.isNotEmpty) ...[
          _sectionHeader('Tags', '${r.tags.length}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.tags
                .map((t) => _tagChip(t['name']?.toString() ?? ''))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _idleView(SearchProvider p) {
    if (p.recentQueries.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Find your next binge',
        message: 'Search by series title, actor name, or tag',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Text('Recent searches', style: AppTextStyles.label),
            const Spacer(),
            TextButton(
              onPressed: () => context.read<SearchProvider>().clearRecent(),
              child: Text('Clear',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.bloodRed)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: p.recentQueries
              .map((q) => GestureDetector(
                    onTap: () {
                      _controller.text = q;
                      context.read<SearchProvider>().search(q);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(q, style: AppTextStyles.caption),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _loading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LoadingShimmer(height: 70, borderRadius: 10),
      ),
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.bloodRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(title, style: AppTextStyles.h4),
        const SizedBox(width: 8),
        Text('($count)', style: AppTextStyles.caption),
      ],
    );
  }

  Widget _seriesTile(Map<String, dynamic> json) {
    final series = Series.fromJson(json);
    final resolved = ApiClient.resolveMediaUrl(series.posterUrl);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 50,
          height: 70,
          child: resolved.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const LoadingShimmer(),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.surfaceElevated),
                )
              : Container(color: AppColors.surfaceElevated),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(series.title,
                style: AppTextStyles.body1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (series.isHot) ...[
            const SizedBox(width: 6),
            const TagChip.hot(),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (series.category != null) series.category,
          if (series.totalEpisodes > 0) '${series.totalEpisodes} Episodes',
        ].join(' · '),
        style: AppTextStyles.body3,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textTertiary, size: 20),
      onTap: () => widget.onOpenSeries?.call(series),
    );
  }

  Widget _actorTile(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Unknown';
    final resolved = ApiClient.resolveMediaUrl(json['avatar_url']?.toString());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: resolved.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const LoadingShimmer(borderRadius: 22),
                  errorWidget: (_, __, ___) =>
                      _avatarFallback(name),
                )
              : _avatarFallback(name),
        ),
      ),
      title: Text(name, style: AppTextStyles.body1),
      subtitle: Text(
        json['role']?.toString() ?? 'Actor',
        style: AppTextStyles.body3,
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textTertiary, size: 20),
      onTap: () {

        _controller.text = name;
        context.read<SearchProvider>().search(name);
      },
    );
  }

  Widget _avatarFallback(String name) {
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(initials.isEmpty ? '?' : initials,
          style: AppTextStyles.body1.copyWith(color: AppColors.textSecondary)),
    );
  }

  Widget _tagChip(String label) {
    return GestureDetector(
      onTap: () {
        _controller.text = label;
        context.read<SearchProvider>().search(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '# $label',
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}
