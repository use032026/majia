import java.io.File
import java.nio.file.Files
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localAcceptance = providers.gradleProperty("isdfxLocalAcceptance").orNull == "true"
val signingPropertiesFile = rootProject.file("key.properties")
val signingPropertiesLinked = Files.isSymbolicLink(signingPropertiesFile.toPath())
val releaseSigningProperties = if (!localAcceptance && (signingPropertiesFile.exists() || signingPropertiesLinked)) {
    require(signingPropertiesFile.isFile) { "Android Release signing requires a readable android/key.properties." }
    Properties().apply { signingPropertiesFile.inputStream().use { load(it) } }
} else {
    null
}

fun Properties.signingValue(name: String): String =
    getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing $name in android/key.properties.")

android {
    namespace = "com.isdfx.lite"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.isdfx.lite"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseSigning = releaseSigningProperties?.let { properties ->
        signingConfigs.create("release") {
            val configuredStore = File(properties.signingValue("storeFile"))
            // A linked properties file describes its external signing directory.
            // A regular android/key.properties uses the repository's module-relative convention.
            val storeDirectory = if (signingPropertiesLinked) {
                signingPropertiesFile.canonicalFile.parentFile
            } else {
                projectDir
            }
            val keystore = if (configuredStore.isAbsolute) configuredStore else storeDirectory.resolve(configuredStore)
            require(keystore.isFile) { "The Android Release keystore from android/key.properties is unavailable." }
            storeFile = keystore
            storePassword = properties.signingValue("storePassword")
            keyAlias = properties.signingValue("keyAlias")
            keyPassword = properties.signingValue("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = releaseSigning
        }
    }
}

flutter {
    source = "../.."
}
