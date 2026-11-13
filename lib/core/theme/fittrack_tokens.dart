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
  static const controlLg = 52.0;

  /// Scroll clearance above the bottom tab bar.
  static const tabBarClearance = 110.0;
}

/// Corner radii: radius-sm 8, radius-md 10, radius-lg 12, radius-xl 20,
/// radius-pill 9999. `xxl` is kept as an alias of `xl` for older callers.
abstract final class FitTrackRadius {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 20.0;
  static const xxl = 20.0;
  static const pill = 9999.0;
  static const full = pill;
}

const _tabular = [FontFeature.tabularFigures()];

/// Type scale from `design/tokens.json`. Colors are applied by the caller
/// (`copyWith(color: palette.ink)`). Numbers use tabular figures so counters
/// do not jitter. Heights are line-height / font-size.
abstract final class FitTrackText {
  // Numbers
  static const mega = TextStyle(
    fontSize: 52,
    height: 54 / 52,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );
  static const hero = TextStyle(
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    fontFeatures: _tabular,
  );
  static const statLg = TextStyle(
    fontSize: 30,
    height: 34 / 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    fontFeatures: _tabular,
  );
  static const stat = TextStyle(
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
  );

  // Text
  static const screenTitle = TextStyle(
    fontSize: 21,
    height: 26 / 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  static const titleLg = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );
  static const title = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w800,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Uppercase section labels, 0.16em tracking. Callers upper-case the text.
  static const overline = TextStyle(
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );

  /// Not part of V2 (it has no text under 10px). Kept so older screens
  /// compile; new code should use [overline] or [caption].
  static const micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
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
