import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de la versión para publicar. Los datos de la llave van en
// android/key.properties, que NO se sube al repositorio (ver
// docs/PUBLICACION.md). Sin ese archivo se firma con la llave de debug, así
// cualquiera del grupo puede compilar igual.
val propiedadesFirma = Properties()
val archivoFirma = rootProject.file("key.properties")
if (archivoFirma.exists()) {
    propiedadesFirma.load(FileInputStream(archivoFirma))
}

android {
    namespace = "com.freshmarket.freshmarket_app"
    // 37 o más: lo exige flutter_local_notifications 23 (notificaciones).
    // Solo cambia contra qué API se compila; los celulares que la pueden
    // instalar los decide minSdk.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications usa fechas de Java 8 que los Android
        // viejos no traen: el "desugaring" las agrega al compilar.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Identificador único en Play Store (no se puede cambiar después de
        // publicar).
        applicationId = "com.freshmarket.freshmarket_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = propiedadesFirma["keyAlias"] as String?
            keyPassword = propiedadesFirma["keyPassword"] as String?
            storeFile = (propiedadesFirma["storeFile"] as String?)?.let { file(it) }
            storePassword = propiedadesFirma["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (archivoFirma.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Notificaciones push: el archivo google-services.json se baja de la consola
// de Firebase (ver docs/NOTIFICACIONES.md). Sin él la app compila igual y
// funciona sin push, así nadie del grupo queda trabado por no tenerlo.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
