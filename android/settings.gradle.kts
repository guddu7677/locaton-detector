// This file configures the root project and defines the plugins for the build.
// A key part of this setup is pointing to the Flutter SDK.
 
pluginManagement {
    // This block of code uses Kotlin syntax to safely read the flutter.sdk path
    // from the local.properties file. It's a common and necessary step for Flutter projects.
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = rootDir.resolve("local.properties")
        if (!localPropertiesFile.exists()) {
            throw GradleException("Could not find local.properties file. Please set flutter.sdk in local.properties.")
        }
        localPropertiesFile.inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        check(path != null) { "flutter.sdk not set in local.properties" }
        path
    }
 
    // Includes the Flutter Gradle build files, which contain all the necessary tasks
    // for building a Flutter application.
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
 
    // The repositories where Gradle looks for plugins.
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
 
// This is the single plugins block that declares all plugins for the root project.
plugins {
    // These plugins are applied to the sub-projects (like the `app` module).
    // The `apply false` keyword ensures they are not applied here.
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
 
    // This plugin is used to load Flutter plugins during the build process.
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}
 
// Includes the main application module.
include(":app")
 
 
