pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
}
}

plugins {
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "7.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.7.10" apply false
}
include ":app"
second in android/build.gradle :- make it simple without any dependancies like this

allprojects {
repositories {
    google()
    mavenCentral()
    }
 }
third add these plugins in app build.gradle

plugins {
id "com.android.application"
id "kotlin-android"
// The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
id "dev.flutter.flutter-gradle-plugin"
}