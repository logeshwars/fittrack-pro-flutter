import 'dart:convert';

import 'workout_models.dart';

/// Next-set suggestion shown while logging (port of `useProgressiveOverload`).
class OverloadSuggestion {
  const OverloadSuggestion({
    required this.lastWeightKg,
    required this.lastReps,
    required this.suggestedWeightKg,
  });

  final double? lastWeightKg;
  final int? lastReps;
  final double? suggestedWeightKg;
}

/// [previousNewestFirst] are earlier sets of one exercise, newest first.
/// If the three most recent sets all reached the last set's reps, suggest
/// adding 2.5 kg; otherwise repeat the last weight.
OverloadSuggestion? suggestOverload(List<WorkoutSet> previousNewestFirst) {
  if (previousNewestFirst.isEmpty) {
    return null;
  }
  final last = previousNewestFirst.first;
  final baseReps = last.reps ?? 0;
  final hitAll = previousNewestFirst
      .take(3)
      .every((s) => s.reps != null && s.reps! >= baseReps);
  var suggested = last.weightKg;
  if (hitAll && last.weightKg != null && last.weightKg! > 0) {
    suggested = last.weightKg! + 2.5;
  }
  return OverloadSuggestion(
    lastWeightKg: last.weightKg,
    lastReps: last.reps,
    suggestedWeightKg: suggested,
  );
}

class SessionSet {
  const SessionSet({
    required this.id,
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.rpe,
    this.durationSeconds,
    this.isPersonalRecord = false,
  });

  final String id;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final double? rpe;
  final int? durationSeconds;
  final bool isPersonalRecord;

  double get volumeKg => (weightKg ?? 0) * (reps ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'setNumber': setNumber,
        'weightKg': weightKg,
        'reps': reps,
        'rpe': rpe,
        'durationSeconds': durationSeconds,
        'isPr': isPersonalRecord,
      };

  factory SessionSet.fromJson(Map<String, dynamic> json) => SessionSet(
        id: json['id'] as String,
        setNumber: (json['setNumber'] as num).toInt(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        reps: (json['reps'] as num?)?.toInt(),
        rpe: (json['rpe'] as num?)?.toDouble(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        isPersonalRecord: json['isPr'] == true,
      );
}

class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.logType = 'weight_reps',
    this.sets = const [],
  });

  final String exerciseId;
  final String name;
  final String muscleGroup;

  /// `weight_reps`, `reps_only` or `duration`.
  final String logType;
  final List<SessionSet> sets;

  int get nextSetNumber => sets.isEmpty ? 1 : sets.last.setNumber + 1;

  SessionExercise copyWith({List<SessionSet>? sets}) => SessionExercise(
        exerciseId: exerciseId,
        name: name,
        muscleGroup: muscleGroup,
        logType: logType,
        sets: sets ?? this.sets,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'muscleGroup': muscleGroup,
        'logType': logType,
        'sets': [for (final s in sets) s.toJson()],
      };

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exerciseId'] as String,
        name: json['name'] as String,
        muscleGroup: (json['muscleGroup'] as String?) ?? '',
        logType: (json['logType'] as String?) ?? 'weight_reps',
        sets: [
          for (final s in (json['sets'] as List?) ?? const [])
            SessionSet.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

/// An in-progress workout. Immutable; the controller replaces it on change.
class SessionState {
  const SessionState({
    required this.workoutId,
    required this.name,
    required this.startedAt,
    this.exercises = const [],
    this.currentIndex = 0,
  });

  final String workoutId;
  final String name;
  final DateTime startedAt;
  final List<SessionExercise> exercises;
  final int currentIndex;

  Iterable<SessionSet> get allSets => exercises.expand((e) => e.sets);
  int get totalSets => allSets.length;
  double get volumeKg => allSets.fold(0, (sum, s) => sum + s.volumeKg);
  int get prCount => allSets.where((s) => s.isPersonalRecord).length;

  /// True when at least one set exists and every set has an RPE.
  bool get allSetsHaveRpe =>
      totalSets > 0 && allSets.every((s) => s.rpe != null);

  SessionExercise? get current => exercises.isEmpty
      ? null
      : exercises[currentIndex.clamp(0, exercises.length - 1).toInt()];

  SessionState copyWith({
    List<SessionExercise>? exercises,
    int? currentIndex,
    String? name,
  }) =>
      SessionState(
        workoutId: workoutId,
        name: name ?? this.name,
        startedAt: startedAt,
        exercises: exercises ?? this.exercises,
        currentIndex: currentIndex ?? this.currentIndex,
      );

  String encode() => jsonEncode({
        'workoutId': workoutId,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'currentIndex': currentIndex,
        'exercises': [for (final e in exercises) e.toJson()],
      });

  static SessionState? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return SessionState(
        workoutId: json['workoutId'] as String,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
        exercises: [
          for (final e in (json['exercises'] as List?) ?? const [])
            SessionExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// Shown after finishing a workout.
class SessionSummary {
  const SessionSummary({
    required this.duration,
    required this.totalSets,
    required this.volumeKg,
    required this.prCount,
    required this.xpEarned,
  });

  final Duration duration;
  final int totalSets;
  final double volumeKg;
  final int prCount;
  final int xpEarned;
}
