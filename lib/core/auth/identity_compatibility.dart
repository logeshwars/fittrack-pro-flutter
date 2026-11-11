/// A conservative identity gate for the existing Supabase schema.
///
/// The legacy column name google_user_id is misleading: email users store a
/// Supabase Auth UUID there, while direct Google sign-in historically stored
/// the Google subject ID. Never infer that these identities are interchangeable.
enum LegacyIdentityKind { supabaseAuthUuid, directGoogleSubject, unknown }

class IdentityCompatibility {
  const IdentityCompatibility._();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static LegacyIdentityKind classify(String? legacyId) {
    if (legacyId == null || legacyId.trim().isEmpty) {
      return LegacyIdentityKind.unknown;
    }
    if (_uuid.hasMatch(legacyId)) return LegacyIdentityKind.supabaseAuthUuid;
    if (RegExp(r'^\d{16,24}$').hasMatch(legacyId)) {
      return LegacyIdentityKind.directGoogleSubject;
    }
    return LegacyIdentityKind.unknown;
  }

  /// Only a matching Supabase Auth UUID may be used as a read scope.
  /// Classification is advisory: RLS must still enforce the authorization.
  static bool canReadAsCurrentUser({
    required String? authenticatedUserId,
    required String? profileGoogleUserId,
  }) {
    if (authenticatedUserId == null || profileGoogleUserId == null) {
      return false;
    }
    return classify(authenticatedUserId) == LegacyIdentityKind.supabaseAuthUuid &&
        authenticatedUserId == profileGoogleUserId;
  }
}
