import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'adwa_button.dart';

/// Clean, beautifully styled authentication wall / prompt for Guest users.
///
/// Adheres strictly to ADWA SHORT brand guidelines: Black (#000000 / #121212),
/// Blood Red (#C8102E / #E50914), and High-Contrast White (#FFFFFF).
class GuestAuthPrompt extends StatelessWidget {
  const GuestAuthPrompt({
    super.key,
    this.title = 'Sign In to Continue',
    this.message =
        'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
  });

  final String title;
  final String message;

  /// Shows the modal bottom sheet and returns `true` if the user successfully
  /// authenticated (logged in or registered), or `false` if dismissed.
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? message,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => GuestAuthPrompt(
        title: title ?? 'Sign In to Continue',
        message: message ??
            'Please sign in or register to unlock episodes, buy coins, and access subscriptions.',
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.bloodRed.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66C8102E),
            blurRadius: 28,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle indicator
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Glowing hero lock icon badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFF1E27),
                      Color(0xFF8B0010),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFF334B),
                    width: 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99FF1744),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Informational Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),

              // Action 1: Sign In (Primary Pill Button)
              AdwaButton(
                label: 'Sign In',
                icon: Icons.login_rounded,
                expanded: true,
                size: AdwaButtonSize.lg,
                onPressed: () async {
                  final nav = Navigator.of(context, rootNavigator: true);
                  final loggedIn = await nav.pushNamed(
                    AppRoutes.login,
                    arguments: {'message': message, 'fromModal': true},
                  );
                  if (context.mounted && nav.canPop()) {
                    nav.pop(loggedIn == true);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Action 2: Register (Secondary Outlined Button)
              AdwaButton(
                label: 'Create an Account',
                icon: Icons.person_add_alt_1_rounded,
                variant: AdwaButtonVariant.secondary,
                expanded: true,
                size: AdwaButtonSize.lg,
                onPressed: () async {
                  final nav = Navigator.of(context, rootNavigator: true);
                  final registered = await nav.pushNamed(
                    AppRoutes.register,
                    arguments: {'message': message, 'fromModal': true},
                  );
                  if (context.mounted && nav.canPop()) {
                    nav.pop(registered == true);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Action 3: Continue as Guest / Dismiss
              TextButton(
                onPressed: () {
                  final nav = Navigator.of(context, rootNavigator: true);
                  if (nav.canPop()) {
                    nav.pop(false);
                  }
                },
                child: Text(
                  'Continue as Guest',
                  style: AppTextStyles.body3.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
