import 'dart:convert';

class DraftSet {
  const DraftSet(
      {required this.exerciseName, required this.weightKg, required this.reps});
  final String exerciseName;
  final double weightKg;
  final int reps;
  double get volumeKg => weightKg * reps;
  Map<String, dynamic> toJson() => {
        'exercise_name': exerciseName,
        'weight_kg': weightKg,
        'reps': reps,
      };
  factory DraftSet.fromJson(Map<String, dynamic> json) => DraftSet(
        exerciseName: json['exercise_name'] as String,
        weightKg: (json['weight_kg'] as num).toDouble(),
        reps: (json['reps'] as num).toInt(),
      );
}

class WorkoutDraft {
  const WorkoutDraft(
      {required this.name, required this.startedAt, this.sets = const []});
  final String name;
  final DateTime startedAt;
  final List<DraftSet> sets;
  double get totalVolumeKg =>
      sets.fold<double>(0, (sum, set) => sum + set.volumeKg);
  WorkoutDraft addSet(DraftSet set) =>
      WorkoutDraft(name: name, startedAt: startedAt, sets: [...sets, set]);
  WorkoutDraft removeSet(int index) => WorkoutDraft(
        name: name,
        startedAt: startedAt,
        sets: [
          for (var i = 0; i < sets.length; i++)
            if (i != index) sets[i]
        ],
      );
  String encode() => jsonEncode({
        'name': name,
        'started_at': startedAt.toUtc().toIso8601String(),
        'sets': sets.map((set) => set.toJson()).toList(),
      });
  factory WorkoutDraft.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return WorkoutDraft(
      name: json['name'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      sets: (json['sets'] as List<dynamic>)
          .map((row) => DraftSet.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }
}
