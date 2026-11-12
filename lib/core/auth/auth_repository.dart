import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Result of an email sign-up.
class SignUpOutcome {
  const SignUpOutcome({required this.requiresVerification});

  /// True when Supabase sent a confirmation email and no session exists yet.
  final bool requiresVerification;
}

/// Result of a Google sign-in attempt.
enum GoogleSignInStatus { signedIn, cancelled }

class GoogleSignInOutcome {
  const GoogleSignInOutcome({
    required this.status,
    this.isNewUser = false,
    this.legacyClaim,
  });

  final GoogleSignInStatus status;

  /// True when the user has no profile row yet and should go to onboarding.
  final bool isNewUser;

  /// Result of the legacy-identity claim: `migrated`, `noop`, `conflict`,
  /// `no_legacy_profile`, or null when no claim was attempted.
  final String? legacyClaim;
}

/// A friendly error that is safe to show in the UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All identities are Supabase Auth identities.
///
/// Every row in the database is keyed by `auth.uid()::text` stored in the
/// legacy-named `google_user_id` column. Google users sign in to Supabase with
/// their Google ID token, so Row Level Security works identically for email
/// and Google accounts. Users who signed in with Google in the React Native app
/// (keyed by their Google subject ID) are re-keyed once by the server-side
/// `claim_legacy_google_profile` function (migration 026).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  GoogleSignIn? _google;

  GoogleSignIn get _googleSignIn => _google ??= GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleWebClientId.isEmpty
            ? null
            : AppConfig.googleWebClientId,
      );

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  // ── Email ────────────────────────────────────────────────────────────────

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(mapAuthError(e.message));
    }
  }

  Future<SignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
      final user = response.user;
      if (user != null && response.session != null) {
        await ensureProfile(displayName: name.trim(), email: email.trim());
      }
      return SignUpOutcome(requiresVerification: response.session == null);
    } on AuthException catch (e) {
      throw AuthFailure(mapAuthError(e.message));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'fittrack://reset-password',
      );
    } on AuthException catch (e) {
      throw AuthFailure(mapAuthError(e.message));
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────

  /// Signs in with Google and exchanges the ID token for a Supabase session.
  ///
  /// Order matters: the legacy-identity claim runs BEFORE [ensureProfile] so a
  /// returning React Native user keeps their history instead of getting a
  /// blank profile.
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    final GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } catch (e) {
      throw AuthFailure('Google sign-in failed: $e');
    }
    if (account == null) {
      return const GoogleSignInOutcome(status: GoogleSignInStatus.cancelled);
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthFailure('Incomplete data from Google. Try again.');
    }

    try {
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
    } on AuthException catch (e) {
      await _googleSignIn.signOut();
      throw AuthFailure(mapAuthError(e.message));
    }

    final claim = await _claimLegacyProfile(account.id);
    final existing = await readOwnProfile();
    if (existing == null) {
      await ensureProfile(
        displayName: account.displayName ?? account.email,
        email: account.email,
        avatarUrl: account.photoUrl,
      );
    }
    return GoogleSignInOutcome(
      status: GoogleSignInStatus.signedIn,
      isNewUser: existing == null,
      legacyClaim: claim,
    );
  }

  /// Asks the server to re-key the caller's React Native-era rows. The server
  /// verifies that the caller's Google identity owns [legacyGoogleId]; the
  /// client never decides ownership. Failure must never block sign-in.
  Future<String?> _claimLegacyProfile(String legacyGoogleId) async {
    try {
      final result = await _client.rpc(
        'claim_legacy_google_profile',
        params: {'p_legacy_id': legacyGoogleId},
      );
      if (result is Map && result['status'] is String) {
        return result['status'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  /// Reads the signed-in user's profile. RLS limits this to the caller's row.
  Future<Map<String, dynamic>?> readOwnProfile() async {
    final id = currentUserId;
    if (id == null) return null;
    return _client
        .from('profiles')
        .select()
        .eq('google_user_id', id)
        .maybeSingle();
  }

  /// Creates the profile and gamification rows if they do not exist. Never
  /// overwrites an existing profile.
  Future<void> ensureProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final provider = user.appMetadata['provider']?.toString() ?? 'email';
    await _client.from('profiles').upsert(
      {
        'google_user_id': user.id,
        'display_name': displayName ?? user.email,
        'email': email ?? user.email,
        'avatar_url': avatarUrl,
        'auth_provider': provider == 'google' ? 'google' : 'email',
        if (provider != 'google') 'email_user_id': user.id,
      },
      onConflict: 'google_user_id',
      ignoreDuplicates: true,
    );
    await _client.from('user_gamification').upsert(
      {'google_user_id': user.id},
      onConflict: 'google_user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not signed in with Google, or the plugin is unavailable.
    }
    await _client.auth.signOut();
  }

  /// Maps raw Supabase messages to user-facing copy (ported from the React
  /// Native `mapAuthError`).
  static String mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Try again.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please verify your email first. Check your inbox.';
    }
    if (message.contains('User already registered')) {
      return 'An account with this email already exists. Log in instead.';
    }
    if (message.contains('at least 6 characters') ||
        message.contains('Password should')) {
      return 'Password must be at least 6 characters.';
    }
    if (message.contains('Unable to validate email') ||
        message.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('network') || message.contains('fetch')) {
      return 'No internet connection. Check your connection and try again.';
    }
    return message;
  }
}
