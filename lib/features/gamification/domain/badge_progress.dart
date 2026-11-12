import 'package:flutter/material.dart';
import 'badge_definition.dart';

/// Rank tier colours (port of the RN `TIER` palette).
Color tierColor(String tier) => switch (tier) {
      'silver' => const Color(0xFF9CA3AF),
      'gold' => const Color(0xFFF59E0B),
      'elite' => const Color(0xFFFFFFFF),
      'legend' => const Color(0xFFA855F7),
      _ => const Color(0xFFCD7F32),
    };

/// Display label for a rank tier.
String tierLabel(String tier) =>
    tier.isEmpty ? 'Bronze' : tier[0].toUpperCase() + tier.substring(1);

/// Current value of the stat a badge counts, or null when the stat is not
/// tracked in the `user_gamification` row (such badges rely on the server /
/// `user_badges` table).
double? badgeStatValue(BadgeDefinition badge, Map<String, dynamic> stats) {
  double n(String key) => (stats[key] as num?)?.toDouble() ?? 0;
  return switch (badge.requirementType) {
    'streak_days' => n('longest_streak') > n('current_streak')
        ? n('longest_streak')
        : n('current_streak'),
    'total_workouts' => n('total_workouts'),
    'total_volume_kg' => n('total_volume_kg'),
    'total_prs' => n('total_prs'),
    'level' => n('level'),
    _ => null,
  };
}

/// 0..1 progress towards [badge]; 0 when it cannot be derived locally.
double badgeProgress(BadgeDefinition badge, Map<String, dynamic> stats) {
  final value = badgeStatValue(badge, stats);
  if (value == null || badge.requirementValue <= 0) {
    return 0;
  }
  final p = value / badge.requirementValue;
  return p < 0 ? 0 : (p > 1 ? 1 : p);
}

/// A badge is earned when recorded in `user_badges` or provably met by stats.
bool isBadgeEarned(
  BadgeDefinition badge,
  Map<String, dynamic> stats,
  Set<String> earnedIds,
) =>
    earnedIds.contains(badge.id) || badgeProgress(badge, stats) >= 1;

/// XP still needed for the next level and fill (0..1) of the current one.
({int toNext, double fill}) levelProgress(int totalXp) {
  final into = totalXp % 500;
  return (toNext: 500 - into, fill: into / 500);
}

/// Start-of-month filter for monthly leaderboard stats.
({double volumeKg, int trainingDays}) monthlyTotals(
  Iterable<({DateTime at, double volumeKg})> workouts,
  DateTime now,
) {
  var volume = 0.0;
  var days = 0;
  for (final w in workouts) {
    final l = w.at.toLocal();
    if (l.year == now.year && l.month == now.month) {
      volume += w.volumeKg;
      days += 1;
    }
  }
  return (volumeKg: volume.roundToDouble(), trainingDays: days);
}
