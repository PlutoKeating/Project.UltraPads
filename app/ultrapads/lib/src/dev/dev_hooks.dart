import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:up_engine/up_engine.dart';

import '../update/apk_installer.dart';

/// 开发 / 验证用的环境变量钩子（桌面；发布构建同样可用，但默认都不开启）：
///
/// - `ULTRAPADS_HUB_AUTOSTART=<名字>`：启动后自动开启 Hub 并生成配对码，
///   把端口、地址和配对码打印到 stdout（无界面的 Hub 联调与截图）；
/// - `ULTRAPADS_LOG_EVENTS=1`：把 pad 状态、Hub 事件和非零电平（≤ 4 次/秒）
///   打印到 stdout，用来确认引擎确实在发声；
/// - `ULTRAPADS_UPDATE_SELFTEST=1`：无界面走一遍应用内更新（检查 → 下载并校验 →
///   Linux 装入并重启 / Android 调起系统安装器），每一步打印到 stdout。
///
/// 没有环境变量的平台（Android）用编译期开关：`--dart-define=UP_LOG_EVENTS=true`、
/// `--dart-define=UP_HUB_AUTOSTART=<名字>` 与 `--dart-define=UP_UPDATE_SELFTEST=true`
/// （日志进 logcat 的 `flutter` 标签）。
abstract final class DevHooks {
  /// 电平日志节流（日志频率，不是界面动效）。
  // up-lint-ignore: 调试日志节流间隔，与界面动效无关
  static const _meterLogInterval = Duration(milliseconds: 250);

  static Map<String, String> get _env =>
      kIsWeb ? const {} : Platform.environment;

  static Future<void> run(EngineClient engine) async {
    const logDefine = bool.fromEnvironment('UP_LOG_EVENTS');
    const hubDefine = String.fromEnvironment('UP_HUB_AUTOSTART');
    const updateDefine = bool.fromEnvironment('UP_UPDATE_SELFTEST');
    if (logDefine || _env['ULTRAPADS_LOG_EVENTS'] == '1') _logEvents(engine);
    if (updateDefine || _env['ULTRAPADS_UPDATE_SELFTEST'] == '1') {
      unawaited(_updateSelftest(engine));
    }
    final hubName = hubDefine.isNotEmpty
        ? hubDefine
        : _env['ULTRAPADS_HUB_AUTOSTART'];
    if (hubName != null && hubName.isNotEmpty) {
      try {
        final s = await engine.hubStartServer(hubName);
        final code = await engine.hubNewPairingCode();
        debugPrint(
          'UltraPads[dev]: hub "${s.name}" port ${s.port} udp ${s.udpPort} '
          'addresses ${s.addresses} pairing code ${code.code}',
        );
      } catch (e) {
        debugPrint('UltraPads[dev]: hub autostart failed: $e');
      }
    }
  }

  static Future<void> _updateSelftest(EngineClient engine) async {
    void log(String m) => debugPrint('UltraPads[dev]: update $m');
    try {
      log('current ${engine.appVersion}');
      final info = await engine.updateCheck();
      log(
        'latest ${info.latest} available=${info.available} '
        'mode=${info.installMode.name} asset=${info.assetName}',
      );
      if (!info.available || info.installMode == UpdateInstallMode.manual) {
        return;
      }
      var lastPercent = -1;
      await for (final p in engine.updateDownload()) {
        switch (p) {
          case UpdateDownloading(:final done, :final total, :final mirror):
            final percent = total == null || total == 0
                ? 0
                : done * 100 ~/ total;
            if (percent ~/ 25 != lastPercent ~/ 25) {
              lastPercent = percent;
              log('downloading $percent% mirror=$mirror');
            }
          case UpdateReady(:final path):
            log('verified $path');
            if (info.installMode == UpdateInstallMode.selfUpdate) {
              await engine.updateApply(path);
              log('applied; relaunching');
              await engine.updateRelaunch();
              await engine.audioStop();
              exit(0);
            }
            const installer = ApkInstaller();
            log('can install: ${await installer.canInstall()}');
            await installer.install(path);
            log('handed to the system installer');
          case UpdateFailed(:final error):
            log('failed: $error');
        }
      }
    } catch (e) {
      log('failed: $e');
    }
  }

  static void _logEvents(EngineClient engine) {
    var lastMeter = DateTime.fromMillisecondsSinceEpoch(0);
    engine.events.listen((e) {
      switch (e) {
        case PadStateEvent(:final pad, :final state):
          debugPrint('UltraPads[dev]: pad $pad ${state.name}');
        case MetersEvent(:final meters):
          final peak = meters.masterPeak.fold<double>(
            0,
            (a, b) => a > b ? a : b,
          );
          final now = DateTime.now();
          if (peak > 0 && now.difference(lastMeter) > _meterLogInterval) {
            lastMeter = now;
            debugPrint(
              'UltraPads[dev]: meters peak ${peak.toStringAsFixed(3)}',
            );
          }
        case HubEventWrapper(:final event):
          debugPrint('UltraPads[dev]: hub ${event.runtimeType} ${_hub(event)}');
        case ErrorEvent(:final error):
          debugPrint('UltraPads[dev]: error $error');
        default:
          break;
      }
    });
  }

  static String _hub(HubEvent e) => switch (e) {
    HubServerChanged(:final status) => 'running=${status.running}',
    HubPeerPaired(:final device) => device.name,
    HubSyncStarted(:final peerId) => peerId,
    HubSyncProgress(:final done, :final total) => '$done/$total',
    HubSyncFinished(:final report) =>
      'down ${report.downloadedBlobs} up ${report.uploadedBlobs} '
          'conflicts ${report.conflicts}',
    HubControllerChanged(:final connected, :final peer) =>
      'connected=$connected ${peer?.name ?? ''}',
    HubRemoteControllerChanged(:final connected, :final name) =>
      'connected=$connected $name',
    HubErrorEvent(:final op, :final error) => '$op $error',
  };
}
