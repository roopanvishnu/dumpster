plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // Add the Google services Gradle plugin
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin
}

android {
    namespace = "com.example.garbage1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.garbage1"
        minSdk = flutter.minSdkVersion // Updated minSdk version
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.10.0"))

    // Firebase Analytics (optional but recommended)
    implementation("com.google.firebase:firebase-analytics")

    // Firebase Authentication (Required for Email & Google Auth)
    implementation("com.google.firebase:firebase-auth")

    // Google Sign-In SDK (Required for Google Authentication)
    implementation("com.google.android.gms:play-services-auth:21.3.0")

    // Add Firestore for storing tickets and SOS alerts
    implementation("com.google.firebase:firebase-firestore")
    
    // Add multidex support
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Add core library desugaring for Java 8+ features
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
