import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fittrack_pro/features/workouts/data/workout_draft_store.dart';
import 'package:fittrack_pro/features/workouts/domain/workout_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('draft round trip preserves sets and volume', () {
    final draft = WorkoutDraft(name: 'Push', startedAt: DateTime.utc(2026, 1, 1))
        .addSet(const DraftSet(exerciseName: 'Bench', weightKg: 60, reps: 8));
    final decoded = WorkoutDraft.decode(draft.encode());
    expect(decoded.name, 'Push');
    expect(decoded.sets.single.exerciseName, 'Bench');
    expect(decoded.totalVolumeKg, 480);
    expect(decoded.removeSet(0).sets, isEmpty);
  });

  test('draft is stored locally and can be discarded', () async {
    final store = WorkoutDraftStore(await SharedPreferences.getInstance());
    final draft = WorkoutDraft(name: 'Legs', startedAt: DateTime.utc(2026, 1, 1));
    await store.save(draft);
    expect(store.load()?.name, 'Legs');
    await store.clear();
    expect(store.load(), isNull);
  });
}
