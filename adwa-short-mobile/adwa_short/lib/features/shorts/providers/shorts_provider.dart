import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/short_item.dart';

enum ShortsLoadStatus { idle, loading, loadingMore, success, error }

class ShortsProvider extends ChangeNotifier {
  ShortsProvider(this._api);

  final ApiClient _api;

  ShortsLoadStatus _status = ShortsLoadStatus.idle;
  final List<ShortItem> _items = [];
  String? _nextCursor;
  String? _errorMessage;
  bool _hasMore = true;

  ShortsLoadStatus get status => _status;
  List<ShortItem> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isEmpty => _items.isEmpty && _status == ShortsLoadStatus.success;

  int get lockedCount =>
      _items.where((i) => !i.isAccessible).length;
  int get freeCount =>
      _items.where((i) => i.isAccessible).length;

  Future<void> refresh() async {
    _items.clear();
    _nextCursor = null;
    _hasMore = true;
    await load();
  }

  Future<void> load() async {
    if (_status == ShortsLoadStatus.loading ||
        _status == ShortsLoadStatus.loadingMore) {
      return;
    }
    final isMore = _items.isNotEmpty;
    _status = isMore ? ShortsLoadStatus.loadingMore : ShortsLoadStatus.loading;
    notifyListeners();
    try {
      final path = ApiConstants.shortsFeed(cursor: _nextCursor);
      final feed = await _api.get(
        path,
        parser: (json) => ShortsFeed.fromJson(json),
      );
      final seenIds = _items.map((e) => e.id).toSet();
      for (final item in feed.items) {
        if (!seenIds.contains(item.id)) {
          _items.add(item);
        }
      }
      _nextCursor = feed.nextCursor;
      _hasMore = feed.nextCursor != null && feed.items.isNotEmpty;
      _status = ShortsLoadStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = ShortsLoadStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ShortsLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> toggleSave(int index) async {
    if (index < 0 || index >= _items.length) return;
    final original = _items[index];
    final updated = original.copyWith(isSaved: !original.isSaved);
    _items[index] = updated;
    notifyListeners();
    try {
      await _api.post(
        ApiConstants.engagementSave,
        body: {'episode_id': original.episodeId ?? original.id},
        parser: (json) => json,
      );
    } catch (e) {
      if (kDebugMode) print('toggleSave failed: $e');
      _items[index] = original;
      notifyListeners();
    }
  }

  void markAccessible(int index) {
    if (index < 0 || index >= _items.length) return;
    final original = _items[index];
    if (original.isAccessible) return;
    _items[index] = original.copyWith(isAccessible: true, accessReason: 'free');
    notifyListeners();
  }
}
