import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/token_manager.dart';
import 'core/utils/device_id.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
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

class AdwaShortAppRoot extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<TokenManager>.value(value: tokenManager),
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider<AppStateProvider>(
          create: (_) => AppStateProvider(),
        ),
        ChangeNotifierProvider<ShelfProvider>(
          create: (_) => ShelfProvider(apiClient),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (_) => CategoryProvider(apiClient),
        ),
        ChangeNotifierProvider<ShortsProvider>(
          create: (_) => ShortsProvider(apiClient),
        ),
        ChangeNotifierProvider<SeriesProvider>(
          create: (_) => SeriesProvider(apiClient),
        ),
        ChangeNotifierProvider<MyListProvider>(
          create: (_) => MyListProvider(apiClient),
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(apiClient),
        ),
        ChangeNotifierProvider<LoyaltyProvider>(
          create: (_) => LoyaltyProvider(apiClient),
        ),
        ChangeNotifierProvider<DeviceProvider>(
          create: (_) =>
              DeviceProvider(apiClient, tokenManager.deviceId),
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(apiClient),
        ),
        ChangeNotifierProvider<RatingProvider>(
          create: (_) => RatingProvider(apiClient),
        ),
        ChangeNotifierProvider<ReviewProvider>(
          create: (_) => ReviewProvider(apiClient),
        ),
      ],
      child: const AdwaShortApp(),
    );
  }
}
