plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.entradas_pev_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Atualizado conforme sugerido pelo Flutter

    defaultConfig {
        applicationId = "com.example.entradas_pev_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "281016"
            storeFile = file("C:\\Users\\elbes.admin\\upload-keystore.jks")
            storePassword = "281016"
        }
    }

    applicationVariants.all {
        if (buildType.name == "pevs-slu") {
            (buildType as com.android.build.api.dsl.BuildType).apply {
                isMinifyEnabled = true
                isShrinkResources = true
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    file("proguard-rules.pro")
                )
            }
        }
    }

    buildFeatures {
        // Se necessário habilitar viewBinding, compose etc.
        // viewBinding = true
    }

    // Define o nome base para os arquivos APK gerados
    setProperty("archivesBaseName", "PEV-SLUDF-${defaultConfig.versionName}")
}

flutter {
    source = "../.."
}
