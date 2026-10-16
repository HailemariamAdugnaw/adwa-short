import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color black = Color(0xFF0A0A0A);
  static const Color bloodRed = Color(0xFFC8102E);
  static const Color white = Color(0xFFFFFFFF);

  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF1C1C1C);
  static const Color surfaceHover = Color(0xFF242424);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF333333);

  static const Color bloodRedBright = Color(0xFFE11D38);
  static const Color bloodRedDark = Color(0xFF9A0B22);
  static const Color bloodRedMuted = Color(0xFF7A0820);
  static const Color bloodRedGlow = Color(0x44C8102E);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB5B5B5);
  static const Color textTertiary = Color(0xFF7A7A7A);
  static const Color textDisabled = Color(0xFF4A4A4A);

  static const Color textOnRed = Color(0xFFFFFFFF);
  static const Color textOnBlack = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF1FA363);
  static const Color warning = Color(0xFFE0A526);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF3B82F6);

  static const Color vipGold = Color(0xFFE0A526);
  static const Color exclusivePurple = Color(0xFF7C3AED);

  static const Color transparent = Color(0x00000000);
  static const Color overlayScrim = Color(0x800A0A0A);
  static const Color shimmerBase = Color(0xFF1C1C1C);
  static const Color shimmerHighlight = Color(0xFF2E2E2E);

  static const LinearGradient bloodRedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bloodRedBright, bloodRedDark],
  );

  static const LinearGradient cinematicGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x000A0A0A), Color(0xCC0A0A0A)],
  );

  static const LinearGradient walletCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C1C1C), bloodRedDark],
  );

  static const MaterialColor bloodRedSwatch = MaterialColor(
    0xFFC8102E,
    <int, Color>{
      50: Color(0xFFFBE5E8),
      100: Color(0xFFF6BFC6),
      200: Color(0xFFEE939E),
      300: Color(0xFFE56675),
      400: Color(0xFFDD394C),
      500: bloodRed,
      600: Color(0xFFB30D26),
      700: bloodRedDark,
      800: Color(0xFF7A0820),
      900: Color(0xFF5A0517),
    },
  );
}
