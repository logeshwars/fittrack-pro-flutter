allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// fittrack: skip Lint's release-only gate
// `assembleRelease` runs a `lintVital*` task per module, and on some plugin
// modules (google_sign_in_android) Lint crashes inside its own Javadoc
// parser with `NoSuchMethodError: JavaDocParser.parseDataItem`. That is a
// bug in the Lint/AGP pair the Flutter template pins, not in code we own,
// and Lint is not a release gate for this app -- `flutter analyze` is. Skip
// the tasks so a release APK can be built.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}
