import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/token_manager.dart';
import 'core/services/ad_service.dart';
import 'core/utils/device_id.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/downloads/providers/download_provider.dart';
import 'features/home/providers/category_provider.dart';
import 'features/home/providers/shelf_provider.dart';
import 'features/my_list/providers/my_list_provider.dart';
import 'features/profile/providers/device_provider.dart';
import 'features/profile/providers/loyalty_provider.dart';
import 'features/profile/providers/wallet_provider.dart';
import 'features/ratings/providers/rating_provider.dart';
import 'features/reviews/providers/review_provider.dart';
import 'features/search/providers/search_provider.dart';
import 'features/series/providers/series_provider.dart';
import 'features/shorts/providers/shorts_provider.dart';
import 'providers/app_state_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {

  }

  // Initialize Google Mobile Ads SDK for rewarded ads
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('Google Mobile Ads initialization warning: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final tokenManager = TokenManager(prefs);

  final deviceIdProvider = DeviceIdProvider(prefs);
  await deviceIdProvider.getDeviceId();

  final apiClient = ApiClient(tokenManager: tokenManager);

  apiClient.onSessionExpired = () {

    tokenManager.clearAll();
  };

  final authRepository = AuthRepository(apiClient, tokenManager);

  runApp(AdwaShortAppRoot(
    apiClient: apiClient,
    tokenManager: tokenManager,
    authRepository: authRepository,
  ));
}

class AdwaShortAppRoot extends StatefulWidget {
  const AdwaShortAppRoot({
    super.key,
    required this.apiClient,
    required this.tokenManager,
    required this.authRepository,
  });

  final ApiClient apiClient;
  final TokenManager tokenManager;
  final AuthRepository authRepository;

  @override
  State<AdwaShortAppRoot> createState() => _AdwaShortAppRootState();
}

class _AdwaShortAppRootState extends State<AdwaShortAppRoot> {
  late final AppStateProvider _appStateProvider;
  late final AuthProvider _authProvider;
  late final WalletProvider _walletProvider;

  @override
  void initState() {
    super.initState();
    _appStateProvider = AppStateProvider();
    _authProvider = AuthProvider(widget.authRepository);
    _walletProvider = WalletProvider(widget.apiClient);

    _authProvider.onAuthStateChanged = (user, isAuthenticated) {
      _appStateProvider.setUser(user);
      if (isAuthenticated) {
        _walletProvider.loadWallet(refresh: true);
        _walletProvider.loadAccessDashboard(refresh: true);
      } else {
        _walletProvider.reset();
      }
    };

    widget.apiClient.onConnectionLost = () {
      _appStateProvider.setConnectionLost(true);
    };

    widget.apiClient.onSessionExpired = () {
      widget.tokenManager.clearAll();
      _authProvider.logout();
    };
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _appStateProvider.dispose();
    _walletProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: widget.apiClient),
        Provider<TokenManager>.value(value: widget.tokenManager),
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<AdService>(create: (_) => AdService(widget.apiClient)),
        ChangeNotifierProvider<AuthProvider>.value(
          value: _authProvider,
        ),
        ChangeNotifierProvider<AppStateProvider>.value(
          value: _appStateProvider,
        ),
        ChangeNotifierProvider<ShelfProvider>(
          create: (_) => ShelfProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => CategoryProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<ShortsProvider>(
          create: (_) => ShortsProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<SeriesProvider>(
          create: (_) => SeriesProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<MyListProvider>(
          create: (_) => MyListProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (_) => DownloadProvider(),
        ),
        ChangeNotifierProvider<WalletProvider>.value(
          value: _walletProvider,
        ),
        ChangeNotifierProvider<LoyaltyProvider>(
          create: (_) => LoyaltyProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<DeviceProvider>(
          create: (_) =>
              DeviceProvider(widget.apiClient, widget.tokenManager.deviceId),
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<RatingProvider>(
          create: (_) => RatingProvider(widget.apiClient),
        ),
        ChangeNotifierProvider<ReviewProvider>(
          create: (_) => ReviewProvider(widget.apiClient),
        ),
      ],
      child: const AdwaShortApp(),
    );
  }
}
