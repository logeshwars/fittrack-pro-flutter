import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/workouts/data/exercise_repository.dart';
import 'package:fittrack_pro/features/workouts/data/workout_splits_data.dart';
import 'package:fittrack_pro/features/workouts/domain/split_models.dart';
import 'package:fittrack_pro/features/workouts/presentation/workout_template_screens.dart';

Exercise _ex(String id, String name, String group) => Exercise(
      id: id,
      name: name,
      muscleGroup: group,
      equipment: 'barbell',
    );

void main() {
  test('splits data is ported completely', () {
    expect(globalSplits.map((s) => s.id),
        ['ppl', 'upper_lower', 'full_body', 'bro_split']);
    expect(globalSplits.map((s) => s.days.length), [3, 4, 3, 5]);
    for (final split in globalSplits) {
      for (final day in split.days) {
        expect(day.exercises, isNotEmpty);
      }
    }
  });

  test('formatRest', () {
    expect(formatRest(45), '45s');
    expect(formatRest(180), '3 min');
    expect(formatRest(90), '1:30');
  });

  test('splitById accepts hyphen ids and falls back', () {
    expect(splitById('upper-lower').id, 'upper_lower');
    expect(splitById('nope').id, 'ppl');
  });

  test('resolveExercises matches by name and flags missing', () {
    final day = globalSplits.first.days.first;
    final first = day.exercises.first;
    final resolved = resolveExercises(
      day.exercises,
      [_ex('a', first.name, 'chest')],
    );
    expect(resolved.first.exerciseId, 'a');
    expect(resolved[1].exerciseId, isNull);
    expect(toPresetExercises(resolved).length, 1);
  });

  test('swapOptions lists suggested alternatives first, same group only', () {
    final planned = globalSplits.first.days.first.exercises.first;
    final target = ResolvedExercise(
      predefined: planned,
      exerciseId: 'a',
      name: planned.name,
      muscleGroup: planned.muscleGroup,
    );
    final all = [
      _ex('1', 'Zzz Press', planned.muscleGroup),
      _ex('2', planned.alternatives.first, planned.muscleGroup),
      _ex('3', 'Squat', 'legs'),
      _ex('4', planned.name, planned.muscleGroup),
    ];
    final options = swapOptions(target, all, '');
    expect(options.map((e) => e.id), ['2', '1']);
    expect(swapOptions(target, all, 'zzz').map((e) => e.id), ['1']);
  });
}
