import 'dart:math';

import 'package:fittrack_pro/core/auth/auth_repository.dart';
import 'package:fittrack_pro/core/data/data_gateway.dart';
import 'package:fittrack_pro/core/data/outbox.dart';
import 'package:fittrack_pro/core/data/sync_engine.dart';
import 'package:fittrack_pro/features/cardio/data/cardio_service.dart';
import 'package:fittrack_pro/features/gamification/data/gamification_service.dart';
import 'package:fittrack_pro/features/sleep/data/sleep_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mergeRows', () {
    test('pending upsert replaces a server row and new rows come first', () {
      final merged = mergeRows(
        [
          {'id': 'a', 'name': 'old'},
          {'id': 'b', 'name': 'keep'},
        ],
        [
          {'id': 'a', 'name': 'new'},
          {'id': 'c', 'name': 'added'},
        ],
        const {},
      );
      expect(merged.map((r) => r['id']), ['c', 'a', 'b']);
      expect(merged.firstWhere((r) => r['id'] == 'a')['name'], 'new');
    });

    test('pending deletes hide rows and updates patch existing rows only', () {
      final merged = mergeRows(
        [
          {'id': 'a', 'finished_at': null},
          {'id': 'b'},
        ],
        const [],
        {'b'},
        pendingUpdates: [
          {'id': 'a', 'finished_at': 'now'},
          {'id': 'ghost', 'finished_at': 'now'},
        ],
      );
      expect(merged, [
        {'id': 'a', 'finished_at': 'now'},
      ]);
    });
  });

  group('RetryPolicy', () {
    const policy = RetryPolicy(
      maxAttempts: 3,
      baseDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 10),
    );

    test('grows exponentially and is capped with bounded jitter', () {
      final random = Random(1);
      final first = policy.delayFor(0, random: random).inMilliseconds;
      final third = policy.delayFor(2, random: random).inMilliseconds;
      final huge = policy.delayFor(30, random: random).inMilliseconds;
      expect(first, inInclusiveRange(1000, 1250));
      expect(third, inInclusiveRange(4000, 5000));
      expect(huge, inInclusiveRange(10000, 12500));
    });

    test('exhausts after maxAttempts', () {
      expect(policy.isExhausted(2), isFalse);
      expect(policy.isExhausted(3), isTrue);
    });
  });

  group('classifyFailure', () {
    FailureKind kind(String code) => classifyFailure(
          PostgrestException(message: 'x', code: code),
        );

    test('RLS and constraint violations are permanent', () {
      expect(kind('42501'), FailureKind.permanent);
      expect(kind('23502'), FailureKind.permanent);
      expect(kind('22P02'), FailureKind.permanent);
    });

    test('missing parent row and deadlocks are retryable', () {
      expect(kind('23503'), FailureKind.retryable);
      expect(kind('40P01'), FailureKind.retryable);
    });

    test('expired JWT and unknown errors are transient', () {
      expect(kind('PGRST301'), FailureKind.transient);
      expect(classifyFailure(Exception('socket closed')), FailureKind.transient);
    });
  });

  group('gamification', () {
    final now = DateTime.utc(2026, 11, 12, 10);

    Map<String, dynamic> stats({
      String? last,
      int streak = 0,
      int xp = 0,
      int longest = 0,
    }) =>
        {
          'google_user_id': 'u',
          'total_xp': xp,
          'level': 1,
          'current_streak': streak,
          'longest_streak': longest,
          'total_workouts': 4,
          'total_prs': 1,
          'total_volume_kg': 1000.0,
          'last_workout_date': last,
        };

    test('first workout starts a streak and awards base xp', () {
      final result = computeWorkoutCompletion(
        current: stats(),
        prCount: 0,
        volumeKg: 500,
        allSetsHaveRpe: false,
        now: now,
      );
      expect(result.xpEarned, 50);
      expect(result.row['current_streak'], 1);
      expect(result.row['total_workouts'], 5);
      expect(result.row['last_workout_date'], '2026-11-12');
      expect(result.row['total_volume_kg'], 1500.0);
    });

    test('consecutive day extends the streak and crossing 7 days adds 200', () {
      final result = computeWorkoutCompletion(
        current: stats(last: '2026-11-11', streak: 6, longest: 6),
        prCount: 2,
        volumeKg: 0,
        allSetsHaveRpe: true,
        now: now,
      );
      expect(result.row['current_streak'], 7);
      expect(result.row['longest_streak'], 7);
      expect(result.xpEarned, 50 + 200 + 10 + 200);
    });

    test('a gap resets the streak and same-day keeps it', () {
      final reset = computeWorkoutCompletion(
        current: stats(last: '2026-11-01', streak: 9, longest: 9),
        prCount: 0,
        volumeKg: 0,
        allSetsHaveRpe: false,
        now: now,
      );
      expect(reset.row['current_streak'], 1);
      expect(reset.row['longest_streak'], 9);

      final sameDay = computeWorkoutCompletion(
        current: stats(last: '2026-11-12', streak: 3),
        prCount: 0,
        volumeKg: 0,
        allSetsHaveRpe: false,
        now: now,
      );
      expect(sameDay.row['current_streak'], 3);
    });

    test('rank score and tiers match the React Native formula', () {
      final score = calculateRankScore(
        trainingDays: 31,
        volumeKg: 50000,
        streakLength: 90,
        prCount: 20,
      );
      expect(score, 100);
      expect(rankTierFromScore(score), 'legend');
      expect(rankTierFromScore(64), 'gold');
      expect(rankTierFromScore(65), 'elite');
      expect(rankTierFromScore(24), 'bronze');
      expect(levelFromXp(1249), 3);
    });
  });

  group('xp rules', () {
    test('cardio xp tiers are cumulative', () {
      expect(calculateCardioXp(durationSeconds: 600), 30);
      expect(calculateCardioXp(durationSeconds: 1800), 50);
      expect(calculateCardioXp(durationSeconds: 3600, distanceKm: 10), 180);
    });

    test('sleep xp peaks at 8-9h and rewards quality', () {
      expect(calculateSleepXp(300, 3), 10);
      expect(calculateSleepXp(480, 3), 40);
      expect(calculateSleepXp(540, 5), 50);
      expect(calculateSleepXp(600, 4), 30);
      expect(formatSleepDuration(450), '7h 30m');
    });
  });

  group('AuthRepository.mapAuthError', () {
    test('maps known Supabase messages to friendly copy', () {
      expect(
        AuthRepository.mapAuthError('Invalid login credentials'),
        'Incorrect email or password. Try again.',
      );
      expect(
        AuthRepository.mapAuthError('User already registered'),
        contains('already exists'),
      );
      expect(AuthRepository.mapAuthError('something else'), 'something else');
    });
  });
}
