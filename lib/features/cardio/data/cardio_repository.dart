import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/cardio_session.dart';

class CardioRepository {
  const CardioRepository(this._client);
  final SupabaseClient _client;
  Future<List<CardioSession>> recent(
      {required String authenticatedUserId}) async {
    if (_client.auth.currentUser?.id != authenticatedUserId) {
      throw StateError('Authentication required');
    }
    final rows = await _client
        .from('cardio_sessions')
        .select()
        .eq('google_user_id', authenticatedUserId)
        .order('started_at', ascending: false)
        .limit(50);
    return rows.map((row) => CardioSession.fromJson(row)).toList();
  }
}
