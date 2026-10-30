import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/widgets/coin_stack_icon.dart';
import 'package:adwa_short/core/widgets/monetization_description_section.dart';
import 'package:adwa_short/features/auth/providers/auth_provider.dart';
import 'package:adwa_short/features/downloads/providers/download_provider.dart';
import 'package:adwa_short/features/profile/providers/wallet_provider.dart';
import 'package:adwa_short/features/profile/screens/coin_store_screen.dart';
import 'package:adwa_short/features/profile/screens/passes_screen.dart';
import 'package:adwa_short/features/profile/screens/profile_screen.dart';
import 'package:adwa_short/features/profile/screens/subscriptions_screen.dart';
import 'package:adwa_short/features/profile/screens/wallet_screen.dart';
import 'package:adwa_short/models/coin_package.dart';
import 'package:adwa_short/models/subscription.dart';
import 'package:adwa_short/models/time_pass.dart';
import 'package:adwa_short/models/user.dart';
import 'package:adwa_short/models/wallet.dart';

class _FakeTokenManager extends Fake implements TokenManager {
  @override
  String? get accessToken => 'fake-token';
  @override
  String? get refreshToken => 'fake-refresh';
  @override
  String? get deviceId => 'test-device';
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
      : super(tokenManager: _FakeTokenManager(), baseUrl: 'http://localhost');
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  AuthStatus get status => AuthStatus.authenticated;
  @override
  String? get errorMessage => null;
  @override
  User? get user => User(
        id: 'u1',
        phone: '+251911223344',
        displayName: 'Test User',
      );
  @override
  Future<bool> login({required String phone, required String password}) async => true;
  @override
  Future<bool> register({required String phone, required String password, required String displayName}) async => true;
  @override
  Future<void> logout() async {}
  @override
  Future<void> refreshUser() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestWalletProvider extends WalletProvider {
  _TestWalletProvider(super.api);

  @override
  Future<void> loadAccessDashboard({bool refresh = false}) async {}
  @override
  Future<void> loadPasses({bool refresh = false}) async {}
  @override
  Future<void> loadSubscriptions({bool refresh = false}) async {}
  @override
  Future<void> loadPackages({bool refresh = false}) async {}
  @override
  Future<void> loadWallet({bool refresh = false}) async {}

  @override
  WalletLoadStatus get packagesStatus => WalletLoadStatus.success;
  @override
  List<CoinPackage> get packages => [
        CoinPackage(
          id: 'pkg1',
          name: 'Starter Pack',
          coins: 100,
          priceBirr: 50,
          bonusCoins: 10,
          episodesUnlocked: 5,
        ),
      ];

  @override
  WalletLoadStatus get passesStatus => WalletLoadStatus.success;
  @override
  List<TimePass> get passes => [
        TimePass(
          id: 'pass1',
          name: '24 Hour Pass',
          durationHours: 24,
          priceBirr: 30,
        ),
      ];

  @override
  WalletLoadStatus get subsStatus => WalletLoadStatus.success;
  @override
  List<SubscriptionPlan> get plans => [
        SubscriptionPlan(
          id: 'sub1',
          name: 'VIP Monthly',
          priceBirr: 150,
          billingCycle: 'monthly',
          features: ['Unlimited Streaming', 'No Ads'],
        ),
      ];

  @override
  WalletLoadStatus get walletStatus => WalletLoadStatus.success;
  @override
  Wallet? get wallet => Wallet(
        balanceBirr: 250,
        balanceCoins: 500,
      );
}

void main() {
  final fakeApi = _FakeApiClient();

  group('Profile Monetization UI & Explanatory Texts', () {
    testWidgets('CoinStoreScreen renders numbered Description section at the bottom and removes obsolete unlocks text', (tester) async {
      final mockAuth = _MockAuthProvider();
      final testWallet = _TestWalletProvider(fakeApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>.value(value: testWallet),
          ],
          child: const MaterialApp(
            home: CoinStoreScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Package info is visible with CoinStackIcon and restored red-accented layout
      expect(find.byType(CoinStackIcon), findsAtLeastNWidgets(1));
      expect(find.text('Starter Pack'), findsOneWidget);
      expect(find.text('110 coins'), findsOneWidget);
      expect(find.text('+ 10 bonus coins'), findsOneWidget);
      expect(find.text('Birr 50'), findsOneWidget);

      // Scroll to bottom Description section
      await tester.scrollUntilVisible(
        find.text('Description'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(MonetizationDescriptionSection), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);

      // Check numbered rules matching tailored ADWA SHORT mechanics
      expect(find.textContaining('1. Unlock short drama episodes:'), findsOneWidget);
      expect(find.textContaining('2. Top-up via CBE & Birr:'), findsOneWidget);
      expect(find.textContaining('3. Bonus Coins & wallet tracking:'), findsOneWidget);
      expect(find.textContaining('4. Permanent library access:'), findsOneWidget);
      expect(find.textContaining('Recharge Agreement'), findsOneWidget);

      // Obsolete "+ Unlocks X episodes" MUST NOT exist
      expect(find.textContaining('+ Unlocks'), findsNothing);
      expect(find.textContaining('Unlocks 5 episodes'), findsNothing);
    });

    testWidgets('PassesScreen renders numbered Description section at the bottom', (tester) async {
      final mockAuth = _MockAuthProvider();
      final testWallet = _TestWalletProvider(fakeApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>.value(value: testWallet),
          ],
          child: const MaterialApp(
            home: PassesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('24 Hour Pass'), findsOneWidget);

      // Scroll to bottom Description section
      await tester.scrollUntilVisible(
        find.text('Description'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(MonetizationDescriptionSection), findsOneWidget);
      expect(find.textContaining('1. Unlimited drama streaming:'), findsOneWidget);
      expect(find.textContaining('2. Pass duration & stacking:'), findsOneWidget);
      expect(find.textContaining('3. CBE Birr payment & non-refundable:'), findsOneWidget);
      expect(find.textContaining('4. Real-time timer in My Wallet:'), findsOneWidget);
      expect(find.textContaining('Time Pass Terms of Service'), findsOneWidget);
    });

    testWidgets('SubscriptionsScreen renders numbered Description section at the bottom', (tester) async {
      final mockAuth = _MockAuthProvider();
      final testWallet = _TestWalletProvider(fakeApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>.value(value: testWallet),
          ],
          child: const MaterialApp(
            home: SubscriptionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('VIP Monthly'), findsOneWidget);

      // Scroll to bottom Description section
      await tester.scrollUntilVisible(
        find.text('Description'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(MonetizationDescriptionSection), findsOneWidget);
      expect(find.textContaining('1. All-access VIP membership:'), findsOneWidget);
      expect(find.textContaining('2. Ad-free & high-bitrate streaming:'), findsOneWidget);
      expect(find.textContaining('3. Flexible ETB renewal:'), findsOneWidget);
      expect(find.textContaining('4. Cancel anytime in settings:'), findsOneWidget);
      expect(find.textContaining('VIP Member Agreement'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders CoinStackIcon in balance card and button, and replaces \$ sign', (tester) async {
      final mockAuth = _MockAuthProvider();
      final testWallet = _TestWalletProvider(fakeApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>.value(value: testWallet),
            ChangeNotifierProvider<DownloadProvider>(create: (_) => DownloadProvider()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No raw '$' string anywhere in the card
      expect(find.text('\$'), findsNothing);

      // Stacked Coin Icon is present in balance card and button
      expect(find.byType(CoinStackIcon), findsNWidgets(2));

      // Explanatory subtitles on menu tiles
      expect(find.text('Timed unlimited access (e.g. 24h, 7d). Watch all episodes without coins'), findsOneWidget);
      expect(find.text('Recurring VIP access. Full catalog streaming & exclusive perks'), findsOneWidget);
    });

    testWidgets('WalletScreen deposit button opens CBE deposit sheet safely without overflow', (tester) async {
      final mockAuth = _MockAuthProvider();
      final testWallet = _TestWalletProvider(fakeApi);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>.value(value: testWallet),
          ],
          child: const MaterialApp(
            home: WalletScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // CoinStackIcon is used for the coin balance indicator
      expect(find.byType(CoinStackIcon), findsOneWidget);

      // Tap Deposit via CBE
      final depositButton = find.text('Deposit via Commercial Bank of Ethiopia (CBE)');
      expect(depositButton, findsOneWidget);
      await tester.tap(depositButton);
      await tester.pumpAndSettle();

      // Deposit bottom sheet opens
      expect(find.text('Deposit via CBE Birr'), findsOneWidget);
      expect(find.text('Continue to CBE'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit via CBE Birr'), findsNothing);
    });
  });
}
