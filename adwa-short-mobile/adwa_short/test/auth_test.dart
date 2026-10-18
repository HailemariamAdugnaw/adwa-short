import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/core/network/api_exception.dart';
import 'package:adwa_short/core/utils/validators.dart';
import 'package:adwa_short/models/user.dart';
import 'package:adwa_short/models/wallet.dart';

void main() {
  group('Validators', () {
    test('phone rejects empty', () {
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone(null), isNotNull);
    });
    test('phone accepts 10-digit number', () {
      expect(Validators.phone('0912345678'), isNull);
    });
    test('phone accepts + with international format', () {
      expect(Validators.phone('+251912345678'), isNull);
    });
    test('phone rejects letters', () {
      expect(Validators.phone('abcdefghij'), isNotNull);
    });
    test('password rejects short', () {
      expect(Validators.password('123'), isNotNull);
    });
    test('password accepts valid', () {
      expect(Validators.password('secret1'), isNull);
    });
    test('displayName rejects empty', () {
      expect(Validators.displayName(''), isNotNull);
    });
    test('displayName accepts name', () {
      expect(Validators.displayName('Selam'), isNull);
    });
  });

  group('User.fromJson', () {
    test('parses complete payload', () {
      final u = User.fromJson({
        'id': 42,
        'phone': '+251912345678',
        'email': 'selam@example.com',
        'display_name': 'Selam',
        'avatar_url': 'https://example.com/a.png',
        'wallet': {
          'balance_birr': 100,
          'balance_coins': 250,
          'recent_transactions': [
            {
              'id': 't1',
              'type': 'coin_purchase',
              'amount': -50,
              'currency': 'birr',
              'description': 'Coin pack',
              'created_at': '2025-01-01T10:00:00Z',
            },
          ],
        },
      });
      expect(u.id, '42');
      expect(u.phone, '+251912345678');
      expect(u.displayName, 'Selam');
      expect(u.wallet, isNotNull);
      expect(u.wallet!.balanceBirr, 100);
      expect(u.wallet!.balanceCoins, 250);
      expect(u.wallet!.recentTransactions.length, 1);
      expect(u.wallet!.recentTransactions.first.isCredit, isFalse);
    });

    test('parses minimal payload with empty wallet', () {
      final u = User.fromJson({
        'id': '1',
        'phone': '0912345678',
        'display_name': 'User',
      });
      expect(u.id, '1');
      expect(u.wallet, isNull);
    });
  });

  group('Wallet', () {
    test('copyWith preserves fields', () {
      final w = Wallet(balanceBirr: 10, balanceCoins: 5);
      final w2 = w.copyWith(balanceCoins: 50);
      expect(w2.balanceBirr, 10);
      expect(w2.balanceCoins, 50);
    });
  });

  group('ApiException', () {
    test('parses message + code from response body', () {
      final e = ApiException.fromResponse(403, {
        'message': 'Device limit reached',
        'code': 'MAX_DEVICE_LIMIT_REACHED',
      });
      expect(e.statusCode, 403);
      expect(e.code, 'MAX_DEVICE_LIMIT_REACHED');
      expect(e.isMaxDeviceLimit, isTrue);
    });
    test('isUnauthorized matches 401', () {
      final e = ApiException(statusCode: 401, message: 'unauth');
      expect(e.isUnauthorized, isTrue);
    });
  });
}
