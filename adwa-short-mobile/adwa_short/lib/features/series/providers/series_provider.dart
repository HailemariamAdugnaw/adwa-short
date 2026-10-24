import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/access_check.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';

enum SeriesDetailStatus { idle, loading, success, error }

class SeriesProvider extends ChangeNotifier {
  SeriesProvider(this._api);

  final ApiClient _api;

  SeriesDetailStatus _status = SeriesDetailStatus.idle;
  Series? _series;
  String? _errorMessage;

  SeriesDetailStatus get status => _status;
  Series? get series => _series;
  String? get errorMessage => _errorMessage;

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
          'episode_id': episodeId,
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
          'episode_id': episodeId,
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

  Future<bool> purchaseWithCoins({
    required String episodeId,
    required int coinCost,
  }) async {
    try {

      await _api.post(
        '/episodes/$episodeId/unlock',
        parser: (j) => j,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshAfterUnlock() async {
    final s = _series;
    if (s == null) return;
    await load(s.id);
  }
}
