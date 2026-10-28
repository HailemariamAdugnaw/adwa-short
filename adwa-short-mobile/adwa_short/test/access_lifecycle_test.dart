import 'package:flutter_test/flutter_test.dart';
import 'package:adwa_short/models/access_status.dart';

void main() {
  group('Access Status Models & Countdown Tests', () {
    test('ActivePassStatus formats remaining time and dates correctly', () {
      final pass = ActivePassStatus(
        hasActivePass: true,
        purchaseId: 1,
        passId: 2,
        name: '24-Hour Binge Pass',
        durationHours: 24,
        priceBirr: 30.0,
        startsAt: DateTime.utc(2026, 10, 26, 12, 0),
        expiresAt: DateTime.utc(2026, 10, 27, 12, 0),
        isActive: true,
        remainingSeconds: 86400,
      );

      expect(pass.hasActivePass, isTrue);
      expect(pass.name, '24-Hour Binge Pass');
      expect(pass.formattedRemaining, '1d 0h 0m 0s');

      final passShort = pass.copyWith(remainingSeconds: 3665);
      expect(passShort.formattedRemaining, '1h 1m 5s');

      final passMinutes = pass.copyWith(remainingSeconds: 125);
      expect(passMinutes.formattedRemaining, '2m 5s');

      final passExpired = pass.copyWith(remainingSeconds: 0);
      expect(passExpired.formattedRemaining, 'Expired');
    });

    test('ActiveSubscriptionStatus formats remaining time and tiers correctly', () {
      final sub = ActiveSubscriptionStatus(
        hasActiveSubscription: true,
        subscriptionId: 10,
        planId: 5,
        planName: 'VIP Monthly Pass',
        billingCycle: 'monthly',
        priceBirr: 150.0,
        status: 'active',
        startedAt: DateTime.utc(2026, 10, 26, 10, 0),
        nextBillingAt: DateTime.utc(2026, 11, 26, 10, 0),
        remainingSeconds: 2592000,
      );

      expect(sub.hasActiveSubscription, isTrue);
      expect(sub.planName, 'VIP Monthly Pass');
      expect(sub.billingCycle, 'monthly');
      expect(sub.formattedRemaining, contains('d'));
      expect(sub.formattedExpiresAt, isNotEmpty);

      final subExpired = sub.copyWith(remainingSeconds: 0);
      expect(subExpired.formattedRemaining, 'Expired');
    });

    test('UserAccessDashboard deserializes composite status correctly', () {
      final json = {
        'server_time': '2026-10-26T20:30:00Z',
        'active_pass': {
          'has_active_pass': true,
          'purchase_id': 1,
          'pass_id': 2,
          'name': '24-Hour Binge Pass',
          'duration_hours': 24,
          'price_birr': 30.0,
          'starts_at': '2026-10-26T12:00:00Z',
          'expires_at': '2026-10-27T12:00:00Z',
          'is_active': true,
          'server_time': '2026-10-26T20:30:00Z',
          'remaining_seconds': 55800,
        },
        'active_subscription': {
          'has_active_subscription': false,
          'server_time': '2026-10-26T20:30:00Z',
          'remaining_seconds': 0,
        },
      };

      final dash = UserAccessDashboard.fromJson(json);
      expect(dash.serverTime.isUtc, isTrue);
      expect(dash.activePass.hasActivePass, isTrue);
      expect(dash.activePass.name, '24-Hour Binge Pass');
      expect(dash.activePass.remainingSeconds, 55800);
      expect(dash.activeSubscription.hasActiveSubscription, isFalse);
    });
  });
}
