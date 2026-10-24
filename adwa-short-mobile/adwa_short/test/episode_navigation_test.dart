import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/features/shorts/widgets/short_bottom_info.dart';
import 'package:adwa_short/models/episode.dart';
import 'package:adwa_short/models/short_item.dart';

void main() {
  group('Episode Model Video URL parsing', () {
    test('parses video_url, hls_url, file_uri, or vertical_video_url', () {
      final ep1 = Episode.fromJson({
        'id': '1',
        'series_id': '10',
        'number': 1,
        'title': 'Ep 1',
        'video_url': 'https://example.com/ep1.mp4',
      });
      expect(ep1.videoUrl, 'https://example.com/ep1.mp4');

      final ep2 = Episode.fromJson({
        'id': '2',
        'series_id': '10',
        'number': 2,
        'title': 'Ep 2',
        'file_uri': '/data/local/ep2.mp4',
      });
      expect(ep2.videoUrl, '/data/local/ep2.mp4');

      final ep3 = Episode.fromJson({
        'id': '3',
        'series_id': '10',
        'number': 3,
        'title': 'Ep 3',
        'stream_url': 'https://example.com/stream3.m3u8',
      });
      expect(ep3.videoUrl, 'https://example.com/stream3.m3u8');
    });
  });

  group('ShortBottomInfo Episode Bar formatting', () {
    testWidgets('renders correct current episode and total count in episode bar', (tester) async {
      final item = ShortItem(
        id: '1',
        seriesId: '10',
        episodeId: '1',
        title: 'Episode 1',
        verticalVideoUrl: 'https://example.com/video.mp4',
        description: 'Test description',
        episodeNumber: 1,
        totalEpisodes: 67,
      );

      var episodesTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortBottomInfo(
              item: item,
              totalEpisodes: 67,
              previewMode: false,
              onShowEpisodes: () {
                episodesTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('EP.1 / 67 EP'), findsOneWidget);

      await tester.tap(find.text('EP.1 / 67 EP'));
      expect(episodesTapped, isTrue);
    });
  });
}
