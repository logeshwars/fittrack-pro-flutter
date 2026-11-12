import 'package:fittrack_pro/features/gamification/data/badges_data.dart';
import 'package:fittrack_pro/features/gamification/domain/badge_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final workouts10 = badgeDefinitions.firstWhere((b) => b.id == 'workouts_10');
  final streak7 = badgeDefinitions.firstWhere((b) => b.id == 'streak_7');

  test('badgeProgress clamps and reads the right stat', () {
    expect(badgeProgress(workouts10, {'total_workouts': 5}), .5);
    expect(badgeProgress(workouts10, {'total_workouts': 99}), 1);
    expect(badgeProgress(workouts10, {}), 0);
  });

  test('streak badges use the best of current and longest streak', () {
    expect(
        badgeProgress(streak7, {'current_streak': 2, 'longest_streak': 7}), 1);
  });

  test('untracked requirement types never auto-earn', () {
    final early = badgeDefinitions
        .firstWhere((b) => b.requirementType == 'early_morning_workout');
    expect(badgeProgress(early, {'total_workouts': 1000}), 0);
    expect(isBadgeEarned(early, {}, {early.id}), isTrue);
    expect(isBadgeEarned(early, {}, {}), isFalse);
  });

  test('levelProgress mirrors 500 XP levels', () {
    expect(levelProgress(0).toNext, 500);
    expect(levelProgress(1250).toNext, 250);
    expect(levelProgress(1250).fill, .5);
  });

  test('monthlyTotals only counts the current month', () {
    final now = DateTime(2026, 11, 12);
    final t = monthlyTotals([
      (at: DateTime(2026, 11, 2), volumeKg: 1000.4),
      (at: DateTime(2026, 11, 9), volumeKg: 500.4),
      (at: DateTime(2026, 10, 30), volumeKg: 9999),
    ], now);
    expect(t.trainingDays, 2);
    expect(t.volumeKg, 1501);
  });

  test('tier helpers fall back to bronze', () {
    expect(tierLabel('gold'), 'Gold');
    expect(tierLabel(''), 'Bronze');
    expect(tierColor('unknown'), tierColor('bronze'));
  });
}
