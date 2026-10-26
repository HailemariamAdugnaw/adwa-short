import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/theme/colors.dart';
import 'package:adwa_short/features/profile/providers/wallet_provider.dart';
import 'package:adwa_short/features/series/widgets/episode_list_tile.dart';
import 'package:adwa_short/features/shorts/widgets/paywall_overlay.dart';
import 'package:adwa_short/models/episode.dart';
import 'package:adwa_short/models/series.dart';
import 'package:adwa_short/models/short_item.dart';

void main() {
  group('Hierarchical Free Trial Episodes & State Rendering', () {
    test('Series.fromJson parses hierarchical free trial episodes fields', () {
      final json1 = {
        'id': '10',
        'title': 'Echoes of Adwa',
        'free_episode_count': 5,
      };
      final s1 = Series.fromJson(json1);
      expect(s1.freeEpisodeCount, 5);

      final json2 = {
        'id': '11',
        'title': 'Global Setting Series',
        'effective_free_episodes': 3,
      };
      final s2 = Series.fromJson(json2);
      expect(s2.freeEpisodeCount, 3);
    });

    test('Episode.fromJson derives isFree and isLocked correctly from hierarchical free count', () {
      // Episode 1 of series with 2 free episodes
      final ep1 = Episode.fromJson({
        'id': '101',
        'episode_number': 1,
        'title': 'Episode 1',
      }, defaultFreeCount: 2);

      expect(ep1.isFree, isTrue);
      expect(ep1.isLocked, isFalse);
      expect(ep1.effectivelyAccessible, isTrue);

      // Episode 3 of series with 2 free episodes
      final ep3 = Episode.fromJson({
        'id': '103',
        'episode_number': 3,
        'title': 'Episode 3',
      }, defaultFreeCount: 2);

      expect(ep3.isFree, isFalse);
      expect(ep3.isLocked, isTrue);
      expect(ep3.effectivelyAccessible, isFalse);
    });

    test('Series with 0 free episodes locks episode 1', () {
      final ep1 = Episode.fromJson({
        'id': '201',
        'episode_number': 1,
        'title': 'Pilot Locked',
      }, defaultFreeCount: 0);

      expect(ep1.isFree, isFalse);
      expect(ep1.isLocked, isTrue);
      expect(ep1.effectivelyAccessible, isFalse);
    });
  });

  group('Brand Color Enforcement on Episode Free Badge', () {
    testWidgets('EpisodeListTile renders FREE badge with blood red brand colors (no green)', (tester) async {
      final freeEpisode = Episode(
        id: '1',
        seriesId: 's1',
        number: 1,
        title: 'Free Pilot',
        isFree: true,
        isLocked: false,
        accessible: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeListTile(
              episode: freeEpisode,
              index: 0,
            ),
          ),
        ),
      );

      expect(find.text('FREE'), findsOneWidget);

      // Verify no green/success colors exist
      final textWidget = tester.widget<Text>(find.text('FREE'));
      expect(textWidget.style?.color, AppColors.bloodRedBright);
      expect(textWidget.style?.color, isNot(AppColors.success));
    });
  });

  group('WalletProvider Real-Time Coin Updates', () {
    test('deductCoins and setCoinBalance update balance immediately', () {
      final dummyClient = _FakeApiClient();
      final walletProvider = WalletProvider(dummyClient);

      int notifyCount = 0;
      walletProvider.addListener(() {
        notifyCount++;
      });

      // Set initial coins to 100
      walletProvider.setCoinBalance(100);
      expect(walletProvider.wallet?.balanceCoins, 100);
      expect(notifyCount, 1);

      // Deduct 15 coins
      walletProvider.deductCoins(15);
      expect(walletProvider.wallet?.balanceCoins, 85);
      expect(notifyCount, 2);
    });
  });

  group('Dynamic Coin Unlock Pricing Hierarchy', () {
    test('Series.fromJson parses custom coin_cost override', () {
      final s = Series.fromJson({
        'id': '50',
        'title': 'Premium Series',
        'coin_cost': 25,
      });
      expect(s.coinCost, 25);
    });

    test('Episode.fromJson uses episode cost, or falls back to series override, then default 10', () {
      // 1. Episode with custom cost 20
      final epCustom = Episode.fromJson({
        'id': '1',
        'coin_cost': 20,
      }, defaultCoinCost: 15);
      expect(epCustom.coinCost, 20);

      // 2. Episode without custom cost inherits series default (15)
      final epSeriesOverride = Episode.fromJson({
        'id': '2',
        'coin_cost': 0,
      }, defaultCoinCost: 15);
      expect(epSeriesOverride.coinCost, 15);

      // 3. Episode without series override defaults to 10
      final epDefault = Episode.fromJson({
        'id': '3',
      });
      expect(epDefault.coinCost, 10);
    });

    testWidgets('PaywallOverlay dynamically reflects series custom coin pricing', (tester) async {
      final item = ShortItem(
        id: '10',
        seriesId: 's10',
        title: 'Special Episode',
        verticalVideoUrl: '',
        coinCost: 25,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallOverlay(
              item: item,
            ),
          ),
        ),
      );

      expect(find.text('Unlock with Coins (25 Coins)'), findsOneWidget);
    });
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(tokenManager: _FakeTokenManager());
}

class _FakeTokenManager implements TokenManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
