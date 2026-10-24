import 'package:flutter_test/flutter_test.dart';
import 'package:adwa_short/core/utils/formatters.dart';

void main() {
  group('Formatters.playbackClock', () {
    test('formats zero duration as 00:00', () {
      expect(Formatters.playbackClock(Duration.zero), '00:00');
    });

    test('formats seconds correctly to mm:ss', () {
      expect(Formatters.playbackClock(const Duration(seconds: 15)), '00:15');
      expect(Formatters.playbackClock(const Duration(seconds: 90)), '01:30');
      expect(Formatters.playbackClock(const Duration(minutes: 2, seconds: 45)), '02:45');
    });

    test('formats hours correctly to hh:mm:ss', () {
      expect(Formatters.playbackClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    });

    test('handles negative duration gracefully', () {
      expect(Formatters.playbackClock(const Duration(seconds: -5)), '00:00');
    });
  });
}
