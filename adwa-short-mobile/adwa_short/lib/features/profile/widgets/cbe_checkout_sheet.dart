import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cbe_payment.dart';
import '../providers/wallet_provider.dart';

class CbeCheckoutSheet extends StatefulWidget {
  const CbeCheckoutSheet({
    super.key,
    required this.initResult,
    required this.title,
    required this.amountBirr,
  });

  final CbePaymentInitiateResult initResult;
  final String title;
  final num amountBirr;

  static Future<bool?> show(
    BuildContext context, {
    required CbePaymentInitiateResult initResult,
    required String title,
    required num amountBirr,
  }) {
    final wp = context.read<WalletProvider>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider<WalletProvider>.value(
        value: wp,
        child: CbeCheckoutSheet(
          initResult: initResult,
          title: title,
          amountBirr: amountBirr,
        ),
      ),
    );
  }

  @override
  State<CbeCheckoutSheet> createState() => _CbeCheckoutSheetState();
}

class _CbeCheckoutSheetState extends State<CbeCheckoutSheet> {
  Timer? _pollingTimer;
  bool _isCompleted = false;
  bool _isSimulating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final status = await context
          .read<WalletProvider>()
          .checkCbeOrderStatus(widget.initResult.orderId);
      if (status != null && status.isCompleted) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
          // Auto close after brief celebration
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        }
      } else if (status != null && status.isFailed) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _errorMessage = 'Payment was declined or expired.';
          });
        }
      }
    });
  }

  Future<void> _simulateInstantPayment() async {
    setState(() => _isSimulating = true);
    final ok = await context
        .read<WalletProvider>()
        .simulateCbePayment(widget.initResult.orderId);
    if (!mounted) return;
    setState(() => _isSimulating = false);
    if (ok) {
      _pollingTimer?.cancel();
      setState(() => _isCompleted = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulation failed. Please try again.'),
          backgroundColor: AppColors.bloodRed,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.bloodRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Bank Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.bloodRed, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.bloodRed,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commercial Bank of Ethiopia',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'CBE Birr Automated Checkout',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.bloodRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Completion View
              if (_isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 54,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Payment Confirmed!',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your ${widget.title} has been activated instantly.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Order Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: AppTextStyles.body1.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            Formatters.birr(widget.amountBirr),
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.bloodRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Bill Reference:',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _copyToClipboard(
                              widget.initResult.billReference,
                              'Bill Reference',
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.initResult.billReference,
                                    style: AppTextStyles.body2.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.bloodRed,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Method 1: USSD Quick Pay
                if (widget.initResult.ussdCode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.dialpad_rounded,
                              color: AppColors.bloodRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Option A: CBE Birr USSD Approval',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dial this code from your registered phone number:',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            widget.initResult.ussdCode,
                            'USSD Code',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.bloodRed.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.initResult.ussdCode,
                                    style: AppTextStyles.body1.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.bloodRed,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Method 2: Checkout Link
                if (widget.initResult.checkoutUrl.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(
                      widget.initResult.checkoutUrl,
                      'Checkout Link',
                    ),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text(
                      'Copy CBE Web / App Checkout Link',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bloodRed,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Automated Listener Status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bloodRed,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Listening for automated payment confirmation from CBE. No receipt upload required.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Test Mode Instant Simulation
                OutlinedButton.icon(
                  onPressed: _isSimulating ? null : _simulateInstantPayment,
                  icon: _isSimulating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.bloodRed,
                          ),
                        )
                      : const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.bloodRed,
                        ),
                  label: Text(
                    _isSimulating
                        ? 'Simulating Confirmation...'
                        : 'Simulate Instant CBE Confirmation (Test Mode)',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.bloodRed),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
