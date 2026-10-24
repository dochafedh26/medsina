import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.medsina.medsina"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.medsina.medsina"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    val storeFilePath = keystoreProperties.getProperty("storeFile") ?: "upload-keystore.jks"
    val resolvedKeystore = when {
        file(storeFilePath).exists() -> file(storeFilePath)
        file("upload-keystore.jks").exists() -> file("upload-keystore.jks")
        rootProject.file(storeFilePath).exists() -> rootProject.file(storeFilePath)
        rootProject.file("app/upload-keystore.jks").exists() -> rootProject.file("app/upload-keystore.jks")
        else -> null
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: "upload"
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: "medsina2027"
            storeFile = resolvedKeystore ?: file("upload-keystore.jks")
            storePassword = keystoreProperties.getProperty("storePassword") ?: "medsina2027"
        }
    }

    buildTypes {
        release {
            if (resolvedKeystore != null && resolvedKeystore.exists()) {
                println(">>> [GRADLE] Using official release keystore: " + resolvedKeystore.absolutePath)
                signingConfig = signingConfigs.getByName("release")
            } else {
                println(">>> [GRADLE WARNING] Release keystore not found! Falling back to debug signing.")
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
