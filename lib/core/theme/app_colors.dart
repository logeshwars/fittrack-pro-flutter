import 'package:flutter/material.dart';

/// Raw color values for the FitTrack Pro V2 design system.
///
/// **Night** is the dark theme and **Pearl** is the light theme. The values
/// mirror `design/tokens.json`; `test/design_tokens_test.dart` fails if the
/// two drift apart. Screens should read colors from [AppPalette.of], not from
/// these constants, except for the domain colors that stay theme-independent.
abstract final class AppColors {
  // ── Night (dark) ──────────────────────────────────────────────────────────
  static const darkBg = Color(0xFF15181B);
  static const darkHeader = Color(0xFF1F2429); // surface
  static const darkCard = Color(0xFF1F2429); // surface
  static const darkCardAlt = Color(0xFF15181B); // recessed panel: bg
  static const darkBorder = Color(0xFF2D343A); // line
  static const darkBorder2 = Color(0xFF404A52); // line-strong
  static const darkAccent = Color(0xFFA8C5B3);
  static const darkAccentTint = Color(0xFF29362F); // accent-soft
  static const darkAccentText = Color(0xFF14201A); // on-accent
  static const darkText = Color(0xFFEEF1EE); // ink
  static const darkSubtext = Color(0xFFA3ADA8); // V2 has no subtext: muted
  static const darkMuted = Color(0xFFA3ADA8);
  static const darkFaint = Color(0xFFA3ADA8); // V2 has no faint: muted
  static const darkInputBg = Color(0xFF1F2429);
  static const darkSegTrack = Color(0xFF2D343A); // line

  // ── Pearl (light) ─────────────────────────────────────────────────────────
  static const lightBg = Color(0xFFFFFFFF);
  static const lightHeader = Color(0xFFF5F5F4); // surface
  static const lightCard = Color(0xFFF5F5F4); // surface
  static const lightCardAlt = Color(0xFFFFFFFF); // recessed panel: bg
  static const lightBorder = Color(0xFFE5E5E2); // line
  static const lightBorder2 = Color(0xFFBDBDB8); // line-strong
  static const lightAccent = Color(0xFF1F1F1F);
  static const lightAccentTint = Color(0xFFE9E9E6); // accent-soft
  static const lightAccentText = Color(0xFFFFFFFF); // on-accent
  static const lightText = Color(0xFF151515); // ink
  static const lightSubtext = Color(0xFF5E5E5B); // V2 has no subtext: muted
  static const lightMuted = Color(0xFF5E5E5B);
  static const lightFaint = Color(0xFF5E5E5B); // V2 has no faint: muted
  static const lightInputBg = Color(0xFFF5F5F4);
  static const lightSegTrack = Color(0xFFDCDCD8);
  static const darkChevron = Color(0xFF8B9591);
  static const lightChevron = Color(0xFF8A8A86);

  // ── Rest timer bar (dark in both themes) ──────────────────────────────────
  static const restBg = Color(0xFF0E1113);
  static const restInk = Color(0xFFFFFFFF);
  static const restMuted = Color(0xFFB8BFCB);
  static const restOutline = Color(0xFF5A646B);

  // ── Hero art (Today and Nutrition headers) ────────────────────────────────
  static const heroDarkStart = Color(0xFF2A3239);
  static const heroDarkEnd = Color(0xFF1E252B);
  static const heroDarkRing = Color(0xFF41505A);
  static const heroLightStart = Color(0xFFECECEA);
  static const heroLightEnd = Color(0xFFD8D8D4);
  static const heroLightDot = Color(0xFFBDBDB8);

  // ── Domain palette (color belongs to data, never chrome) ──────────────────
  // Unsuffixed = Night (luminous); `Light` = Pearl (deep, reads on white).
  static const workout = Color(0xFFFFB020);
  static const workoutLight = Color(0xFFB45309);
  static const nutrition = Color(0xFFB5E549);
  static const nutritionLight = Color(0xFF5C8A12);
  static const cardio = Color(0xFFFF6B4A);
  static const cardioLight = Color(0xFFA8360A);
  static const sleep = Color(0xFF8F8FFF);
  static const sleepLight = Color(0xFF4F46B8);
  static const water = Color(0xFF45C4FF);
  static const weight = Color(0xFF45C4FF);
  static const waterLight = Color(0xFF0369A1);
  static const xp = Color(0xFFE8C558);
  static const xpLight = Color(0xFFA16207);
  // Not part of V2 tokens; kept so existing screens keep compiling.
  static const recovery = Color(0xFF4ADE80);
  static const recoveryLight = Color(0xFF15803D);

  // ── Status ────────────────────────────────────────────────────────────────
  static const dangerDark = Color(0xFFF4506B); // bad
  static const dangerLight = Color(0xFFB42318);
  static const warningDark = Color(0xFFE8C558); // warn
  static const warningLight = Color(0xFF7A5B00);
  static const okDark = Color(0xFF6FCF9F);
  static const okLight = Color(0xFF0B6B44);
  static const okSoftDark = Color(0xFF1F3329);
  static const okSoftLight = Color(0xFFE3F0E8);
  static const warnSoftDark = Color(0xFF3A331C);
  static const warnSoftLight = Color(0xFFF5EBC4);
  static const badSoftDark = Color(0xFF3A2229);
  static const badSoftLight = Color(0xFFFBE4E1);
  static const textBadDark = Color(0xFFFF8095);
  static const textBadLight = Color(0xFFB42318);
  static const textNutritionDark = Color(0xFFB5E549);
  static const textNutritionLight = Color(0xFF46690F);
  static const sleepSoftDark = Color(0xFF2E2E4F);
  static const sleepSoftLight = Color(0xFFE4E2F6);

  // ── Rank tiers (Elite = ink, Legend = sleep) ──────────────────────────────
  static const tierBronzeDark = Color(0xFFD9944F);
  static const tierBronzeLight = Color(0xFF8A5518);
  static const tierSilverDark = Color(0xFFB8C0BC);
  static const tierSilverLight = Color(0xFF5E6663);
  static const tierGoldDark = Color(0xFFE8C558);
  static const tierGoldLight = Color(0xFF7A5B00);
}

/// Theme-aware color set. Resolve with [AppPalette.of].
///
/// The original field names (`card`, `border`, `text`, …) are kept so existing
/// screens compile; the V2 token names are exposed as getters (`surface`,
/// `line`, `ink`, …). New code should use the V2 names.
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
    required this.segTrack,
    required this.chevron,
    required this.danger,
    required this.warning,
    required this.ok,
    required this.okSoft,
    required this.warnSoft,
    required this.badSoft,
    required this.textBad,
    required this.textNutrition,
    required this.sleepSoft,
    required this.workoutColor,
    required this.nutritionColor,
    required this.cardioColor,
    required this.sleepColor,
    required this.waterColor,
    required this.xpColor,
    required this.tierBronze,
    required this.tierSilver,
    required this.tierGold,
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

  /// Track behind a segmented control.
  final Color segTrack;

  /// Disclosure chevrons in rows.
  final Color chevron;
  final Color danger;
  final Color warning;

  // New in V2.
  final Color ok;
  final Color okSoft;
  final Color warnSoft;
  final Color badSoft;
  final Color textBad;
  final Color textNutrition;
  final Color sleepSoft;
  final Color workoutColor;
  final Color nutritionColor;
  final Color cardioColor;
  final Color sleepColor;
  final Color waterColor;
  final Color xpColor;
  final Color tierBronze;
  final Color tierSilver;
  final Color tierGold;

  // V2 token names.
  Color get surface => card;
  Color get ink => text;
  Color get line => border;
  Color get lineStrong => border2;
  Color get accentSoft => accentTint;
  Color get onAccent => accentText;
  Color get bad => danger;
  Color get warn => warning;
  Color get tierElite => text;
  Color get tierLegend => sleepColor;

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
    segTrack: AppColors.darkSegTrack,
    chevron: AppColors.darkChevron,
    danger: AppColors.dangerDark,
    warning: AppColors.warningDark,
    ok: AppColors.okDark,
    okSoft: AppColors.okSoftDark,
    warnSoft: AppColors.warnSoftDark,
    badSoft: AppColors.badSoftDark,
    textBad: AppColors.textBadDark,
    textNutrition: AppColors.textNutritionDark,
    sleepSoft: AppColors.sleepSoftDark,
    workoutColor: AppColors.workout,
    nutritionColor: AppColors.nutrition,
    cardioColor: AppColors.cardio,
    sleepColor: AppColors.sleep,
    waterColor: AppColors.water,
    xpColor: AppColors.xp,
    tierBronze: AppColors.tierBronzeDark,
    tierSilver: AppColors.tierSilverDark,
    tierGold: AppColors.tierGoldDark,
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
    segTrack: AppColors.lightSegTrack,
    chevron: AppColors.lightChevron,
    danger: AppColors.dangerLight,
    warning: AppColors.warningLight,
    ok: AppColors.okLight,
    okSoft: AppColors.okSoftLight,
    warnSoft: AppColors.warnSoftLight,
    badSoft: AppColors.badSoftLight,
    textBad: AppColors.textBadLight,
    textNutrition: AppColors.textNutritionLight,
    sleepSoft: AppColors.sleepSoftLight,
    workoutColor: AppColors.workoutLight,
    nutritionColor: AppColors.nutritionLight,
    cardioColor: AppColors.cardioLight,
    sleepColor: AppColors.sleepLight,
    waterColor: AppColors.waterLight,
    xpColor: AppColors.xpLight,
    tierBronze: AppColors.tierBronzeLight,
    tierSilver: AppColors.tierSilverLight,
    tierGold: AppColors.tierGoldLight,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
