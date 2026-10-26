import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adwa_short/core/services/ad_service.dart';
import 'package:adwa_short/features/profile/providers/loyalty_provider.dart';
import 'package:adwa_short/features/profile/screens/loyalty_screen.dart';
import 'package:adwa_short/features/shorts/widgets/paywall_overlay.dart';
import 'package:adwa_short/models/loyalty_grant.dart';
import 'package:adwa_short/models/short_item.dart';

class MockLoyaltyProvider extends ChangeNotifier implements LoyaltyProvider {
  final LoyaltyStatus _status = LoyaltyStatus.success;
  List<LoyaltyGrant> _grants = [];
  AdUnlockRule? _rule;
  LoyaltyUserStatus? _loyaltyStatus;
  String? _errorMessage;
  final bool _isClaiming = false;

  @override
  LoyaltyStatus get status => _status;
  @override
  List<LoyaltyGrant> get grants => _grants;
  @override
  AdUnlockRule? get rule => _rule;
  @override
  LoyaltyUserStatus? get loyaltyStatus => _loyaltyStatus;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get isClaiming => _isClaiming;

  set mockLoyaltyStatus(LoyaltyUserStatus? s) {
    _loyaltyStatus = s;
    notifyListeners();
  }

  set mockRule(AdUnlockRule? r) {
    _rule = r;
    notifyListeners();
  }

  set mockGrants(List<LoyaltyGrant> g) {
    _grants = g;
    notifyListeners();
  }

  @override
  Future<void> load() async {}

  @override
  Future<bool> claimLoyaltyReward() async {
    if (_loyaltyStatus?.isClaimed == true) return false;
    _loyaltyStatus = _loyaltyStatus?.copyWith(isClaimed: true, canClaim: false);
    notifyListeners();
    return true;
  }
}

void main() {
  group('AdUnlockRule Model', () {
    test('AdUnlockRule.fromJson parses complete payload', () {
      final json = {
        'ads_required': 2,
        'episodes_unlocked': 1,
        'is_active': true,
        'provider': 'admob',
        'app_id': 'ca-app-pub-3940256099942544~3347511713',
        'rewarded_unit_id': 'ca-app-pub-3940256099942544/5224354917',
        'reward_ad_value_birr': 0.25,
        'estimated_cpm_birr': 250.0,
        'test_mode': true,
      };

      final rule = AdUnlockRule.fromJson(json);
      expect(rule.adsRequired, 2);
      expect(rule.episodesUnlocked, 1);
      expect(rule.provider, 'admob');
      expect(rule.rewardedUnitId, 'ca-app-pub-3940256099942544/5224354917');
      expect(rule.rewardAdValueBirr, 0.25);
      expect(rule.estimatedCpmBirr, 250.0);
      expect(rule.testMode, isTrue);
    });
  });

  group('Loyalty Models', () {
    test('LoyaltyConfig.fromJson parses super admin configuration', () {
      final json = {
        'min_balance_birr': 50.0,
        'max_balance_birr': 1000.0,
        'daily_access_days': 7,
        'free_coins': 100,
        'free_full_series_count': 2,
        'is_active': true,
      };

      final config = LoyaltyConfig.fromJson(json);
      expect(config.minBalanceBirr, 50.0);
      expect(config.maxBalanceBirr, 1000.0);
      expect(config.dailyAccessDays, 7);
      expect(config.freeCoins, 100);
      expect(config.freeFullSeriesCount, 2);
      expect(config.isActive, isTrue);
    });

    test('LoyaltyUserStatus.fromJson parses qualification progress with reward_id and is_claimed', () {
      final json = {
        'min_balance_birr': 50.0,
        'max_balance_birr': 1000.0,
        'daily_access_days': 7,
        'free_coins': 100,
        'free_full_series_count': 2,
        'is_active': true,
        'wallet_balance_birr': 65.0,
        'wallet_balance_coins': 12,
        'qualifies': true,
        'needed_birr': 0.0,
        'progress_pct': 100.0,
        'can_claim': false,
        'reward_id': 1,
        'is_claimed': true,
      };

      final status = LoyaltyUserStatus.fromJson(json);
      expect(status.walletBalanceBirr, 65.0);
      expect(status.qualifies, isTrue);
      expect(status.neededBirr, 0.0);
      expect(status.progressPct, 100.0);
      expect(status.canClaim, isFalse);
      expect(status.rewardId, 1);
      expect(status.isClaimed, isTrue);

      // copyWith test
      final updated = status.copyWith(isClaimed: false, canClaim: true);
      expect(updated.isClaimed, isFalse);
      expect(updated.canClaim, isTrue);
    });

    test('LoyaltyGrant.fromJson parses reward_id from details map', () {
      final json = {
        'id': 'g_1',
        'details': {
          'title': 'Tier 1 Reward',
          'type': 'coins',
          'coins': 100,
          'reward_id': 1,
        },
        'granted_at': '2026-10-25T12:00:00Z',
      };

      final grant = LoyaltyGrant.fromJson(json);
      expect(grant.title, 'Tier 1 Reward');
      expect(grant.value, 100);
      expect(grant.rewardId, 1);
    });
  });

  group('PaywallOverlay Widget Flow', () {
    testWidgets('renders Unlock via Ads button when onUnlockAds provided and triggers tap', (tester) async {
      bool adTapped = false;
      bool coinsTapped = false;

      final item = ShortItem(
        id: 'ep_101',
        seriesId: 'series_1',
        title: 'Episode 5: The Climax',
        description: 'Locked episode',
        verticalVideoUrl: 'https://example.com/video.mp4',
        durationSeconds: 120,
        isAccessible: false,
        accessReason: 'need_ad',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallOverlay(
              item: item,
              onUnlockAds: () => adTapped = true,
              onBuyCoins: () => coinsTapped = true,
            ),
          ),
        ),
      );

      // Verify "Unlock via Ads (Watch Ad)" is rendered
      expect(find.text('Unlock via Ads (Watch Ad)'), findsOneWidget);
      expect(find.textContaining('Unlock with Coins'), findsOneWidget);

      // Tap "Unlock via Ads"
      await tester.tap(find.text('Unlock via Ads (Watch Ad)'));
      await tester.pump();

      expect(adTapped, isTrue);
      expect(coinsTapped, isFalse);
    });
  });

  group('LoyaltyScreen Claiming & Overflow Flow', () {
    testWidgets('renders qualified claiming section and handles claim to prevent duplicates', (tester) async {
      final mockProvider = MockLoyaltyProvider();
      mockProvider.mockLoyaltyStatus = LoyaltyUserStatus(
        minBalanceBirr: 50.0,
        maxBalanceBirr: 1000.0,
        dailyAccessDays: 7,
        freeCoins: 100,
        freeFullSeriesCount: 2,
        isActive: true,
        walletBalanceBirr: 80.0,
        walletBalanceCoins: 5,
        qualifies: true,
        neededBirr: 0.0,
        progressPct: 100.0,
        canClaim: true,
        rewardId: 1,
        isClaimed: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LoyaltyProvider>.value(value: mockProvider),
            Provider<AdService>.value(value: AdService()),
          ],
          child: const MaterialApp(
            home: LoyaltyScreen(),
          ),
        ),
      );
      await tester.pump();

      // Check initial qualified state
      expect(find.text('QUALIFIED'), findsOneWidget);
      expect(find.text('Claim Loyalty Perks (+100 Coins)'), findsOneWidget);

      // Tap claim button
      await tester.tap(find.text('Claim Loyalty Perks (+100 Coins)'));
      await tester.pump();

      // State is now marked claimed, preventing multiple claims
      expect(find.text('CLAIMED'), findsOneWidget);
      expect(find.text('Reward Already Claimed'), findsOneWidget);
    });

    testWidgets('renders on narrow screen (320px width) without pixel overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final mockProvider = MockLoyaltyProvider();
      mockProvider.mockLoyaltyStatus = LoyaltyUserStatus(
        minBalanceBirr: 5000.0,
        maxBalanceBirr: 10000.0,
        dailyAccessDays: 30,
        freeCoins: 5000,
        freeFullSeriesCount: 10,
        isActive: true,
        walletBalanceBirr: 12500.50,
        walletBalanceCoins: 250,
        qualifies: true,
        neededBirr: 0.0,
        progressPct: 100.0,
        canClaim: false,
        rewardId: 1,
        isClaimed: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LoyaltyProvider>.value(value: mockProvider),
            Provider<AdService>.value(value: AdService()),
          ],
          child: const MaterialApp(
            home: LoyaltyScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Reward Already Claimed'), findsOneWidget);
    });

    testWidgets('confirms standalone loyalty ad bonus section is removed from LoyaltyScreen', (tester) async {
      final mockProvider = MockLoyaltyProvider();
      mockProvider.mockLoyaltyStatus = LoyaltyUserStatus(
        minBalanceBirr: 50.0,
        maxBalanceBirr: 1000.0,
        dailyAccessDays: 7,
        freeCoins: 100,
        freeFullSeriesCount: 2,
        isActive: true,
        walletBalanceBirr: 20.0,
        walletBalanceCoins: 5,
        qualifies: false,
        neededBirr: 30.0,
        progressPct: 40.0,
        canClaim: false,
        rewardId: 1,
        isClaimed: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LoyaltyProvider>.value(value: mockProvider),
            Provider<AdService>.value(value: AdService()),
          ],
          child: const MaterialApp(
            home: LoyaltyScreen(),
          ),
        ),
      );
      await tester.pump();

      // Ensure standalone ad-watch bonus section is completely absent
      expect(find.text('Watch Ad for Loyalty Bonus'), findsNothing);
      expect(find.text('Watch a rewarded ad to earn daily bonus coins'), findsNothing);
      expect(find.text('Watch ads to get 100 coins'), findsNothing);
    });
  });

  group('RewardedAdBatchDialog Continuous Flow', () {
    testWidgets('plays batch silently without manual progress screens and auto-unlocks on completion', (tester) async {
      final rule = AdUnlockRule(
        adsRequired: 2,
        episodesUnlocked: 1,
        provider: 'admob',
        rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
        testMode: true,
      );

      bool completed = false;

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
                      episodeTitle: 'Episode 3 · Confrontation',
                      adService: AdService(),
                    ),
                  );
                  completed = res == true;
                },
                child: const Text('Launch Ad'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Ad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initial state: Silent buffer loading Ad 1
      expect(find.text('Loading ad 1 of 2...'), findsOneWidget);
      // Manual progress screens, intermediate countdown overlays, and buttons are eliminated
      expect(find.text('AD 1 OF 2'), findsNothing);
      expect(find.text('Unlock & Watch Episode Now'), findsNothing);

      // Fast-forward through Ad 1 (6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      // Automatically and silently in Ad 2 without premature reward banners
      expect(find.text('Loading ad 2 of 2...'), findsOneWidget);
      expect(find.text('Reward Granted'), findsNothing);

      // Fast-forward through Ad 2 (final ad, 6 seconds)
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Instantly unlocks and returns directly to caller without manual interaction!
      expect(completed, isTrue);
      expect(find.byType(RewardedAdBatchDialog), findsNothing);
    });
  });
}
