import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(ApiConstants.storageAccessToken, accessToken);
    await _prefs.setString(ApiConstants.storageRefreshToken, refreshToken);
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
  }

  bool get isAuthenticated =>
      accessToken != null && accessToken!.isNotEmpty;

  static String encodeJson(Map<String, dynamic> body) =>
      jsonEncode(body);

  static dynamic decodeJson(String body) {
    if (body.isEmpty) return null;
    return jsonDecode(body);
  }
}
