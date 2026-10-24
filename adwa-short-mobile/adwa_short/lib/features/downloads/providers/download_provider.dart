import 'package:flutter/foundation.dart';

import '../../../core/services/download_service.dart';
import '../../../models/episode.dart';
import '../../../models/series.dart';

enum DownloadStatus { idle, downloading, success, error, accessDenied }

class DownloadProvider extends ChangeNotifier {
  DownloadStatus _status = DownloadStatus.idle;
  String _errorMessage = '';
  double _progress = 0.0;
  int? _downloadingEpisodeId;
  List<DownloadedEpisode> _downloads = const [];

  DownloadStatus get status => _status;
  String get errorMessage => _errorMessage;
  double get progress => _progress;
  int? get downloadingEpisodeId => _downloadingEpisodeId;
  List<DownloadedEpisode> get downloads => List.unmodifiable(_downloads);
  bool get isDownloading => _status == DownloadStatus.downloading;

  Future<void> loadDownloads() async {
    _downloads = await DownloadService.getDownloadedEpisodes();
    notifyListeners();
  }

  Future<bool> downloadEpisode(
    Episode episode,
    Series series,
    String authToken,
  ) async {
    if (_status == DownloadStatus.downloading) return false;
    final epId = int.tryParse(episode.id);
    if (epId == null) {
      _status = DownloadStatus.error;
      _errorMessage = 'Invalid episode id';
      notifyListeners();
      return false;
    }
    if (_downloads.any((e) => e.episodeId == epId)) {
      _status = DownloadStatus.success;
      notifyListeners();
      return true;
    }
    _status = DownloadStatus.downloading;
    _downloadingEpisodeId = epId;
    _progress = 0.0;
    _errorMessage = '';
    notifyListeners();
    try {
      await DownloadService.downloadEpisode(
        episodeId: epId,
        episodeTitle: episode.title,
        seriesId: int.tryParse(series.id) ?? 0,
        seriesTitle: series.title,
        episodeNumber: episode.number,
        durationSeconds: episode.durationSeconds,
        thumbnailUrl: episode.thumbnailUrl,
        videoUrl: episode.videoUrl ?? '',
        authToken: authToken,
      );
      _downloads = await DownloadService.getDownloadedEpisodes();
      _status = DownloadStatus.success;
      _progress = 1.0;
      _downloadingEpisodeId = null;
      notifyListeners();
      return true;
    } on DownloadAccessDeniedException catch (e) {
      _status = DownloadStatus.accessDenied;
      _errorMessage = e.message;
      _downloadingEpisodeId = null;
      notifyListeners();
      return false;
    } catch (e) {
      _status = DownloadStatus.error;
      _errorMessage = e.toString();
      _downloadingEpisodeId = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteDownload(int episodeId) async {
    await DownloadService.deleteDownload(episodeId);
    _downloads = await DownloadService.getDownloadedEpisodes();
    notifyListeners();
  }

  Future<void> deleteAllDownloads() async {
    await DownloadService.deleteAllDownloads();
    _downloads = const [];
    notifyListeners();
  }

  bool isDownloaded(int episodeId) {
    return _downloads.any((e) => e.episodeId == episodeId);
  }

  String? getLocalPath(int episodeId) {
    for (final e in _downloads) {
      if (e.episodeId == episodeId) return e.localFilePath;
    }
    return null;
  }

  String? getFileUri(int episodeId) {
    final path = getLocalPath(episodeId);
    if (path == null) return null;
    return 'file://$path';
  }

  void resetStatus() {
    if (_status == DownloadStatus.downloading) return;
    _status = DownloadStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }
}
