import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Light palette companion to [AppColors].
abstract final class AppColorsLight {
  static const background = Color(0xFFF4F5F7);
  static const backgroundDeep = Color(0xFFE8EAED);
  static const backgroundLift = Color(0xFFFAFBFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHighlight = Color(0xFFF0F2F5);
  static const accent = Color(0xFF0077CC);
  static const textPrimary = Color(0xFF1A1A1E);
  static const textSecondary = Color(0xFF5C5C66);
  static const textTertiary = Color(0xFF8E8E98);
  static const shadowDark = Color(0x1A000000);
  static const shadowLight = Color(0x33FFFFFF);
}

/// Resolves a palette color for the current theme brightness.
Color fxColor(
  BuildContext context, {
  required Color dark,
  required Color light,
}) {
  return Theme.of(context).brightness == Brightness.light ? light : dark;
}

/// Theme-aware palette accessors for widgets that cannot use [AppColors] directly.
abstract final class FxColors {
  static Color surface(BuildContext context) => fxColor(
        context,
        dark: AppColors.surface,
        light: AppColorsLight.surface,
      );

  static Color surfaceHighlight(BuildContext context) => fxColor(
        context,
        dark: AppColors.surfaceHighlight,
        light: AppColorsLight.surfaceHighlight,
      );

  static Color textPrimary(BuildContext context) => fxColor(
        context,
        dark: AppColors.textPrimary,
        light: AppColorsLight.textPrimary,
      );

  static Color textSecondary(BuildContext context) => fxColor(
        context,
        dark: AppColors.textSecondary,
        light: AppColorsLight.textSecondary,
      );

  static Color textTertiary(BuildContext context) => fxColor(
        context,
        dark: AppColors.textTertiary,
        light: AppColorsLight.textTertiary,
      );

  static Color accent(BuildContext context) => fxColor(
        context,
        dark: AppColors.accent,
        light: AppColorsLight.accent,
      );

  static Color borderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0x14000000)
          : const Color(0x0CFFFFFF);
}
