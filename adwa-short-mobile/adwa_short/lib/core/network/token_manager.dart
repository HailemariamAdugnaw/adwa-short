import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../constants/api_constants.dart';

class TokenManager {
  TokenManager(this._prefs);

  final SharedPreferences _prefs;

  String? get accessToken => _prefs.getString(ApiConstants.storageAccessToken);
  String? get refreshToken => _prefs.getString(ApiConstants.storageRefreshToken);
  String? get deviceId => _prefs.getString(ApiConstants.storageDeviceId);
  String? get userId => _prefs.getString(ApiConstants.storageUserId);
  String? get userPhone => _prefs.getString(ApiConstants.storageUserPhone);
  String? get displayName => _prefs.getString(ApiConstants.storageDisplayName);
  bool get isLoggedIn =>
      _prefs.getBool(ApiConstants.storageIsLoggedIn) ??
      (accessToken != null && accessToken!.isNotEmpty);
  bool get isGuest => _prefs.getBool(ApiConstants.storageIsGuest) ?? false;
  String? get userProfileJson =>
      _prefs.getString(ApiConstants.storageUserProfileJson);

  Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool(ApiConstants.storageIsLoggedIn, value);
    if (value) {
      await _prefs.setBool(ApiConstants.storageIsGuest, false);
    }
  }

  Future<void> setGuest(bool value) async {
    await _prefs.setBool(ApiConstants.storageIsGuest, value);
    if (value) {
      await _prefs.setBool(ApiConstants.storageIsLoggedIn, false);
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(ApiConstants.storageAccessToken, accessToken);
    await _prefs.setString(ApiConstants.storageRefreshToken, refreshToken);
    await setLoggedIn(true);
  }

  Future<void> saveUserProfile(User user) async {
    await _prefs.setString(
        ApiConstants.storageUserProfileJson, jsonEncode(user.toJson()));
    await saveUser(
      userId: user.id,
      phone: user.phone,
      displayName: user.displayName,
    );
  }

  User? getSavedUser() {
    final raw = userProfileJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = decodeJson(raw);
        if (map is Map<String, dynamic>) {
          return User.fromJson(map);
        }
      } catch (_) {}
    }
    final id = userId;
    if (id != null && id.isNotEmpty) {
      return User(
        id: id,
        phone: userPhone ?? '',
        displayName: displayName ?? 'User',
      );
    }
    return null;
  }

  Future<void> saveUser({
    String? userId,
    String? phone,
    String? displayName,
  }) async {
    if (userId != null) {
      await _prefs.setString(ApiConstants.storageUserId, userId);
    }
    if (phone != null) {
      await _prefs.setString(ApiConstants.storageUserPhone, phone);
    }
    if (displayName != null) {
      await _prefs.setString(ApiConstants.storageDisplayName, displayName);
    }
  }

  Future<void> saveDeviceId(String id) async {
    await _prefs.setString(ApiConstants.storageDeviceId, id);
  }

  Future<void> clearAll() async {
    await _prefs.remove(ApiConstants.storageAccessToken);
    await _prefs.remove(ApiConstants.storageRefreshToken);
    await _prefs.remove(ApiConstants.storageUserId);
    await _prefs.remove(ApiConstants.storageUserPhone);
    await _prefs.remove(ApiConstants.storageDisplayName);
    await _prefs.remove(ApiConstants.storageUserProfileJson);
    await _prefs.remove(ApiConstants.storageIsLoggedIn);
    await _prefs.remove(ApiConstants.storageIsGuest);
  }

  bool get isAuthenticated =>
      isLoggedIn && accessToken != null && accessToken!.isNotEmpty;

  static String encodeJson(Map<String, dynamic> body) =>
      jsonEncode(body);

  static dynamic decodeJson(String body) {
    if (body.isEmpty) return null;
    return jsonDecode(body);
  }
}
