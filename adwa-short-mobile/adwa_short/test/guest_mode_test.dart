import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/widgets/guest_auth_prompt.dart';
import 'package:adwa_short/features/auth/providers/auth_provider.dart';
import 'package:adwa_short/features/auth/screens/login_screen.dart';
import 'package:adwa_short/features/auth/screens/register_screen.dart';
import 'package:adwa_short/features/auth/screens/welcome_screen.dart';
import 'package:adwa_short/features/downloads/providers/download_provider.dart';
import 'package:adwa_short/features/profile/screens/profile_screen.dart';
import 'package:adwa_short/features/profile/screens/wallet_screen.dart';
import 'package:adwa_short/features/profile/screens/devices_screen.dart';
import 'package:adwa_short/features/profile/screens/loyalty_screen.dart';
import 'package:adwa_short/features/my_list/screens/my_list_screen.dart';
import 'package:adwa_short/features/profile/providers/wallet_provider.dart';
import 'package:adwa_short/features/profile/providers/device_provider.dart';
import 'package:adwa_short/features/profile/providers/loyalty_provider.dart';
import 'package:adwa_short/features/my_list/providers/my_list_provider.dart';
import 'package:adwa_short/models/user.dart';
import 'package:adwa_short/providers/app_state_provider.dart';

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

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isAuth = false;

  @override
  bool get isAuthenticated => _isAuth;

  void setAuthenticated(bool val) {
    _isAuth = val;
    notifyListeners();
  }

  @override
  AuthStatus get status =>
      _isAuth ? AuthStatus.authenticated : AuthStatus.unauthenticated;

  @override
  String? get errorMessage => null;

  @override
  User? get user => null;

  @override
  Future<bool> login({required String phone, required String password}) async => true;

  @override
  Future<bool> register({required String phone, required String password, required String displayName}) async => true;

  @override
  Future<void> logout() async {
    _isAuth = false;
    notifyListeners();
  }

  @override
  Future<void> refreshUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final fakeApi = _FakeApiClient();

  group('Guest Mode & Monetization Restriction Tests', () {
    testWidgets('GuestAuthPrompt renders brand-compliant UI and handles actions', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await GuestAuthPrompt.show(
                    ctx,
                    title: 'Sign In to Unlock',
                    message: 'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
                  );
                },
                child: const Text('Open Prompt'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In to Unlock'), findsOneWidget);
      expect(
        find.text('Please sign in or register to unlock episodes, buy coins, and access subscriptions.'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);

      // Tap Continue as Guest -> dismisses modal returning false
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('LoginScreen renders promptMessage banner and Continue as Guest option', (tester) async {
      final mockAuth = MockAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<AppStateProvider>(create: (_) => AppStateProvider()),
            ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider(fakeApi)),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('RegisterScreen renders Create Account and Continue as Guest option', (tester) async {
      final mockAuth = MockAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<AppStateProvider>(create: (_) => AppStateProvider()),
            ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider(fakeApi)),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Join ADWA SHORT in seconds'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('WalletScreen renders dedicated guest state when unauthenticated', (tester) async {
      final mockAuth = MockAuthProvider()..setAuthenticated(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider(fakeApi)),
          ],
          child: const MaterialApp(
            home: WalletScreen(),
          ),
        ),
      );

      expect(find.text('Sign In to Access Wallet'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);
    });

    testWidgets('DevicesScreen renders dedicated guest state when unauthenticated', (tester) async {
      final mockAuth = MockAuthProvider()..setAuthenticated(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<AppStateProvider>(create: (_) => AppStateProvider()),
            ChangeNotifierProvider<DeviceProvider>(create: (_) => DeviceProvider(fakeApi, 'test-device')),
          ],
          child: const MaterialApp(
            home: DevicesScreen(),
          ),
        ),
      );

      expect(find.text('Device Session Management'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);
    });

    testWidgets('LoyaltyScreen renders dedicated guest state when unauthenticated', (tester) async {
      final mockAuth = MockAuthProvider()..setAuthenticated(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<LoyaltyProvider>(create: (_) => LoyaltyProvider(fakeApi)),
          ],
          child: const MaterialApp(
            home: LoyaltyScreen(),
          ),
        ),
      );

      expect(find.text('Unlock Loyalty Rewards'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);
    });

    testWidgets('MyListScreen renders dedicated guest state when unauthenticated', (tester) async {
      final mockAuth = MockAuthProvider()..setAuthenticated(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<MyListProvider>(create: (_) => MyListProvider(fakeApi)),
          ],
          child: const MaterialApp(
            home: MyListScreen(),
          ),
        ),
      );

      expect(find.text('Keep Track of Your Favorites'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);
    });

    testWidgets('WelcomeScreen renders cinematic entry UI with Sign In, Register, and Continue as Guest', (tester) async {
      String? routedTo;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (_) => const WelcomeScreen(),
            '/login': (_) {
              routedTo = '/login';
              return const Scaffold(body: Text('Login Route'));
            },
            '/register': (_) {
              routedTo = '/register';
              return const Scaffold(body: Text('Register Route'));
            },
            '/main': (_) {
              routedTo = '/main';
              return const Scaffold(body: Text('Main Route'));
            },
          },
        ),
      );

      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('ADWA SHORT')), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);

      // Tap Continue as Guest
      await tester.ensureVisible(find.text('Continue as Guest'));
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      expect(routedTo, '/main');
    });

    testWidgets('ProfileScreen renders dedicated engaging guest state with CTA banner and guarded options', (tester) async {
      final mockAuth = MockAuthProvider()..setAuthenticated(false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider(fakeApi)),
            ChangeNotifierProvider<DownloadProvider>(create: (_) => DownloadProvider()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Guest Header
      expect(find.text('Guest Account'), findsOneWidget);
      expect(find.text('Guest Mode • #GUEST'), findsOneWidget);
      expect(find.text('Browsing locally without an account'), findsOneWidget);

      // Prominent Call-to-action banner
      expect(find.text('Unlock Full Access'), findsOneWidget);
      expect(
        find.text('Sign in or register to sync your wallet, track time passes, and unlock premium episodes'),
        findsOneWidget,
      );

      // Action buttons inside CTA banner
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);

      // Settings and guarded premium features
      expect(find.text('Settings'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('My Wallet'), 200);
      expect(find.text('My Wallet'), findsOneWidget);
      // Verify VIP badges are removed in guest mode
      expect(find.text('VIP'), findsNothing);
    });

    testWidgets('AuthScreen smoothly switches between Sign In and Create Account tabs', (tester) async {
      final mockAuth = MockAuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<AppStateProvider>(create: (_) => AppStateProvider()),
            ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider(fakeApi)),
          ],
          child: const MaterialApp(
            home: AuthScreen(initialMode: AuthScreenMode.login),
          ),
        ),
      );

      // Initially on Sign In tab
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('PHONE NUMBER'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('DISPLAY NAME'), findsNothing);

      // Switch to Create Account tab
      await tester.tap(find.text('Create Account').first);
      await tester.pumpAndSettle();

      // Now on Register form
      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Join ADWA SHORT in seconds'), findsOneWidget);
      expect(find.text('DISPLAY NAME'), findsOneWidget);
      expect(find.text('PHONE NUMBER'), findsOneWidget);

      // Switch back to Sign In tab
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Back on Sign In form
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
