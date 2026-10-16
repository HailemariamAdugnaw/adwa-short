import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/series.dart';
import '../providers/my_list_provider.dart';
import '../widgets/history_tab.dart';
import '../widgets/saved_tab.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({
    super.key,
    this.onOpenSeries,
    this.onOpenEpisode,
  });

  final void Function(Series series)? onOpenSeries;
  final void Function(String seriesId, String episodeId)? onOpenEpisode;

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final p = context.read<MyListProvider>();
      final i = _tabController.index;
      if (i == 0 &&
          (p.historyStatus == MyListStatus.idle ||
              p.historyStatus == MyListStatus.error)) {
        p.loadHistory(refresh: false);
      } else if (i == 1 &&
          (p.savedStatus == MyListStatus.idle ||
              p.savedStatus == MyListStatus.error)) {
        p.loadSaved(refresh: false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<MyListProvider>();
      p.loadAll(refresh: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text('My List', style: AppTextStyles.h3),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.bloodRed,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.bloodRed,
          unselectedLabelColor: AppColors.textTertiary,
          labelStyle: AppTextStyles.label,
          unselectedLabelStyle: AppTextStyles.label
              .copyWith(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Watch History'),
            Tab(text: 'Saved Videos'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            HistoryTab(onOpenEpisode: widget.onOpenEpisode),
            SavedTab(
              onOpenSeries: widget.onOpenSeries,
              onUnsave: (s) async {
                final ok = await context.read<MyListProvider>().unsaveSeries(s.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Removed from saved list'
                        : 'Could not remove series'),
                    backgroundColor:
                        ok ? AppColors.success : AppColors.error,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
