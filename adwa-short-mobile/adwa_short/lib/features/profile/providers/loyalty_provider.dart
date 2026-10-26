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
  LoyaltyUserStatus? _loyaltyStatus;
  String? _errorMessage;
  bool _isClaiming = false;

  LoyaltyStatus get status => _status;
  List<LoyaltyGrant> get grants => _grants;
  AdUnlockRule? get rule => _rule;
  LoyaltyUserStatus? get loyaltyStatus => _loyaltyStatus;
  String? get errorMessage => _errorMessage;
  bool get isClaiming => _isClaiming;

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
        _api.get<LoyaltyUserStatus?>(
          ApiConstants.loyaltyStatus,
          parser: (json) => json is Map<String, dynamic>
              ? LoyaltyUserStatus.fromJson(json)
              : null,
        ).catchError((_) => null),
      ]);

      _grants = results[0] as List<LoyaltyGrant>;
      _rule = results[1] as AdUnlockRule;
      if (results[2] is LoyaltyUserStatus) {
        _loyaltyStatus = results[2] as LoyaltyUserStatus;
      }
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

  /// Claims available Super Admin configured loyalty tier perks (coins + access).
  /// Strictly blocks duplicate claims if already claimed or ineligible.
  Future<bool> claimLoyaltyReward() async {
    if (_loyaltyStatus != null && (_loyaltyStatus!.isClaimed || !_loyaltyStatus!.canClaim)) {
      _errorMessage = 'You have already claimed this loyalty reward. Each reward can only be claimed once.';
      notifyListeners();
      return false;
    }
    _isClaiming = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.post(
        ApiConstants.loyaltyClaim,
        body: {},
        parser: (j) => j,
      );
      if (_loyaltyStatus != null) {
        _loyaltyStatus = _loyaltyStatus!.copyWith(
          isClaimed: true,
          canClaim: false,
        );
      }
      await load();
      return true;
    } catch (e) {
      if (kDebugMode) print('Failed to claim loyalty reward: $e');
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isClaiming = false;
      notifyListeners();
    }
  }
}
