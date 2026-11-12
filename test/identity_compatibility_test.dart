import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack_pro/core/auth/identity_compatibility.dart';

void main() {
  test('classifies historical identity representations', () {
    expect(
        IdentityCompatibility.classify('0b3a1c2d-1111-4222-8333-123456789abc'),
        LegacyIdentityKind.supabaseAuthUuid);
    expect(IdentityCompatibility.classify('123456789012345678901'),
        LegacyIdentityKind.directGoogleSubject);
    expect(IdentityCompatibility.classify('unknown-user'),
        LegacyIdentityKind.unknown);
    expect(IdentityCompatibility.classify(null), LegacyIdentityKind.unknown);
  });
  test('requires exact authenticated UUID match', () {
    const user = '0b3a1c2d-1111-4222-8333-123456789abc';
    expect(
        IdentityCompatibility.canReadAsCurrentUser(
            authenticatedUserId: user, profileGoogleUserId: user),
        isTrue);
    expect(
        IdentityCompatibility.canReadAsCurrentUser(
            authenticatedUserId: user,
            profileGoogleUserId: '123456789012345678901'),
        isFalse);
    expect(
        IdentityCompatibility.canReadAsCurrentUser(
            authenticatedUserId: null, profileGoogleUserId: user),
        isFalse);
  });
}
