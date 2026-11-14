import 'package:flutter/material.dart';

/// Spacing and control sizes from `design/tokens.json` (space-1 … space-6,
/// touch-min, control-md, control-lg). All gaps are multiples of 4.
abstract final class FitTrackSpacing {
  static const xs = 4.0; // space-1
  static const sm = 8.0; // space-2
  static const md = 12.0; // space-3
  static const lg = 16.0; // space-4: screen edge and card padding
  static const xl = 20.0; // space-5: gap between sections
  static const xxl = 24.0; // space-6: page header horizontal padding

  static const section = 16.0;
  static const row = 12.0;
  static const card = 20.0;

  /// Minimum tap target. Icon buttons are 44 x 44.
  static const touchMin = 44.0;

  /// Control heights: 36 small (inside a 44 tap area), 44 default, 52 primary
  /// full-width call to action.
  static const controlSm = 36.0;
  static const controlMd = 44.0;
  static const controlLg = 48.0;

  /// Screen gutter and gap between cards on the screen boards.
  static const gutter = 16.0;
  static const gap = 12.0;

  /// Card and row inner padding on the screen boards.
  static const cardPad = 14.0;

  /// Scroll clearance above the bottom tab bar.
  static const tabBarClearance = 110.0;
}

/// Corner radii: radius-sm 8, radius-md 10, radius-lg 12, radius-xl 20,
/// radius-pill 9999. `xxl` is kept as an alias of `xl` for older callers.
abstract final class FitTrackRadius {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;

  /// Cards, tiles, list cards, segmented tracks and search fields.
  static const card = 10.0;

  /// Buttons, inputs and the selected segment.
  static const control = 8.0;

  /// Card radius on the hero screens (Today and Nutrition): 18 in Night,
  /// 12 in Pearl.
  static double hero(Brightness brightness) =>
      brightness == Brightness.dark ? 18 : 12;
  static const xl = 20.0;
  static const xxl = 20.0;
  static const pill = 9999.0;
  static const full = pill;
}

const _tabular = [FontFeature.tabularFigures()];

/// Type scale, taken from the screen boards (Night and Pearl share it).
/// Colors are applied by the caller (`copyWith(color: palette.ink)`).
/// Numbers use tabular figures so counters do not jitter. Heights are
/// line-height / font-size.
///
/// The boards use 600 for titles and values and 500 for supporting text.
/// The Today and Nutrition hero areas are heavier (800); those two screens
/// set the weight themselves.
abstract final class FitTrackText {
  /// Night uses Work Sans, Pearl uses Source Sans 3. Both are bundled in
  /// `assets/fonts`.
  static const family = 'WorkSans';
  static const familyPearl = 'SourceSans3';

  // Numbers
  static const mega = TextStyle(
    fontSize: 52,
    height: 54 / 52,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.5,
    fontFeatures: _tabular,
  );
  static const hero = TextStyle(
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    fontFeatures: _tabular,
  );
  static const statLg = TextStyle(
    fontSize: 30,
    height: 34 / 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    fontFeatures: _tabular,
  );

  /// KPI value in stat tiles and strips: 20 / 600.
  static const stat = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
  );

  // Text
  /// Tab screen title: 20 / 600.
  static const screenTitle = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Pushed screen title and sheet title: 18 / 600.
  static const titleLg = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.18,
  );

  /// Card title: 15 / 600.
  static const title = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
  );

  /// Row and section title: 14 / 600.
  static const rowTitle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  /// Body text: 14 / 500.
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// Links, chips and header subtitles: 13 / 600.
  static const label = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  /// Supporting text under titles and values: 12 / 500.
  static const caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// An emoji standing in for an icon, such as a badge glyph.
  static const emoji = TextStyle(fontSize: 18, height: 1);

  /// Small tags such as PR: 11 / 700.
  static const overline = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  /// Kept so older screens compile; new code should use [overline].
  static const micro = overline;

  // Hero screens (Today and Nutrition): heavier and tighter.
  /// Greeting on Today: 22 / 800.
  static const greeting = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.66,
  );

  /// Page title on Nutrition: 26 / 800.
  static const display = TextStyle(
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.78,
  );

  /// Section title on hero screens: 16 / 800.
  static const section = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w800,
  );

  /// Card title on hero screens: 15 / 800.
  static const titleHeavy = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w800,
  );

  /// Summary value on Today: 21 / 800.
  static const heroStat = TextStyle(
    fontSize: 21,
    height: 26 / 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.63,
    fontFeatures: _tabular,
  );

  /// Tile value on Today: 22 / 800.
  static const tileStat = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.44,
    fontFeatures: _tabular,
  );

  /// Rest timer readout: 24 / 600.
  static const timer = TextStyle(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.48,
    fontFeatures: _tabular,
  );

  /// Ring centre on Today (Pearl): 26 / 800.
  static const ringStat = TextStyle(
    fontSize: 26,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.78,
    fontFeatures: _tabular,
  );

  /// Macro value on Nutrition: 30 / 800.
  static const macroStat = TextStyle(
    fontSize: 30,
    height: 34 / 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    fontFeatures: _tabular,
  );
}

/// Camera chrome (scanner screens). The viewfinder is dark in Night and
/// Pearl alike, so these do not follow the theme palette.
abstract final class FitTrackCamera {
  /// Screen background around the viewfinder.
  static Color bg(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF0E1113)
      : const Color(0xFF151515);

  /// Viewfinder panel and segmented-control track.
  static const panel = Color(0xFF262C37);

  /// Primary text, icons and the scan frame.
  static const ink = Color(0xFFFFFFFF);

  /// Hints and secondary text on the dark chrome.
  static const muted = Color(0xFFB8BFCB);
}
