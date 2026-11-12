import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/workouts/domain/workout_metrics.dart';
import 'package:fittrack_pro/features/workouts/domain/workout_models.dart';

void main() {
  group('workout metrics parity', () {
    test('set volume uses kilograms times reps', () {
      const set = WorkoutSet(
          id: 'a', exerciseId: 'b', setNumber: 1, weightKg: 60, reps: 8);
      expect(set.volumeKg, 480);
    });

    test('first valid set is a PR', () {
      expect(
          isPersonalRecord(weightKg: 50, reps: 10, previousSets: []), isTrue);
    });

    test('PR matches prior highest-weight-set comparison', () {
      const previous = [
        WorkoutSet(
            id: '1', exerciseId: 'e', setNumber: 1, weightKg: 100, reps: 2),
        WorkoutSet(
            id: '2', exerciseId: 'e', setNumber: 2, weightKg: 80, reps: 10),
      ];
      expect(isPersonalRecord(weightKg: 90, reps: 3, previousSets: previous),
          isTrue);
      expect(isPersonalRecord(weightKg: 90, reps: 2, previousSets: previous),
          isFalse);
    });

    test('protein goal follows React Native fallback calculation', () {
      expect(calculateProteinGoal(bodyweightKg: 80, goal: 'bulk'), 175);
      expect(calculateProteinGoal(bodyweightKg: 80, goal: 'cut'), 160);
      expect(calculateProteinGoal(bodyweightKg: 80, goal: 'maintain'), 145);
    });

    test('workout deserializes nested Supabase sets', () {
      final workout = Workout.fromJson({
        'id': 'w1',
        'name': 'Push',
        'started_at': '2026-11-11T08:00:00Z',
        'finished_at': '2026-11-11T09:00:00Z',
        'workout_sets': [
          {
            'id': 's1',
            'exercise_id': 'e1',
            'set_number': 1,
            'weight_kg': 50,
            'reps': 10
          }
        ],
      });
      expect(workout.isFinished, isTrue);
      expect(workout.totalVolumeKg, 500);
    });
  });
}
