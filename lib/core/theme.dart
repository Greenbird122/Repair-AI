import 'package:flutter/material.dart';

/// Brand palette lifted from the RepairAI web splash (index_5.html).
abstract final class RepairColors {
  // Light "app world" — calm lavender used across in-app pages.
  static const Color bgCenter = Color(0xFFFDFBFF);
  static const Color purple = Color(0xFF4A2068);
  static const Color amber = Color(0xFFF5A012);
  static const Color muted = Color(0xFF7B5A9A);

  // Dark splash stage — matches the official black-background logo.
  static const Color splashBgCenter = Color(0xFF161119);
  static const Color splashBg = Color(0xFF0D0D0D);
  static const Color onDark = Color(0xFFF7F4FB);
  static const Color onDarkMuted = Color(0xFFC9BEDA);
}

/// Shared text styles. `serif` maps to Noto Serif on Android, the closest
/// on-device match for the Palatino/Georgia stack used on the web splash.
abstract final class RepairText {
  static const String serifFamily = 'serif';

  static TextStyle wordmark(
    double fontSize, {
    Color color = RepairColors.purple,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01 * fontSize,
        height: 1.0,
        color: color,
      );

  static TextStyle tagline(
    double fontSize, {
    Color color = RepairColors.muted,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontSize: fontSize,
        letterSpacing: 0.14 * fontSize,
        color: color,
      );
}

/// The light in-app theme. The splash intentionally opts out (it paints its
/// own dark stage); every other page rides this.
abstract final class RepairTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RepairColors.purple,
      surface: RepairColors.bgCenter,
    ),
    scaffoldBackgroundColor: RepairColors.bgCenter,
  );
}
