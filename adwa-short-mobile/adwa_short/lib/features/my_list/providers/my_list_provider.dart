import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/access_check.dart';
import '../../../models/series.dart';

enum MyListStatus { idle, loading, refreshing, success, error }

class MyListProvider extends ChangeNotifier {
  MyListProvider(this._api);

  final ApiClient _api;

  MyListStatus _historyStatus = MyListStatus.idle;
  MyListStatus _savedStatus = MyListStatus.idle;
  List<WatchHistoryEntry> _history = [];
  List<Series> _saved = [];
  final Map<String, String> _savedEpisodeBySeriesId = {};
  String? _historyError;
  String? _savedError;

  MyListStatus get historyStatus => _historyStatus;
  MyListStatus get savedStatus => _savedStatus;
  List<WatchHistoryEntry> get history => _history;
  List<Series> get saved => _saved;
  String? get historyError => _historyError;
  String? get savedError => _savedError;

  Future<void> loadHistory({bool refresh = false}) async {
    _historyStatus = refresh ? MyListStatus.refreshing : MyListStatus.loading;
    notifyListeners();
    try {
      final List<WatchHistoryEntry> list =
          await _api.get<List<WatchHistoryEntry>>(
        ApiConstants.engagementHistory,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => WatchHistoryEntry.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['items'] is List) {
            return (json['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => WatchHistoryEntry.fromJson(e))
                .toList();
          }
          return <WatchHistoryEntry>[];
        },
      );
      _history = list;
      _historyStatus = MyListStatus.success;
      _historyError = null;
    } on ApiException catch (e) {
      _historyError = e.message;
      _historyStatus = MyListStatus.error;
    } catch (e) {
      _historyError = e.toString();
      _historyStatus = MyListStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadSaved({bool refresh = false}) async {
    _savedStatus = refresh ? MyListStatus.refreshing : MyListStatus.loading;
    notifyListeners();
    try {
      final List<Series> list = await _api.get<List<Series>>(
        ApiConstants.engagementSaved,
        parser: (json) {
          List<dynamic> rawList;
          if (json is List) {
            rawList = json;
          } else if (json is Map<String, dynamic> && json['items'] is List) {
            rawList = json['items'] as List;
          } else {
            rawList = const [];
          }
          return rawList
              .whereType<Map<String, dynamic>>()
              .map(_savedItemToSeries)
              .toList();
        },
      );
      _saved = list;
      _savedEpisodeBySeriesId.clear();
      for (final s in list) {
        final epId = s.episodeId;
        if (epId != null && epId.isNotEmpty) {
          _savedEpisodeBySeriesId[s.id] = epId;
        }
      }
      _savedStatus = MyListStatus.success;
      _savedError = null;
    } on ApiException catch (e) {
      _savedError = e.message;
      _savedStatus = MyListStatus.error;
    } catch (e) {
      _savedError = e.toString();
      _savedStatus = MyListStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadAll({bool refresh = false}) async {
    await Future.wait([
      loadHistory(refresh: refresh),
      loadSaved(refresh: refresh),
    ]);
  }

  Future<bool> unsaveSeries(String id) async {
    final episodeId = _savedEpisodeBySeriesId[id];
    if (episodeId == null || episodeId.isEmpty) {
      _saved = _saved.where((s) => s.id != id).toList();
      _savedEpisodeBySeriesId.remove(id);
      notifyListeners();
      return false;
    }
    try {
      await _api.delete(
        '/engagement/save/$episodeId',
        parser: (j) => j,
      );
      _saved = _saved.where((s) => s.id != id).toList();
      _savedEpisodeBySeriesId.remove(id);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('unsave failed: $e');
      return false;
    }
  }
}

Series _savedItemToSeries(Map<String, dynamic> json) {
  final dynamic rawSeriesId = json['series_id'] ?? json['id'];
  final dynamic rawEpisodeId = json['episode_id'];
  final dynamic rawTitle =
      json['series_title'] ?? json['title'] ?? json['episode_title'];
  final dynamic rawPoster =
      json['poster_url'] ?? json['thumbnail_url'] ?? json['banner_url'];
  return Series(
    id: rawSeriesId?.toString() ?? '',
    title: rawTitle?.toString() ?? 'Saved',
    description: json['episode_title']?.toString() ?? '',
    posterUrl: rawPoster?.toString(),
    bannerUrl: json['banner_url']?.toString(),
    isVip: json['is_vip'] == true,
    isExclusive: json['is_exclusive'] == true,
    isHot: json['is_hot'] == true,
    isNewRelease: json['is_new_release'] == true,
    totalEpisodes: _asInt(json['total_episodes']) ??
        _asInt(json['episode_count']) ??
        0,
    freeEpisodeCount: _asInt(json['free_episode_count']) ?? 0,
    cast: const [],
    tags: const [],
    rating: null,
    episodeId: rawEpisodeId?.toString(),
  );
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
