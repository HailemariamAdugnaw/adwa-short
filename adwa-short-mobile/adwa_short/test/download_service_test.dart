import 'package:flutter_test/flutter_test.dart';
import 'package:adwa_short/core/services/download_service.dart';

void main() {
  group('DownloadedEpisode', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'episode_id': 42,
        'episode_title': 'The Reveal',
        'series_id': 7,
        'series_title': 'Crimson Heart',
        'episode_number': 5,
        'duration_seconds': 180,
        'thumbnail_url': '/uploads/posters/ep5.jpg',
        'local_file_path': '/tmp/adwa_downloads/episode_42.mp4',
        'download_token': 'tok_abc',
        'downloaded_at': '2026-01-15T10:30:00.000',
      };
      final ep = DownloadedEpisode.fromJson(json);
      expect(ep.episodeId, 42);
      expect(ep.episodeTitle, 'The Reveal');
      expect(ep.seriesId, 7);
      expect(ep.seriesTitle, 'Crimson Heart');
      expect(ep.episodeNumber, 5);
      expect(ep.durationSeconds, 180);
      expect(ep.thumbnailUrl, '/uploads/posters/ep5.jpg');
      expect(ep.localFilePath, '/tmp/adwa_downloads/episode_42.mp4');
      expect(ep.downloadToken, 'tok_abc');
      expect(ep.downloadedAt, DateTime.parse('2026-01-15T10:30:00.000'));
    });

    test('fromJson accepts string numeric ids', () {
      final ep = DownloadedEpisode.fromJson({
        'episode_id': '99',
        'series_id': '3',
        'episode_number': '12',
        'duration_seconds': '240',
      });
      expect(ep.episodeId, 99);
      expect(ep.seriesId, 3);
      expect(ep.episodeNumber, 12);
      expect(ep.durationSeconds, 240);
    });

    test('toJson round-trips through fromJson', () {
      final original = DownloadedEpisode(
        episodeId: 11,
        episodeTitle: 'Pilot',
        seriesId: 2,
        seriesTitle: 'Storm',
        episodeNumber: 1,
        durationSeconds: 90,
        thumbnailUrl: '/p.jpg',
        localFilePath: '/data/ep_11.mp4',
        downloadToken: 'tok',
        downloadedAt: DateTime(2026, 2, 1, 8, 0, 0),
      );
      final encoded = original.toJson();
      final decoded = DownloadedEpisode.fromJson(encoded);
      expect(decoded.episodeId, original.episodeId);
      expect(decoded.episodeTitle, original.episodeTitle);
      expect(decoded.seriesId, original.seriesId);
      expect(decoded.seriesTitle, original.seriesTitle);
      expect(decoded.episodeNumber, original.episodeNumber);
      expect(decoded.durationSeconds, original.durationSeconds);
      expect(decoded.thumbnailUrl, original.thumbnailUrl);
      expect(decoded.localFilePath, original.localFilePath);
      expect(decoded.downloadToken, original.downloadToken);
      expect(decoded.downloadedAt, original.downloadedAt);
    });

    test('fileUri prefixes localFilePath with file://', () {
      final ep = DownloadedEpisode(
        episodeId: 1,
        episodeTitle: 'Ep',
        seriesId: 1,
        episodeNumber: 1,
        durationSeconds: 0,
        localFilePath: '/data/ep.mp4',
        downloadToken: 't',
        downloadedAt: DateTime.now(),
      );
      expect(ep.fileUri, 'file:///data/ep.mp4');
    });

    test('DownloadAccessDeniedException carries message + reason', () {
      final e = DownloadAccessDeniedException('locked', reason: 'need_coins');
      expect(e.message, 'locked');
      expect(e.reason, 'need_coins');
      expect(e.toString(), 'locked');
    });
  });
}
