import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:adwa_short/core/network/api_client.dart';
import 'package:adwa_short/core/network/token_manager.dart';
import 'package:adwa_short/core/theme/colors.dart';
import 'package:adwa_short/features/profile/providers/wallet_provider.dart';
import 'package:adwa_short/features/profile/widgets/cbe_checkout_sheet.dart';
import 'package:adwa_short/models/cbe_payment.dart';

class _MockTokenManager implements TokenManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCbeApiClient extends ApiClient {
  _MockCbeApiClient() : super(tokenManager: _MockTokenManager());

  bool statusIsCompleted = false;

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool requireAuth = true,
    required T Function(dynamic p1) parser,
  }) async {
    if (path.contains('/api/v1/payments/cbe/initiate')) {
      final json = {
        'order_id': 'CBE-ORD-TEST123456',
        'item_type': 'coins',
        'item_id': 1,
        'amount_birr': 80.0,
        'currency': 'ETB',
        'status': 'pending',
        'bill_reference': 'CBE12345678',
        'checkout_url': 'https://checkout.cbe.com.et/pay?billReference=CBE12345678',
        'ussd_code': '*847*1*847291*CBE12345678#',
        'created_at': DateTime.now().toIso8601String(),
      };
      return parser(json);
    }
    if (path.contains('/api/v1/payments/cbe/simulate-payment/')) {
      statusIsCompleted = true;
      return parser({'status': 'success', 'order_id': 'CBE-ORD-TEST123456'});
    }
    return parser(<String, dynamic>{});
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, String>? query,
    bool requireAuth = true,
    required T Function(dynamic p1) parser,
  }) async {
    if (path.contains('/api/v1/payments/cbe/order/')) {
      final json = {
        'order_id': 'CBE-ORD-TEST123456',
        'item_type': 'coins',
        'item_id': 1,
        'amount_birr': 80.0,
        'currency': 'ETB',
        'status': statusIsCompleted ? 'completed' : 'pending',
        'cbe_transaction_id': statusIsCompleted ? 'TX-CBE-TEST-99' : null,
        'bill_reference': 'CBE12345678',
        'checkout_url': 'https://checkout.cbe.com.et/pay?billReference=CBE12345678',
        'ussd_code': '*847*1*847291*CBE12345678#',
        'created_at': DateTime.now().toIso8601String(),
      };
      return parser(json);
    }
    if (path.contains('/wallet')) {
      return parser({
        'balance_birr': 100.0,
        'balance_coins': statusIsCompleted ? 150 : 50,
      });
    }
    return parser(<String, dynamic>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CBE Payment Models & Serialization', () {
    test('CbePaymentInitiateResult parses correctly from JSON', () {
      final json = {
        'order_id': 'CBE-ORD-AAA111',
        'item_type': 'coins',
        'item_id': 4,
        'amount_birr': 120.5,
        'currency': 'ETB',
        'status': 'pending',
        'bill_reference': 'CBE99887766',
        'checkout_url': 'https://checkout.cbe.com.et/pay?bill=CBE99887766',
        'ussd_code': '*847*1*847291*CBE99887766#',
        'created_at': '2026-10-26T12:00:00Z',
      };
      final model = CbePaymentInitiateResult.fromJson(json);
      expect(model.orderId, 'CBE-ORD-AAA111');
      expect(model.itemType, 'coins');
      expect(model.itemId, 4);
      expect(model.amountBirr, 120.5);
      expect(model.billReference, 'CBE99887766');
      expect(model.ussdCode, '*847*1*847291*CBE99887766#');
      expect(model.status, 'pending');
    });

    test('CbeOrderStatus parses correctly and handles status flags', () {
      final pendingJson = {
        'order_id': 'CBE-ORD-BBB222',
        'item_type': 'time_pass',
        'amount_birr': 50.0,
        'currency': 'ETB',
        'status': 'pending',
      };
      final pending = CbeOrderStatus.fromJson(pendingJson);
      expect(pending.isPending, isTrue);
      expect(pending.isCompleted, isFalse);
      expect(pending.isFailed, isFalse);

      final completedJson = {
        'order_id': 'CBE-ORD-BBB222',
        'item_type': 'time_pass',
        'amount_birr': 50.0,
        'currency': 'ETB',
        'status': 'completed',
        'cbe_transaction_id': 'TX-CBE-999',
      };
      final completed = CbeOrderStatus.fromJson(completedJson);
      expect(completed.isCompleted, isTrue);
      expect(completed.isPending, isFalse);
    });
  });

  group('CbeCheckoutSheet Widget Flow', () {
    late _MockCbeApiClient mockApi;
    late WalletProvider walletProvider;

    setUp(() {
      mockApi = _MockCbeApiClient();
      walletProvider = WalletProvider(mockApi);
    });

    testWidgets('Renders CBE checkout sheet with brand colors and automated listener', (tester) async {
      final initResult = CbePaymentInitiateResult(
        orderId: 'CBE-ORD-TEST123456',
        itemType: 'coins',
        itemId: 1,
        amountBirr: 80.0,
        currency: 'ETB',
        status: 'pending',
        billReference: 'CBE12345678',
        checkoutUrl: 'https://checkout.cbe.com.et/pay?billReference=CBE12345678',
        ussdCode: '*847*1*847291*CBE12345678#',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<WalletProvider>.value(
          value: walletProvider,
          child: MaterialApp(
            theme: ThemeData(
              scaffoldBackgroundColor: AppColors.black,
              colorScheme: const ColorScheme.dark(
                primary: AppColors.bloodRed,
                surface: AppColors.surface,
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CbeCheckoutSheet.show(
                    context,
                    initResult: initResult,
                    title: '100 Coins Pack',
                    amountBirr: 80.0,
                  ),
                  child: const Text('Open CBE Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open CBE Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Header and Bank Branding
      expect(find.text('Commercial Bank of Ethiopia'), findsOneWidget);
      expect(find.text('CBE Birr Automated Checkout'), findsOneWidget);
      expect(find.text('100 Coins Pack'), findsOneWidget);
      expect(find.text('CBE12345678'), findsOneWidget);

      // Verify USSD Option
      expect(find.text('*847*1*847291*CBE12345678#'), findsOneWidget);
      expect(find.text('Option A: CBE Birr USSD Approval'), findsOneWidget);

      // Verify Web / App Checkout Option
      expect(find.text('Copy CBE Web / App Checkout Link'), findsOneWidget);

      // Verify Automated Listener Banner
      expect(
        find.text('Listening for automated payment confirmation from CBE. No receipt upload required.'),
        findsOneWidget,
      );

      // Verify Test Simulation Button
      expect(
        find.text('Simulate Instant CBE Confirmation (Test Mode)'),
        findsOneWidget,
      );

      // Simulate instant payment
      await tester.tap(find.text('Simulate Instant CBE Confirmation (Test Mode)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Payment Confirmed celebration
      expect(find.text('Payment Confirmed!'), findsOneWidget);

      // Let auto-pop finish
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
