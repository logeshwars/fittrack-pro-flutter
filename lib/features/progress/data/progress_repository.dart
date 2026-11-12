import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/progress_models.dart';

class ProgressRepository {
  const ProgressRepository(this._client);
  final SupabaseClient _client;

  Future<({List<WeightLog> weights, List<SleepLog> sleep})> recent({required String authenticatedUserId}) async {
    if (_client.auth.currentUser?.id != authenticatedUserId) {
      throw StateError('Authentication required');
    }
    final weights = await _client.from('weight_logs').select('id,weight_kg,logged_at,note')
      .eq('google_user_id', authenticatedUserId).order('logged_at', ascending: false).limit(30);
    final sleep = await _client.from('sleep_logs').select('id,bedtime,wake_time,duration_minutes,quality')
      .eq('google_user_id', authenticatedUserId).order('wake_time', ascending: false).limit(30);
    return (
      weights: weights.map((row) => WeightLog.fromJson(row)).toList(),
      sleep: sleep.map((row) => SleepLog.fromJson(row)).toList(),
    );
  }
}
