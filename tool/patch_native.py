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


NOTIFICATION_RECEIVERS = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""


def patch_android_notifications() -> None:
    """Scheduled reminders need the plugin receivers and core-library desugaring."""
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if manifest.exists():
        s = manifest.read_text()
        if "ScheduledNotificationReceiver" not in s:
            s = s.replace("</application>", NOTIFICATION_RECEIVERS + "    </application>", 1)
            manifest.write_text(s)
    gradle = Path("android/app/build.gradle.kts")
    if not gradle.exists():
        return
    s = gradle.read_text()
    if "isCoreLibraryDesugaringEnabled" not in s and "compileOptions {" in s:
        s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "coreLibraryDesugaring" not in s:
        deps = 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        if "\ndependencies {" in s:
            s = s.replace("\ndependencies {", "\ndependencies {\n    coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:2.1.4\")", 1)
        else:
            s = s.rstrip() + "\n\n" + deps
    gradle.write_text(s)


def patch_android_notification_icon() -> None:
    """Status-bar icon for reminders (white glyph on transparent)."""
    source = Path("assets/icon/notification-icon.png")
    res = Path("android/app/src/main/res")
    if source.exists() and res.exists():
        target = res / "drawable"
        target.mkdir(exist_ok=True)
        (target / "ic_notification.png").write_bytes(source.read_bytes())


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


def patch_gradle_properties() -> None:
    """Some plugins (flutter_timezone) compile Java for 11 but Kotlin for 1.8.

    Newer Kotlin Gradle plugins fail the build on that mismatch; downgrade
    the check to a warning. The generated debug build is unaffected.
    """
    props = Path("android/gradle.properties")
    if not props.exists():
        return
    line = "kotlin.jvm.target.validation.mode=warning"
    text = props.read_text()
    if line not in text:
        props.write_text(text.rstrip("\n") + "\n" + line + "\n")


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
    patch_android_notifications()
    patch_android_notification_icon()
    patch_gradle_properties()
    patch_ios()
    print("Native permissions patched.")
