plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fede22dev.beauty_center"
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
        applicationId = "com.fede22dev.beauty_center"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        val vCode = (System.currentTimeMillis() / 1000).toInt() % 2000000000
        versionCode = vCode
        versionName = flutter.versionName

        manifestPlaceholders["APP_VERSION"] = flutter.versionName
        manifestPlaceholders["BUILD_NUMBER"] = vCode.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
