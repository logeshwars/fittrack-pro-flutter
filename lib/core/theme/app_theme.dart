import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? ColorScheme.dark(
            primary: palette.accent,
            onPrimary: palette.accentText,
            surface: palette.bg,
            onSurface: palette.text,
            error: palette.danger,
          )
        : ColorScheme.light(
            primary: palette.accent,
            onPrimary: palette.accentText,
            surface: palette.bg,
            onSurface: palette.text,
            error: palette.danger,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.bg,
      cardColor: palette.card,
      dividerColor: palette.border,
      splashColor: palette.accent.withValues(alpha: 0.06),
      highlightColor: palette.accent.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.header,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: palette.text,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: palette.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: palette.text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: palette.subtext,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(
          color: palette.text,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.border2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.border2),
        ),
      ),
    );
  }
}
