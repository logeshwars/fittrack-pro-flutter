#!/usr/bin/env bash
set -euo pipefail

# Generates native platform projects with a development-only identity.
# Requires Flutter SDK and (for iOS compilation) macOS/Xcode.
flutter create --platforms=android,ios --org com.logesh .
rm -f test/widget_test.dart

if [[ -f android/app/build.gradle.kts ]]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("android/app/build.gradle.kts")
s = p.read_text()
s = s.replace('applicationId = "com.logesh.fittrack_pro"', 'applicationId = "com.logesh.fittrackpro.flutterdev"')
s = s.replace('applicationId = "com.logesh.fittrackpro"', 'applicationId = "com.logesh.fittrackpro.flutterdev"')
if 'applicationId = "com.logesh.fittrackpro.flutterdev"' not in s:
    raise SystemExit("Unexpected Android Gradle application ID: inspect manually")
p.write_text(s)
PY
fi

# iOS bundle ID is not modified automatically: inspect and set the
# development bundle ID and signing team in Xcode before installing.
echo "Native projects generated. Review signing and iOS bundle identifiers."
