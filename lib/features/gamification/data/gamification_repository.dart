import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/gamification_stats.dart';

/// Read-only until identity and deployed RLS are verified.
class GamificationRepository {
  const GamificationRepository(this.client);
  final SupabaseClient client;

  Future<GamificationStats?> readOwnStats({
    required String authenticatedUserId,
  }) async {
    if (client.auth.currentUser?.id != authenticatedUserId) {
      throw StateError('Matching authenticated user required');
    }
    final row = await client.from('user_gamification')
        .select('total_xp,level,current_streak,longest_streak,total_workouts,total_prs,total_volume_kg,rank_tier')
        .eq('google_user_id', authenticatedUserId)
        .maybeSingle();
    return row == null ? null : GamificationStats.fromJson(row);
  }
}
