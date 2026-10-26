import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/coin_package.dart';
import '../../../models/subscription.dart';
import '../../../models/time_pass.dart';
import '../../../models/wallet.dart';

enum WalletLoadStatus { idle, loading, refreshing, success, error }

class WalletProvider extends ChangeNotifier {
  WalletProvider(this._api);

  final ApiClient _api;

  WalletLoadStatus _walletStatus = WalletLoadStatus.idle;
  WalletLoadStatus _packagesStatus = WalletLoadStatus.idle;
  WalletLoadStatus _passesStatus = WalletLoadStatus.idle;
  WalletLoadStatus _subsStatus = WalletLoadStatus.idle;

  Wallet? _wallet;
  List<CoinPackage> _packages = [];
  List<TimePass> _passes = [];
  List<SubscriptionPlan> _plans = [];

  String? _walletError;
  String? _packagesError;
  String? _passesError;
  String? _subsError;

  Wallet? get wallet => _wallet;
  List<CoinPackage> get packages => _packages;
  List<TimePass> get passes => _passes;
  List<SubscriptionPlan> get plans => _plans;

  WalletLoadStatus get walletStatus => _walletStatus;
  WalletLoadStatus get packagesStatus => _packagesStatus;
  WalletLoadStatus get passesStatus => _passesStatus;
  WalletLoadStatus get subsStatus => _subsStatus;

  String? get walletError => _walletError;
  String? get packagesError => _packagesError;
  String? get passesError => _passesError;
  String? get subsError => _subsError;

  void deductCoins(int coins) {
    if (_wallet != null) {
      final newCoins = (_wallet!.balanceCoins - coins).clamp(0, 99999999);
      _wallet = _wallet!.copyWith(balanceCoins: newCoins);
      notifyListeners();
    }
  }

  void setCoinBalance(int newBalance) {
    if (_wallet != null) {
      _wallet = _wallet!.copyWith(balanceCoins: newBalance);
    } else {
      _wallet = Wallet(balanceBirr: 0, balanceCoins: newBalance);
    }
    notifyListeners();
  }

  Future<void> loadWallet({bool refresh = false}) async {
    _walletStatus = refresh ? WalletLoadStatus.refreshing : WalletLoadStatus.loading;
    notifyListeners();
    try {
      final Wallet w = await _api.get<Wallet>(
        ApiConstants.wallet,
        parser: (json) => json is Map<String, dynamic>
            ? Wallet.fromJson(json)
            : Wallet(balanceBirr: 0, balanceCoins: 0),
      );
      _wallet = w;
      _walletStatus = WalletLoadStatus.success;
      _walletError = null;
    } on ApiException catch (e) {
      _walletError = e.message;
      _walletStatus = WalletLoadStatus.error;
    } catch (e) {
      _walletError = e.toString();
      _walletStatus = WalletLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadPackages() async {
    _packagesStatus = WalletLoadStatus.loading;
    notifyListeners();
    try {
      final List<CoinPackage> list = await _api.get<List<CoinPackage>>(
        ApiConstants.coinsPackages,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => CoinPackage.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['items'] is List) {
            return (json['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => CoinPackage.fromJson(e))
                .toList();
          }
          return <CoinPackage>[];
        },
      );
      _packages = list;
      _packagesStatus = WalletLoadStatus.success;
      _packagesError = null;
    } on ApiException catch (e) {
      _packagesError = e.message;
      _packagesStatus = WalletLoadStatus.error;
    } catch (e) {
      _packagesError = e.toString();
      _packagesStatus = WalletLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadPasses() async {
    _passesStatus = WalletLoadStatus.loading;
    notifyListeners();
    try {
      final List<TimePass> list = await _api.get<List<TimePass>>(
        ApiConstants.passes,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => TimePass.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['items'] is List) {
            return (json['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => TimePass.fromJson(e))
                .toList();
          }
          return <TimePass>[];
        },
      );
      _passes = list;
      _passesStatus = WalletLoadStatus.success;
      _passesError = null;
    } on ApiException catch (e) {
      _passesError = e.message;
      _passesStatus = WalletLoadStatus.error;
    } catch (e) {
      _passesError = e.toString();
      _passesStatus = WalletLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadSubscriptions() async {
    _subsStatus = WalletLoadStatus.loading;
    notifyListeners();
    try {
      final List<SubscriptionPlan> list =
          await _api.get<List<SubscriptionPlan>>(
        ApiConstants.subscriptionsPlans,
        parser: (json) {
          if (json is List) {
            return json
                .whereType<Map<String, dynamic>>()
                .map((e) => SubscriptionPlan.fromJson(e))
                .toList();
          }
          if (json is Map<String, dynamic> && json['items'] is List) {
            return (json['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => SubscriptionPlan.fromJson(e))
                .toList();
          }
          return <SubscriptionPlan>[];
        },
      );
      _plans = list;
      _subsStatus = WalletLoadStatus.success;
      _subsError = null;
    } on ApiException catch (e) {
      _subsError = e.message;
      _subsStatus = WalletLoadStatus.error;
    } catch (e) {
      _subsError = e.toString();
      _subsStatus = WalletLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> purchaseCoins(CoinPackage pkg) async {
    try {
      await _api.post(
        ApiConstants.coinsPurchase,
        body: {'package_id': pkg.id},
        parser: (j) => j,
      );
      await loadWallet(refresh: true);
      return true;
    } catch (e) {
      if (kDebugMode) print('purchaseCoins failed: $e');
      return false;
    }
  }

  Future<bool> purchasePass(TimePass pass) async {
    try {
      await _api.post(
        ApiConstants.passesPurchase,
        body: {'pass_id': pass.id},
        parser: (j) => j,
      );
      await loadWallet(refresh: true);
      return true;
    } catch (e) {
      if (kDebugMode) print('purchasePass failed: $e');
      return false;
    }
  }

  Future<bool> subscribe(SubscriptionPlan plan) async {
    try {
      await _api.post(
        ApiConstants.subscriptionsSubscribe,
        body: {'plan_id': plan.id},
        parser: (j) => j,
      );
      await loadWallet(refresh: true);
      return true;
    } catch (e) {
      if (kDebugMode) print('subscribe failed: $e');
      return false;
    }
  }

  Future<bool> deposit(num amount) async {
    try {
      await _api.post(
        ApiConstants.walletDeposit,
        body: {'amount': amount, 'provider': 'telebirr'},
        parser: (j) => j,
      );
      await loadWallet(refresh: true);
      return true;
    } catch (e) {
      if (kDebugMode) print('deposit failed: $e');
      return false;
    }
  }
}
