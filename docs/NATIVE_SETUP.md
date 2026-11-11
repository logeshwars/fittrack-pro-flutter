# Native project setup

The Flutter repository does not yet commit generated Android/iOS folders.
The GitHub Actions workflow now generates both and compiles a debug Android
APK to catch platform-specific dependency problems early.

## Reproduce locally
1. Install the stable Flutter SDK and run `flutter doctor`.
2. Run `flutter create --platforms=android,ios --org com.logesh .`.
3. Run `flutter pub get && flutter analyze && flutter test`.
4. Run `flutter build apk --debug` for an Android smoke build.
5. On macOS with Xcode, run `flutter build ios --no-codesign`.

## Release identity
- React Native production application ID: `com.logesh.fittrackpro`.
- Never use this production identifier for an experimental Flutter install
  until signing, data migration and release rollout have been verified.
- Use a distinct development application ID (e.g. `com.logesh.fittrackpro.flutterdev`)
  when preparing committed native folders.
- iOS bundle IDs, capabilities, entitlement groups and signing must be
  reviewed before distribution.

## Production safety
The debug build does not require Supabase credentials; it displays
configuration guidance instead. Never embed service-role credentials or
production signing secrets in the repository.

## Current limitations
The CI debug APK is not uploaded as a downloadable artifact. iOS native
compilation requires a macOS runner and is not yet part of CI.
