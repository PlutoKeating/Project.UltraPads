import 'package:flutter/services.dart';

/// Android 系统安装器（MethodChannel `dev.ultrapads/update`，见 MainActivity.kt）。
class ApkInstaller {
  const ApkInstaller();

  static const _channel = MethodChannel('dev.ultrapads/update');

  /// 是否已允许本应用「安装未知应用」。
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  /// 打开本应用的「安装未知应用」设置页。
  Future<void> openSettings() => _channel.invokeMethod('openInstallSettings');

  /// 把下载并校验过的 APK（`cacheDir/updates/`）交给系统安装器；用户在系统界面确认。
  Future<void> install(String path) =>
      _channel.invokeMethod('installApk', {'path': path});
}
