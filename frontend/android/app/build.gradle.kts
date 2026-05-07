plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin
    id("dev.flutter.flutter-gradle-plugin")
    //id("com.google.gms.google-services")
}

android {
    namespace = "com.example.safepulse"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.safepulse"
        // minSdk = flutter.minSdkVersion
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}