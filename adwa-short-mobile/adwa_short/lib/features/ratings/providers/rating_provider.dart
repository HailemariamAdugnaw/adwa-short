import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/rating.dart';

class RatingProvider extends ChangeNotifier {
  RatingProvider(this._api);

  final ApiClient _api;

  final Map<String, RatingSummary> _summaryCache = {};
  final Map<String, int> _userRating = {};
  final Set<String> _loadingEpisodes = {};
  String? _errorMessage;

  RatingSummary? summaryFor(String episodeId) => _summaryCache[episodeId];
  int userRatingFor(String episodeId) => _userRating[episodeId] ?? 0;
  bool isLoading(String episodeId) => _loadingEpisodes.contains(episodeId);
  String? get errorMessage => _errorMessage;

  Future<void> rateEpisode(String episodeId, int rating) async {
    final clamped = rating.clamp(1, 5);
    final previous = _userRating[episodeId];
    _userRating[episodeId] = clamped;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.post(
        ApiConstants.ratings,
        body: {'episode_id': episodeId, 'rating': clamped},
        parser: (j) => j,
      );
      await getEpisodeRating(episodeId, force: true);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _userRating[episodeId] = previous ?? 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _userRating[episodeId] = previous ?? 0;
      if (kDebugMode) print('rateEpisode failed: $e');
      notifyListeners();
    }
  }

  Future<RatingSummary?> getEpisodeRating(
    String episodeId, {
    bool force = false,
  }) async {
    if (!force && _summaryCache.containsKey(episodeId)) {
      return _summaryCache[episodeId];
    }
    _loadingEpisodes.add(episodeId);
    notifyListeners();
    try {
      final json = await _api.get(
        ApiConstants.episodeRatingById(episodeId),
        parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
      );
      final summary = RatingSummary.fromJson(json);
      _summaryCache[episodeId] = summary;
      if (summary.userRating != null) {
        _userRating[episodeId] = summary.userRating!;
      }
      _loadingEpisodes.remove(episodeId);
      _errorMessage = null;
      notifyListeners();
      return summary;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _loadingEpisodes.remove(episodeId);
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _loadingEpisodes.remove(episodeId);
      if (kDebugMode) print('getEpisodeRating failed: $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteRating(String ratingId, {String? episodeId}) async {
    try {
      await _api.delete(
        ApiConstants.ratingById(ratingId),
        parser: (j) => j,
      );
      if (episodeId != null) {
        _userRating.remove(episodeId);
        await getEpisodeRating(episodeId, force: true);
      }
    } catch (e) {
      if (kDebugMode) print('deleteRating failed: $e');
    }
  }

  Future<void> getMyRatings() async {
    try {
      final json = await _api.get(
        ApiConstants.myRatings,
        parser: (j) => j,
      );
      List<dynamic> items;
      if (json is List) {
        items = json;
      } else if (json is Map<String, dynamic> && json['items'] is List) {
        items = json['items'] as List;
      } else {
        items = const [];
      }
      for (final raw in items.whereType<Map<String, dynamic>>()) {
        final r = EpisodeRating.fromJson(raw);
        _userRating[r.episodeId.toString()] = r.rating;
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('getMyRatings failed: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
