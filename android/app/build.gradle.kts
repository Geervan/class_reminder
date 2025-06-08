// Import statements must be at the very top of the file.
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(FileInputStream(localPropertiesFile))
    }
    return properties
}

val flutterSdkPath by lazy {
    localProperties().getProperty("flutter.sdk")
}

android {
    namespace = "com.example.time_table_app"
    compileSdk = 34

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.time_table_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    // This section is for build types, like release or debug.
    buildTypes {
        release {
            // This makes the release build sign with the debug key.
            // TODO: Add your own signing config for a real release.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // This line is for Kotlin support.
    implementation(kotlin("stdlib-jdk7"))
    // This line enables the desugaring of modern Java features.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}