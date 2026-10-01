import 'package:flutter/material.dart';

/// Brand palette lifted from the RepairAI web splash (index_5.html).
abstract final class RepairColors {
  static const Color bgCenter = Color(0xFFFDFBFF);
  static const Color bgEdge = Color(0xFFF0E7FA);
  static const Color purple = Color(0xFF4A2068);
  static const Color amber = Color(0xFFF5A012);
  static const Color muted = Color(0xFF7B5A9A);
  static const Color black = Color(0xFF0D0D0D);
}

/// Shared text styles. `serif` maps to Noto Serif on Android, the closest
/// on-device match for the Palatino/Georgia stack used on the web splash.
abstract final class RepairText {
  static const String serifFamily = 'serif';

  static TextStyle wordmark(double fontSize) => TextStyle(
        fontFamily: serifFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01 * fontSize,
        height: 1.0,
        color: RepairColors.purple,
      );

  static TextStyle tagline(double fontSize) => TextStyle(
        fontFamily: serifFamily,
        fontSize: fontSize,
        letterSpacing: 0.14 * fontSize,
        color: RepairColors.muted,
      );
}
