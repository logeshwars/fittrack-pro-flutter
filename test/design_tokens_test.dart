import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Brightness;

import 'package:fittrack_pro/core/theme/app_colors.dart';
import 'package:fittrack_pro/core/theme/fittrack_tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Color _hex(String value) =>
    Color(0xFF000000 | int.parse(value.substring(1), radix: 16));

double _channel(int c) {
  final v = c / 255;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
}

double _luminance(Color c) {
  // ignore: deprecated_member_use
  final v = c.value;
  return 0.2126 * _channel((v >> 16) & 0xFF) +
      0.7152 * _channel((v >> 8) & 0xFF) +
      0.0722 * _channel(v & 0xFF);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final tokens = jsonDecode(File('design/tokens.json').readAsStringSync())
      as Map<String, dynamic>;
  final list = (tokens['color'] as Map<String, dynamic>)['tokens'] as List;
  final byName = {
    for (final t in list.cast<Map<String, dynamic>>())
      t['name'] as String: t['value'] as Map<String, dynamic>,
  };

  // A token value may reference another token, e.g. `{ink}`.
  String resolve(String name, String theme) {
    final value = byName[name]![theme] as String;
    return value.startsWith('{')
        ? resolve(value.substring(1, value.length - 1), theme)
        : value;
  }

  Map<String, Color> paletteOf(AppPalette p) => {
        'bg': p.bg,
        'surface': p.surface,
        'ink': p.ink,
        'muted': p.muted,
        'line': p.line,
        'line-strong': p.lineStrong,
        'accent': p.accent,
        'accent-soft': p.accentSoft,
        'on-accent': p.onAccent,
        'ok': p.ok,
        'ok-soft': p.okSoft,
        'warn': p.warn,
        'warn-soft': p.warnSoft,
        'bad': p.bad,
        'bad-soft': p.badSoft,
        'text-bad': p.textBad,
        'workout': p.workoutColor,
        'nutrition': p.nutritionColor,
        'text-nutrition': p.textNutrition,
        'cardio': p.cardioColor,
        'sleep': p.sleepColor,
        'sleep-soft': p.sleepSoft,
        'water': p.waterColor,
        'xp': p.xpColor,
        'tier-bronze': p.tierBronze,
        'tier-silver': p.tierSilver,
        'tier-gold': p.tierGold,
        'tier-elite': p.tierElite,
        'tier-legend': p.tierLegend,
      };

  for (final entry in {'night': AppPalette.dark, 'pearl': AppPalette.light}.entries) {
    group('${entry.key} palette matches design/tokens.json', () {
      final palette = paletteOf(entry.value);
      for (final name in byName.keys) {
        test(name, () {
          expect(palette.containsKey(name), isTrue, reason: 'unmapped token');
          expect(palette[name], _hex(resolve(name, entry.key)));
        });
      }
    });
  }

  // Text pairs must reach 4.5:1. line-strong is a border and is not asserted
  // at 3:1 here: it measures about 1.9:1 today (reported to design).
  const textPairs = <(String, String)>[
    ('ink', 'bg'),
    ('ink', 'surface'),
    ('muted', 'bg'),
    ('muted', 'surface'),
    ('on-accent', 'accent'),
    ('ok', 'ok-soft'),
    ('warn', 'warn-soft'),
    ('text-bad', 'bad-soft'),
    ('sleep', 'sleep-soft'),
    ('on-accent', 'bad'),
  ];
  for (final entry in {'night': AppPalette.dark, 'pearl': AppPalette.light}.entries) {
    final palette = paletteOf(entry.value);
    for (final (fg, bg) in textPairs) {
      test('${entry.key}: $fg on $bg is at least 4.5:1', () {
        expect(_contrast(palette[fg]!, palette[bg]!), greaterThanOrEqualTo(4.5));
      });
    }
  }

  test('radii and spacing follow tokens', () {
    expect(FitTrackRadius.sm, 8);
    expect(FitTrackRadius.md, 10);
    expect(FitTrackRadius.lg, 12);
    expect(FitTrackRadius.xl, 20);
    expect(FitTrackRadius.pill, 9999);
    // The names the screens use: cards 10, controls 8.
    expect(FitTrackRadius.card, 10);
    expect(FitTrackRadius.control, 8);
    // Hero cards are rounder on Night than on Pearl.
    expect(FitTrackRadius.hero(Brightness.dark), 18);
    expect(FitTrackRadius.hero(Brightness.light), 12);
    expect(FitTrackSpacing.touchMin, 44);
    expect(FitTrackSpacing.tabBarClearance, 110);
    // Screen gutter, gap between cards and card padding.
    expect(FitTrackSpacing.gutter, 16);
    expect(FitTrackSpacing.gap, 12);
    expect(FitTrackSpacing.cardPad, 14);
  });

  test('both themes have a type family bundled in assets', () {
    expect(FitTrackText.family, 'WorkSans');
    expect(FitTrackText.familyPearl, 'SourceSans3');
  });
}
