import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../providers/auth_provider.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: true);
      if (auth.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.main);
          }
        });
      }
    } on ProviderNotFoundException {
      // Allow running in isolated widget tests where AuthProvider is omitted
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.black,
            gradient: RadialGradient(
              center: Alignment(0.0, -0.4),
              radius: 1.2,
              colors: [
                Color(0x38C8102E),
                Color(0x08000000),
                AppColors.black,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        // Top & Center Brand Section
                        _buildBrandHeader(),

                        const SizedBox(height: 48),

                        // Centered Action Buttons & Footer
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildActionButtons(context),
                            const SizedBox(height: 24),
                            _buildFooter(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Glowing brand emblem with layered neon drop shadow
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.bloodRed,
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF2A3B),
                AppColors.bloodRed,
                AppColors.bloodRedDark,
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88C8102E),
                blurRadius: 36,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: AppColors.white,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Title typography
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTextStyles.brandLogo.copyWith(fontSize: 34, letterSpacing: 1.5),
            children: const [
              TextSpan(text: 'ADWA', style: TextStyle(color: AppColors.white)),
              TextSpan(
                text: ' SHORT',
                style: TextStyle(color: AppColors.bloodRedBright),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppStrings.tagline.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.overline.copyWith(
            color: const Color(0xFFDDDDDD),
            letterSpacing: 4.0,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Stream original Ethiopian miniseries in 1-minute binge episodes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sign In (Primary Glossy Red Pill)
        GestureDetector(
          onTap: () async {
            final ok = await Navigator.of(context).pushNamed(AppRoutes.login);
            if (ok == true && context.mounted) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.main);
            }
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF1A2B),
                  AppColors.bloodRed,
                  AppColors.bloodRedDark,
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66E50914),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, color: AppColors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Sign In',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Register (Secondary Outlined Red Pill)
        GestureDetector(
          onTap: () async {
            final ok = await Navigator.of(context).pushNamed(AppRoutes.register);
            if (ok == true && context.mounted) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.main);
            }
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF14080B),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.bloodRed, width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.bloodRedBright, size: 20),
                SizedBox(width: 10),
                Text(
                  'Register',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 3. Continue as Guest (Ghost / Muted Pill)
        GestureDetector(
          onTap: () async {
            try {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (auth.isAuthenticated) {
                await auth.logout();
              }
            } on ProviderNotFoundException {}
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.main);
            }
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.bloodRedBright,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      'By continuing, you agree to our Terms of Service & Privacy Policy.',
      textAlign: TextAlign.center,
      style: AppTextStyles.caption.copyWith(
        color: const Color(0xFF757575),
        fontSize: 11,
      ),
    );
  }
}
