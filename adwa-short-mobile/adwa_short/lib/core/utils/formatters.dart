class Formatters {
  Formatters._();

  static String thousands(num value) {
    final s = value.toInt().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  static String compact(num value) {
    if (value < 1000) return value.toInt().toString();
    if (value < 1_000_000) {
      final k = value / 1000;
      return k >= 100
          ? '${k.round()}K'
          : '${k.toStringAsFixed(1)}K';
    }
    final m = value / 1_000_000;
    return m >= 100
        ? '${m.round()}M'
        : '${m.toStringAsFixed(1)}M';
  }

  static String durationFromMinutes(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

  static String clockFromSeconds(int totalSeconds) {
    if (totalSeconds < 0) return '0:00';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String shortDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String birr(num value, {bool withDecimals = true}) {
    if (withDecimals) {
      return 'Birr ${value.toStringAsFixed(2)}';
    }
    return 'Birr ${value.toInt()}';
  }

  static String coins(num value) {
    return '${thousands(value)} coins';
  }

  static String episodeNumber(int n) => 'Episode $n';

  static String episodeCount(int n) => '$n ${n == 1 ? 'episode' : 'episodes'}';

  static String timeLeft(DateTime until) {
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '$m minutes left';
    if (m == 0) return '$h hours left';
    return '$h hr $m min left';
  }

  static String date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }
}
