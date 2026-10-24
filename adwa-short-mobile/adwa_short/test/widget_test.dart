import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/core/theme/colors.dart';
import 'package:adwa_short/core/theme/theme.dart';
import 'package:adwa_short/core/widgets/adwa_button.dart';
import 'package:adwa_short/core/widgets/tag_chip.dart';

void main() {
  group('AppTheme', () {
    testWidgets('darkTheme applies brand colors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: SizedBox.shrink()),
      ));
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.scaffoldBackgroundColor, AppColors.black);
      expect(theme.colorScheme.primary, AppColors.bloodRed);
    });
  });

  group('AdwaButton', () {
    testWidgets('renders label and reacts to taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdwaButton(
            label: 'Click me',
            onPressed: () => tapped++,
          ),
        ),
      ));
      expect(find.text('Click me'), findsOneWidget);
      await tester.tap(find.byType(AdwaButton));
      expect(tapped, 1);
    });

    testWidgets('does not call onPressed when disabled', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdwaButton(
            label: 'Click me',
            disabled: true,
            onPressed: () => tapped++,
          ),
        ),
      ));
      await tester.tap(find.byType(AdwaButton));
      expect(tapped, 0);
    });
  });

  group('TagChip', () {
    testWidgets('hot chip renders the HOT label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TagChip.hot()),
      ));
      expect(find.text('HOT'), findsOneWidget);
    });
  });
}
