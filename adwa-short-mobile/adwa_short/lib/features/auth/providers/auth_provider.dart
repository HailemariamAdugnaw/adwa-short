import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  void Function(User? user, bool isAuthenticated)? onAuthStateChanged;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      _user = await _repository.fetchMe();
      _status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
    onAuthStateChanged?.call(_user, isAuthenticated);
  }

  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _repository.login(phone: phone, password: password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      onAuthStateChanged?.call(_user, true);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _repository.register(
        phone: phone,
        password: password,
        displayName: displayName,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      onAuthStateChanged?.call(_user, true);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    onAuthStateChanged?.call(null, false);
  }

  Future<void> refreshUser() async {
    try {
      _user = await _repository.fetchMe();
      notifyListeners();
      onAuthStateChanged?.call(_user, isAuthenticated);
    } catch (e) {
      if (kDebugMode) print('refreshUser failed: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}
