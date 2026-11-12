import 'package:shared_preferences/shared_preferences.dart';
import '../domain/workout_draft.dart';

/// Device-only draft storage. Never syncs or modifies production records.
class WorkoutDraftStore {
  const WorkoutDraftStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'fittrack_workout_draft_v1';

  WorkoutDraft? load() {
    final value = preferences.getString(key);
    return value == null ? null : WorkoutDraft.decode(value);
  }

  Future<void> save(WorkoutDraft draft) async {
    if (!await preferences.setString(key, draft.encode())) {
      throw StateError('Unable to save workout draft');
    }
  }

  Future<void> clear() async {
    if (!await preferences.remove(key)) {
      throw StateError('Unable to clear workout draft');
    }
  }
}
