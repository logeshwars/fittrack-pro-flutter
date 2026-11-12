import 'package:supabase_flutter/supabase_flutter.dart';
import 'identity_compatibility.dart';

enum ProfileAccessStatus {
  signedOut,
  compatible,
  noMatchingProfile,
  legacyIdentityRequiresMigration
}

class ProfileAccessResult {
  const ProfileAccessResult({required this.status, this.profile});
  final ProfileAccessStatus status;
  final Map<String, dynamic>? profile;
}

/// Read-only account compatibility check. Does not enumerate other profiles,
/// join accounts by email, update IDs, or bypass RLS.
class ProfileAccess {
  const ProfileAccess(this._client);
  final SupabaseClient _client;

  Future<ProfileAccessResult> inspect() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const ProfileAccessResult(status: ProfileAccessStatus.signedOut);
    }
    final profile = await _client
        .from('profiles')
        .select('google_user_id,auth_provider,email_user_id,display_name')
        .eq('google_user_id', user.id)
        .maybeSingle();
    if (profile == null) {
      return const ProfileAccessResult(
          status: ProfileAccessStatus.noMatchingProfile);
    }
    final id = profile['google_user_id'] as String?;
    if (!IdentityCompatibility.canReadAsCurrentUser(
      authenticatedUserId: user.id,
      profileGoogleUserId: id,
    )) {
      return const ProfileAccessResult(
          status: ProfileAccessStatus.legacyIdentityRequiresMigration);
    }
    return ProfileAccessResult(
        status: ProfileAccessStatus.compatible, profile: profile);
  }
}
