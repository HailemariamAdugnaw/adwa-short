import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/review.dart';

class ReviewProvider extends ChangeNotifier {
  ReviewProvider(this._api);

  final ApiClient _api;

  final Map<String, List<Review>> _reviewsByEpisode = {};
  final Map<String, bool> _hasMoreByEpisode = {};
  final Map<String, int> _pageByEpisode = {};
  final Map<String, int> _countByEpisode = {};
  final Set<String> _loadingEpisodes = {};
  final Set<String> _submittingEpisodes = {};
  int _maxChars = 100;
  String? _errorMessage;
  String? _submitError;

  List<Review> reviewsFor(String episodeId) =>
      List.unmodifiable(_reviewsByEpisode[episodeId] ?? const <Review>[]);
  int countFor(String episodeId) => _countByEpisode[episodeId] ?? 0;
  bool hasMoreFor(String episodeId) => _hasMoreByEpisode[episodeId] ?? true;
  bool isLoading(String episodeId) => _loadingEpisodes.contains(episodeId);
  bool isSubmitting(String episodeId) =>
      _submittingEpisodes.contains(episodeId);
  int get maxChars => _maxChars;
  String? get errorMessage => _errorMessage;
  String? get submitError => _submitError;

  bool get isOverLimit => false;

  bool isValid(String text) {
    final t = text.trim();
    return t.isNotEmpty && t.length <= _maxChars;
  }

  Future<void> loadSettings() async {
    try {
      final json = await _api.get(
        ApiConstants.appSettings,
        parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
      );
      final v = json['review_max_chars'] ?? json['max_chars'];
      if (v is num) {
        _maxChars = v.toInt();
      } else if (v is String) {
        final n = int.tryParse(v);
        if (n != null && n > 0) _maxChars = n;
      }
      notifyListeners();
    } catch (e) {
      if (e is ApiException && e.isForbidden) {
        return;
      }
      if (kDebugMode) print('loadSettings failed: $e');
    }
  }

  Future<bool> submitReview(
    String episodeId,
    String text, {
    int? rating,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > _maxChars) {
      _submitError = 'Review must be between 1 and $_maxChars characters.';
      notifyListeners();
      return false;
    }
    _submittingEpisodes.add(episodeId);
    _submitError = null;
    notifyListeners();
    try {
      await _api.post(
        ApiConstants.reviews,
        body: {
          'episode_id': episodeId,
          'text': trimmed,
          if (rating != null) 'rating': rating,
        },
        parser: (j) => j,
      );
      _submittingEpisodes.remove(episodeId);
      await getEpisodeReviews(episodeId, reset: true);
      return true;
    } on ApiException catch (e) {
      _submitError = e.message;
      _submittingEpisodes.remove(episodeId);
      notifyListeners();
      return false;
    } catch (e) {
      _submitError = e.toString();
      _submittingEpisodes.remove(episodeId);
      if (kDebugMode) print('submitReview failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> getEpisodeReviews(
    String episodeId, {
    bool reset = false,
  }) async {
    if (reset) {
      _pageByEpisode[episodeId] = 1;
      _reviewsByEpisode[episodeId] = [];
    }
    final page = _pageByEpisode[episodeId] ?? 1;
    _loadingEpisodes.add(episodeId);
    notifyListeners();
    try {
      final json = await _api.get(
        ApiConstants.episodeReviewsById(episodeId),
        query: {'page': page.toString()},
        parser: (j) => j is Map<String, dynamic> ? j : <String, dynamic>{},
      );
      final itemsRaw = json['items'] ?? json['reviews'];
      final List<Review> items = itemsRaw is List
          ? itemsRaw
              .whereType<Map<String, dynamic>>()
              .map(Review.fromJson)
              .toList()
          : const <Review>[];
      final totalRaw = json['total'] ?? json['count'];
      final int? total = totalRaw is num
          ? totalRaw.toInt()
          : (totalRaw is String ? int.tryParse(totalRaw) : null);
      final existing = _reviewsByEpisode[episodeId] ?? const <Review>[];
      final merged = reset ? items : [...existing, ...items];
      _reviewsByEpisode[episodeId] = merged;
      final bool more;
      if (items.isEmpty) {
        more = false;
      } else if (total != null) {
        more = merged.length < total;
      } else {
        more = items.length >= 10;
      }
      _hasMoreByEpisode[episodeId] = more;
      _pageByEpisode[episodeId] = page + 1;
      if (total != null) _countByEpisode[episodeId] = total;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) print('getEpisodeReviews failed: $e');
    }
    _loadingEpisodes.remove(episodeId);
    notifyListeners();
  }

  Future<bool> updateReview(String reviewId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > _maxChars) {
      _submitError = 'Review must be between 1 and $_maxChars characters.';
      notifyListeners();
      return false;
    }
    try {
      await _api.put(
        ApiConstants.reviewById(reviewId),
        body: {'text': trimmed},
        parser: (j) => j,
      );
      return true;
    } on ApiException catch (e) {
      _submitError = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _submitError = e.toString();
      if (kDebugMode) print('updateReview failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId, {String? episodeId}) async {
    try {
      await _api.delete(
        ApiConstants.reviewById(reviewId),
        parser: (j) => j,
      );
      if (episodeId != null) {
        final list = _reviewsByEpisode[episodeId];
        if (list != null) {
          _reviewsByEpisode[episodeId] =
              list.where((r) => r.id.toString() != reviewId).toList();
          final count = _countByEpisode[episodeId];
          if (count != null && count > 0) {
            _countByEpisode[episodeId] = count - 1;
          }
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('deleteReview failed: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    _submitError = null;
    notifyListeners();
  }
}
