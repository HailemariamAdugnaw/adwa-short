import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/widgets/connection_lost_view.dart';
import 'package:adwa_short/features/home/providers/category_provider.dart';
import 'package:adwa_short/features/home/providers/shelf_provider.dart';
import 'package:adwa_short/features/home/screens/home_screen.dart';
import 'package:adwa_short/features/home/widgets/category_tab_bar.dart';
import 'package:adwa_short/features/home/widgets/overlay_search_bar.dart';
import 'package:adwa_short/features/shorts/providers/shorts_provider.dart';
import 'package:adwa_short/features/shorts/screens/shorts_screen.dart';
import 'package:adwa_short/features/shorts/widgets/paywall_overlay.dart';
import 'package:adwa_short/models/shelf.dart';
import 'package:adwa_short/models/short_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeTokenManager extends Fake implements TokenManager {
  @override
  String? get accessToken => null;
  @override
  String? get refreshToken => null;
  @override
  String? get deviceId => 'test-device';
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
      : super(tokenManager: _FakeTokenManager(), baseUrl: 'http://localhost');
}

class FakeShelfProvider extends ShelfProvider {
  FakeShelfProvider() : super(_FakeApiClient());

  ShelfLoadStatus _mockStatus = ShelfLoadStatus.error;
  bool refreshed = false;

  @override
  ShelfLoadStatus get status => _mockStatus;
  set mockStatus(ShelfLoadStatus s) {
    _mockStatus = s;
    notifyListeners();
  }

  @override
  List<Shelf> get shelves => [];

  @override
  Future<void> load({bool refresh = false}) async {
    refreshed = true;
  }
}

class FakeCategoryProvider extends CategoryProvider {
  FakeCategoryProvider() : super(_FakeApiClient());

  @override
  Future<void> load() async {}
}

class FakeShortsProvider extends ShortsProvider {
  FakeShortsProvider() : super(_FakeApiClient());

  ShortsLoadStatus _mockStatus = ShortsLoadStatus.idle;
  final List<ShortItem> _mockItems = [];
  bool refreshed = false;

  @override
  ShortsLoadStatus get status => _mockStatus;
  set mockStatus(ShortsLoadStatus s) {
    _mockStatus = s;
    notifyListeners();
  }

  @override
  List<ShortItem> get items => _mockItems;

  @override
  Future<void> refresh() async {
    refreshed = true;
  }

  @override
  Future<void> load() async {
    refreshed = true;
  }
}

void main() {
  group('HomeScreen Connection Lost State Tests', () {
    testWidgets(
        'renders ConnectionLostView scoped to content area while keeping header intact',
        (tester) async {
      final shelfProvider = FakeShelfProvider();
      shelfProvider.mockStatus = ShelfLoadStatus.error;
      final categoryProvider = FakeCategoryProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShelfProvider>.value(value: shelfProvider),
            ChangeNotifierProvider<CategoryProvider>.value(
                value: categoryProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeScreen(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Expect ConnectionLostView is rendered in content area with isFullScreen: false
      expect(find.byType(ConnectionLostView), findsOneWidget);
      final clv = tester.widget<ConnectionLostView>(find.byType(ConnectionLostView));
      expect(clv.isFullScreen, isFalse);

      // Verify header search bar and category bar remain intact and accessible
      expect(find.byType(OverlaySearchBar), findsOneWidget);
      expect(find.byType(CategoryTabBar), findsOneWidget);

      expect(find.text('Try Again'), findsOneWidget);

      // Tap Try Again and verify refresh triggered
      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(shelfProvider.refreshed, isTrue);
    });
  });

  group('ShortsScreen Refresh and Error Tests', () {
    testWidgets('renders ConnectionLostView scoped to feed on ShortsLoadStatus.error',
        (tester) async {
      final shortsProvider = FakeShortsProvider();
      shortsProvider.mockStatus = ShortsLoadStatus.error;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShortsProvider>.value(value: shortsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ShortsScreen(active: true),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ConnectionLostView), findsOneWidget);
      final clv = tester.widget<ConnectionLostView>(find.byType(ConnectionLostView));
      expect(clv.isFullScreen, isFalse);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(shortsProvider.refreshed, isTrue);
    });

    testWidgets('renders RefreshIndicator on empty list state', (tester) async {
      final shortsProvider = FakeShortsProvider();
      shortsProvider.mockStatus = ShortsLoadStatus.success;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShortsProvider>.value(value: shortsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ShortsScreen(active: true),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('No shorts available right now'), findsOneWidget);
    });
  });

  group('Compact Single-Screen PaywallOverlay Tests', () {
    testWidgets(
        'renders compact single-screen modal without scrolling and all choices visible',
        (tester) async {
      bool adsTapped = false;
      bool coinsTapped = false;
      bool passTapped = false;
      bool subTapped = false;
      bool laterTapped = false;

      final item = ShortItem(
        id: 'ep_12',
        seriesId: 'series_adwa',
        title: 'The Great Victory',
        seriesTitle: 'Adwa Chronicles',
        episodeNumber: 12,
        coinCost: 15,
        accessReason: 'need_coins',
        verticalVideoUrl: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallOverlay(
              item: item,
              onUnlockAds: () => adsTapped = true,
              onBuyCoins: () => coinsTapped = true,
              onBuyPass: () => passTapped = true,
              onSubscribe: () => subTapped = true,
              onMaybeLater: () => laterTapped = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Ensure PaywallOverlay does NOT use SingleChildScrollView (no multi-screen bloat)
      expect(
        find.descendant(
          of: find.byType(PaywallOverlay),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );

      // Verify all pricing tiers are instantly visible on screen
      expect(find.text('Unlock via Ads (Watch Ad)'), findsOneWidget);
      expect(find.text('Unlock with Coins (15 Coins)'), findsOneWidget);
      expect(find.text('Buy Time Pass'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);

      // Verify badges
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('15 COINS'), findsOneWidget);
      expect(find.text('UNLIMITED'), findsOneWidget);
      expect(find.text('BEST VALUE'), findsOneWidget);

      // Tap choices directly without needing to scroll
      await tester.tap(find.text('Unlock via Ads (Watch Ad)'));
      await tester.pump();
      expect(adsTapped, isTrue);

      await tester.tap(find.text('Unlock with Coins (15 Coins)'));
      await tester.pump();
      expect(coinsTapped, isTrue);

      await tester.tap(find.text('Buy Time Pass'));
      await tester.pump();
      expect(passTapped, isTrue);

      await tester.tap(find.text('Subscribe'));
      await tester.pump();
      expect(subTapped, isTrue);

      await tester.tap(find.text('Maybe later'));
      await tester.pump();
      expect(laterTapped, isTrue);
    });

    testWidgets(
        'renders reference design header, Locked pill, and conditional guest subtitle',
        (tester) async {
      final guestItem = ShortItem(
        id: 'ep_4',
        seriesId: 'series_echoes',
        title: 'Echoes of Addis - Episode 4',
        seriesTitle: 'Echoes of Addis',
        episodeNumber: 4,
        coinCost: 0, // Should default to 50 Coins
        accessReason: 'need_login', // Guest mode
        verticalVideoUrl: '',
      );

      // 1. Guest Mode Render
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallOverlay(
              item: guestItem,
              onUnlockAds: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify exact header: "Echoes of Addis · Echoes of Addis - Episode 4"
      expect(
        find.text('Echoes of Addis · Echoes of Addis - Episode 4'),
        findsOneWidget,
      );

      // Verify "Locked" pill badge
      expect(find.text('Locked'), findsOneWidget);

      // Verify "Unlock Episode" card header
      expect(find.text('Unlock Episode'), findsOneWidget);

      // Verify guest subtitle is shown
      expect(
        find.text('Sign in or register to unlock episodes.'),
        findsOneWidget,
      );

      // Verify default 50 coins pricing row and badge
      expect(find.text('Unlock with Coins (50 Coins)'), findsOneWidget);
      expect(find.text('50 COINS'), findsOneWidget);

      // Verify chevrons on badges
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(4));

      // 2. Authenticated Mode Render: subtitle must be hidden
      final authItem = ShortItem(
        id: 'ep_4',
        seriesId: 'series_echoes',
        title: 'Echoes of Addis - Episode 4',
        seriesTitle: 'Echoes of Addis',
        episodeNumber: 4,
        coinCost: 50,
        accessReason: 'need_coins', // Logged in, coins needed
        verticalVideoUrl: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallOverlay(
              item: authItem,
              onUnlockAds: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Subtitle must be hidden for authenticated users
      expect(
        find.text('Sign in or register to unlock episodes.'),
        findsNothing,
      );
    });
  });
}
