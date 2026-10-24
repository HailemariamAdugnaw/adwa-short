import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/models/time_pass.dart';

void main() {
  group('TimePass Model', () {
    test('parses shortDuration correctly', () {
      final pass1 = TimePass(id: '1', name: 'Hourly Pass', durationHours: 1, priceBirr: 5);
      expect(pass1.shortDuration, '1h');

      final pass2 = TimePass(id: '2', name: 'Daily Pass', durationHours: 24, priceBirr: 25);
      expect(pass2.shortDuration, '1d');

      final pass3 = TimePass(id: '3', name: 'Weekly Pass', durationHours: 168, priceBirr: 100);
      expect(pass3.shortDuration, '7d');

      final pass4 = TimePass(id: '4', name: 'Monthly Pass', durationHours: 720, priceBirr: 300);
      expect(pass4.shortDuration, '30d');

      final pass5 = TimePass(id: '5', name: 'Yearly Pass', durationHours: 8760, priceBirr: 2500);
      expect(pass5.shortDuration, '365d');
    });
  });
}
