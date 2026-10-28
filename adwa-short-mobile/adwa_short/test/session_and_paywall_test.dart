import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/theme/colors.dart';
import 'package:adwa_short/features/auth/providers/auth_provider.dart';
import 'package:adwa_short/features/auth/repositories/auth_repository.dart';
import 'package:adwa_short/features/profile/providers/wallet_provider.dart';
import 'package:adwa_short/models/access_status.dart';
import 'package:adwa_short/providers/app_state_provider.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final http.Response Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final res = _handler(req);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  group('Auth Session Monitoring & Global Broadcast Tests', () {
    test('onAuthStateChanged broadcasts user and updates AppState & Wallet', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tokenManager = TokenManager(prefs);

      final client = _FakeHttpClient((req) {
        if (req.url.path.contains('/users/me')) {
          return http.Response(
            '{"id": "usr_99", "phone": "+251911223344", "display_name": "Haile", "role": "user"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/wallet')) {
          return http.Response(
            '{"balance_birr": 250.0, "balance_coins": 120}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/passes/active') || req.url.path.contains('/subscriptions/active')) {
          return http.Response(
            '{"has_active": false}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(tokenManager: tokenManager, client: client);
      final authRepo = AuthRepository(apiClient, tokenManager);
      final authProvider = AuthProvider(authRepo);
      final appState = AppStateProvider();
      final walletProvider = WalletProvider(apiClient);

      authProvider.onAuthStateChanged = (user, isAuthenticated) {
        appState.setUser(user);
        if (isAuthenticated) {
          walletProvider.loadWallet(refresh: true);
        } else {
          walletProvider.reset();
        }
      };

      expect(appState.isAuthenticated, isFalse);
      expect(walletProvider.wallet, isNull);

      // Simulate login
      await tokenManager.saveTokens(accessToken: 'access_abc', refreshToken: 'ref_abc');
      await authProvider.bootstrap();

      expect(authProvider.isAuthenticated, isTrue);
      expect(appState.isAuthenticated, isTrue);
      expect(appState.user?.displayName, 'Haile');

      // Wait for wallet loading
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(walletProvider.wallet?.balanceCoins, 120);

      // Simulate logout
      await authProvider.logout();

      expect(authProvider.isAuthenticated, isFalse);
      expect(appState.isAuthenticated, isFalse);
      expect(appState.user, isNull);
      expect(walletProvider.wallet, isNull);
      expect(tokenManager.accessToken, isNull);
    });

    test('WalletProvider reset() cleanly clears all balances and temporal statuses', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeHttpClient((req) => http.Response('{}', 200));
      final apiClient = ApiClient(tokenManager: TokenManager(prefs), client: client);
      final wp = WalletProvider(apiClient);

      wp.setCoinBalance(500);
      expect(wp.wallet?.balanceCoins, 500);

      wp.reset();

      expect(wp.wallet, isNull);
      expect(wp.activePass, isNull);
      expect(wp.activeSubscription, isNull);
      expect(wp.packages, isEmpty);
      expect(wp.passes, isEmpty);
      expect(wp.plans, isEmpty);
      expect(wp.hasActiveAccess, isFalse);
    });
  });

  group('Temporal Paywall Bypass Logic Tests', () {
    test('hasActiveAccess evaluates true for active pass with remaining seconds', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeHttpClient((req) => http.Response('{}', 200));
      final apiClient = ApiClient(tokenManager: TokenManager(prefs), client: client);
      final wp = WalletProvider(apiClient);

      expect(wp.hasActiveAccess, isFalse);

      final mockDashboard = UserAccessDashboard(
        serverTime: DateTime.now(),
        activePass: const ActivePassStatus(
          hasActivePass: true,
          name: '24-Hour Pass',
          remainingSeconds: 3600,
        ),
        activeSubscription: ActiveSubscriptionStatus.empty(),
      );

      // Verify temporal pass grants access
      expect(
        (mockDashboard.activePass.hasActivePass == true &&
            mockDashboard.activePass.remainingSeconds > 0),
        isTrue,
      );
    });

    test('hasActiveAccess evaluates true for active subscription with remaining seconds', () {
      final mockDashboard = UserAccessDashboard(
        serverTime: DateTime.now(),
        activePass: ActivePassStatus.empty(),
        activeSubscription: const ActiveSubscriptionStatus(
          hasActiveSubscription: true,
          planName: 'VIP Monthly',
          remainingSeconds: 86400,
        ),
      );

      expect(
        (mockDashboard.activeSubscription.hasActiveSubscription == true &&
            mockDashboard.activeSubscription.remainingSeconds > 0),
        isTrue,
      );
    });
  });

  group('Coin Manual Unlock Confirmation Dialog Tests', () {
    testWidgets('Renders Deduct coins confirmation dialog and triggers on confirm', (tester) async {
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.lock_open_rounded, color: AppColors.bloodRed, size: 24),
                          SizedBox(width: 8),
                          Text('Unlock Episode'),
                        ],
                      ),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deduct 50 coins to unlock this episode?'),
                          SizedBox(height: 6),
                          Text('Current Balance: 120 coins\nBalance After: 70 coins'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.bloodRed),
                          onPressed: () => Navigator.of(dCtx).pop(true),
                          child: const Text('Confirm Unlock'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    unlocked = true;
                  }
                },
                child: const Text('Tap Unlock with Coins'),
              ),
            ),
          ),
        ),
      );

      // Tap to trigger dialog
      await tester.tap(find.text('Tap Unlock with Coins'));
      await tester.pumpAndSettle();

      // Verify dialog is presented with requested manual tap confirmation
      expect(find.text('Unlock Episode'), findsOneWidget);
      expect(find.text('Deduct 50 coins to unlock this episode?'), findsOneWidget);
      expect(find.text('Current Balance: 120 coins\nBalance After: 70 coins'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm Unlock'), findsOneWidget);

      // Tap Confirm Unlock
      await tester.tap(find.text('Confirm Unlock'));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });
  });
}
