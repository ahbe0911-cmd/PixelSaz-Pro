import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Material 3 visual language. All text styles resolve to bundled Vazirmatn.
/// No Google Fonts networking or implicit system font selection is used.
abstract final class AppTheme {
  static const String fontFamily = 'Vazirmatn';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final foreground = dark ? AppColors.darkText : AppColors.lightText;
    final muted = dark ? AppColors.darkMuted : AppColors.lightMuted;
    final outline = dark ? AppColors.darkOutline : AppColors.lightOutline;
    final elevated = dark ? AppColors.darkElevated : const Color(0xFFF1F5FC);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.oceanBlue,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.oceanBlue,
      onPrimary: Colors.white,
      primaryContainer: dark ? const Color(0xFF24407B) : const Color(0xFFE6EEFF),
      onPrimaryContainer: dark ? Colors.white : AppColors.deepBlue,
      secondary: AppColors.violet,
      tertiary: AppColors.aqua,
      surface: surface,
      onSurface: foreground,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outline,
      surfaceContainerLowest: background,
      surfaceContainerLow: background,
      surfaceContainer: elevated,
      surfaceContainerHigh: elevated,
      surfaceContainerHighest: elevated,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );
    final typography = base.textTheme
        .apply(
          fontFamily: fontFamily,
          bodyColor: foreground,
          displayColor: foreground,
        )
        .copyWith(
          headlineLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 29,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 24,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 21,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 19,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            height: 1.6,
            color: foreground,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            height: 1.6,
            color: foreground,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            height: 1.5,
            color: muted,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1.4,
            color: foreground,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            height: 1.4,
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
    );
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(0, 52),
      backgroundColor: AppColors.oceanBlue,
      foregroundColor: Colors.white,
      disabledBackgroundColor: dark ? AppColors.darkElevated : const Color(0xFFE4E8F1),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 19),
      shape: shape,
      textStyle: typography.labelLarge,
    );

    return base.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: foreground,
        toolbarHeight: 56,
        iconTheme: IconThemeData(color: foreground),
        titleTextStyle: typography.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: outline),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: elevated,
        hintStyle: typography.bodyMedium?.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.oceanBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: AppColors.oceanBlue,
          foregroundColor: Colors.white,
          shape: shape,
          textStyle: typography.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: outline),
          foregroundColor: foreground,
          shape: shape,
          textStyle: typography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.oceanBlue,
          textStyle: typography.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkElevated : AppColors.lightText,
        contentTextStyle: typography.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: typography.titleLarge,
        contentTextStyle: typography.bodyMedium,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: elevated,
        labelStyle: typography.labelMedium,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.oceanBlue,
      ),
    );
  }
}
