import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名（应用内更新要求签名永不变化）。依次查找：
//   $UP_KEY_PROPERTIES → android/key.properties → ~/.config/ultrapads/key.properties
// 字段：storeFile / storePassword / keyAlias / keyPassword。都不存在时回退调试密钥（本地开发），
// CI（环境变量 CI=true）中缺失则构建失败，避免发布调试签名的包。
val releaseKeyProperties: Properties? = listOfNotNull(
    System.getenv("UP_KEY_PROPERTIES")?.let(::File),
    rootProject.file("key.properties"),
    File(System.getProperty("user.home"), ".config/ultrapads/key.properties"),
).firstOrNull { it.isFile }?.let { f -> Properties().apply { f.inputStream().use(::load) } }

if (releaseKeyProperties == null && System.getenv("CI") == "true") {
    throw GradleException("release signing key not found (UP_KEY_PROPERTIES / key.properties)")
}

android {
    namespace = "dev.ultrapads.ultrapads"
    // permission_handler_android requires compiling against API 37+.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.ultrapads.ultrapads"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseKeyProperties?.let { p ->
            create("release") {
                storeFile = file(p.getProperty("storeFile"))
                storePassword = p.getProperty("storePassword")
                keyAlias = p.getProperty("keyAlias")
                keyPassword = p.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // jni 型插件（shared_preferences / path_provider）需要的 keep 规则。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
