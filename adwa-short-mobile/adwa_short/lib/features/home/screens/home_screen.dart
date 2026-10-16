import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../core/widgets/shelf_banner.dart';
import '../../../models/category.dart';
import '../../../models/series.dart';
import '../../../models/shelf.dart';
import '../providers/category_provider.dart';
import '../providers/shelf_provider.dart';
import '../widgets/category_tab_bar.dart';
import '../widgets/home_shelf_section.dart';
import '../widgets/overlay_search_bar.dart';

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
  static const double _heroHeight = 340.0;
  static const double _tabBarHeight = 48.0;

  String _selectedTab = 'popular';
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shelves = context.read<ShelfProvider>();
      final cats = context.read<CategoryProvider>();
      if (shelves.status == ShelfLoadStatus.idle) shelves.load();
      if (cats.status == CategoryLoadStatus.idle) cats.load();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final opacity = (offset / _heroHeight).clamp(0.0, 1.0);
    if ((opacity - _headerOpacity).abs() > 0.01) {
      setState(() => _headerOpacity = opacity);
    }
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

  void _onTabSelected(String id) {
    setState(() => _selectedTab = id);
    final cat = context.read<CategoryProvider>();
    if (id == 'popular' || id == 'hot' || id == 'new') {
      cat.select('all');
    } else {
      cat.select(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final cat = context.watch<CategoryProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.black,
      body: RefreshIndicator(
        color: AppColors.bloodRed,
        backgroundColor: AppColors.surfaceElevated,
        edgeOffset: topInset,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _hero()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyCategoryBarDelegate(
                categories: cat.categories,
                selectedId: _selectedTab,
                onSelected: _onTabSelected,
                statusBarHeight: topInset,
                opacity: _headerOpacity,
              ),
            ),
            _body(),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final shelves = context.watch<ShelfProvider>();
    final banner = shelves.bannerShelf;
    final Widget heroChild;
    if (banner != null && banner.items.isNotEmpty) {
      heroChild = ShelfBanner(
        items: banner.items,
        immersive: true,
        height: _heroHeight,
        onItemTap: widget.onWatchSeries,
        onWatchNow: widget.onWatchSeries,
      );
    } else if (shelves.status == ShelfLoadStatus.loading ||
        shelves.status == ShelfLoadStatus.idle) {
      heroChild = const LoadingShimmer();
    } else {
      heroChild = Container(
        color: AppColors.surfaceElevated,
        child: const Center(
          child: Icon(Icons.movie_outlined,
              color: AppColors.textTertiary, size: 48),
        ),
      );
    }
    return SizedBox(
      height: _heroHeight,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: heroChild),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: OverlaySearchBar(
              onTap: widget.onOpenSearch,
              onFilterTap: widget.onOpenSearch,
            ),
          ),
        ],
      ),
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
        final rowShelves = shelves.shelves
            .where((s) =>
                s.type != ShelfType.banner && s.key != ShelfKeys.hot)
            .toList();
        return SliverList.builder(
          itemCount: rowShelves.length,
          itemBuilder: (_, i) {
            final shelf = rowShelves[i];
            return HomeShelfSection(
              shelf: shelf,
              onItemTap: widget.onWatchSeries,
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
          return const SliverToBoxAdapter(
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
                  onTap: widget.onWatchSeries != null
                      ? () => widget.onWatchSeries!(s)
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

class _StickyCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyCategoryBarDelegate({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.statusBarHeight,
    required this.opacity,
  });

  final List<AdwaCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double statusBarHeight;
  final double opacity;

  @override
  double get minExtent => statusBarHeight + _HomeScreenState._tabBarHeight;

  @override
  double get maxExtent => statusBarHeight + _HomeScreenState._tabBarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Color.lerp(AppColors.transparent, AppColors.black, opacity),
      padding: EdgeInsets.only(top: statusBarHeight),
      alignment: Alignment.bottomCenter,
      child: CategoryTabBar(
        categories: categories,
        selectedId: selectedId,
        onSelected: onSelected,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyCategoryBarDelegate oldDelegate) {
    return categories != oldDelegate.categories ||
        selectedId != oldDelegate.selectedId ||
        onSelected != oldDelegate.onSelected ||
        statusBarHeight != oldDelegate.statusBarHeight ||
        opacity != oldDelegate.opacity;
  }
}
