import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/loyalty_grant.dart';

enum LoyaltyStatus { idle, loading, success, error }

class LoyaltyProvider extends ChangeNotifier {
  LoyaltyProvider(this._api);

  final ApiClient _api;

  LoyaltyStatus _status = LoyaltyStatus.idle;
  List<LoyaltyGrant> _grants = [];
  AdUnlockRule? _rule;
  String? _errorMessage;

  LoyaltyStatus get status => _status;
  List<LoyaltyGrant> get grants => _grants;
  AdUnlockRule? get rule => _rule;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _status = LoyaltyStatus.loading;
    notifyListeners();
    try {
      final List<dynamic> results = await Future.wait([
        _api.get<List<LoyaltyGrant>>(
          ApiConstants.loyaltyMyGrants,
          parser: (json) {
            if (json is List) {
              return json
                  .whereType<Map<String, dynamic>>()
                  .map((e) => LoyaltyGrant.fromJson(e))
                  .toList();
            }
            if (json is Map<String, dynamic> && json['items'] is List) {
              return (json['items'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map((e) => LoyaltyGrant.fromJson(e))
                  .toList();
            }
            return <LoyaltyGrant>[];
          },
        ),
        _api.get<AdUnlockRule>(
          ApiConstants.adUnlocksRule,
          parser: (json) => json is Map<String, dynamic>
              ? AdUnlockRule.fromJson(json)
              : AdUnlockRule.fromJson({}),
        ),
      ]);
      _grants = results[0] as List<LoyaltyGrant>;
      _rule = results[1] as AdUnlockRule;
      _status = LoyaltyStatus.success;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = LoyaltyStatus.error;
    } catch (e) {
      _errorMessage = e.toString();
      _status = LoyaltyStatus.error;
    }
    notifyListeners();
  }
}
