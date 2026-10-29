import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/core/constants/api_constants.dart';
import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/services/ad_service.dart';
import 'package:adwa_short/core/theme/colors.dart';
import 'package:adwa_short/models/loyalty_grant.dart';

class MockTokenManager extends Fake implements TokenManager {
  @override
  String? get accessToken => 'mock_token';
  @override
  String? get refreshToken => 'mock_refresh';
  @override
  String? get deviceId => 'mock_device';
  @override
  String? get userId => '1';
  @override
  String? get userPhone => '0912345678';
  @override
  String? get displayName => 'Mock User';
  @override
  bool get isAuthenticated => true;
  @override
  Future<void> clearAll() async {}
  @override
  Future<void> saveDeviceId(String id) async {}
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> saveUser({String? userId, String? phone, String? displayName}) async {}
}

class TrackingApiClient extends ApiClient {
  TrackingApiClient() : super(tokenManager: MockTokenManager(), baseUrl: 'http://localhost:8000');

  final List<Map<String, dynamic>> postCalls = [];

  @override
  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    Map<String, String>? headers,
    required T Function(dynamic json) parser,
  }) async {
    postCalls.add({'path': path, 'body': body});
    return parser({'status': 'ok'});
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, String>? query,
    bool requireAuth = true,
    required T Function(dynamic json) parser,
  }) async {
    if (path == ApiConstants.adUnlocksRule) {
      return parser({
        'ads_required': 2,
        'episodes_unlocked': 1,
        'provider': 'admob',
        'rewarded_unit_id': 'ca-app-pub-3940256099942544/5224354917',
        'reward_ad_value_birr': 0.25,
        'test_mode': true,
      });
    }
    return parser({});
  }
}

void main() {
  group('Silent Multi-Ad Batch & Immediate Unlock', () {
    testWidgets('plays 3-ad batch silently without manual progress screens, countdown overlays, or premature reward banners', (tester) async {
      final rule = AdUnlockRule(
        adsRequired: 3,
        episodesUnlocked: 1,
        provider: 'admob',
        rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
        testMode: true,
      );

      bool batchDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  final res = await showGeneralDialog<bool>(
                    context: ctx,
                    pageBuilder: (_, __, ___) => RewardedAdBatchDialog(
                      rule: rule,
                      episodeTitle: 'Episode 7 · The Final Stand',
                      adService: AdService(),
                    ),
                  );
                  batchDismissed = res == true;
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // --- Ad 1 of 3 (Initial Silent State) ---
      expect(find.text('Loading ad 1 of 3...'), findsOneWidget);

      // Manual progress screens, intermediate countdown overlays, and buttons are completely eliminated
      expect(find.text('AD 1 OF 3'), findsNothing);
      expect(find.text('Unlock & Watch Episode Now'), findsNothing);
      expect(find.text('All 3 Ads Completed!'), findsNothing);
      expect(find.text('Reward Granted! Episode access verified.'), findsNothing);

      // Fast-forward through Ad 1 (6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      // --- Ad 2 of 3 (Silent Transition without Premature Reward Banner) ---
      expect(find.text('Loading ad 2 of 3...'), findsOneWidget);
      // Suppress premature reward UI elements
      expect(find.text('Reward Granted'), findsNothing);
      expect(find.text('Unlock & Watch Episode Now'), findsNothing);

      // Fast-forward through Ad 2 (6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      // --- Ad 3 of 3 (Final Ad Silent Transition) ---
      expect(find.text('Loading ad 3 of 3...'), findsOneWidget);
      expect(find.text('Reward Granted'), findsNothing);

      // Fast-forward through Ad 3 (6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Instantly unlocks and returns directly without manual user interaction
      expect(batchDismissed, isTrue);
      expect(find.byType(RewardedAdBatchDialog), findsNothing);
    });

    testWidgets('defers backend verification and onRewardEarned until complete batch finishes, then instantly returns to player', (tester) async {
      final mockApi = TrackingApiClient();
      final adService = AdService(mockApi);
      bool rewardEarnedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  await adService.showRewardedAd(
                    ctx,
                    episodeId: '42',
                    episodeTitle: 'Episode 42 · Climax',
                    onRewardEarned: () {
                      rewardEarnedCalled = true;
                    },
                  );
                },
                child: const Text('Start Unlock'),
              ),
            ),
          ),
        ),
      );

      // Tap to launch ad batch
      await tester.tap(find.text('Start Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ad 1 starts: no premature verification
      expect(find.text('Loading ad 1 of 2...'), findsOneWidget);
      expect(rewardEarnedCalled, isFalse);
      expect(mockApi.postCalls.isEmpty, isTrue);

      // Fast forward through Ad 1 (6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      // Ad 2 starts silently: verification and callback still deferred!
      expect(find.text('Loading ad 2 of 2...'), findsOneWidget);
      expect(rewardEarnedCalled, isFalse);
      expect(mockApi.postCalls.isEmpty, isTrue);

      // Fast forward through Ad 2 (final ad, 6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Instant return directly to player: no manual click required!
      expect(rewardEarnedCalled, isTrue);
      expect(mockApi.postCalls.length, 1);
      expect(mockApi.postCalls.first['path'], ApiConstants.adUnlocksWatched);
      expect(mockApi.postCalls.first['body']['episode_id'], 42);
      expect(mockApi.postCalls.first['body']['ads_watched'], 2);
    });

    testWidgets('cancelling early does not trigger backend verification or reward callbacks', (tester) async {
      final mockApi = TrackingApiClient();
      final adService = AdService(mockApi);
      bool rewardEarnedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  await adService.showRewardedAd(
                    ctx,
                    episodeId: '99',
                    onRewardEarned: () {
                      rewardEarnedCalled = true;
                    },
                  );
                },
                child: const Text('Start Unlock'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Loading ad 1 of 2...'), findsOneWidget);

      // Tap subtle close button (X)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog pops up
      expect(find.text('Cancel Ad Unlock?'), findsOneWidget);

      // Tap Exit (Remain Locked)
      await tester.tap(find.text('Exit (Remain Locked)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Overlay dismissed, NO reward callback, NO verification postback
      expect(rewardEarnedCalled, isFalse);
      expect(mockApi.postCalls.isEmpty, isTrue);
    });

    testWidgets('strictly enforces brand colors (Black, Blood Red, White) and removes manual progress screens', (tester) async {
      final rule = AdUnlockRule(
        adsRequired: 2,
        episodesUnlocked: 1,
        provider: 'admob',
        rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
        testMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardedAdBatchDialog(
              rule: rule,
              episodeTitle: 'Episode 1 · Brand Check',
              adService: AdService(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Scaffold background is Deep Black (#0A0A0A)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, AppColors.black);

      // Buffer indicator is Blood Red
      final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(indicator.color, AppColors.bloodRed);

      // Manual progress screens & buttons are absent
      expect(find.text('Unlock & Watch Episode Now'), findsNothing);
      expect(find.text('AD 1 OF 2'), findsNothing);
    });

    testWidgets('displays clean error state when ad fails to load and strictly prevents free unlock bypass', (tester) async {
      final rule = AdUnlockRule(
        adsRequired: 2,
        episodesUnlocked: 1,
        provider: 'admob',
        rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
        testMode: true,
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showGeneralDialog<bool>(
                    context: ctx,
                    pageBuilder: (_, __, ___) => RewardedAdBatchDialog(
                      rule: rule,
                      episodeTitle: 'Episode 5 · Locked',
                      adService: AdService(),
                      simulateFailure: true,
                    ),
                  );
                },
                child: const Text('Open Ad Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Ad Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Clean error state rendered
      expect(find.text('Ad Unavailable'), findsOneWidget);
      expect(
        find.text('Ad unavailable. Please check your connection or try again later'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Verify strict brand color enforcement: Blood Red icon, Black background
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
      expect(icon.color, AppColors.bloodRed);

      // Verify no countdown or automatic bypass occurs
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text('Ad Unavailable'), findsOneWidget);
      expect(dialogResult, isNull);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Strictly returns false, keeping episode locked
      expect(dialogResult, isFalse);
    });

    testWidgets('showRewardedAd returns false on ad failure without calling backend verification', (tester) async {
      final mockApi = TrackingApiClient();
      final adService = AdService(mockApi);
      bool rewardEarnedCalled = false;
      bool? unlockResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  unlockResult = await adService.showRewardedAd(
                    ctx,
                    episodeId: '77',
                    simulateFailure: true,
                    onRewardEarned: () {
                      rewardEarnedCalled = true;
                    },
                  );
                },
                child: const Text('Trigger Ad Unlock'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Ad Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error UI is visible
      expect(find.text('Ad Unavailable'), findsOneWidget);
      expect(rewardEarnedCalled, isFalse);
      expect(mockApi.postCalls.isEmpty, isTrue);

      // Tap top-right Close (X) button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Result must strictly be false: NO free bypass, NO backend postback, NO reward callback!
      expect(unlockResult, isFalse);
      expect(rewardEarnedCalled, isFalse);
      expect(mockApi.postCalls.isEmpty, isTrue);
    });
  });
}
