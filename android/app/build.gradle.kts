import java.io.FileInputStream
import java.util.Properties

// The upload key lives outside the repository: android/key.properties names
// the keystore and carries its passwords, and .gitignore keeps both out of
// git. Without that file a release build falls back to the debug key, which
// keeps `flutter run --release` working on a bench but is refused by Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasUploadKey = keystorePropertiesFile.exists()

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.techpebble.eal_track"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.techpebble.EALtrack"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storePassword = keystoreProperties.getProperty("storePassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let(::file)
        }
    }

    buildTypes {
        debug {
            // Installs beside the real app rather than replacing it, so a
            // test build and the live one can sit on the same phone.
            applicationIdSuffix = ".dev"
        }

        release {
            // Signed with the upload key where there is one. A bundle for
            // Play has to carry it: the console refuses a debug
            // certificate, and the key that signs the first upload is the
            // one every later version has to be signed with.
            signingConfig = signingConfigs.getByName(
                if (hasUploadKey) "upload" else "debug"
            )
        }
    }
}

flutter {
    source = "../.."
}
