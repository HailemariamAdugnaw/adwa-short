import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import 'api_exception.dart';
import 'token_manager.dart';

class ApiClient {
  ApiClient({
    required this.tokenManager,
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final TokenManager tokenManager;
  final String _baseUrl;

  void Function()? onDeviceLimitReached;

  void Function()? onSessionExpired;

  void Function()? onConnectionLost;

  static String? _cachedBaseUrl;

  static String _resolveBaseUrl() {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    String raw;
    try {
      final v = dotenv.maybeGet(ApiConstants.envApiKey);
      raw = (v != null && v.trim().isNotEmpty)
          ? v.trim()
          : ApiConstants.fallbackBaseUrl;
    } catch (_) {
      raw = ApiConstants.fallbackBaseUrl;
    }
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    _cachedBaseUrl = url;
    return url;
  }

  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('asset://')) return url.substring('asset://'.length);
    if (url.startsWith('file://')) return url.substring('file://'.length);
    final base = _resolveBaseUrl();
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  String get baseUrl => _baseUrl;

  String _fullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final trimmed = path.startsWith('/') ? path : '/$path';
    return '$_baseUrl$trimmed';
  }

  Map<String, String> _buildHeaders({
    Map<String, String>? extra,
    bool requireAuth = true,
  }) {
    final headers = <String, String>{
      ApiConstants.headerAccept: 'application/json',
      ApiConstants.headerContentType: ApiConstants.contentTypeJson,
    };
    final deviceId = tokenManager.deviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      headers[ApiConstants.headerDeviceId] = deviceId;
    }
    if (requireAuth) {
      final token = tokenManager.accessToken;
      if (token != null && token.isNotEmpty) {
        headers[ApiConstants.headerAuthorization] = 'Bearer $token';
      }
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<T> _request<T>({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, String>? query,
    bool requireAuth = true,
    bool isRefreshCall = false,
    required T Function(dynamic json) parser,
  }) async {
    final uri = Uri.parse(_fullUrl(path)).replace(queryParameters: query);
    final h = _buildHeaders(extra: headers, requireAuth: requireAuth);
    final payload = body != null ? TokenManager.encodeJson(body) : null;

    if (kDebugMode && _logEnabled()) {
      dev.log('→ $method ${uri.toString()}',
          name: 'adwa.http', level: 0);
    }

    http.Response response;
    try {
      response = await _client
          .send(http.Request(method, uri)
            ..headers.addAll(h)
            ..body = payload ?? '')
          .then((stream) => http.Response.fromStream(stream))
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      onConnectionLost?.call();
      throw ApiException.network('Network error: $e', stackTrace: st);
    }

    if (kDebugMode && _logEnabled()) {
      dev.log('← ${response.statusCode} ${uri.toString()}',
          name: 'adwa.http', level: 0);
    }

    if (response.statusCode == 401 && !isRefreshCall) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(
          method: method,
          path: path,
          body: body,
          headers: headers,
          query: query,
          requireAuth: requireAuth,
          isRefreshCall: true,
          parser: parser,
        );
      }
      onSessionExpired?.call();
      throw ApiException(
        statusCode: 401,
        message: 'Session expired. Please log in again.',
        code: 'TOKEN_EXPIRED',
      );
    }

    if (response.statusCode == 403) {
      final bodyJson = _tryDecode(response.body);
      final code = bodyJson is Map<String, dynamic>
          ? (bodyJson['code'] ?? bodyJson['error_code'])?.toString()
          : null;
      if (code == ApiConstants.errorCodeMaxDeviceLimit) {
        onDeviceLimitReached?.call();
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyJson = _tryDecode(response.body);
      if (bodyJson is Map<String, dynamic>) {
        throw ApiException.fromResponse(response.statusCode, bodyJson);
      }
      throw ApiException(
        statusCode: response.statusCode,
        message:
            'Request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = _tryDecode(response.body);
    return parser(decoded);
  }

  Future<bool> _tryRefresh() async {
    final refresh = tokenManager.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _client.post(
        Uri.parse(_fullUrl(ApiConstants.refresh)),
        headers: _buildHeaders(requireAuth: false),
        body: TokenManager.encodeJson({'refresh_token': refresh}),
      );
      if (response.statusCode != 200) return false;
      final json = _tryDecode(response.body);
      if (json is Map<String, dynamic> &&
          json['access_token'] is String) {
        await tokenManager.saveTokens(
          accessToken: json['access_token'] as String,
          refreshToken:
              (json['refresh_token'] as String?) ?? refresh,
        );
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  dynamic _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  bool _logEnabled() {
    try {
      final v = dotenv.maybeGet(ApiConstants.envHttpLogEnabled);
      return v == null ? kDebugMode : v.toLowerCase() == 'true';
    } catch (_) {
      return kDebugMode;
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, String>? query,
    bool requireAuth = true,
    required T Function(dynamic json) parser,
  }) {
    return _request(
      method: 'GET',
      path: path,
      query: query,
      requireAuth: requireAuth,
      parser: parser,
    );
  }

  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    required T Function(dynamic json) parser,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      requireAuth: requireAuth,
      parser: parser,
    );
  }

  Future<T> put<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    required T Function(dynamic json) parser,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      body: body,
      requireAuth: requireAuth,
      parser: parser,
    );
  }

  Future<T> delete<T>(
    String path, {
    bool requireAuth = true,
    required T Function(dynamic json) parser,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      requireAuth: requireAuth,
      parser: parser,
    );
  }

  void dispose() {
    _client.close();
  }
}
