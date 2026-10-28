import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/adwa_button.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../../models/series.dart';
import '../../auth/providers/auth_provider.dart';
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

  bool _isAuth(BuildContext context, {bool listen = false}) {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: listen);
      return auth.isAuthenticated;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (!_isAuth(context, listen: false)) return;
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
      if (_isAuth(context, listen: false)) {
        final p = context.read<MyListProvider>();
        p.loadAll(refresh: false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = _isAuth(context, listen: true);
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text('My List', style: AppTextStyles.h3),
        bottom: isAuth
            ? TabBar(
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
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: !isAuth
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bloodRed.withValues(alpha: 0.15),
                          border:
                              Border.all(color: AppColors.bloodRed, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66C8102E),
                              blurRadius: 22,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bookmark_border_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Keep Track of Your Favorites',
                        style: AppTextStyles.h2
                            .copyWith(color: AppColors.white, fontSize: 19),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in to save your favorite series, track your watch history, and resume where you left off.',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 26),
                      AdwaButton(
                        label: 'Sign In / Register',
                        icon: Icons.login_rounded,
                        expanded: true,
                        onPressed: () async {
                          final ok = await GuestAuthPrompt.show(
                            context,
                            title: 'Sign In to View My List',
                            message:
                                'Please sign in or register to view your watch history and saved series.',
                          );
                          if (ok && mounted) {
                            context
                                .read<MyListProvider>()
                                .loadAll(refresh: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  HistoryTab(onOpenEpisode: widget.onOpenEpisode),
                  SavedTab(
                    onOpenSeries: widget.onOpenSeries,
                    onUnsave: (s) async {
                      final ok = await context
                          .read<MyListProvider>()
                          .unsaveSeries(s.id);
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
