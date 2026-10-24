import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

class DownloadAccessDeniedException implements Exception {
  DownloadAccessDeniedException(this.message, {this.reason});

  final String message;
  final String? reason;

  @override
  String toString() => message;
}

class DownloadedEpisode {
  DownloadedEpisode({
    required this.episodeId,
    required this.episodeTitle,
    required this.seriesId,
    this.seriesTitle,
    required this.episodeNumber,
    required this.durationSeconds,
    this.thumbnailUrl,
    required this.localFilePath,
    required this.downloadToken,
    required this.downloadedAt,
  });

  final int episodeId;
  final String episodeTitle;
  final int seriesId;
  final String? seriesTitle;
  final int episodeNumber;
  final int durationSeconds;
  final String? thumbnailUrl;
  final String localFilePath;
  final String downloadToken;
  final DateTime downloadedAt;

  factory DownloadedEpisode.fromJson(Map<String, dynamic> json) {
    return DownloadedEpisode(
      episodeId: _asInt(json['episode_id']) ?? 0,
      episodeTitle: json['episode_title']?.toString() ?? '',
      seriesId: _asInt(json['series_id']) ?? 0,
      seriesTitle: json['series_title']?.toString(),
      episodeNumber: _asInt(json['episode_number']) ?? 0,
      durationSeconds: _asInt(json['duration_seconds']) ?? 0,
      thumbnailUrl: json['thumbnail_url']?.toString(),
      localFilePath: json['local_file_path']?.toString() ?? '',
      downloadToken: json['download_token']?.toString() ?? '',
      downloadedAt:
          DateTime.tryParse(json['downloaded_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'episode_id': episodeId,
        'episode_title': episodeTitle,
        'series_id': seriesId,
        'series_title': seriesTitle,
        'episode_number': episodeNumber,
        'duration_seconds': durationSeconds,
        'thumbnail_url': thumbnailUrl,
        'local_file_path': localFilePath,
        'download_token': downloadToken,
        'downloaded_at': downloadedAt.toIso8601String(),
      };

  String get fileUri => 'file://$localFilePath';
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt();
  return null;
}

class DownloadService {
  DownloadService._();

  static const _storageKey = 'downloaded_episodes';
  static String? _cachedDownloadDir;
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

  static Future<String> _getDownloadDir() async {
    if (_cachedDownloadDir != null) return _cachedDownloadDir!;
    final base = Directory.systemTemp;
    final dir = Directory('${base.path}/adwa_downloads');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cachedDownloadDir = dir.path;
    return dir.path;
  }

  static Future<List<DownloadedEpisode>> getDownloadedEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <DownloadedEpisode>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(DownloadedEpisode.fromJson(item));
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static Future<DownloadedEpisode?> downloadEpisode({
    required int episodeId,
    required String episodeTitle,
    required int seriesId,
    String? seriesTitle,
    required int episodeNumber,
    required int durationSeconds,
    String? thumbnailUrl,
    required String videoUrl,
    required String authToken,
  }) async {
    final baseUrl = _resolveBaseUrl();
    final tokenUri = Uri.parse('$baseUrl${ApiConstants.downloadTokens}');
    final tokenResponse = await http
        .post(
          tokenUri,
          headers: <String, String>{
            ApiConstants.headerAccept: 'application/json',
            ApiConstants.headerContentType: ApiConstants.contentTypeJson,
            ApiConstants.headerAuthorization: 'Bearer $authToken',
          },
          body: jsonEncode(<String, dynamic>{'episode_id': episodeId}),
        )
        .timeout(const Duration(seconds: 30));

    if (tokenResponse.statusCode == 403) {
      final body = _tryDecode(tokenResponse.body);
      final message = (body is Map
              ? (body['message'] ??
                  body['detail'] ??
                  body['error'] ??
                  'Episode is locked')
              : 'Episode is locked')
          .toString();
      final reason = (body is Map
              ? (body['access_reason'] ?? body['code'])
              : null)
          ?.toString();
      throw DownloadAccessDeniedException(message, reason: reason);
    }
    if (tokenResponse.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      throw Exception(
          'Failed to get download token (${tokenResponse.statusCode}).');
    }

    final tokenJson = _tryDecode(tokenResponse.body);
    final token = (tokenJson is Map
            ? (tokenJson['token'] ?? tokenJson['download_token'])
            : null)
        ?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Server did not return a download token.');
    }

    final dir = await _getDownloadDir();
    final filePath = '$dir/episode_$episodeId.mp4';
    final fileUri =
        Uri.parse('$baseUrl${ApiConstants.downloadFile}/$token');
    final client = http.Client();
    try {
      final request = http.Request('GET', fileUri);
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(minutes: 30));
      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
            'Failed to download file (${streamedResponse.statusCode}).');
      }
      final file = File(filePath);
      final sink = file.openWrite();
      try {
        await streamedResponse.stream.pipe(sink);
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }

    final episode = DownloadedEpisode(
      episodeId: episodeId,
      episodeTitle: episodeTitle,
      seriesId: seriesId,
      seriesTitle: seriesTitle,
      episodeNumber: episodeNumber,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl,
      localFilePath: filePath,
      downloadToken: token,
      downloadedAt: DateTime.now(),
    );

    final existing = await getDownloadedEpisodes();
    final filtered = existing
        .where((e) => e.episodeId != episodeId)
        .toList()
      ..add(episode);
    await _saveAll(filtered);
    return episode;
  }

  static Future<bool> deleteDownload(int episodeId) async {
    final list = await getDownloadedEpisodes();
    final target = list.where((e) => e.episodeId == episodeId).toList();
    if (target.isEmpty) return false;
    for (final e in target) {
      await _safeDelete(e.localFilePath);
    }
    final filtered = list.where((e) => e.episodeId != episodeId).toList();
    await _saveAll(filtered);
    return true;
  }

  static Future<bool> deleteAllDownloads() async {
    final list = await getDownloadedEpisodes();
    for (final e in list) {
      await _safeDelete(e.localFilePath);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    return true;
  }

  static Future<bool> isDownloaded(int episodeId) async {
    final list = await getDownloadedEpisodes();
    return list.any((e) => e.episodeId == episodeId);
  }

  static Future<String?> getLocalPath(int episodeId) async {
    final list = await getDownloadedEpisodes();
    for (final e in list) {
      if (e.episodeId == episodeId) return e.localFilePath;
    }
    return null;
  }

  static Future<void> _saveAll(List<DownloadedEpisode> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  static dynamic _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
