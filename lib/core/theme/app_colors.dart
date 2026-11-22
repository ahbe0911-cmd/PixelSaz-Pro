import 'package:flutter/material.dart';

/// One semantic palette for both themes, shared by all application features.
abstract final class AppColors {
  static const Color oceanBlue = Color(0xFF2563EB);
  static const Color deepBlue = Color(0xFF1946C9);
  static const Color violet = Color(0xFF7355DC);
  static const Color aqua = Color(0xFF19B6BB);

  static const Color lightBackground = Color(0xFFF6F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF18243D);
  static const Color lightMuted = Color(0xFF68778E);
  static const Color lightOutline = Color(0xFFE5EAF2);

  static const Color darkBackground = Color(0xFF0B1223);
  static const Color darkSurface = Color(0xFF151E33);
  static const Color darkElevated = Color(0xFF202D49);
  static const Color darkText = Color(0xFFF2F6FF);
  static const Color darkMuted = Color(0xFFACB9CD);
  static const Color darkOutline = Color(0xFF32425C);
}
