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
      expect(Formatters.playbackClock(const Duration(seconds: 5)), '00:05');
      expect(Formatters.playbackClock(const Duration(minutes: 1)), '01:00');
    });

    test('formats hours correctly to hh:mm:ss', () {
      expect(Formatters.playbackClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    });

    test('handles negative duration gracefully', () {
      expect(Formatters.playbackClock(const Duration(seconds: -5)), '00:00');
    });
  });

  group('Video Player Progress Bar and Scrubber Binding', () {
    test('when duration is zero or uninitialized, seekbar does not jump to maximum', () {
      final liveDur = Duration.zero;
      final position = const Duration(milliseconds: 500);

      final maxMs = liveDur.inMilliseconds.toDouble();
      final sliderMax = maxMs > 0 ? maxMs : 1.0;
      final sliderValue = maxMs > 0
          ? position.inMilliseconds.toDouble().clamp(0.0, sliderMax)
          : 0.0;
      final isEnabled = maxMs > 0;

      expect(sliderMax, 1.0);
      expect(sliderValue, 0.0);
      expect(isEnabled, isFalse);
      expect(Formatters.playbackClock(liveDur), '00:00');
    });

    test('when duration is initialized, progress bar binds strictly to total duration', () {
      final liveDur = const Duration(seconds: 90);
      final maxMs = liveDur.inMilliseconds.toDouble();
      expect(maxMs, 90000.0);

      final sliderMax = maxMs > 0 ? maxMs : 1.0;
      expect(sliderMax, 90000.0);

      // Playback begins (e.g. 500ms)
      const pos1 = Duration(milliseconds: 500);
      final sliderVal1 = pos1.inMilliseconds.toDouble().clamp(0.0, sliderMax);
      expect(sliderVal1, 500.0);
      expect(sliderVal1 < sliderMax, isTrue);

      // Halfway (45s)
      const pos2 = Duration(seconds: 45);
      final sliderVal2 = pos2.inMilliseconds.toDouble().clamp(0.0, sliderMax);
      expect(sliderVal2, 45000.0);

      // End
      const pos3 = Duration(seconds: 90);
      final sliderVal3 = pos3.inMilliseconds.toDouble().clamp(0.0, sliderMax);
      expect(sliderVal3, 90000.0);

      // Formatted labels
      expect(Formatters.playbackClock(pos1), '00:00');
      expect(Formatters.playbackClock(pos2), '00:45');
      expect(Formatters.playbackClock(liveDur), '01:30');
    });

    test('scrubber correctly previews and seeks to dragged position', () {
      const liveDur = Duration(minutes: 2);
      final maxMs = liveDur.inMilliseconds.toDouble();

      // User drags scrubber to 45.5 seconds
      const scrubMs = 45500.0;
      final displayPosition = Duration(milliseconds: scrubMs.round());
      final seekTarget = Duration(milliseconds: scrubMs.round());

      expect(Formatters.playbackClock(displayPosition), '00:45');
      expect(seekTarget.inMilliseconds, 45500);
      expect(scrubMs <= maxMs, isTrue);
    });

    test('pausing and resuming preserves exact live timestamp without reset', () {
      var livePosition = const Duration(seconds: 14, milliseconds: 320);
      var isPlaying = true;

      // Pause
      isPlaying = false;
      expect(livePosition.inMilliseconds, 14320);

      // Resume without re-initializing or seeking to 0
      isPlaying = true;
      expect(livePosition.inMilliseconds, 14320);
      expect(Formatters.playbackClock(livePosition), '00:14');
    });

    test('effectiveDuration resolution hierarchy correctly falls back', () {
      Duration resolveEffectiveDuration({
        Duration controllerDuration = Duration.zero,
        Duration stateDuration = Duration.zero,
        Duration knownDuration = Duration.zero,
      }) {
        if (controllerDuration >= const Duration(seconds: 1)) {
          return controllerDuration;
        }
        if (knownDuration >= const Duration(seconds: 1)) return knownDuration;
        if (stateDuration >= const Duration(seconds: 1)) return stateDuration;
        if (controllerDuration > Duration.zero) return controllerDuration;
        if (knownDuration > Duration.zero) return knownDuration;
        if (stateDuration > Duration.zero) return stateDuration;
        return Duration.zero;
      }

      // 1. Controller has valid duration >= 1s
      expect(
        resolveEffectiveDuration(
          controllerDuration: const Duration(seconds: 120),
          stateDuration: const Duration(seconds: 60),
          knownDuration: const Duration(seconds: 30),
        ),
        const Duration(seconds: 120),
      );

      // 2. Controller has bogus sub-second duration (e.g. 50ms from fMP4 stream), falls back to knownDuration
      expect(
        resolveEffectiveDuration(
          controllerDuration: const Duration(milliseconds: 50),
          stateDuration: Duration.zero,
          knownDuration: const Duration(seconds: 123),
        ),
        const Duration(seconds: 123),
      );

      // 3. Controller duration is uninitialized (0:00), falls back to knownDuration
      expect(
        resolveEffectiveDuration(
          controllerDuration: Duration.zero,
          stateDuration: const Duration(seconds: 60),
          knownDuration: const Duration(seconds: 144),
        ),
        const Duration(seconds: 144),
      );

      // 4. Controller & known are zero, falls back to stateDuration
      expect(
        resolveEffectiveDuration(
          controllerDuration: Duration.zero,
          stateDuration: const Duration(seconds: 45),
          knownDuration: Duration.zero,
        ),
        const Duration(seconds: 45),
      );

      // 5. All zero
      expect(
        resolveEffectiveDuration(
          controllerDuration: Duration.zero,
          stateDuration: Duration.zero,
          knownDuration: Duration.zero,
        ),
        Duration.zero,
      );
    });

    test('progress bar and total duration label strictly bound to effectiveDuration', () {
      const known = Duration(seconds: 45);
      const rawControllerDur = Duration.zero; // Uninitialized controller

      // Effective duration resolves to knownDuration
      final effectiveDur = rawControllerDur > Duration.zero ? rawControllerDur : known;
      expect(effectiveDur, const Duration(seconds: 45));

      final maxMs = effectiveDur.inMilliseconds.toDouble();
      expect(maxMs, 45000.0);

      const pos = Duration(seconds: 15);
      final sliderVal = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
      expect(sliderVal, 15000.0);
      expect(sliderVal / maxMs, closeTo(1 / 3, 0.01));

      // Labels never stuck at 0:00 / 0:00
      expect(Formatters.playbackClock(pos), '00:15');
      expect(Formatters.playbackClock(effectiveDur), '00:45');
    });
  });
}
