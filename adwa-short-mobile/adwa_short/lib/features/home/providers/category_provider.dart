import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/category.dart';
import '../../../models/series.dart';

enum CategoryLoadStatus { idle, loading, success, error }
enum CategorySeriesStatus { idle, loading, refreshing, success, error }

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._api);

  final ApiClient _api;

  CategoryLoadStatus _status = CategoryLoadStatus.idle;
  List<AdwaCategory> _categories = <AdwaCategory>[];
  String? _errorMessage;
  String _selectedId = 'all';

  CategorySeriesStatus _seriesStatus = CategorySeriesStatus.idle;
  List<Series> _filteredSeries = <Series>[];
  String? _seriesError;

  CategoryLoadStatus get status => _status;
  List<AdwaCategory> get categories => _categories;
  String? get errorMessage => _errorMessage;
  String get selectedId => _selectedId;

  CategorySeriesStatus get seriesStatus => _seriesStatus;
  List<Series> get filteredSeries => _filteredSeries;
  String? get seriesError => _seriesError;

  bool get isFiltering => _selectedId != 'all';

  AdwaCategory? get selected => _selectedId == 'all'
      ? null
      : _categories
          .where((AdwaCategory c) => c.id == _selectedId)
          .cast<AdwaCategory?>()
          .firstWhere((_) => true, orElse: () => null);

  void select(String id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
    if (_selectedId == 'all') {
      _filteredSeries = <Series>[];
      _seriesStatus = CategorySeriesStatus.idle;
      _seriesError = null;
      notifyListeners();
    } else {
      loadFilteredSeries();
    }
  }

  Future<void> loadFilteredSeries({bool refresh = false}) async {
    if (_selectedId == 'all') {
      _filteredSeries = <Series>[];
      _seriesStatus = CategorySeriesStatus.idle;
      _seriesError = null;
      notifyListeners();
      return;
    }
    _seriesStatus =
        refresh ? CategorySeriesStatus.refreshing : CategorySeriesStatus.loading;
    notifyListeners();
    try {
      final List<Series> list = await _api.get<List<Series>>(
        ApiConstants.seriesList,
        query: {'category_id': _selectedId, 'limit': '100'},
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => Series.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['items'] is List) {
            return (json['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => Series.fromJson(e))
                .toList();
          }
          return <Series>[];
        },
      );
      _filteredSeries = list;
      _seriesStatus = CategorySeriesStatus.success;
      _seriesError = null;
    } on ApiException catch (e) {
      _seriesError = e.message;
      _seriesStatus = CategorySeriesStatus.error;
    } catch (e) {
      _seriesError = e.toString();
      _seriesStatus = CategorySeriesStatus.error;
    }
    notifyListeners();
  }

  Future<void> load() async {
    _status = CategoryLoadStatus.loading;
    notifyListeners();
    try {
      final List<AdwaCategory> list = await _api.get<List<AdwaCategory>>(
        ApiConstants.categories,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => AdwaCategory.fromJson(e))
                .toList();
          }
          return <AdwaCategory>[];
        },
      );
      list.sort((AdwaCategory a, AdwaCategory b) =>
          a.sortOrder.compareTo(b.sortOrder));
      _categories = list;
      _status = CategoryLoadStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = CategoryLoadStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CategoryLoadStatus.error;
    }
    notifyListeners();
  }
}
