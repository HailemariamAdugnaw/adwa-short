import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/shelf.dart';

enum ShelfLoadStatus { idle, loading, refreshing, success, error }

class ShelfProvider extends ChangeNotifier {
  ShelfProvider(this._api);

  final ApiClient _api;

  ShelfLoadStatus _status = ShelfLoadStatus.idle;
  List<Shelf> _shelves = [];
  String? _errorMessage;

  ShelfLoadStatus get status => _status;
  List<Shelf> get shelves => _shelves;
  String? get errorMessage => _errorMessage;

  Shelf? get bannerShelf {
    for (final s in _shelves) {
      if (s.type == ShelfType.banner || s.key == ShelfKeys.hot) return s;
    }
    return null;
  }

  List<Shelf> get rowShelves =>
      _shelves.where((s) => s.type != ShelfType.banner).toList();

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _status = ShelfLoadStatus.refreshing;
    } else {
      _status = ShelfLoadStatus.loading;
    }
    notifyListeners();
    try {
      final List<Shelf> list = await _api.get<List<Shelf>>(
        ApiConstants.shelvesHome,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => Shelf.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['shelves'] is List) {
            return (json['shelves'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => Shelf.fromJson(e))
                .toList();
          }
          return <Shelf>[];
        },
      );
      _shelves = list;
      _status = ShelfLoadStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = ShelfLoadStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ShelfLoadStatus.error;
    }
    notifyListeners();
  }
}
