# R8 规则（release）。
#
# shared_preferences_android 2.5+ / path_provider_android 2.3+ 改为由 Dart 经 package:jni
# 直接调用 Kotlin/Java 方法（jnigen 生成的绑定按名字反射查找）。R8 看不到这些调用，
# 会把方法删掉或改名，release 启动时报 NoSuchMethodError。保留这些插件和 jni 运行时的类。
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class dev.ultrapads.** { *; }
# jni 按完整签名查找 suspend 方法（`(…Lkotlin/coroutines/Continuation;)`），并在 Dart 侧
# 按名字使用 Kotlin 运行时类（如 `kotlin.Result$Failure`、协程续体），保留 Kotlin 运行时。
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
