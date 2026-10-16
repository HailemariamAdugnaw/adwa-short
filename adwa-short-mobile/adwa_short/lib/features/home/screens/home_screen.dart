import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../models/series.dart';
import '../providers/category_provider.dart';
import '../providers/shelf_provider.dart';
import '../widgets/category_tab_bar.dart';
import '../widgets/home_shelf_section.dart';
import '../widgets/search_bar_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenSearch,
    this.onOpenSeries,
    this.onWatchSeries,
  });

  final VoidCallback? onOpenSearch;

  final void Function(Series series)? onOpenSeries;

  final void Function(Series series)? onWatchSeries;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shelves = context.read<ShelfProvider>();
      final cats = context.read<CategoryProvider>();
      if (shelves.status == ShelfLoadStatus.idle) shelves.load();
      if (cats.status == CategoryLoadStatus.idle) cats.load();
    });
  }

  Future<void> _onRefresh() async {
    final shelves = context.read<ShelfProvider>();
    final cats = context.read<CategoryProvider>();
    final futures = <Future<void>>[
      shelves.load(refresh: true),
      cats.load(),
    ];
    if (cats.isFiltering) {
      futures.add(cats.loadFilteredSeries(refresh: true));
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.bloodRed,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _categories()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              _body(),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.display3.copyWith(fontSize: 22),
                    children: const [
                      TextSpan(
                          text: 'ADWA',
                          style: TextStyle(color: AppColors.white)),
                      TextSpan(
                          text: ' SHORT',
                          style: TextStyle(color: AppColors.bloodRedBright)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text('Premium short drama',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textSecondary),
            onPressed: () {

            },
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SearchBarWidget(onTap: widget.onOpenSearch),
    );
  }

  Widget _categories() {
    final cat = context.watch<CategoryProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBar(),
        CategoryTabBar(
          categories: cat.categories,
          selectedId: cat.selectedId,
          onSelected: cat.select,
        ),
      ],
    );
  }

  Widget _body() {
    final cat = context.watch<CategoryProvider>();
    if (cat.isFiltering) {
      return _filteredBody(cat);
    }
    final shelves = context.watch<ShelfProvider>();
    switch (shelves.status) {
      case ShelfLoadStatus.idle:
      case ShelfLoadStatus.loading:
        return const SliverToBoxAdapter(child: HomeLoadingView());
      case ShelfLoadStatus.error:
        return SliverToBoxAdapter(
          child: ErrorView(
            message: shelves.errorMessage ?? 'Failed to load shelves',
            onRetry: () => shelves.load(),
          ),
        );
      case ShelfLoadStatus.refreshing:
      case ShelfLoadStatus.success:
        if (shelves.shelves.isEmpty) {
          return const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'No content yet',
              message: 'Check back later for new releases',
            ),
          );
        }
        return SliverList.builder(
          itemCount: shelves.shelves.length,
          itemBuilder: (_, i) {
            final shelf = shelves.shelves[i];
            return HomeShelfSection(
              shelf: shelf,
              onItemTap: widget.onOpenSeries,
              onWatchNow: widget.onWatchSeries,
            );
          },
        );
    }
  }

  Widget _filteredBody(CategoryProvider cat) {
    switch (cat.seriesStatus) {
      case CategorySeriesStatus.idle:
      case CategorySeriesStatus.loading:
        return const SliverToBoxAdapter(child: HomeLoadingView());
      case CategorySeriesStatus.error:
        return SliverToBoxAdapter(
          child: ErrorView(
            message: cat.seriesError ?? 'Failed to load series',
            onRetry: () => cat.loadFilteredSeries(refresh: true),
          ),
        );
      case CategorySeriesStatus.refreshing:
      case CategorySeriesStatus.success:
        if (cat.filteredSeries.isEmpty) {
          return SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'No series in this category',
              message: 'Try another category or check back later',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.48,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int i) {
                final s = cat.filteredSeries[i];
                return PosterCard(
                  series: s,
                  width: double.infinity,
                  onTap: widget.onOpenSeries != null
                      ? () => widget.onOpenSeries!(s)
                      : null,
                );
              },
              childCount: cat.filteredSeries.length,
            ),
          ),
        );
    }
  }
}
