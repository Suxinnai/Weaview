plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("WEAVIEW_KEYSTORE_PATH")
val releaseKeystorePassword = System.getenv("WEAVIEW_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("WEAVIEW_KEY_ALIAS")
val releaseKeyPassword = System.getenv("WEAVIEW_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseKeystorePath,
    releaseKeystorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val requestsReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (requestsReleaseBuild && !hasReleaseSigning) {
    throw org.gradle.api.GradleException(
        "Release signing is not configured. Set WEAVIEW_KEYSTORE_PATH, " +
            "WEAVIEW_KEYSTORE_PASSWORD, WEAVIEW_KEY_ALIAS, and WEAVIEW_KEY_PASSWORD."
    )
}

android {
    namespace = "com.weaview.weaview_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.weaview.weaview_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
