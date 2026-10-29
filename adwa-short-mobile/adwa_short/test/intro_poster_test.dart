import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/core/constants/app_constants.dart';
import 'package:adwa_short/core/router/app_router.dart';
import 'package:adwa_short/features/auth/screens/intro_poster_screen.dart';
import 'package:adwa_short/features/auth/screens/splash_screen.dart';
import 'package:adwa_short/models/intro_poster_config.dart';

void main() {
  group('IntroPosterConfig Model Tests', () {
    test('IntroPosterConfig.fromJson parses full payload', () {
      final config = IntroPosterConfig.fromJson({
        'enabled': true,
        'series_id': '101',
        'title': 'Love in the In-Between',
        'poster_url': 'https://example.com/poster.jpg',
        'banner_url': 'https://example.com/banner.jpg',
        'countdown_seconds': 5,
        'action_text': 'Watch Now',
      });

      expect(config.enabled, isTrue);
      expect(config.seriesId, '101');
      expect(config.title, 'Love in the In-Between');
      expect(config.posterUrl, 'https://example.com/poster.jpg');
      expect(config.countdownSeconds, 5);
      expect(config.actionText, 'Watch Now');
    });

    test('IntroPosterConfig.fromJson applies sensible defaults', () {
      final config = IntroPosterConfig.fromJson({});

      expect(config.enabled, isTrue);
      expect(config.title, '');
      expect(config.countdownSeconds, 5);
      expect(config.actionText, 'Watch Now');
    });
  });

  group('IntroPosterScreen UI & Interaction Tests', () {
    testWidgets('renders top-right countdown skip badge, dynamic title and Watch Now button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IntroPosterScreen(
            config: IntroPosterConfig(
              posterUrl: 'https://example.com/poster.jpg',
              title: 'The Royal Betrayal',
              countdownSeconds: 5,
              actionText: 'Watch Now',
            ),
          ),
        ),
      );

      // Verify Skip badge displays initial countdown
      expect(find.byKey(const ValueKey('intro_poster_skip_button')), findsOneWidget);
      expect(find.text('5 Skip'), findsOneWidget);

      // Verify dynamic series title
      expect(find.text('The Royal Betrayal'), findsOneWidget);

      // Verify "Watch Now" call-to-action button
      expect(find.byKey(const ValueKey('intro_poster_watch_now_button')), findsOneWidget);
      expect(find.text('Watch Now'), findsOneWidget);
    });

    testWidgets('gracefully auto-bypasses to target when posterUrl is null or empty', (tester) async {
      var autoProceeded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: IntroPosterScreen(
            config: const IntroPosterConfig(
              posterUrl: null,
              bannerUrl: null,
            ),
            onSkip: () {
              autoProceeded = true;
            },
          ),
        ),
      );

      await tester.pump();
      expect(autoProceeded, isTrue);
    });

    testWidgets('tapping top-right Skip button immediately invokes onSkip callback', (tester) async {
      var skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: IntroPosterScreen(
            config: const IntroPosterConfig(
              posterUrl: 'https://example.com/poster.jpg',
              countdownSeconds: 5,
            ),
            onSkip: () {
              skipped = true;
            },
          ),
        ),
      );

      expect(skipped, isFalse);

      final skipFinder = find.byKey(const ValueKey('intro_poster_skip_button'));
      expect(skipFinder, findsOneWidget);
      await tester.tap(skipFinder);
      await tester.pump();

      expect(skipped, isTrue);
    });

    testWidgets('countdown ticks down and auto-proceeds when timer reaches 0', (tester) async {
      var autoProceeded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: IntroPosterScreen(
            config: const IntroPosterConfig(
              posterUrl: 'https://example.com/poster.jpg',
              countdownSeconds: 2,
            ),
            onSkip: () {
              autoProceeded = true;
            },
          ),
        ),
      );

      expect(find.text('2 Skip'), findsOneWidget);
      expect(autoProceeded, isFalse);

      // Advance by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1 Skip'), findsOneWidget);
      expect(autoProceeded, isFalse);

      // Advance by 1 more second to reach 0
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(autoProceeded, isTrue);
    });

    testWidgets('tapping Watch Now button invokes onWatchNow callback', (tester) async {
      var watchNowTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: IntroPosterScreen(
            config: const IntroPosterConfig(
              posterUrl: 'https://example.com/poster.jpg',
              seriesId: '42',
              actionText: 'Watch Now',
            ),
            onWatchNow: () {
              watchNowTriggered = true;
            },
          ),
        ),
      );

      expect(watchNowTriggered, isFalse);

      final watchBtnFinder = find.byKey(const ValueKey('intro_poster_watch_now_button'));
      expect(watchBtnFinder, findsOneWidget);
      await tester.tap(watchBtnFinder);
      await tester.pump();

      expect(watchNowTriggered, isTrue);
    });

    testWidgets('tapping Watch Now button forwards dynamic seriesId to onWatchSeries callback', (tester) async {
      String? tappedSeriesId;

      await tester.pumpWidget(
        MaterialApp(
          home: IntroPosterScreen(
            config: const IntroPosterConfig(
              posterUrl: 'https://example.com/poster.jpg',
              seriesId: 'series-999',
              actionText: 'Watch Now',
            ),
            onWatchSeries: (id) {
              tappedSeriesId = id;
            },
          ),
        ),
      );

      expect(tappedSeriesId, isNull);

      final watchBtnFinder = find.byKey(const ValueKey('intro_poster_watch_now_button'));
      expect(watchBtnFinder, findsOneWidget);
      await tester.tap(watchBtnFinder);
      await tester.pump();

      expect(tappedSeriesId, equals('series-999'));
    });

    testWidgets('tapping Watch Now button without callbacks replaces with targetRoute and pushes seriesDetail', (tester) async {
      String? pushedSeriesDetailArg;
      final routes = <String, WidgetBuilder>{
        AppRoutes.welcome: (context) => const Scaffold(body: Text('Welcome Screen')),
        AppRoutes.seriesDetail: (context) {
          pushedSeriesDetailArg = ModalRoute.of(context)?.settings.arguments as String?;
          return const Scaffold(body: Text('Series Detail Screen'));
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => const IntroPosterScreen(
                  config: IntroPosterConfig(
                    posterUrl: 'https://example.com/poster.jpg',
                    seriesId: 'series-dyn-77',
                    actionText: 'Watch Now',
                  ),
                  targetRoute: AppRoutes.welcome,
                ),
            ...routes,
          },
        ),
      );

      final watchBtnFinder = find.byKey(const ValueKey('intro_poster_watch_now_button'));
      await tester.tap(watchBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Series Detail Screen'), findsOneWidget);
      expect(pushedSeriesDetailArg, equals('series-dyn-77'));
    });

    testWidgets('navigates to target route when Skip button is tapped without custom onSkip', (tester) async {
      final routes = <String, WidgetBuilder>{
        AppRoutes.welcome: (context) => const Scaffold(body: Text('Welcome Screen')),
      };

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => const IntroPosterScreen(
                  config: IntroPosterConfig(
                    posterUrl: 'https://example.com/poster.jpg',
                  ),
                  targetRoute: AppRoutes.welcome,
                ),
            ...routes,
          },
        ),
      );

      expect(find.byType(IntroPosterScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('intro_poster_skip_button')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Screen'), findsOneWidget);
      expect(find.byType(IntroPosterScreen), findsNothing);
    });

    testWidgets('SplashScreen renders branded splash loading view with logo initially and invokes onDone', (tester) async {
      var onDoneTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onDone: () {
              onDoneTriggered = true;
            },
          ),
        ),
      );

      // Verify branded splash loading view is rendered initially
      expect(find.byKey(const ValueKey('splash_loading_view')), findsOneWidget);
      expect(find.text(AppStrings.tagline), findsOneWidget);
      expect(onDoneTriggered, isFalse);

      // Advance by minimum display duration
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();

      expect(onDoneTriggered, isTrue);
    });
  });
}
