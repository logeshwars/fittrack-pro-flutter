import '../../../core/data/data_gateway.dart';

/// One exercise inside a saved preset (stored as JSON in `workout_presets`).
class PresetExercise {
  const PresetExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.defaultSets,
    this.cdnName,
  });

  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final int defaultSets;
  final String? cdnName;

  factory PresetExercise.fromJson(Map<String, dynamic> json) => PresetExercise(
        exerciseId: json['exerciseId'] as String,
        exerciseName: json['exerciseName'] as String,
        muscleGroup: (json['muscleGroup'] as String?) ?? '',
        defaultSets: (json['defaultSets'] as num?)?.toInt() ?? 3,
        cdnName: json['cdnName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'defaultSets': defaultSets,
        if (cdnName != null) 'cdnName': cdnName,
      };
}

class WorkoutPreset {
  const WorkoutPreset({
    required this.id,
    required this.name,
    required this.exercises,
  });

  final String id;
  final String name;
  final List<PresetExercise> exercises;

  factory WorkoutPreset.fromJson(Map<String, dynamic> json) => WorkoutPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: [
          for (final e in (json['exercises'] as List?) ?? const [])
            PresetExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

/// Port of `src/services/presetService.ts`.
class PresetService {
  PresetService(this._gateway);

  final DataGateway _gateway;

  Future<List<WorkoutPreset>> presets() async {
    final rows = await _gateway.mergedList(
      'workout_presets',
      'workout_presets',
      () async {
        final data = await _gateway.client
            .from('workout_presets')
            .select()
            .eq('google_user_id', _gateway.userId)
            .order('created_at', ascending: false);
        return [for (final row in data) Json.from(row)];
      },
    );
    return [for (final row in rows) WorkoutPreset.fromJson(row)];
  }

  Future<String> create(String name, List<PresetExercise> exercises) async {
    final id = _gateway.newId();
    await _gateway.upsert('workout_presets', {
      'id': id,
      'name': name,
      'exercises': [for (final e in exercises) e.toJson()],
    });
    return id;
  }

  Future<void> update(String id, String name, List<PresetExercise> exercises) {
    return _gateway.update('workout_presets', id, {
      'name': name,
      'exercises': [for (final e in exercises) e.toJson()],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> delete(String id) => _gateway.delete('workout_presets', id);
}
