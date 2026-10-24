import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/access_check.dart';

enum SearchStatus { idle, loading, success, error }

class SearchProvider extends ChangeNotifier {
  SearchProvider(this._api);

  final ApiClient _api;
  Timer? _debounce;

  SearchStatus _status = SearchStatus.idle;
  SearchResult _result = SearchResult();
  String _query = '';
  String? _errorMessage;
  List<String> _recentQueries = [];

  SearchStatus get status => _status;
  SearchResult get result => _result;
  String get query => _query;
  String? get errorMessage => _errorMessage;
  List<String> get recentQueries => _recentQueries;

  void debouncedSearch(String q, {Duration delay = const Duration(milliseconds: 400)}) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      clear();
      return;
    }
    _debounce = Timer(delay, () => search(query));
  }

  Future<void> search(String q) async {
    _debounce?.cancel();
    final query = q.trim();
    _query = query;
    if (query.isEmpty) {
      _result = SearchResult();
      _status = SearchStatus.idle;
      notifyListeners();
      return;
    }
    _status = SearchStatus.loading;
    notifyListeners();
    try {
      _result = await _api.get<SearchResult>(
        ApiConstants.search(query),
        parser: (j) => SearchResult.fromJson(j),
      );
      _status = SearchStatus.success;
      _errorMessage = null;

      _recentQueries = [
        query,
        ..._recentQueries.where((e) => e != query),
      ].take(8).toList();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = SearchStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = SearchStatus.error;
    }
    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _query = '';
    _result = SearchResult();
    _status = SearchStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void clearRecent() {
    _recentQueries = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
