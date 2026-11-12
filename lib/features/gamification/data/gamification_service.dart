import '../../../core/data/data_gateway.dart';

int levelFromXp(int xp) => (xp ~/ 500) + 1;

/// Monthly rank score (ported from `rankScoreCalculator.ts`).
int calculateRankScore({
  required int trainingDays,
  required double volumeKg,
  required int streakLength,
  required int prCount,
}) {
  double cap(double v) => v > 100 ? 100 : v;
  final consistency = cap(trainingDays / 31 * 100) * 0.30;
  final volume = cap(volumeKg / 50000 * 100) * 0.35;
  final streak = cap(streakLength / 90 * 100) * 0.20;
  final prs = cap(prCount / 20 * 100) * 0.15;
  // Math.round semantics for non-negative numbers.
  return (consistency + volume + streak + prs + 0.5).floor();
}

String rankTierFromScore(int score) {
  if (score >= 85) return 'legend';
  if (score >= 65) return 'elite';
  if (score >= 45) return 'gold';
  if (score >= 25) return 'silver';
  return 'bronze';
}

String _isoDay(DateTime d) => d.toUtc().toIso8601String().substring(0, 10);

/// Result of finishing a workout.
class WorkoutCompletion {
  const WorkoutCompletion({required this.row, required this.xpEarned});

  /// The full updated `user_gamification` row to write back.
  final Json row;
  final int xpEarned;
}

/// Pure port of `recordWorkoutCompletion` so streak and XP rules are testable.
/// Dates are UTC days, matching the React Native app.
WorkoutCompletion computeWorkoutCompletion({
  required Json current,
  required int prCount,
  required double volumeKg,
  required bool allSetsHaveRpe,
  required DateTime now,
}) {
  final today = _isoDay(now);
  final yesterday = _isoDay(now.subtract(const Duration(days: 1)));
  final lastDate = current['last_workout_date'] as String?;
  final prevStreak = (current['current_streak'] as num?)?.toInt() ?? 0;

  var streak = prevStreak;
  if (lastDate == null || lastDate.compareTo(yesterday) < 0) {
    streak = 1;
  } else if (lastDate == yesterday) {
    streak = prevStreak + 1;
  }
  final longest = [
    streak,
    (current['longest_streak'] as num?)?.toInt() ?? 0,
  ].reduce((a, b) => a > b ? a : b);

  var xp = 50 + prCount * 100;
  if (allSetsHaveRpe) xp += 10;
  if (prevStreak < 7 && streak >= 7) xp += 200;
  if (prevStreak < 30 && streak >= 30) xp += 500;
  if (prevStreak < 90 && streak >= 90) xp += 2000;

  final totalXp = ((current['total_xp'] as num?)?.toInt() ?? 0) + xp;
  return WorkoutCompletion(
    xpEarned: xp,
    row: {
      ...current,
      'total_xp': totalXp,
      'level': levelFromXp(totalXp),
      'current_streak': streak,
      'longest_streak': longest,
      'last_workout_date': today,
      'total_workouts': ((current['total_workouts'] as num?)?.toInt() ?? 0) + 1,
      'total_prs': ((current['total_prs'] as num?)?.toInt() ?? 0) + prCount,
      'total_volume_kg':
          ((current['total_volume_kg'] as num?)?.toDouble() ?? 0) + volumeKg,
      'updated_at': now.toUtc().toIso8601String(),
    },
  );
}

/// Port of `gamificationService.ts` and `leaderboardService.ts`.
class GamificationService {
  GamificationService(this._gateway);

  final DataGateway _gateway;

  Future<Json?> stats() => _gateway.cachedRow('gamification', () async {
        final row = await _gateway.client
            .from('user_gamification')
            .select()
            .eq('google_user_id', _gateway.userId)
            .maybeSingle();
        return row == null ? null : Json.from(row);
      });

  Future<List<Json>> badges() => _gateway.cachedList('badges', () async {
        final rows = await _gateway.client
            .from('user_badges')
            .select()
            .eq('google_user_id', _gateway.userId)
            .order('earned_at', ascending: false);
        return [for (final row in rows) Json.from(row)];
      });

  /// Awards XP for a non-workout action (protein goal, sleep, cardio...).
  Future<void> awardXp(int xp) async {
    final current = await stats();
    if (current == null || xp <= 0) return;
    final total = ((current['total_xp'] as num?)?.toInt() ?? 0) + xp;
    await _gateway.upsert(
      'user_gamification',
      {
        ...current,
        'total_xp': total,
        'level': levelFromXp(total),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'google_user_id',
    );
  }

  /// Applies streak/XP rules for a finished workout and returns the XP earned.
  Future<int> recordWorkoutCompletion({
    required int prCount,
    required double volumeKg,
    required bool allSetsHaveRpe,
  }) async {
    final current = await stats();
    if (current == null) return 0;
    final result = computeWorkoutCompletion(
      current: current,
      prCount: prCount,
      volumeKg: volumeKg,
      allSetsHaveRpe: allSetsHaveRpe,
      now: DateTime.now(),
    );
    await _gateway.upsert(
      'user_gamification',
      result.row,
      onConflict: 'google_user_id',
    );
    return result.xpEarned;
  }

  /// This month's leaderboard ranked by score.
  Future<List<Json>> monthlyLeaderboard({int limit = 20}) async {
    final now = DateTime.now();
    final yearMonth =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final rows = await _gateway.cachedList('leaderboard_$yearMonth', () async {
      final data = await _gateway.client
          .from('leaderboard_monthly')
          .select('*, profiles(display_name, avatar_url)')
          .eq('year_month', yearMonth)
          .order('volume_kg', ascending: false)
          .limit(limit);
      return [for (final row in data) Json.from(row)];
    });
    final scored = [
      for (final row in rows)
        () {
          final score = calculateRankScore(
            trainingDays: (row['training_days'] as num?)?.toInt() ?? 0,
            volumeKg: (row['volume_kg'] as num?)?.toDouble() ?? 0,
            streakLength: (row['streak_length'] as num?)?.toInt() ?? 0,
            prCount: (row['pr_count'] as num?)?.toInt() ?? 0,
          );
          return {
            ...row,
            'rank_score': score,
            'rank_tier': rankTierFromScore(score)
          };
        }(),
    ];
    scored.sort(
      (a, b) => (b['rank_score'] as int).compareTo(a['rank_score'] as int),
    );
    return scored;
  }

  Future<void> upsertMonthlyStats({
    required double volumeKg,
    required int trainingDays,
    required int streakLength,
    required int prCount,
  }) {
    final now = DateTime.now();
    final yearMonth =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final score = calculateRankScore(
      trainingDays: trainingDays,
      volumeKg: volumeKg,
      streakLength: streakLength,
      prCount: prCount,
    );
    return _gateway.upsert(
      'leaderboard_monthly',
      {
        'year_month': yearMonth,
        'volume_kg': volumeKg,
        'training_days': trainingDays,
        'streak_length': streakLength,
        'pr_count': prCount,
        'rank_tier': rankTierFromScore(score),
      },
      onConflict: 'google_user_id,year_month',
    );
  }
}
