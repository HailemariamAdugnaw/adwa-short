import 'package:flutter/material.dart';

import 'colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String displayFamily = 'Poppins';
  static const String bodyFamily = 'Inter';
  static const String monoFamily = 'RobotoMono';

  static const TextStyle display1 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    fontSize: 38,
    height: 1.1,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle display2 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 1.15,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle display3 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle body3 = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.5,
    color: AppColors.textTertiary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.4,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.2,
    letterSpacing: 0.4,
    color: AppColors.textOnRed,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    height: 1.4,
    letterSpacing: 1.2,
    color: AppColors.textTertiary,
  );

  static const TextStyle brandLogo = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w900,
    fontSize: 34,
    letterSpacing: 2.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle userIdMonospace = TextStyle(
    fontFamily: monoFamily,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    letterSpacing: 1.0,
    color: AppColors.textTertiary,
  );
}
