plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Aapke code se liya gaya

    compileOptions {
        // #################### BADLAV 1: YEH LINE ADD KAREIN ####################
        // Kotlin DSL me isko is tarah likhte hain
        isCoreLibraryDesugaringEnabled = true
        // ####################################################################
        
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.flow"
        minSdk = 22
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // #################### BADLAV 2: YEH LINE ADD KAREIN ####################
    // Kotlin DSL me isko is tarah likhte hain
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // ####################################################################

    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.0.0")
}

flutter {
    source = "../.."
}