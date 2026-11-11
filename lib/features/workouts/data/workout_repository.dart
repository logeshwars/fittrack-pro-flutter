import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/workout_models.dart';

/// Read-only until the identity compatibility and RLS audit is completed.
class WorkoutRepository {
  WorkoutRepository(this._client);
  final SupabaseClient _client;

  Future<List<Workout>> getHistory({
    required String authenticatedUserId,
    int offset = 0,
    int pageSize = 20,
  }) async {
    final sessionId = _client.auth.currentUser?.id;
    if (sessionId == null || sessionId != authenticatedUserId) {
      throw StateError('A matching authenticated Supabase user is required.');
    }
    if (offset < 0 || pageSize < 1) throw ArgumentError('Invalid pagination');
    final rows = await _client
        .from('workouts')
        .select('*, workout_sets(*)')
        .eq('google_user_id', authenticatedUserId)
        .not('finished_at', 'is', null)
        .order('started_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    return rows.map((row) => Workout.fromJson(row)).toList();
  }
}
