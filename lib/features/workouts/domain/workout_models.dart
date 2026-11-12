class WorkoutSet {
  const WorkoutSet(
      {required this.id,
      required this.exerciseId,
      required this.setNumber,
      this.weightKg,
      this.reps,
      this.rpe,
      this.isPersonalRecord = false,
      this.durationSeconds,
      this.exerciseName,
      this.muscleGroup});
  final String id;
  final String exerciseId;
  final int setNumber;
  final int? durationSeconds;
  final String? exerciseName;
  final String? muscleGroup;
  final double? weightKg;
  final int? reps;
  final double? rpe;
  final bool isPersonalRecord;
  double get volumeKg => (weightKg ?? 0) * (reps ?? 0);
  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        id: json['id'] as String,
        exerciseId: json['exercise_id'] as String,
        setNumber: (json['set_number'] as num).toInt(),
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        reps: (json['reps'] as num?)?.toInt(),
        rpe: (json['rpe'] as num?)?.toDouble(),
        isPersonalRecord: json['is_pr'] == true,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
        exerciseName: (json['exercises'] as Map?)?['name'] as String?,
        muscleGroup: (json['exercises'] as Map?)?['muscle_group'] as String?,
      );
}

class Workout {
  const Workout(
      {required this.id,
      required this.name,
      required this.startedAt,
      this.finishedAt,
      this.sets = const []});
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<WorkoutSet> sets;
  bool get isFinished => finishedAt != null;
  double get totalVolumeKg => sets.fold(0, (sum, set) => sum + set.volumeKg);
  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String,
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : 'Workout',
        startedAt: DateTime.parse(json['started_at'] as String),
        finishedAt: json['finished_at'] == null
            ? null
            : DateTime.parse(json['finished_at'] as String),
        sets: ((json['workout_sets'] as List<dynamic>?) ?? [])
            .map((row) => WorkoutSet.fromJson(row as Map<String, dynamic>))
            .toList(),
      );
}
