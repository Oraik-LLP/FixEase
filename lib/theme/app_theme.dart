import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/theme_service.dart';

/// Palette derived from Tesla Cybertruck dark UI reference:
///   - Near-black base (#111114)
///   - Subtle lifted surfaces (#1B1B1F)
///   - Electric cyan accent on active controls only
///   - Thin/light secondary text, bold primaries
abstract final class AppColors {
  static const background = Color(0xFF111114);
  static const backgroundDeep = Color(0xFF0C0C0E);
  static const backgroundLift = Color(0xFF17171B);
  static const surface = Color(0xFF1B1B1F);
  static const surfaceHighlight = Color(0xFF242428);
  static const accent = Color(0xFF009DFF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF787880);
  static const textTertiary = Color(0xFF505058);
  static const shadowDark = Color(0xFF050507);
  static const shadowLight = Color(0xFF222228);
}

TextTheme _fixEaseTextTheme(Brightness brightness) {
  final base = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );
  final primary = brightness == Brightness.dark
      ? AppColors.textPrimary
      : AppColorsLight.textPrimary;
  final secondary = brightness == Brightness.dark
      ? AppColors.textSecondary
      : AppColorsLight.textSecondary;
  final tertiary = brightness == Brightness.dark
      ? AppColors.textTertiary
      : AppColorsLight.textTertiary;

  return base.copyWith(
    displayLarge: GoogleFonts.inter(
      fontSize: 52,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.5,
      height: 1.05,
      color: primary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 1.15,
      color: primary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.22,
      color: primary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.3,
      color: primary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
      height: 1.35,
      color: primary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.5,
      color: secondary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.45,
      color: secondary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.05,
      height: 1.4,
      color: tertiary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.2,
      color: primary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      height: 1.2,
      color: secondary,
    ),
  );
}

ThemeData _buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final accent = isLight ? AppColorsLight.accent : AppColors.accent;
  final surface = isLight ? AppColorsLight.surface : AppColors.surface;
  final textPrimary =
      isLight ? AppColorsLight.textPrimary : AppColors.textPrimary;
  final textSecondary =
      isLight ? AppColorsLight.textSecondary : AppColors.textSecondary;
  final textTertiary =
      isLight ? AppColorsLight.textTertiary : AppColors.textTertiary;
  final backgroundDeep =
      isLight ? AppColorsLight.backgroundDeep : AppColors.backgroundDeep;
  final textTheme = _fixEaseTextTheme(brightness);

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: textTheme,
    colorScheme: brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: Color(0xFF009DFF),
            onPrimary: Color(0xFFFFFFFF),
            surface: Color(0xFF1B1B1F),
            onSurface: Color(0xFFFFFFFF),
            secondary: Color(0xFF009DFF),
            onSecondary: Color(0xFFFFFFFF),
          )
        : ColorScheme.light(
            primary: accent,
            onPrimary: Colors.white,
            surface: surface,
            onSurface: textPrimary,
            secondary: accent,
            onSecondary: Colors.white,
          ),
    iconTheme: IconThemeData(
      color: textSecondary,
      size: 20,
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (BuildContext context) => Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: textPrimary,
      ),
      closeButtonIconBuilder: (BuildContext context) => Icon(
        Icons.close_rounded,
        size: 20,
        color: textPrimary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textSecondary,
        iconSize: 20,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textPrimary,
      centerTitle: true,
      toolbarHeight: 48,
      titleSpacing: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(
        color: textSecondary,
        size: 20,
      ),
      actionsIconTheme: IconThemeData(
        color: textSecondary,
        size: 20,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: backgroundDeep,
      indicatorColor: accent.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.1,
          color: selected ? accent : textTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? accent : textTertiary,
          size: 22,
        );
      }),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildFixEaseTheme() => _buildTheme(Brightness.dark);

ThemeData buildFixEaseLightTheme() => _buildTheme(Brightness.light);

/// Near-black layered background matching reference automotive UI.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight
              ? [
                  AppColorsLight.backgroundLift,
                  AppColorsLight.background,
                  AppColorsLight.backgroundDeep,
                ]
              : [
                  AppColors.backgroundLift,
                  AppColors.background,
                  AppColors.backgroundDeep,
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Styled back control for wizard steps.
class FixEaseStepBackButton extends StatelessWidget {
  const FixEaseStepBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: fxColor(
                context,
                dark: AppColors.textSecondary,
                light: AppColorsLight.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Back',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
                color: fxColor(
                  context,
                  dark: AppColors.textSecondary,
                  light: AppColorsLight.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
