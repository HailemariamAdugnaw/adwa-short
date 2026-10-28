import 'package:adwa_short/core/widgets/connection_lost_view.dart';
import 'package:adwa_short/core/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionLostView Widget Tests', () {
    testWidgets('renders title with Blood Red Lost and default subtitle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionLostView(),
          ),
        ),
      );

      // Verify custom Wi-Fi graphic is rendered
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify rich title contains Connection and Lost
      expect(find.byType(RichText), findsWidgets);
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final hasConnectionLost = richTexts.any(
        (rt) => rt.text.toPlainText().contains('Connection Lost'),
      );
      expect(hasConnectionLost, isTrue);

      // Verify subtitle
      expect(
        find.text("Can't connect to server, please try\nagain later."),
        findsOneWidget,
      );

      // When no onRetry is provided, button is not shown
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('renders Try Again pill button and triggers callback on tap',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionLostView(
              onRetry: () async {
                retried = true;
              },
            ),
          ),
        ),
      );

      // Button with text "Try Again" is displayed
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Tap the Try Again button
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(retried, isTrue);
    });

    testWidgets('ConnectionLostScreen renders with full screen black scaffold',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectionLostScreen(),
        ),
      );

      expect(find.byType(ConnectionLostScreen), findsOneWidget);
      expect(find.byType(ConnectionLostView), findsOneWidget);
    });

    testWidgets('ErrorView renders ConnectionLostView on full error state',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Network error: Failed host lookup',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      // Verify it automatically displays the visual ConnectionLostView
      expect(find.byType(ConnectionLostView), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(retried, isTrue);
    });

    testWidgets('ErrorView renders compact inline banner when compact=true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Failed to load comments',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.text('Failed to load comments'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });
}
