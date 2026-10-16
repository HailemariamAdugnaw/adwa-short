import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_manager.dart';
import '../../../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokenManager);

  final ApiClient _api;
  final TokenManager _tokenManager;

  Future<User> register({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    final body = {
      'phone': phone,
      'password': password,
      'display_name': displayName,
    };
    final response = await _api.post<Map<String, dynamic>>(
      ApiConstants.register,
      body: body,
      requireAuth: false,
      parser: (json) =>
          json is Map<String, dynamic> ? json : <String, dynamic>{},
    );
    await _persist(response);
    return _parseUser(response);
  }

  Future<User> login({
    required String phone,
    required String password,
  }) async {
    final body = {
      'phone': phone,
      'password': password,
    };
    Map<String, dynamic> response;
    try {
      response = await _api.post<Map<String, dynamic>>(
        ApiConstants.login,
        body: body,
        requireAuth: false,
        parser: (json) =>
            json is Map<String, dynamic> ? json : <String, dynamic>{},
      );
    } on ApiException catch (e) {

      if (e.statusCode == 401 || e.statusCode == 400) {
        throw ApiException(
          statusCode: e.statusCode,
          message: 'Invalid phone or password',
          code: e.code,
          body: e.body,
        );
      }
      rethrow;
    }
    await _persist(response);
    return _parseUser(response);
  }

  Future<bool> refresh() async {
    final refreshToken = _tokenManager.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiConstants.refresh,
        body: {'refresh_token': refreshToken},
        requireAuth: false,
        parser: (json) =>
            json is Map<String, dynamic> ? json : <String, dynamic>{},
      );
      final access = response['access_token'] as String?;
      if (access == null || access.isEmpty) return false;
      await _tokenManager.saveTokens(
        accessToken: access,
        refreshToken:
            (response['refresh_token'] as String?) ?? refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<User> fetchMe() async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiConstants.usersMe,
      parser: (json) =>
          json is Map<String, dynamic> ? json : <String, dynamic>{},
    );
    final user = User.fromJson(response);
    await _tokenManager.saveUser(
      userId: user.id,
      phone: user.phone,
      displayName: user.displayName,
    );
    return user;
  }

  Future<User> updateMe({
    String? displayName,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    final response = await _api.put<Map<String, dynamic>>(
      ApiConstants.usersMe,
      body: body,
      parser: (json) =>
          json is Map<String, dynamic> ? json : <String, dynamic>{},
    );
    return User.fromJson(response);
  }

  Future<void> logout() async {
    await _tokenManager.clearAll();
  }

  User _parseUser(Map<String, dynamic> response) {
    final dynamic rawUser = response['user'];
    final Map<String, dynamic> userJson =
        rawUser is Map<String, dynamic> ? rawUser : response;
    return User.fromJson(userJson);
  }

  Future<void> _persist(Map<String, dynamic> response) async {
    final access = response['access_token'] as String?;
    final refresh = response['refresh_token'] as String?;
    if (access == null || access.isEmpty) {
      throw ApiException(
        statusCode: 500,
        message: 'Server did not return access_token',
        code: 'NO_ACCESS_TOKEN',
        body: response,
      );
    }
    await _tokenManager.saveTokens(
      accessToken: access,
      refreshToken: refresh ?? '',
    );
    final user = _parseUser(response);
    await _tokenManager.saveUser(
      userId: user.id,
      phone: user.phone,
      displayName: user.displayName,
    );
  }

  static String prettyJson(Map<String, dynamic> body) =>
      const JsonEncoder.withIndent('  ').convert(body);
}
