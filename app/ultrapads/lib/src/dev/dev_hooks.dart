import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:up_engine/up_engine.dart';

/// 开发 / 验证用的环境变量钩子（桌面；发布构建同样可用，但默认都不开启）：
///
/// - `ULTRAPADS_HUB_AUTOSTART=<名字>`：启动后自动开启 Hub 并生成配对码，
///   把端口、地址和配对码打印到 stdout（无界面的 Hub 联调与截图）；
/// - `ULTRAPADS_LOG_EVENTS=1`：把 pad 状态、Hub 事件和非零电平（≤ 4 次/秒）
///   打印到 stdout，用来确认引擎确实在发声。
///
/// 没有环境变量的平台（Android）用编译期开关：`--dart-define=UP_LOG_EVENTS=true`
/// 与 `--dart-define=UP_HUB_AUTOSTART=<名字>`（日志进 logcat 的 `flutter` 标签）。
abstract final class DevHooks {
  /// 电平日志节流（日志频率，不是界面动效）。
  // up-lint-ignore: 调试日志节流间隔，与界面动效无关
  static const _meterLogInterval = Duration(milliseconds: 250);

  static Map<String, String> get _env =>
      kIsWeb ? const {} : Platform.environment;

  static Future<void> run(EngineClient engine) async {
    const logDefine = bool.fromEnvironment('UP_LOG_EVENTS');
    const hubDefine = String.fromEnvironment('UP_HUB_AUTOSTART');
    if (logDefine || _env['ULTRAPADS_LOG_EVENTS'] == '1') _logEvents(engine);
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
