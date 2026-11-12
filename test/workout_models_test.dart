import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/features/workouts/domain/workout_models.dart';

void main() {
  test('nullable legacy workout names have a safe label', () {
    final workout = Workout.fromJson(
        {'id': 'w', 'name': null, 'started_at': '2026-01-01T00:00:00Z'});
    expect(workout.name, 'Workout');
    expect(workout.sets, isEmpty);
  });
}
