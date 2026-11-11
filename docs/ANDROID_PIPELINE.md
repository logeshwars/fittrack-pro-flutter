# Android build pipeline

Workflow: `.github/workflows/android-build.yml`

## Download a development APK
1. Open GitHub > Actions > **Android APK build**.
2. Choose **Run workflow**, select `feature/flutter-foundation`, and run.
3. Wait for the **Analyze, test and build APK** job to succeed.
4. Open the run, scroll to **Artifacts**, and download
   `fittrack-pro-flutter-debug-apk-<run number>`.
5. Extract the ZIP to obtain `app-debug.apk`. Transfer to an Android
   device and install only if you trust the source. Android may require
   permission to install from the chosen file manager.

The workflow also runs automatically on relevant pushes and pull requests.
The debug APK uses development-only application ID
`com.logesh.fittrackpro.flutterdev` from `tool/bootstrap_native.sh`,
so it does not overwrite the original app.

## Important restrictions
- This is a **debug** APK, not a production Play Store release.
- Supabase credentials are deliberately blank. The app opens in a
  backend-unconfigured mode; authenticated features require a separate
  secure environment configuration.
- Artifacts expire after 14 days.
- Flutter currently generates native Android files in CI rather than
  storing a reviewed native project in Git.
- Production AAB builds are intentionally not enabled: commit and review
  native Android configuration, finalize the production application ID,
  create an upload keystore offline, configure Gradle release signing,
  and add keystore + passwords as GitHub Actions secrets first.
- Do not put keystores, service-role keys, or signing passwords in Git.
- GitHub Actions secrets are not automatically available to forked PRs.
- Before release, verify Supabase identity/RLS, offline data handling,
  subscriptions, platform permissions, and end-to-end device tests.

## Future signed release pipeline
Use a manual `workflow_dispatch` release workflow protected by a GitHub
Environment with required reviewers. Restore a base64-encoded upload
keystore from an Actions secret to a temporary file, inject signing
properties from secrets, build `flutter build appbundle --release`,
upload the AAB as a restricted artifact, and remove temporary key files.
Only enable this after native release signing is audited.
