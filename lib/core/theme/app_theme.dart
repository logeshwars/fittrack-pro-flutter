import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.darkBg,
    card: AppColors.darkCard,
    text: AppColors.darkText,
    accent: AppColors.darkAccent,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.lightBg,
    card: AppColors.lightCard,
    text: AppColors.lightText,
    accent: AppColors.lightAccent,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color card,
    required Color text,
    required Color accent,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: background,
      primary: accent,
      onPrimary: background,
      onSurface: text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardColor: card,
      appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: text, elevation: 0),
      cardTheme: CardThemeData(color: card, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
