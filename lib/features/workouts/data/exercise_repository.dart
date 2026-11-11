import 'package:supabase_flutter/supabase_flutter.dart';

class Exercise {
  const Exercise({required this.id, required this.name, required this.muscleGroup, required this.equipment});
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    muscleGroup: json['muscle_group'] as String,
    equipment: json['equipment'] as String,
  );
}

class ExerciseRepository {
  const ExerciseRepository(this._client);
  final SupabaseClient _client;
  Future<List<Exercise>> getGlobalExercises({String? muscleGroup}) async {
    var query = _client.from('exercises').select('id,name,muscle_group,equipment').isFilter('google_user_id', null);
    if (muscleGroup != null && muscleGroup.isNotEmpty) query = query.eq('muscle_group', muscleGroup);
    final rows = await query.order('name').limit(500);
    return rows.map((row) => Exercise.fromJson(row)).toList();
  }
}
