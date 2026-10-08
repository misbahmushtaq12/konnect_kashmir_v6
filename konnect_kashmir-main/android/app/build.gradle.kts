import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Push notifications (Firebase): only switched on when the project's
// google-services.json has been added, so builds without it keep working.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Load key.properties (android/key.properties). This file is git-ignored, so it
// may not exist on a fresh clone. In that case we skip release signing instead
// of crashing, and debug builds / `flutter run` still work.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun keystoreProp(name: String): String =
    keystoreProperties.getProperty(name)
        ?: error("android/key.properties is missing '$name'")

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

android {
    namespace = "com.mediamosiac.konnect_kashmir"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.mediamosiac.konnect_kashmir"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProp("keyAlias")
                keyPassword = keystoreProp("keyPassword")
                storeFile = file(keystoreProp("storeFile"))
                storePassword = keystoreProp("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties: sign with the debug key so the build works
                // locally. NOT valid for Play Store upload.
                logger.warn("WARNING: android/key.properties not found - release build is signed with the DEBUG key.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}