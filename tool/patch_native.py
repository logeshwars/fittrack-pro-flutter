"""Adds the permissions the feature set needs to the generated native projects.

Run by tool/bootstrap_native.sh after `flutter create`. Idempotent.
"""
from pathlib import Path

ANDROID_PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACTIVITY_RECOGNITION",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.health.READ_STEPS",
]

IOS_KEYS = {
    "NSCameraUsageDescription": "FitTrack uses the camera to scan food barcodes and photograph meals.",
    "NSPhotoLibraryUsageDescription": "FitTrack lets you pick a meal photo to estimate its nutrition.",
    "NSLocationWhenInUseUsageDescription": "FitTrack uses your location to track cardio routes and distance.",
    "NSHealthShareUsageDescription": "FitTrack reads your step count from Apple Health.",
    "NSHealthUpdateUsageDescription": "FitTrack does not write to Apple Health.",
    "NSMotionUsageDescription": "FitTrack uses motion data to count steps.",
}

RATIONALE = (
    "    <intent-filter>\n"
    '        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
    "    </intent-filter>\n"
)
QUERIES = (
    "    <queries>\n"
    '        <package android:name="com.google.android.apps.healthdata" />\n'
    "    </queries>\n"
)


def patch_android() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        return
    s = manifest.read_text()
    lines = "".join(
        f'    <uses-permission android:name="{p}" />\n'
        for p in ANDROID_PERMISSIONS
        if p not in s
    )
    if lines:
        s = s.replace("<application", lines + "    <application", 1)
    if "ACTION_SHOW_PERMISSIONS_RATIONALE" not in s:
        s = s.replace("</activity>", RATIONALE + "        </activity>", 1)
    if "com.google.android.apps.healthdata" not in s:
        s = s.replace("</manifest>", QUERIES + "</manifest>")
    manifest.write_text(s)


def patch_android_build() -> None:
    """Health Connect needs FlutterFragmentActivity and minSdk 26."""
    for activity in Path("android/app/src/main").glob("**/MainActivity.*"):
        text = activity.read_text()
        if "FlutterFragmentActivity" not in text and "FlutterActivity" in text:
            text = text.replace(
                "import io.flutter.embedding.android.FlutterActivity",
                "import io.flutter.embedding.android.FlutterFragmentActivity",
            ).replace(": FlutterActivity()", ": FlutterFragmentActivity()")
            activity.write_text(text)
    for name in ("build.gradle.kts", "build.gradle"):
        gradle = Path("android/app") / name
        if not gradle.exists():
            continue
        text = gradle.read_text()
        for old in ("minSdk = flutter.minSdkVersion", "minSdkVersion flutter.minSdkVersion"):
            if old in text:
                new = "minSdk = 26" if "=" in old else "minSdkVersion 26"
                text = text.replace(old, new)
        gradle.write_text(text)


def patch_ios() -> None:
    plist = Path("ios/Runner/Info.plist")
    if not plist.exists():
        return
    s = plist.read_text()
    add = "".join(
        f"\t<key>{k}</key>\n\t<string>{v}</string>\n"
        for k, v in IOS_KEYS.items()
        if k not in s
    )
    if add:
        s = s.replace("</dict>\n</plist>", add + "</dict>\n</plist>")
        plist.write_text(s)


if __name__ == "__main__":
    patch_android()
    patch_android_build()
    patch_ios()
    print("Native permissions patched.")
