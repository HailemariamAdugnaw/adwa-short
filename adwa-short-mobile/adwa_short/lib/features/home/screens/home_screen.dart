import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/poster_card.dart';
import '../../../core/widgets/shelf_banner.dart';
import '../../../models/series.dart';
import '../providers/category_provider.dart';
import '../providers/shelf_provider.dart';
import '../widgets/category_tab_bar.dart';
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
  static const double _pinnedFooterGap = 88.0;

  String _selectedTab = 'popular';
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0.0;
  bool _shelvesApplied = false;

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
    final isShelfTab = _selectedTab == 'popular' ||
        _selectedTab == 'hot' ||
        _selectedTab == 'new';
    if (isShelfTab) {
      _shelvesApplied = false;
    }
    final futures = <Future<void>>[
      shelves.load(refresh: true),
      cats.load(),
    ];
    if (!isShelfTab) {
      futures.add(cats.selectCategory(_selectedTab, refresh: true));
    }
    await Future.wait(futures);
    if (!mounted) return;
    if (isShelfTab) {
      _applyShelfTab();
    }
  }

  void _applyShelfTab() {
    final shelves = context.read<ShelfProvider>();
    final cat = context.read<CategoryProvider>();
    if (shelves.status != ShelfLoadStatus.success &&
        shelves.status != ShelfLoadStatus.refreshing) {
      return;
    }
    final items = _shelfItemsFor(shelves);
    if (items == null) return;
    cat.setShelfTab(_selectedTab, items);
    _shelvesApplied = true;
  }

  List<Series>? _shelfItemsFor(ShelfProvider shelves) {
    if (shelves.shelves.isEmpty) return null;
    final key = _selectedTab == 'new' ? 'new_releases' : _selectedTab;
    for (final s in shelves.shelves) {
      if (s.key == key) return s.items;
    }
    return null;
  }

  Future<void> _onTabSelected(String id) async {
    setState(() => _selectedTab = id);
    final cat = context.read<CategoryProvider>();
    if (id == 'popular' || id == 'hot' || id == 'new') {
      final shelves = context.read<ShelfProvider>();
      final items = _shelfItemsFor(shelves);
      if (items != null) {
        cat.setShelfTab(id, items);
      } else {
        await shelves.load(refresh: true);
        if (!mounted) return;
        final retryItems = _shelfItemsFor(shelves);
        if (retryItems != null) {
          cat.setShelfTab(id, retryItems);
        }
      }
      return;
    }
    await cat.selectCategory(id);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final cat = context.watch<CategoryProvider>();
    final shelves = context.watch<ShelfProvider>();
    if (!_shelvesApplied &&
        (shelves.status == ShelfLoadStatus.success ||
            shelves.status == ShelfLoadStatus.refreshing) &&
        shelves.shelves.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyShelfTab();
      });
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.black,
      body: RefreshIndicator(
        color: AppColors.bloodRed,
        backgroundColor: AppColors.surfaceElevated,
        edgeOffset: topInset + _pinnedFooterGap,
        onRefresh: _onRefresh,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _hero()),
                _body(cat, shelves),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _PinnedHeader(
                opacity: _headerOpacity,
                searchBar: OverlaySearchBar(
                  onTap: widget.onOpenSearch,
                  onFilterTap: widget.onOpenSearch,
                ),
                categoryBar: CategoryTabBar(
                  categories: cat.categories,
                  selectedId: _selectedTab,
                  onSelected: (id) {
                    _onTabSelected(id);
                  },
                ),
              ),
            ),
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
      child: heroChild,
    );
  }

  Widget _body(CategoryProvider cat, ShelfProvider shelves) {
    final isShelfTab =
        _selectedTab == 'popular' || _selectedTab == 'hot' || _selectedTab == 'new';
    if (isShelfTab) {
      return _shelfTabBody(shelves);
    }
    return _categoryBody(cat);
  }

  Widget _shelfTabBody(ShelfProvider shelves) {
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
        final items = _shelfItemsFor(shelves) ?? <Series>[];
        if (items.isEmpty) {
          return const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'No content yet',
              message: 'Check back later for new releases',
            ),
          );
        }
        return _gridBody(items);
    }
  }

  Widget _categoryBody(CategoryProvider cat) {
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
        return _gridBody(cat.filteredSeries);
    }
  }

  Widget _gridBody(List<Series> items) {
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
            final s = items[i];
            return PosterCard(
              series: s,
              width: double.infinity,
              onTap: widget.onWatchSeries != null
                  ? () => widget.onWatchSeries!(s)
                  : null,
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

class _PinnedHeader extends StatelessWidget {
  const _PinnedHeader({
    required this.opacity,
    required this.searchBar,
    required this.categoryBar,
  });

  final double opacity;
  final Widget searchBar;
  final Widget categoryBar;

  @override
  Widget build(BuildContext context) {
    final clamped = opacity.clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.transparent, AppColors.black, clamped),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withValues(alpha: clamped),
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          searchBar,
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: categoryBar,
          ),
        ],
      ),
    );
  }
}
