import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/service_providers.dart';
import '../data/exercise_repository.dart';
import '../data/preset_service.dart';
import '../domain/session_models.dart';
import '../domain/workout_models.dart';

const _prefsKey = 'fittrack_active_session_v1';

/// Outcome of logging a set.
class SetLogResult {
  const SetLogResult({required this.isPersonalRecord});
  final bool isPersonalRecord;
}

/// Owns the in-progress workout. Writes go through [WorkoutService] (queued and
/// idempotent), and the session snapshot is mirrored to SharedPreferences so
/// the app can resume after being killed.
class SessionController extends Notifier<SessionState?> {
  @override
  SessionState? build() => null;

  /// Restores a saved session if none is active. Returns whether one exists.
  Future<bool> restore() async {
    if (state != null) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = SessionState.decode(prefs.getString(_prefsKey));
    if (saved != null) {
      state = saved;
    }
    return saved != null;
  }

  /// Starts a workout. Returns false when no data service is available
  /// (signed out or Supabase not configured).
  Future<bool> start(
    String name, {
    List<PresetExercise> preset = const [],
    List<Exercise> presetExercises = const [],
  }) async {
    final service = ref.read(workoutServiceProvider);
    if (service == null) {
      return false;
    }
    final startedAt = DateTime.now();
    final id = await service.startWorkout(name, startedAt: startedAt);
    final byId = {for (final e in presetExercises) e.id: e};
    state = SessionState(
      workoutId: id,
      name: name,
      startedAt: startedAt,
      exercises: [
        for (final p in preset)
          SessionExercise(
            exerciseId: p.exerciseId,
            name: p.exerciseName,
            muscleGroup: p.muscleGroup,
            logType: byId[p.exerciseId]?.logType ?? 'weight_reps',
          ),
      ],
    );
    await _persist();
    return true;
  }

  Future<void> addExercise(Exercise exercise) async {
    final current = state;
    if (current == null) {
      return;
    }
    final existing =
        current.exercises.indexWhere((e) => e.exerciseId == exercise.id);
    if (existing >= 0) {
      state = current.copyWith(currentIndex: existing);
    } else {
      final next = [
        ...current.exercises,
        SessionExercise(
          exerciseId: exercise.id,
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          logType: exercise.logType,
        ),
      ];
      state = current.copyWith(
        exercises: next,
        currentIndex: next.length - 1,
      );
    }
    await _persist();
  }

  void select(int index) {
    final current = state;
    if (current == null || index < 0 || index >= current.exercises.length) {
      return;
    }
    state = current.copyWith(currentIndex: index);
  }

  /// Logs a set for the current exercise.
  Future<SetLogResult?> logSet({
    double? weightKg,
    int? reps,
    double? rpe,
    int? durationSeconds,
  }) async {
    final current = state;
    final service = ref.read(workoutServiceProvider);
    final exercise = current?.current;
    if (current == null || service == null || exercise == null) {
      return null;
    }

    final logged = await service.logSet(
      workoutId: current.workoutId,
      exerciseId: exercise.exerciseId,
      setNumber: exercise.nextSetNumber,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      durationSeconds: durationSeconds,
    );

    // The session may have changed while the write was queued.
    final latest = state;
    if (latest == null) {
      return SetLogResult(isPersonalRecord: logged.isPersonalRecord);
    }
    final index =
        latest.currentIndex.clamp(0, latest.exercises.length - 1).toInt();
    final updated = [...latest.exercises];
    updated[index] = updated[index].copyWith(
      sets: [
        ...updated[index].sets,
        SessionSet(
          id: logged.id,
          setNumber: exercise.nextSetNumber,
          weightKg: weightKg,
          reps: reps,
          rpe: rpe,
          durationSeconds: durationSeconds,
          isPersonalRecord: logged.isPersonalRecord,
        ),
      ],
    );
    state = latest.copyWith(exercises: updated);
    await _persist();
    return SetLogResult(isPersonalRecord: logged.isPersonalRecord);
  }

  Future<void> removeSet(String setId) async {
    final current = state;
    final service = ref.read(workoutServiceProvider);
    if (current == null || service == null) {
      return;
    }
    await service.deleteSet(setId);
    state = current.copyWith(
      exercises: [
        for (final e in current.exercises)
          e.copyWith(sets: [for (final s in e.sets) if (s.id != setId) s]),
      ],
    );
    await _persist();
  }

  /// Finishes the workout, awards XP and clears the session. A workout with no
  /// sets is discarded instead and returns null.
  Future<SessionSummary?> finish() async {
    final current = state;
    final service = ref.read(workoutServiceProvider);
    if (current == null || service == null) {
      return null;
    }
    if (current.totalSets == 0) {
      await discard();
      return null;
    }
    final finishedAt = DateTime.now();
    await service.finishWorkout(current.workoutId, finishedAt: finishedAt);
    final xp = await ref
            .read(gamificationServiceProvider)
            ?.recordWorkoutCompletion(
              prCount: current.prCount,
              volumeKg: current.volumeKg,
              allSetsHaveRpe: current.allSetsHaveRpe,
            ) ??
        0;
    final summary = SessionSummary(
      duration: finishedAt.difference(current.startedAt),
      totalSets: current.totalSets,
      volumeKg: current.volumeKg,
      prCount: current.prCount,
      xpEarned: xp,
    );
    await _clear();
    return summary;
  }

  /// Deletes the workout and every set logged in it.
  Future<void> discard() async {
    final current = state;
    final service = ref.read(workoutServiceProvider);
    if (current != null && service != null) {
      await service.deleteWorkout(current.workoutId);
    }
    await _clear();
  }

  Future<void> _persist() async {
    final current = state;
    if (current == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, current.encode());
  }

  Future<void> _clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState?>(SessionController.new);

/// Earlier sets of an exercise for the overload hint (newest first).
final previousSetsProvider =
    FutureProvider.autoDispose.family<List<WorkoutSet>, String>((ref, id) async {
  final service = ref.watch(workoutServiceProvider);
  if (service == null) {
    return const [];
  }
  try {
    return await service.previousSets(id);
  } catch (_) {
    return const [];
  }
});
