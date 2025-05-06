import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Carrega as propriedades de assinatura do arquivo key.properties
val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    }
}

android {
    namespace = "slu.pev.entradas_pev_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "slu.pev.entradas_pev_app"
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        minSdk = 23
        targetSdk = 34
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    // Configuração de assinatura para o build release
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let(::file)
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
            // Garante que os símbolos nativos sejam incluídos no AAB
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }

    buildFeatures {
        // Descomente se precisar de viewBinding ou compose
        // viewBinding = true
    }
}

flutter {
    source = "../.."
}