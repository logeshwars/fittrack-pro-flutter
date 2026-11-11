import 'package:supabase_flutter/supabase_flutter.dart';

/// Email authentication is supported by Supabase Auth. Google account
/// compatibility requires a separate identity/RLS audit before enabling OAuth.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  /// Only reads the profile matching the authenticated Supabase UUID.
  /// The historical Google-ID mapping must be verified before writes.
  Future<Map<String, dynamic>?> readOwnProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final provider = user.appMetadata['provider']?.toString();
    final identityColumn =
        provider == 'email' ? 'email_user_id' : 'google_user_id';
    final data = await _client
        .from('profiles')
        .select()
        .eq(identityColumn, user.id)
        .maybeSingle();
    return data;
  }
}
