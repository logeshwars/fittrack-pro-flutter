import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_models.dart';

class NutritionRepository {
  const NutritionRepository(this._client);
  final SupabaseClient _client;

  Future<List<NutritionLog>> getRecentLogs(
      {required String authenticatedUserId, int limit = 100}) async {
    if (_client.auth.currentUser?.id != authenticatedUserId) {
      throw StateError('A matching authenticated Supabase user is required.');
    }
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    final rows = await _client
        .from('nutrition_logs')
        .select(
            'id,food_name,meal_type,quantity_g,protein_g,calories,carbs_g,fat_g,fiber_g,logged_at')
        .eq('google_user_id', authenticatedUserId)
        .order('logged_at', ascending: false)
        .limit(limit);
    return rows.map((row) => NutritionLog.fromJson(row)).toList();
  }
}
