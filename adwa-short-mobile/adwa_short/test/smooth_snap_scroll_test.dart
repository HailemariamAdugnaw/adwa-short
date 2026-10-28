import 'package:adwa_short/core/widgets/smooth_video_snap_scroll_physics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScrollMetrics extends Fake implements ScrollMetrics {
  _FakeScrollMetrics({
    required this.pixels,
    required this.minScrollExtent,
    required this.maxScrollExtent,
    required this.viewportDimension,
  });

  @override
  final double pixels;
  @override
  final double minScrollExtent;
  @override
  final double maxScrollExtent;
  @override
  final double viewportDimension;
}

void main() {
  group('SmoothVideoSnapScrollPhysics Unit Tests', () {
    const physics = SmoothVideoSnapScrollPhysics();

    test('spring dynamics are critically tuned for snappy ~200ms arrival', () {
      expect(physics.spring.mass, 0.8);
      expect(physics.spring.stiffness, 260.0);
      expect(physics.spring.damping, 28.0);
    });

    test('velocity threshold is low (60.0) for effortless light flicks', () {
      final metrics = _FakeScrollMetrics(
        pixels: 100.0,
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
      );
      final tol = physics.toleranceFor(metrics);
      expect(tol.velocity, 60.0);
    });

    test('gentle upward flick (velocity: 70) snaps to next page', () {
      final metrics = _FakeScrollMetrics(
        pixels: 40.0, // Only 8% of 500px viewport dragged
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
      );

      final sim = physics.createBallisticSimulation(metrics, 70.0);
      expect(sim, isNotNull);
      // Simulation target should be page 1 (500 pixels)
      expect(sim!.x(10.0), closeTo(500.0, 1.0));
    });

    test('gentle downward flick (velocity: -70) snaps to previous page', () {
      final metrics = _FakeScrollMetrics(
        pixels: 460.0, // At page 1 (500), slightly dragged down to 460
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
      );

      final sim = physics.createBallisticSimulation(metrics, -70.0);
      expect(sim, isNotNull);
      // Simulation target should be page 0 (0 pixels)
      expect(sim!.x(10.0), closeTo(0.0, 1.0));
    });

    test('short slow drag (>18% of screen) commits and snaps to next page without flick', () {
      final metrics = _FakeScrollMetrics(
        pixels: 100.0, // 20% of 500px viewport dragged, release with 0 velocity
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
      );

      final sim = physics.createBallisticSimulation(metrics, 0.0);
      expect(sim, isNotNull);
      // Simulation target should commit to page 1 (500 pixels)
      expect(sim!.x(10.0), closeTo(500.0, 1.0));
    });

    test('minimal drag (<18% of screen) springs back to current page when released slowly', () {
      final metrics = _FakeScrollMetrics(
        pixels: 50.0, // Only 10% of 500px viewport dragged, release with 0 velocity
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        viewportDimension: 500.0,
      );

      final sim = physics.createBallisticSimulation(metrics, 0.0);
      expect(sim, isNotNull);
      // Simulation target should spring back to page 0 (0 pixels)
      expect(sim!.x(10.0), closeTo(0.0, 1.0));
    });

    test('applies parent BouncingScrollPhysics correctly', () {
      final combined = physics.applyTo(const BouncingScrollPhysics());
      expect(combined.parent, isA<BouncingScrollPhysics>());
    });
  });

  group('Smooth Vertical Feed Snapping Widget Tests', () {
    testWidgets('PageView with SmoothVideoSnapScrollPhysics snaps on short swipe',
        (tester) async {
      final controller = PageController();
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView.builder(
              controller: controller,
              dragStartBehavior: DragStartBehavior.down,
              physics: const SmoothVideoSnapScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              scrollDirection: Axis.vertical,
              itemCount: 5,
              onPageChanged: (i) => currentPage = i,
              itemBuilder: (context, i) => Container(
                key: ValueKey('page_$i'),
                color: i.isEven ? Colors.red : Colors.blue,
                child: Center(child: Text('Video $i')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Video 0'), findsOneWidget);
      expect(currentPage, 0);

      // Perform a gentle fling upward (heading to next video)
      await tester.fling(find.text('Video 0'), const Offset(0, -200), 500);
      await tester.pumpAndSettle();

      expect(currentPage, 1);
      expect(find.text('Video 1'), findsOneWidget);

      // Perform a gentle downward flick (heading back to previous video)
      await tester.fling(find.text('Video 1'), const Offset(0, 200), 500);
      await tester.pumpAndSettle();

      expect(currentPage, 0);
      expect(find.text('Video 0'), findsOneWidget);
    });
  });
}
