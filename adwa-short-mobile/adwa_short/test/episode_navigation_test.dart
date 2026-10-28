import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adwa_short/core/services/ad_service.dart';
import 'package:adwa_short/features/auth/providers/auth_provider.dart';
import 'package:adwa_short/features/downloads/providers/download_provider.dart';
import 'package:adwa_short/features/profile/providers/wallet_provider.dart';
import 'package:adwa_short/features/ratings/providers/rating_provider.dart';
import 'package:adwa_short/features/reviews/providers/review_provider.dart';
import 'package:adwa_short/features/series/providers/series_provider.dart';
import 'package:adwa_short/features/series/screens/episode_player_screen.dart';
import 'package:adwa_short/features/shorts/widgets/episode_selector_sheet.dart';
import 'package:adwa_short/features/shorts/widgets/short_bottom_info.dart';
import 'package:adwa_short/models/access_check.dart';
import 'package:adwa_short/models/episode.dart';
import 'package:adwa_short/models/rating.dart';
import 'package:adwa_short/models/series.dart';
import 'package:adwa_short/models/short_item.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return Stream<VideoEvent>.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 60),
        size: const Size(1080, 1920),
      ),
    );
  }

  @override
  Widget buildView(int textureId) => const SizedBox();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class _FakeSeriesProvider extends ChangeNotifier implements SeriesProvider {
  _FakeSeriesProvider(this._series);

  final Series _series;

  @override
  Series? get series => _series;

  @override
  SeriesDetailStatus get status => SeriesDetailStatus.success;

  @override
  int get defaultEpisodeCoinCost => 10;

  @override
  String? get errorMessage => null;

  @override
  Future<void> load(String seriesId) async {}

  @override
  Future<void> refreshAfterUnlock() async {}

  @override
  Future<AccessCheck> accessCheck(String episodeId) async {
    return const AccessCheck(
      accessible: true,
      reason: AccessReason.free,
      coinCost: 0,
    );
  }

  @override
  Future<void> pingView({required String episodeId, required int watchTimeSeconds, required bool completed}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloadProvider extends ChangeNotifier implements DownloadProvider {
  @override
  bool isDownloaded(int episodeId) => false;
  @override
  bool get isDownloading => false;
  @override
  int? get downloadingEpisodeId => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWalletProvider extends ChangeNotifier implements WalletProvider {
  @override
  bool get hasActiveAccess => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRatingProvider extends ChangeNotifier implements RatingProvider {
  @override
  RatingSummary? summaryFor(String episodeId) => null;
  @override
  int userRatingFor(String episodeId) => 0;
  @override
  bool isLoading(String episodeId) => false;
  @override
  Future<RatingSummary?> getEpisodeRating(String episodeId, {bool force = false}) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReviewProvider extends ChangeNotifier implements ReviewProvider {
  @override
  Future<void> getEpisodeReviews(String episodeId, {bool reset = false}) async {}
  @override
  Future<void> loadSettings() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAdService implements AdService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

    testWidgets('dynamically binds active currentEpisodeNumber state and totalEpisodes count', (tester) async {
      final item = ShortItem(
        id: '5',
        seriesId: '10',
        episodeId: '5',
        title: 'Episode 5',
        verticalVideoUrl: 'https://example.com/video5.mp4',
        description: 'Episode 5 description',
        episodeNumber: 1, // Underlying short item has static 1
        totalEpisodes: 67,
      );

      var arrowTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShortBottomInfo(
              item: item,
              currentEpisodeNumber: 5, // Dynamically bound to 5
              totalEpisodes: 67,
              previewMode: false,
              onShowEpisodes: () {
                arrowTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify dynamic binding renders EP.5 / 67 EP instead of EP.1
      expect(find.text('EP.5 / 67 EP'), findsOneWidget);

      // Verify tapping the arrow icon (>) specifically triggers onShowEpisodes
      final arrowFinder = find.byKey(const ValueKey('episode_bar_arrow_btn'));
      expect(arrowFinder, findsOneWidget);
      await tester.tap(arrowFinder);
      expect(arrowTapped, isTrue);
    });
  });

  group('EpisodeSelectorSheet Scrollability & Layout Tests', () {
    testWidgets('EpisodeSelectorSheet renders inside bounded Expanded viewport with smooth scroll physics',
        (tester) async {
      final episodes = List.generate(
        35,
        (i) => Episode(
          id: 'ep_${i + 1}',
          seriesId: 'series_10',
          number: i + 1,
          title: 'Episode ${i + 1}',
          videoUrl: 'https://example.com/ep${i + 1}.mp4',
        ),
      );

      final series = Series(
        id: 'series_10',
        title: 'Test Series',
        totalEpisodes: 35,
        episodes: episodes,
      );

      final fakeProvider = _FakeSeriesProvider(series);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SeriesProvider>.value(value: fakeProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    EpisodeSelectorSheet.show(
                      ctx,
                      seriesId: 'series_10',
                      currentEpisodeNumber: 1,
                    );
                  },
                  child: const Text('Open Episodes'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Episodes'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(EpisodeSelectorSheet), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(gridView.physics, isA<BouncingScrollPhysics>());
      expect((gridView.physics as BouncingScrollPhysics).parent, isA<AlwaysScrollableScrollPhysics>());
      expect(gridView.shrinkWrap, isFalse);
      expect(gridView.controller, isNotNull);

      // Verify that dragging vertically scrolls without locking
      final initialOffset = gridView.controller!.offset;
      await tester.drag(find.byType(GridView), const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 100));

      expect(gridView.controller!.offset, greaterThan(initialOffset));
    });

    testWidgets('Tapping episode button in EpisodeSelectorSheet invokes onEpisodeSelected and dismisses sheet',
        (tester) async {
      final episodes = List.generate(
        10,
        (i) => Episode(
          id: 'ep_${i + 1}',
          seriesId: 'series_10',
          number: i + 1,
          title: 'Episode ${i + 1}',
          videoUrl: 'https://example.com/ep${i + 1}.mp4',
        ),
      );

      final series = Series(
        id: 'series_10',
        title: 'Test Series',
        totalEpisodes: 10,
        episodes: episodes,
      );

      final fakeProvider = _FakeSeriesProvider(series);
      Episode? selectedEpisode;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SeriesProvider>.value(value: fakeProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    EpisodeSelectorSheet.show(
                      ctx,
                      seriesId: 'series_10',
                      currentEpisodeNumber: 1,
                      onEpisodeSelected: (ep) {
                        selectedEpisode = ep;
                      },
                    );
                  },
                  child: const Text('Open Episodes'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Episodes'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(EpisodeSelectorSheet), findsOneWidget);

      // Tap Episode 5 button
      final ep5Finder = find.text('5');
      expect(ep5Finder, findsOneWidget);
      await tester.tap(ep5Finder);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // Verify callback received Episode 5
      expect(selectedEpisode, isNotNull);
      expect(selectedEpisode!.number, 5);
      expect(selectedEpisode!.id, 'ep_5');

      // Verify bottom sheet is dismissed
      expect(find.byType(EpisodeSelectorSheet), findsNothing);
    });
  });

  group('EpisodePlayerScreen Swiping & Episode Selector Synchronization Tests', () {
    setUp(() {
      VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    });

    Widget buildPlayerScreen({
      required Series series,
      required Episode initialEpisode,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SeriesProvider>.value(
            value: _FakeSeriesProvider(series),
          ),
          ChangeNotifierProvider<DownloadProvider>.value(
            value: _FakeDownloadProvider(),
          ),
          ChangeNotifierProvider<WalletProvider>.value(
            value: _FakeWalletProvider(),
          ),
          ChangeNotifierProvider<RatingProvider>.value(
            value: _FakeRatingProvider(),
          ),
          ChangeNotifierProvider<ReviewProvider>.value(
            value: _FakeReviewProvider(),
          ),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _FakeAuthProvider(),
          ),
          Provider<AdService>.value(
            value: _FakeAdService(),
          ),
        ],
        child: MaterialApp(
          home: EpisodePlayerScreen(
            series: series,
            episode: initialEpisode,
          ),
        ),
      );
    }

    testWidgets('binds initial episode index dynamically and reflects in episode bar', (tester) async {
      final episodes = List.generate(
        5,
        (i) => Episode(
          id: 'ep_${i + 1}',
          seriesId: 'series_10',
          number: i + 1,
          title: 'Episode ${i + 1}',
          videoUrl: 'https://example.com/ep${i + 1}.mp4',
          isFree: true,
        ),
      );
      final series = Series(
        id: 'series_10',
        title: 'Test Series',
        totalEpisodes: 5,
        episodes: episodes,
      );

      await tester.pumpWidget(
        buildPlayerScreen(series: series, initialEpisode: episodes[0]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Should display EP.1 / 5 EP
      expect(find.text('EP.1 / 5 EP'), findsOneWidget);
    });

    testWidgets('swiping vertically snaps to next episode and synchronizes episode bar', (tester) async {
      final episodes = List.generate(
        5,
        (i) => Episode(
          id: 'ep_${i + 1}',
          seriesId: 'series_10',
          number: i + 1,
          title: 'Episode ${i + 1}',
          videoUrl: 'https://example.com/ep${i + 1}.mp4',
          isFree: true,
        ),
      );
      final series = Series(
        id: 'series_10',
        title: 'Test Series',
        totalEpisodes: 5,
        episodes: episodes,
      );

      await tester.pumpWidget(
        buildPlayerScreen(series: series, initialEpisode: episodes[0]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('EP.1 / 5 EP'), findsOneWidget);

      // Swipe upward to advance to next episode
      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Should dynamically display EP.2 / 5 EP
      expect(find.text('EP.2 / 5 EP'), findsOneWidget);
    });

    testWidgets('swiping horizontally left advances to next episode', (tester) async {
      final episodes = List.generate(
        5,
        (i) => Episode(
          id: 'ep_${i + 1}',
          seriesId: 'series_10',
          number: i + 1,
          title: 'Episode ${i + 1}',
          videoUrl: 'https://example.com/ep${i + 1}.mp4',
          isFree: true,
        ),
      );
      final series = Series(
        id: 'series_10',
        title: 'Test Series',
        totalEpisodes: 5,
        episodes: episodes,
      );

      await tester.pumpWidget(
        buildPlayerScreen(series: series, initialEpisode: episodes[0]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('EP.1 / 5 EP'), findsOneWidget);

      // Swipe horizontally left (drag from right to left)
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Should advance to EP.2 / 5 EP
      expect(find.text('EP.2 / 5 EP'), findsOneWidget);
    });

    testWidgets('selecting episode in bottom sheet dismisses sheet and jumps to target episode', (tester) async {
      final episodes = List.generate(
        5,
        (i) => Episode(
          id: 'ep_${i + 1}',
          seriesId: 'series_10',
          number: i + 1,
          title: 'Episode ${i + 1}',
          videoUrl: 'https://example.com/ep${i + 1}.mp4',
          isFree: true,
        ),
      );
      final series = Series(
        id: 'series_10',
        title: 'Test Series',
        totalEpisodes: 5,
        episodes: episodes,
      );

      await tester.pumpWidget(
        buildPlayerScreen(series: series, initialEpisode: episodes[0]),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('EP.1 / 5 EP'), findsOneWidget);

      // Tap episode bar arrow button to pop up selector sheet
      await tester.tap(find.byKey(const ValueKey('episode_bar_arrow_btn')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(EpisodeSelectorSheet), findsOneWidget);

      // Tap Episode 4 in selector sheet
      final ep4Finder = find.text('4');
      expect(ep4Finder, findsOneWidget);
      await tester.tap(ep4Finder);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // Sheet should be dismissed
      expect(find.byType(EpisodeSelectorSheet), findsNothing);

      // Page view should now show EP.4 / 5 EP
      expect(find.text('EP.4 / 5 EP'), findsOneWidget);
    });
  });
}
