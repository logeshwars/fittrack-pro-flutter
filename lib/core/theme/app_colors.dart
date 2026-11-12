import 'package:flutter/material.dart';

/// Exact Flutter port of the React Native "Luminous Dark" color system.
abstract final class AppColors {
  static const darkBg = Color(0xFF060609);
  static const darkHeader = Color(0xFF060609);
  static const darkCard = Color(0xFF12121A);
  static const darkCardAlt = Color(0xFF0C0C12);
  static const darkBorder = Color(0xFF1C1C27);
  static const darkBorder2 = Color(0xFF282836);
  static const darkAccent = Color(0xFFF4F5FA);
  static const darkAccentTint = Color(0xFF1E1E2B);
  static const darkAccentText = Color(0xFF060609);
  static const darkText = Color(0xFFECEDF4);
  static const darkSubtext = Color(0xFFC6C8D4);
  static const darkMuted = Color(0xFF9B9DAC);
  static const darkFaint = Color(0xFF6C6E7E);
  static const darkInputBg = Color(0xFF0C0C12);
  static const darkCardHighlight = Color(0x0AFFFFFF);

  static const lightBg = Color(0xFFEEF0F6);
  static const lightHeader = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardAlt = Color(0xFFF5F6FA);
  static const lightBorder = Color(0xFFE6E8EF);
  static const lightBorder2 = Color(0xFFD3D6E0);
  static const lightAccent = Color(0xFF111318);
  static const lightAccentTint = Color(0xFFEAECF2);
  static const lightAccentText = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF101218);
  static const lightSubtext = Color(0xFF3C3F4A);
  static const lightMuted = Color(0xFF71747F);
  static const lightFaint = Color(0xFFA0A3AE);
  static const lightInputBg = Color(0xFFF5F6FA);

  // Domain palette. Color belongs to data, not chrome.
  static const workout = Color(0xFFFFB020);
  static const workoutLight = Color(0xFFB45309);
  static const nutrition = Color(0xFFB5E549);
  static const nutritionLight = Color(0xFF5C8A12);
  static const cardio = Color(0xFFFF6B4A);
  static const cardioLight = Color(0xFFC2410C);
  static const sleep = Color(0xFF8F8FFF);
  static const sleepLight = Color(0xFF4F46B8);
  static const water = Color(0xFF45C4FF);
  static const weight = Color(0xFF45C4FF);
  static const waterLight = Color(0xFF0369A1);
  static const recovery = Color(0xFF4ADE80);
  static const recoveryLight = Color(0xFF15803D);
  static const xp = Color(0xFFE8C558);
  static const xpLight = Color(0xFFA16207);

  static const dangerDark = Color(0xFFF4506B);
  static const dangerLight = Color(0xFFDC2640);
  static const warningDark = Color(0xFFF5A623);
  static const warningLight = Color(0xFFC87B06);
}

class AppPalette {
  const AppPalette({
    required this.bg,
    required this.header,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.border2,
    required this.accent,
    required this.accentTint,
    required this.accentText,
    required this.text,
    required this.subtext,
    required this.muted,
    required this.faint,
    required this.inputBg,
    required this.danger,
    required this.warning,
  });

  final Color bg;
  final Color header;
  final Color card;
  final Color cardAlt;
  final Color border;
  final Color border2;
  final Color accent;
  final Color accentTint;
  final Color accentText;
  final Color text;
  final Color subtext;
  final Color muted;
  final Color faint;
  final Color inputBg;
  final Color danger;
  final Color warning;

  static const dark = AppPalette(
    bg: AppColors.darkBg,
    header: AppColors.darkHeader,
    card: AppColors.darkCard,
    cardAlt: AppColors.darkCardAlt,
    border: AppColors.darkBorder,
    border2: AppColors.darkBorder2,
    accent: AppColors.darkAccent,
    accentTint: AppColors.darkAccentTint,
    accentText: AppColors.darkAccentText,
    text: AppColors.darkText,
    subtext: AppColors.darkSubtext,
    muted: AppColors.darkMuted,
    faint: AppColors.darkFaint,
    inputBg: AppColors.darkInputBg,
    danger: AppColors.dangerDark,
    warning: AppColors.warningDark,
  );

  static const light = AppPalette(
    bg: AppColors.lightBg,
    header: AppColors.lightHeader,
    card: AppColors.lightCard,
    cardAlt: AppColors.lightCardAlt,
    border: AppColors.lightBorder,
    border2: AppColors.lightBorder2,
    accent: AppColors.lightAccent,
    accentTint: AppColors.lightAccentTint,
    accentText: AppColors.lightAccentText,
    text: AppColors.lightText,
    subtext: AppColors.lightSubtext,
    muted: AppColors.lightMuted,
    faint: AppColors.lightFaint,
    inputBg: AppColors.lightInputBg,
    danger: AppColors.dangerLight,
    warning: AppColors.warningLight,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
