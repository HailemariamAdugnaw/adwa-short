import 'package:flutter/material.dart';

import '../features/auth/providers/auth_provider.dart';
import '../models/user.dart';

class AppStateProvider extends ChangeNotifier {
  AppStateProvider();

  User? _user;
  String? _deviceId;
  Locale _locale = const Locale('en');

  User? get user => _user;
  String? get deviceId => _deviceId;
  Locale get locale => _locale;

  void setUser(User? user) {
    if (_user == user) return;
    _user = user;
    notifyListeners();
  }

  void setDeviceId(String id) {
    if (_deviceId == id) return;
    _deviceId = id;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void syncFromAuth(AuthProvider auth) {
    setUser(auth.user);
  }

  bool get isAuthenticated => _user != null;
}
