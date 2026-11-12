import '../../../core/data/data_gateway.dart';
import '../domain/workout_metrics.dart';
import '../domain/workout_models.dart';
import 'exercise_repository.dart';

/// A set that was just logged, with its personal-record flag.
class LoggedSet {
  const LoggedSet({required this.id, required this.isPersonalRecord});
  final String id;
  final bool isPersonalRecord;
}

/// Port of `src/services/workoutService.ts`.
///
/// Reads work offline from the on-device cache plus pending local writes.
/// Writes are queued in the outbox and delivered idempotently.
class WorkoutService {
  WorkoutService(this._gateway);

  final DataGateway _gateway;

  static const _select = '*, workout_sets(*, exercises(name, muscle_group))';
  static const _exerciseColumns =
      'id, name, muscle_group, equipment, primary_muscles, secondary_muscles, '
      'log_type, is_bilateral, is_custom, level, mechanic, force, category, '
      'cdn_name';

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Finished workouts, newest first.
  Future<List<Workout>> history({int limit = 20}) async {
    final rows = await _gateway.mergedList(
      'workouts',
      'workouts_history_$limit',
      () async {
        final data = await _gateway.client
            .from('workouts')
            .select(_select)
            .eq('google_user_id', _gateway.userId)
            .not('finished_at', 'is', null)
            .order('started_at', ascending: false)
            .limit(limit);
        return [for (final row in data) Json.from(row)];
      },
      keep: (row) => row['finished_at'] != null,
    );
    return _withPendingSets(rows);
  }

  /// One page of finished workouts (infinite scroll).
  Future<List<Workout>> historyPage({
    required int offset,
    int pageSize = 20,
  }) async {
    if (offset < 0 || pageSize < 1) throw ArgumentError('Invalid pagination');
    final rows = await _gateway.cachedList(
      'workouts_page_${offset}_$pageSize',
      () async {
        final data = await _gateway.client
            .from('workouts')
            .select(_select)
            .eq('google_user_id', _gateway.userId)
            .not('finished_at', 'is', null)
            .order('started_at', ascending: false)
            .range(offset, offset + pageSize - 1);
        return [for (final row in data) Json.from(row)];
      },
    );
    return _withPendingSets(rows);
  }

  /// Finished workouts that started on the local calendar day of [date].
  Future<List<Workout>> forDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _gateway.cachedList(
      'workouts_day_${start.toIso8601String()}',
      () async {
        final data = await _gateway.client
            .from('workouts')
            .select(_select)
            .eq('google_user_id', _gateway.userId)
            .not('finished_at', 'is', null)
            .gte('started_at', start.toUtc().toIso8601String())
            .lt('started_at', end.toUtc().toIso8601String())
            .order('started_at', ascending: false);
        return [for (final row in data) Json.from(row)];
      },
    );
    return _withPendingSets(rows);
  }

  /// A single workout with its sets, or null when it does not exist.
  Future<Workout?> byId(String id) async {
    final row = await _gateway.cachedRow('workout_$id', () async {
      final data = await _gateway.client
          .from('workouts')
          .select(_select)
          .eq('id', id)
          .eq('google_user_id', _gateway.userId)
          .maybeSingle();
      return data == null ? null : Json.from(data);
    });
    if (row == null) return null;
    final workouts = await _withPendingSets([row]);
    return workouts.isEmpty ? null : workouts.first;
  }

  /// Global (non-custom) exercises, optionally filtered.
  Future<List<Exercise>> exercises({
    String? muscleGroup,
    String? equipment,
  }) async {
    final rows = await _gateway.cachedList(
      'exercises_${muscleGroup ?? 'all'}_${equipment ?? 'all'}',
      () async {
        var query = _gateway.client
            .from('exercises')
            .select(_exerciseColumns)
            .isFilter('google_user_id', null);
        if (muscleGroup != null && muscleGroup.isNotEmpty) {
          query = query.eq('muscle_group', muscleGroup);
        }
        if (equipment != null && equipment.isNotEmpty) {
          query = query.eq('equipment', equipment);
        }
        final data = await query.order('name').limit(2000);
        return [for (final row in data) Json.from(row)];
      },
    );
    return [for (final row in rows) Exercise.fromJson(row)];
  }

  /// Earlier sets of [exerciseId], newest first, for progressive overload.
  Future<List<WorkoutSet>> previousSets(
    String exerciseId, {
    int limit = 30,
  }) async {
    final rows = await _gateway.cachedList('prev_sets_$exerciseId', () async {
      final data = await _gateway.client
          .from('workout_sets')
          .select('id, exercise_id, set_number, weight_kg, reps, rpe, is_pr, '
              'workout_id, logged_at')
          .eq('exercise_id', exerciseId)
          .eq('google_user_id', _gateway.userId)
          .order('logged_at', ascending: false)
          .limit(limit);
      return [for (final row in data) Json.from(row)];
    });
    return [for (final row in rows) WorkoutSet.fromJson(row)];
  }

  // ── Writes (queued) ──────────────────────────────────────────────────────

  /// Starts a workout and returns its id (usable immediately, even offline).
  Future<String> startWorkout(
    String name, {
    DateTime? startedAt,
    String? id,
  }) async {
    final workoutId = id ?? _gateway.newId();
    await _gateway.upsert('workouts', {
      'id': workoutId,
      'name': name,
      'started_at': (startedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
    return workoutId;
  }

  Future<void> finishWorkout(String workoutId, {DateTime? finishedAt}) {
    return _gateway.update('workouts', workoutId, {
      'finished_at': (finishedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  Future<void> renameWorkout(String workoutId, String name) =>
      _gateway.update('workouts', workoutId, {'name': name});

  Future<void> deleteWorkout(String workoutId) =>
      _gateway.delete('workouts', workoutId);

  /// Logs a set. The PR flag needs the network; offline sets are never PRs
  /// (same documented limitation as the React Native app).
  Future<LoggedSet> logSet({
    required String workoutId,
    required String exerciseId,
    required int setNumber,
    double? weightKg,
    int? reps,
    double? rpe,
    int? durationSeconds,
    String? id,
  }) async {
    final setId = id ?? _gateway.newId();
    final isPr = await _checkIsPr(exerciseId, weightKg, reps);
    await _gateway.upsert('workout_sets', {
      'id': setId,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'weight_kg': weightKg,
      'reps': reps,
      'rpe': rpe,
      'duration_seconds': durationSeconds,
      'is_pr': isPr,
    });
    return LoggedSet(id: setId, isPersonalRecord: isPr);
  }

  Future<void> deleteSet(String setId) =>
      _gateway.delete('workout_sets', setId);

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<bool> _checkIsPr(String exerciseId, double? weightKg, int? reps) async {
    if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0) {
      return false;
    }
    try {
      final data = await _gateway.client
          .from('workout_sets')
          .select('weight_kg, reps')
          .eq('exercise_id', exerciseId)
          .eq('google_user_id', _gateway.userId)
          .order('weight_kg', ascending: false)
          .limit(1);
      final previous = [
        for (final row in data)
          WorkoutSet(
            id: '',
            exerciseId: exerciseId,
            setNumber: 0,
            weightKg: (row['weight_kg'] as num?)?.toDouble(),
            reps: (row['reps'] as num?)?.toInt(),
          ),
      ];
      return isPersonalRecord(
        weightKg: weightKg,
        reps: reps,
        previousSets: previous,
      );
    } catch (_) {
      return false;
    }
  }

  Future<List<Workout>> _withPendingSets(List<Json> rows) async {
    final pending =
        await _gateway.outbox.pendingUpserts(_gateway.userId, 'workout_sets');
    final deleted =
        await _gateway.outbox.pendingDeleteIds(_gateway.userId, 'workout_sets');
    return [
      for (final row in rows) Workout.fromJson(_attach(row, pending, deleted)),
    ];
  }

  Json _attach(Json workout, List<Json> pending, Set<String> deleted) {
    final id = workout['id'];
    final server = <Json>[
      for (final set in (workout['workout_sets'] as List?) ?? const [])
        Json.from(set as Map),
    ];
    final extra = pending.where((s) => s['workout_id'] == id).toList();
    if (extra.isEmpty && deleted.isEmpty) return workout;
    return {
      ...workout,
      'workout_sets': mergeRows(server, extra, deleted),
    };
  }
}
