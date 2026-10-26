import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/access_check.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';

enum SeriesDetailStatus { idle, loading, success, error }

class UnlockEpisodeResult {
  UnlockEpisodeResult({
    required this.success,
    this.coinsDeducted = 0,
    this.newBalanceCoins,
    this.message,
  });

  final bool success;
  final int coinsDeducted;
  final int? newBalanceCoins;
  final String? message;
}

class SeriesProvider extends ChangeNotifier {
  SeriesProvider(this._api);

  final ApiClient _api;

  SeriesDetailStatus _status = SeriesDetailStatus.idle;
  Series? _series;
  String? _errorMessage;
  int _defaultEpisodeCoinCost = 10;

  SeriesDetailStatus get status => _status;
  Series? get series => _series;
  String? get errorMessage => _errorMessage;
  int get defaultEpisodeCoinCost => _defaultEpisodeCoinCost;

  /// Fetches global public settings (such as default_episode_coin_cost) from Super Admin config.
  Future<void> fetchPublicSettings() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        ApiConstants.publicSettings,
        parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
      );
      if (res['default_episode_coin_cost'] is num) {
        _defaultEpisodeCoinCost = (res['default_episode_coin_cost'] as num).toInt();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('fetchPublicSettings note: $e');
    }
  }

  /// Dynamically resolves the coin cost for an episode following the strict priority hierarchy:
  /// 1. Custom episode coin cost if set (> 0)
  /// 2. Custom series-level coin cost override if configured on the series (> 0)
  /// 3. Global Super Admin default configuration (from public settings / default 10)
  int resolveCoinCost({Episode? episode, Series? series}) {
    if (episode?.coinCost != null && episode!.coinCost! > 0) {
      return episode.coinCost!;
    }
    final s = series ?? _series;
    if (s?.coinCost != null && s!.coinCost! > 0) {
      return s.coinCost!;
    }
    return _defaultEpisodeCoinCost;
  }

  Future<void> load(String id) async {
    _status = SeriesDetailStatus.loading;
    _series = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final json = await _api.get(
        ApiConstants.seriesDetail(id),
        parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
      );
      _series = Series.fromJson(json);
      _status = SeriesDetailStatus.success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = SeriesDetailStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = SeriesDetailStatus.error;
    }
    notifyListeners();
  }

  Future<AccessCheck> accessCheck(String episodeId) async {
    final json = await _api.get(
      ApiConstants.episodeAccessCheck(episodeId),
      parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
    );
    return AccessCheck.fromJson(json);
  }

  Future<bool> toggleSave({required String episodeId, bool currentlySaved = false}) async {
    try {
      if (currentlySaved) {
        await _api.delete(
          '${ApiConstants.engagementSave}/$episodeId',
          parser: (j) => j,
        );
      } else {
        await _api.post(
          ApiConstants.engagementSave,
          body: {'episode_id': episodeId},
          parser: (j) => j,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('toggleSave failed: $e');
      return false;
    }
  }

  Future<bool> toggleEpisodeLike(Episode episode) async {
    try {
      await _api.post(
        ApiConstants.engagementLike,
        body: {'episode_id': episode.id},
        parser: (j) => j,
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('toggleEpisodeLike failed: $e');
      return false;
    }
  }

  Future<void> pingView({
    required String episodeId,
    required int watchTimeSeconds,
    required bool completed,
  }) async {
    try {
      await _api.post(
        ApiConstants.engagementView,
        body: {
          'episode_id': int.tryParse(episodeId) ?? episodeId,
          'watch_time_seconds': watchTimeSeconds,
          'completed': completed,
        },
        parser: (j) => j,
      );
    } catch (e) {
      if (kDebugMode) print('pingView failed: $e');
    }
  }

  Future<bool> recordAdWatched({
    required String episodeId,
    required int adsWatched,
  }) async {
    try {
      await _api.post(
        ApiConstants.adUnlocksWatched,
        body: {
          'episode_id': int.tryParse(episodeId) ?? episodeId,
          'ads_watched': adsWatched,
        },
        parser: (j) => j,
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('recordAdWatched failed: $e');
      return false;
    }
  }

  Future<UnlockEpisodeResult> unlockWithCoinsDetailed({
    required String episodeId,
    required int coinCost,
  }) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/episodes/$episodeId/unlock',
        parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
      );
      final deducted = (res['coins_deducted'] is num)
          ? (res['coins_deducted'] as num).toInt()
          : coinCost;
      final newBal = (res['new_balance_coins'] is num)
          ? (res['new_balance_coins'] as num).toInt()
          : null;
      final msg = res['message']?.toString();

      if (_series != null) {
        final updatedEps = _series!.episodes.map((e) {
          if (e.id == episodeId) {
            return e.copyWith(
              isFree: false,
              isLocked: false,
              accessible: true,
              isAccessible: true,
            );
          }
          return e;
        }).toList();
        _series = _series!.copyWith(episodes: updatedEps);
        notifyListeners();
      }

      return UnlockEpisodeResult(
        success: true,
        coinsDeducted: deducted,
        newBalanceCoins: newBal,
        message: msg,
      );
    } catch (e) {
      if (kDebugMode) print('unlockWithCoinsDetailed failed: $e');
      return UnlockEpisodeResult(success: false);
    }
  }

  Future<bool> purchaseWithCoins({
    required String episodeId,
    required int coinCost,
  }) async {
    final res = await unlockWithCoinsDetailed(
      episodeId: episodeId,
      coinCost: coinCost,
    );
    return res.success;
  }

  Future<void> refreshAfterUnlock() async {
    final s = _series;
    if (s == null) return;
    await load(s.id);
  }
}
