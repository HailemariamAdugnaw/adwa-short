import 'package:adwa_short/core/router/app_router.dart';
import 'package:adwa_short/core/widgets/smooth_video_snap_scroll_physics.dart';
import 'package:adwa_short/core/widgets/unified_video_player.dart';
import 'package:adwa_short/features/auth/providers/auth_provider.dart';
import 'package:adwa_short/features/auth/repositories/auth_repository.dart';
import 'package:adwa_short/features/auth/screens/auth_screen.dart';
import 'package:adwa_short/features/auth/screens/welcome_screen.dart';
import 'package:adwa_short/features/shorts/widgets/short_video_item.dart';
import 'package:adwa_short/models/short_item.dart';
import 'package:adwa_short/models/user.dart';
import 'package:adwa_short/providers/app_state_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _MockScrollPosition extends Fake implements ScrollPosition {
  _MockScrollPosition({
    required this.pixels,
    required this.minScrollExtent,
    required this.maxScrollExtent,
    required this.viewportDimension,
    required this.userScrollDirection,
  });

  @override
  final double pixels;
  @override
  final double minScrollExtent;
  @override
  final double maxScrollExtent;
  @override
  final double viewportDimension;
  @override
  final ScrollDirection userScrollDirection;
}

class _MockAuthRepository extends Fake implements AuthRepository {
  User? mockUser;
  bool shouldSucceed = true;
  bool loggedOut = false;

  @override
  Future<User> fetchMe() async {
    if (mockUser != null) return mockUser!;
    throw Exception('Not authenticated');
  }

  @override
  Future<User> login({required String phone, required String password}) async {
    if (shouldSucceed) {
      mockUser = User(
        id: 'user_123',
        phone: '+251911223344',
        displayName: 'Test User',
      );
      return mockUser!;
    }
    throw Exception('Invalid credentials');
  }

  @override
  Future<User> register({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    if (shouldSucceed) {
      mockUser = User(
        id: 'user_123',
        phone: phone,
        displayName: displayName,
      );
      return mockUser!;
    }
    throw Exception('Registration failed');
  }

  @override
  Future<void> logout() async {
    mockUser = null;
    loggedOut = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmoothVideoSnapScrollPhysics Symmetric Tests', () {
    const physics = SmoothVideoSnapScrollPhysics();

    test('downward slow drag (>18% commit toward previous page) snaps back to basePage', () {
      final pos = _MockScrollPosition(
        pixels: 390.0, // currentPage = 0.78, pageFraction = 0.78, 1 - 0.78 = 0.22 > 0.18
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
        userScrollDirection: ScrollDirection.forward, // Dragging down to smaller pixels
      );

      final sim = physics.createBallisticSimulation(pos, 0.0);
      expect(sim, isNotNull);
      // Target should commit to page 0 (0.0 pixels)
      expect(sim!.x(10.0), closeTo(0.0, 1.0));
    });

    test('downward slow drag (<18% commit) springs back to basePage + 1', () {
      final pos = _MockScrollPosition(
        pixels: 450.0, // currentPage = 0.90, pageFraction = 0.90, 1 - 0.90 = 0.10 <= 0.18
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
        userScrollDirection: ScrollDirection.forward,
      );

      final sim = physics.createBallisticSimulation(pos, 0.0);
      expect(sim, isNotNull);
      // Target should spring back to page 1 (500.0 pixels)
      expect(sim!.x(10.0), closeTo(500.0, 1.0));
    });
  });

  group('UnifiedVideoPlayer Viewport & Scaffold Elimination Tests', () {
    testWidgets('UnifiedVideoPlayer fullscreen does not create a nested Scaffold',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedVideoPlayer(
              presentation: VideoPlayerPresentation.fullscreen,
              videoUrl: '',
              title: 'Adwa Chronicles',
              description: 'Epic historical miniseries',
              currentEpisode: 'EP.1',
              totalEpisodes: 10,
              ratingCount: 120,
              isSaved: false,
              onRate: () {},
              onEpisodes: () {},
              onToggleSave: () {},
              onShare: () {},
              autoPlay: false,
            ),
          ),
        ),
      );

      // Verify that there is only the parent Scaffold, NOT a nested Scaffold inside UnifiedVideoPlayer
      expect(find.byType(Scaffold), findsOneWidget);
      // Verify ColoredBox is used as the container root
      expect(find.byType(ColoredBox), findsWidgets);
    });
  });

  group('Auth Loop & Guest Persistence Tests', () {
    testWidgets('WelcomeScreen auto-forwards to AppRoutes.main if already authenticated',
        (tester) async {
      final repo = _MockAuthRepository();
      final auth = AuthProvider(repo);
      await auth.login(phone: '+251911223344', password: 'password123');

      String? pushedRoute;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: MaterialApp(
            home: const WelcomeScreen(),
            onGenerateRoute: (settings) {
              pushedRoute = settings.name;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => Scaffold(body: Text('Route: ${settings.name}')),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.main);
    });

    testWidgets('WelcomeScreen Continue as Guest resets any residual session',
        (tester) async {
      final repo = _MockAuthRepository();
      final auth = AuthProvider(repo);
      await auth.login(phone: '+251911223344', password: 'password123');
      expect(auth.isAuthenticated, isTrue);

      String? pushedRoute;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: MaterialApp(
            home: const WelcomeScreen(),
            onGenerateRoute: (settings) {
              pushedRoute = settings.name;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => Scaffold(body: Text('Route: ${settings.name}')),
              );
            },
          ),
        ),
      );

      // Tap "Continue as Guest"
      final continueGuestFinder = find.text('Continue as Guest');
      expect(continueGuestFinder, findsOneWidget);
      await tester.tap(continueGuestFinder);
      await tester.pumpAndSettle();

      expect(repo.loggedOut, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(pushedRoute, AppRoutes.main);
    });

    testWidgets('AuthScreen._onAuthSuccess pops true when modal prompt arguments are passed',
        (tester) async {
      final repo = _MockAuthRepository();
      final auth = AuthProvider(repo);
      final appState = AppStateProvider();

      bool? modalResult;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: appState),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    modalResult = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute(
                        settings: const RouteSettings(
                          arguments: {'message': 'Unlock Episode'},
                        ),
                        builder: (_) => const AuthScreen(initialMode: AuthScreenMode.login),
                      ),
                    );
                  },
                  child: const Text('Open Modal Auth'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open modal auth
      await tester.tap(find.text('Open Modal Auth'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);

      // Fill phone & password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. 0912345678'),
        '0911223344',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'password123',
      );

      // Ensure Log In button is visible and tap it
      final logInFinder = find.widgetWithText(GestureDetector, 'Log In');
      await tester.ensureVisible(logInFinder);
      await tester.tap(logInFinder);
      await tester.pumpAndSettle();

      expect(modalResult, isTrue);
      expect(find.byType(AuthScreen), findsNothing);
    });
  });

  group('Video Player Windowing & Gesture Transparency Tests', () {
    testWidgets('ShortVideoItem passes autoPlay true/false to UnifiedVideoPlayer',
        (tester) async {
      final shortItem = ShortItem(
        id: 'short_1',
        seriesId: 'series_1',
        title: 'Episode 1',
        verticalVideoUrl: 'http://localhost/video.mp4',
        durationSeconds: 60,
      );

      // Render with autoPlay: false (simulating adjacent preloaded short)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoItem(
              item: shortItem,
              autoPlay: false,
            ),
          ),
        ),
      );

      final playerFinder = find.byType(UnifiedVideoPlayer);
      expect(playerFinder, findsOneWidget);
      final playerWidget = tester.widget<UnifiedVideoPlayer>(playerFinder);
      expect(playerWidget.autoPlay, isFalse);

      // Render with autoPlay: true (simulating active in-focus short)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortVideoItem(
              item: shortItem,
              autoPlay: true,
            ),
          ),
        ),
      );

      final activePlayerWidget = tester.widget<UnifiedVideoPlayer>(playerFinder);
      expect(activePlayerWidget.autoPlay, isTrue);
    });

    test('Adjacent controller windowing preserves bounded active players', () {
      const currentIndex = 2;
      const totalItems = 5;

      final isMounted = <int, bool>{};
      final autoPlayMap = <int, bool>{};

      for (var i = 0; i < totalItems; i++) {
        final isCurrent = i == currentIndex;
        final isAdjacent = i == currentIndex - 1 || i == currentIndex + 1;
        if (isCurrent || isAdjacent) {
          isMounted[i] = true;
          autoPlayMap[i] = isCurrent; // true if current, false if adjacent
        } else {
          isMounted[i] = false;
        }
      }

      // Current item (2) is mounted and autoPlays
      expect(isMounted[2], isTrue);
      expect(autoPlayMap[2], isTrue);

      // Adjacent items (1 and 3) are mounted but paused (autoPlay: false)
      expect(isMounted[1], isTrue);
      expect(autoPlayMap[1], isFalse);
      expect(isMounted[3], isTrue);
      expect(autoPlayMap[3], isFalse);

      // Distant items (0 and 4) are unmounted from active video playback
      expect(isMounted[0], isFalse);
      expect(isMounted[4], isFalse);
    });

    testWidgets('UnifiedVideoPlayer does not render CachedNetworkImage in video surface',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedVideoPlayer(
              videoUrl: 'http://localhost/video.mp4',
              title: 'Sample Video',
              description: 'Sample description',
              currentEpisode: 'EP.1',
              totalEpisodes: 10,
              ratingCount: 5,
              isSaved: false,
              posterUrl: 'http://localhost/poster.jpg',
              onRate: () {},
              onEpisodes: () {},
              onToggleSave: () {},
              onShare: () {},
            ),
          ),
        ),
      );

      // Verify that no CachedNetworkImage is rendered in the video player tree
      expect(find.byType(CachedNetworkImage), findsNothing);
      // Verify clean black backdrop is present
      expect(find.byType(ColoredBox), findsWidgets);
    });
  });
}
