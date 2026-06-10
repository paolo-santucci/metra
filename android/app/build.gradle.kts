import java.util.Properties

plugins {
    id("com.android.application")
    // Kotlin Android plugin (declared in settings.gradle.kts, version 2.2.20).
    // Required because android.builtInKotlin=false — without this, MainActivity.kt
    // is never compiled and the app crashes at startup with
    // ClassNotFoundException: com.paolosantucci.metraapp.MainActivity.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.paolosantucci.metraapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.paolosantucci.metraapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Android version is pinned here, independent of pubspec.yaml.
        // iOS version is tracked in pubspec.yaml (and set via --build-name in ios.yml CI).
        // Bump versionCode by +1 for every Play Store submission (must be strictly increasing).
        versionCode = 11
        versionName = "1.0.0"
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug") // fallback for CI without key.properties
            }
            // R8 is enabled by the Flutter Gradle plugin for release builds.
            // Declared explicitly here so the config is readable and custom
            // proguard-rules.pro is applied (required for Gson TypeToken
            // compatibility with flutter_local_notifications).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// KGP 2.x: kotlinOptions inside android {} is a hard error; use compilerOptions instead.
afterEvaluate {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}
