import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
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
  bool get isGuest => _repository.tokenManager.isGuest;

  Future<void> continueAsGuest() async {
    await logout();
    await _repository.setGuest(true);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    onAuthStateChanged?.call(null, false);
  }

  Future<void> bootstrap() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final tokenManager = _repository.tokenManager;
    final hasToken = tokenManager.accessToken != null &&
        tokenManager.accessToken!.isNotEmpty;
    final savedUser = tokenManager.getSavedUser();

    // 1. If user previously logged in, restore local authentication immediately
    if (hasToken || tokenManager.isLoggedIn) {
      if (savedUser != null) {
        _user = savedUser;
        _status = AuthStatus.authenticated;
        notifyListeners();
        onAuthStateChanged?.call(_user, true);
      }

      // 2. Refresh profile with backend in background without dropping session on network error
      try {
        final freshUser = await _repository.fetchMe();
        _user = freshUser;
        _status = AuthStatus.authenticated;
      } on ApiException catch (e) {
        // Only invalidate if the backend explicitly rejected the token as expired
        if (e.statusCode == 401 &&
            (e.code == ApiConstants.errorCodeTokenExpired ||
                e.message.toLowerCase().contains('expired'))) {
          await logout();
          return;
        }
        // If offline or other network error, keep saved user authenticated
        if (_user != null) {
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } catch (_) {
        if (_user != null) {
          _status = AuthStatus.authenticated;
        }
      }
    } else if (tokenManager.isGuest) {
      _user = null;
      _status = AuthStatus.unauthenticated;
    } else {
      _user = null;
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
