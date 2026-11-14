import 'package:flutter/widgets.dart';

/// The one icon set for FitTrack Pro: Phosphor (MIT), bundled as three
/// fonts in `assets/fonts` — regular, bold and fill.
///
/// Screens use these names, never `Icons.*` or a letter in a box, so the
/// whole app can change set or weight here. Add an icon here before using
/// it: take the code point from phosphoricons.com and give it the family of
/// the weight you want. Directional glyphs carry `matchTextDirection` so
/// they mirror in Arabic.
abstract final class FitIcons {
  // Navigation and actions
  static const IconData back = IconData(
    0xe138,
    fontFamily: 'PhosphorBold',
    matchTextDirection: true,
  );
  static const IconData forward = IconData(
    0xe06c,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData chevronRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorBold',
    matchTextDirection: true,
  );
  static const IconData chevronLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorBold',
    matchTextDirection: true,
  );
  static const IconData chevronDown = IconData(
    0xe136,
    fontFamily: 'PhosphorBold',
  );
  static const IconData chevronUp = IconData(
    0xe13c,
    fontFamily: 'PhosphorBold',
  );
  static const IconData close = IconData(
    0xe4f6,
    fontFamily: 'PhosphorBold',
  );
  static const IconData add = IconData(
    0xe3d4,
    fontFamily: 'PhosphorBold',
  );
  static const IconData remove = IconData(
    0xe32a,
    fontFamily: 'PhosphorBold',
  );
  static const IconData check = IconData(
    0xe182,
    fontFamily: 'PhosphorBold',
  );
  static const IconData checkCircle = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData delete = IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData edit = IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData more = IconData(
    0xe208,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData search = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData refresh = IconData(
    0xe036,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData swap = IconData(
    0xe83c,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData play = IconData(
    0xe3d0,
    fontFamily: 'PhosphorFill',
    matchTextDirection: true,
  );
  static const IconData pause = IconData(
    0xe39e,
    fontFamily: 'PhosphorFill',
  );
  static const IconData save = IconData(
    0xe0ea,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData star = IconData(
    0xe46a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData starFilled = IconData(
    0xe46a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData dot = IconData(
    0xe18a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData signIn = IconData(
    0xe428,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData signOut = IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData google = IconData(
    0xe292,
    fontFamily: 'PhosphorBold',
  );

  // Status
  static const IconData info = IconData(
    0xe2ce,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData warning = IconData(
    0xe4e0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData error = IconData(
    0xe4e2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData lock = IconData(
    0xe2fa,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData secure = IconData(
    0xe40c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData eye = IconData(
    0xe220,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData eyeOff = IconData(
    0xe224,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData placeholder = IconData(
    0xe5d4,
    fontFamily: 'PhosphorRegular',
  );

  // Tabs
  static const IconData today = IconData(
    0xe464,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData workout = IconData(
    0xe0b6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData nutrition = IconData(
    0xe262,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cardio = IconData(
    0xe000,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData progress = IconData(
    0xe150,
    fontFamily: 'PhosphorRegular',
  );

  // Cardio activities
  static const IconData run = IconData(
    0xe730,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cycle = IconData(
    0xe734,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData walk = IconData(
    0xe73a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData swim = IconData(
    0xe736,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData hiit = IconData(
    0xe2de,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData otherActivity = IconData(
    0xe2ac,
    fontFamily: 'PhosphorRegular',
  );

  // Domains and data
  static const IconData sleep = IconData(
    0xe330,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sleepStars = IconData(
    0xe58e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData water = IconData(
    0xe210,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData weight = IconData(
    0xe628,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData steps = IconData(
    0xea88,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData xp = IconData(
    0xe2de,
    fontFamily: 'PhosphorFill',
  );
  static const IconData streak = IconData(
    0xe242,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData streakFilled = IconData(
    0xe242,
    fontFamily: 'PhosphorFill',
  );
  static const IconData streakBold = IconData(
    0xe242,
    fontFamily: 'PhosphorBold',
  );
  static const IconData calories = IconData(
    0xe242,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData trophy = IconData(
    0xe67e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData medal = IconData(
    0xe320,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData leaderboard = IconData(
    0xed62,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData goal = IconData(
    0xe47c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData flag = IconData(
    0xe244,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData health = IconData(
    0xe2ac,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData timer = IconData(
    0xe492,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData clock = IconData(
    0xe19a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData calendar = IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData trendUp = IconData(
    0xe4ae,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData trendDown = IconData(
    0xe4ac,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  static const IconData route = IconData(
    0xe39c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData pin = IconData(
    0xe316,
    fontFamily: 'PhosphorRegular',
  );

  // Nutrition
  static const IconData breakfast = IconData(
    0xe1c2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData lunch = IconData(
    0xeaa4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData dinner = IconData(
    0xe262,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData snack = IconData(
    0xe6ca,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData supplement = IconData(
    0xe700,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData barcode = IconData(
    0xe0b8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData camera = IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData gallery = IconData(
    0xe836,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData manualEntry = IconData(
    0xe34c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData flashOn = IconData(
    0xe2de,
    fontFamily: 'PhosphorFill',
  );
  static const IconData flashOff = IconData(
    0xe2e0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData protein = IconData(
    0xe812,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData carbs = IconData(
    0xec68,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData fat = IconData(
    0xe566,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData fiber = IconData(
    0xe2da,
    fontFamily: 'PhosphorRegular',
  );

  // Settings and profile
  static const IconData settings = IconData(
    0xe270,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData user = IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData bell = IconData(
    0xe0ce,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData palette = IconData(
    0xe6c8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData language = IconData(
    0xe4a2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData units = IconData(
    0xe6b8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData subscription = IconData(
    0xe614,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData document = IconData(
    0xe23a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData help = IconData(
    0xe3e8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sun = IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sunrise = IconData(
    0xe5b6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData system = IconData(
    0xe1e0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sparkle = IconData(
    0xe6a2,
    fontFamily: 'PhosphorRegular',
  );
}
