import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/token_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/widgets/bottom_nav_bar.dart';
import 'core/widgets/connection_lost_view.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/intro_poster_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/downloads/screens/downloads_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/my_list/screens/my_list_screen.dart';
import 'features/profile/screens/coin_store_screen.dart';
import 'features/profile/screens/devices_screen.dart';
import 'features/profile/screens/loyalty_screen.dart';
import 'features/profile/screens/passes_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/profile/screens/subscriptions_screen.dart';
import 'features/profile/screens/wallet_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/series/providers/series_provider.dart';
import 'features/series/screens/episode_player_screen.dart';
import 'features/series/screens/series_detail_screen.dart';
import 'features/shorts/screens/shorts_screen.dart';
import 'models/episode.dart';
import 'models/intro_poster_config.dart';
import 'models/series.dart';
import 'providers/app_state_provider.dart';

class AdwaShortApp extends StatelessWidget {
  const AdwaShortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADWA SHORT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (context) => const SplashScreen());
      case AppRoutes.introPoster:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => IntroPosterScreen(
            config: args?['config'] as IntroPosterConfig?,
            targetRoute:
                args?['targetRoute'] as String? ?? AppRoutes.welcome,
            onSkip: args?['onSkip'] as VoidCallback?,
            onWatchNow: args?['onWatchNow'] as VoidCallback?,
            onWatchSeries: args?['onWatchSeries'] as void Function(String)?,
          ),
        );
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (context) => const WelcomeScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (context) => const RegisterScreen());
      case AppRoutes.main:
        return MaterialPageRoute(builder: (context) => const MainShell());
      case AppRoutes.search:
        return MaterialPageRoute(
          builder: (context) =>
              SearchScreen(onOpenSeries: (s) => _openSeriesDetail(context, s)),
        );
      case AppRoutes.seriesDetail:
        final args = settings.arguments;
        String seriesId;
        if (args is String) {
          seriesId = args;
        } else if (args is Series) {
          seriesId = args.id;
        } else if (args is Map) {
          seriesId = args['series_id'] as String;
        } else {
          seriesId = '';
        }
        return MaterialPageRoute(
          builder: (context) => SeriesDetailScreen(
            seriesId: seriesId,
            onPlayEpisode: (series, episode) =>
                _openEpisodePlayer(context, series, episode),
            onOpenPasses: () =>
                Navigator.of(context).pushNamed(AppRoutes.passes),
            onOpenSubscriptions: () =>
                Navigator.of(context).pushNamed(AppRoutes.subscriptions),
          ),
        );
      case AppRoutes.episodePlayer:
        final args = settings.arguments as Map;
        return MaterialPageRoute(
          builder: (context) => EpisodePlayerScreen(
            series: args['series'] as Series,
            episode: args['episode'] as Episode,
            onNextEpisode: _nextEpisode,
            openEpisodesSheet: (args['openEpisodesSheet'] as bool?) ?? false,
          ),
        );
      case AppRoutes.wallet:
        return MaterialPageRoute(
          builder: (context) => WalletScreen(
            onBuyCoins: () =>
                Navigator.of(context).pushNamed(AppRoutes.coinStore),
            onBuyPass: () => Navigator.of(context).pushNamed(AppRoutes.passes),
            onSubscribe: () =>
                Navigator.of(context).pushNamed(AppRoutes.subscriptions),
          ),
        );
      case AppRoutes.coinStore:
        return MaterialPageRoute(builder: (context) => const CoinStoreScreen());
      case AppRoutes.passes:
        return MaterialPageRoute(builder: (context) => const PassesScreen());
      case AppRoutes.subscriptions:
        return MaterialPageRoute(
          builder: (context) => const SubscriptionsScreen(),
        );
      case AppRoutes.loyalty:
        return MaterialPageRoute(builder: (context) => const LoyaltyScreen());
      case AppRoutes.devices:
        return MaterialPageRoute(builder: (context) => const DevicesScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (context) => const SettingsScreen());
      case AppRoutes.downloads:
        return MaterialPageRoute(
          builder: (context) => const DownloadsScreen(),
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (context) => ProfileScreen(
            onOpenWallet: () =>
                Navigator.of(context).pushNamed(AppRoutes.wallet),
            onOpenCoinStore: () =>
                Navigator.of(context).pushNamed(AppRoutes.coinStore),
            onBuyPass: () => Navigator.of(context).pushNamed(AppRoutes.passes),
            onSubscribe: () =>
                Navigator.of(context).pushNamed(AppRoutes.subscriptions),
            onOpenLoyalty: () =>
                Navigator.of(context).pushNamed(AppRoutes.loyalty),
            onOpenDevices: () =>
                Navigator.of(context).pushNamed(AppRoutes.devices),
            onOpenSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onOpenDownloads: () =>
                Navigator.of(context).pushNamed(AppRoutes.downloads),
          ),
        );
      case AppRoutes.connectionLost:
        final args = settings.arguments;
        Future<void> Function()? onRetry;
        if (args is Future<void> Function()) {
          onRetry = args;
        } else if (args is VoidCallback) {
          onRetry = () async => args();
        }
        return MaterialPageRoute(
          builder: (context) => ConnectionLostScreen(onRetry: onRetry),
        );
    }
    return null;
  }

  void _openSeriesDetail(BuildContext context, Series series) {
    Navigator.of(context)
        .pushNamed(AppRoutes.seriesDetail, arguments: series.id);
  }

  void _openEpisodePlayer(
    BuildContext context,
    Series series,
    Episode episode,
  ) {
    Navigator.of(context).pushNamed(
      AppRoutes.episodePlayer,
      arguments: {'series': series, 'episode': episode},
    );
  }

  Episode? _nextEpisode(Series series, Episode current) {
    final i = series.episodes.indexWhere((e) => e.id == current.id);
    if (i == -1 || i + 1 >= series.episodes.length) return null;
    return series.episodes[i + 1];
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AppStateProvider>().syncFromAuth(auth);
      final tokenManager = context.read<TokenManager>();
      final deviceId = tokenManager.deviceId;
      if (deviceId != null) {
        context.read<AppStateProvider>().setDeviceId(deviceId);
      }
    });
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenSearch: () =>
                Navigator.of(context).pushNamed(AppRoutes.search),
            onOpenSeries: (s) =>
                Navigator.of(context)
                    .pushNamed(AppRoutes.seriesDetail, arguments: s.id),
            onWatchSeries: (s) => _watchSeries(s),
          ),
          ShortsScreen(
            onBack: () => _goTo(0),
            active: _index == 1,
            onWatchNow: (seriesId) =>
                Navigator.of(context)
                    .pushNamed(AppRoutes.seriesDetail, arguments: seriesId),
            onOpenSearch: () =>
                Navigator.of(context).pushNamed(AppRoutes.search),
            onOpenSeries: (seriesId) =>
                Navigator.of(context)
                    .pushNamed(AppRoutes.seriesDetail, arguments: seriesId),
            onPlayEpisode: (series, episode, {openEpisodesSheet = false}) =>
                Navigator.of(context).pushNamed(
              AppRoutes.episodePlayer,
              arguments: {
                'series': series,
                'episode': episode,
                'openEpisodesSheet': openEpisodesSheet,
              },
            ),
          ),
          MyListScreen(
            onOpenSeries: (s) =>
                Navigator.of(context)
                    .pushNamed(AppRoutes.seriesDetail, arguments: s.id),
            onOpenEpisode: (seriesId, _) =>
                Navigator.of(context)
                    .pushNamed(AppRoutes.seriesDetail, arguments: seriesId),
          ),
          ProfileScreen(
            onOpenWallet: () =>
                Navigator.of(context).pushNamed(AppRoutes.wallet),
            onOpenCoinStore: () =>
                Navigator.of(context).pushNamed(AppRoutes.coinStore),
            onBuyPass: () => Navigator.of(context).pushNamed(AppRoutes.passes),
            onSubscribe: () =>
                Navigator.of(context).pushNamed(AppRoutes.subscriptions),
            onOpenLoyalty: () =>
                Navigator.of(context).pushNamed(AppRoutes.loyalty),
            onOpenDevices: () =>
                Navigator.of(context).pushNamed(AppRoutes.devices),
            onOpenSettings: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            onOpenDownloads: () =>
                Navigator.of(context).pushNamed(AppRoutes.downloads),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: _index, onTap: _goTo),
    );
  }

  Future<void> _watchSeries(Series series) async {
    final provider = context.read<SeriesProvider>();
    await provider.load(series.id);
    if (!mounted) return;
    final s = provider.series;
    if (s == null || s.episodes.isEmpty) {
      Navigator.of(context)
          .pushNamed(AppRoutes.seriesDetail, arguments: series.id);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      AppRoutes.episodePlayer,
      arguments: {'series': s, 'episode': s.episodes.first},
    );
  }
}
