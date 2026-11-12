import 'package:fittrack_pro/features/workouts/domain/session_models.dart';
import 'package:fittrack_pro/features/workouts/domain/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSet _set(double? weight, int? reps) => WorkoutSet(
      id: 'x',
      exerciseId: 'e',
      setNumber: 1,
      weightKg: weight,
      reps: reps,
    );

void main() {
  group('suggestOverload', () {
    test('returns null without history', () {
      expect(suggestOverload(const []), isNull);
    });

    test('adds 2.5 kg when the last three sets all reached the last reps', () {
      final hint = suggestOverload([
        _set(60, 8),
        _set(60, 8),
        _set(57.5, 10),
      ]);
      expect(hint!.lastWeightKg, 60);
      expect(hint.lastReps, 8);
      expect(hint.suggestedWeightKg, 62.5);
    });

    test('repeats the weight when an earlier set missed the reps', () {
      final hint = suggestOverload([
        _set(60, 8),
        _set(60, 6),
        _set(60, 8),
      ]);
      expect(hint!.suggestedWeightKg, 60);
    });

    test('does not suggest an increase from a bodyweight (zero) set', () {
      final hint = suggestOverload([_set(0, 12), _set(0, 12)]);
      expect(hint!.suggestedWeightKg, 0);
    });
  });

  group('SessionState', () {
    final state = SessionState(
      workoutId: 'w1',
      name: 'Push day',
      startedAt: DateTime.utc(2026, 11, 12, 6),
      currentIndex: 1,
      exercises: const [
        SessionExercise(
          exerciseId: 'bench',
          name: 'Bench press',
          muscleGroup: 'chest',
          sets: [
            SessionSet(id: 's1', setNumber: 1, weightKg: 80, reps: 5, rpe: 8),
            SessionSet(
              id: 's2',
              setNumber: 2,
              weightKg: 82.5,
              reps: 5,
              rpe: 9,
              isPersonalRecord: true,
            ),
          ],
        ),
        SessionExercise(
          exerciseId: 'plank',
          name: 'Plank',
          muscleGroup: 'core',
          logType: 'duration',
          sets: [SessionSet(id: 's3', setNumber: 1, durationSeconds: 60)],
        ),
      ],
    );

    test('derives totals', () {
      expect(state.totalSets, 3);
      expect(state.volumeKg, 80 * 5 + 82.5 * 5);
      expect(state.prCount, 1);
      expect(state.allSetsHaveRpe, isFalse);
      expect(state.current!.name, 'Plank');
      expect(state.current!.nextSetNumber, 2);
    });

    test('round-trips through JSON', () {
      final restored = SessionState.decode(state.encode())!;
      expect(restored.workoutId, 'w1');
      expect(restored.currentIndex, 1);
      expect(restored.exercises.length, 2);
      expect(restored.exercises.first.sets.last.isPersonalRecord, isTrue);
      expect(restored.exercises.last.logType, 'duration');
      expect(restored.startedAt, state.startedAt);
    });

    test('decode tolerates garbage', () {
      expect(SessionState.decode(null), isNull);
      expect(SessionState.decode('not json'), isNull);
      expect(SessionState.decode('{"workoutId": 3}'), isNull);
    });
  });
}
