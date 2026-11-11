# Native project setup

The Flutter repository currently does not commit generated Android/iOS
directories. CI generates native projects to validate dependency compatibility.
Run `bash tool/bootstrap_native.sh` locally after installing Flutter.

## Android
The bootstrap script creates Android/iOS scaffolding and attempts to assign
the development Android application ID `com.logesh.fittrackpro.flutterdev`.
It fails rather than silently continuing if the generated Gradle format differs.
Inspect the Android namespace and MainActivity package before release.

## iOS
Set a unique development bundle ID in Xcode and select your signing team.
Do not reuse the original app's bundle ID or keychain access groups until the
migration and release strategy are confirmed.

## CI
- Ubuntu: Flutter analysis, tests and Android debug APK compilation.
- macOS: Flutter iOS simulator debug compilation (no distribution signing).
- Neither job signs production artifacts or publishes them.

## Release gates
- Confirm both platform CI jobs pass.
- Commit reviewed native project folders and app identity settings.
- Review permissions for camera, health integrations and notifications.
- Set up provisioning profiles, signing and store distribution.
- Verify deployed Supabase RLS and Google identity mapping before writes.
