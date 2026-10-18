import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';

import '../state/engine_state.dart';
import '../state/settings_state.dart';
import 'apk_installer.dart';

/// 应用内更新的阶段（docs/ARCHITECTURE.md §10）。
enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,

  /// Linux：新版本已装好，等待重启；Android：APK 已下载，等待安装。
  ready,
  failed,
}

class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.info,
    this.progress,
    this.mirror = true,
    this.path,
    this.error,
  });

  final UpdatePhase phase;
  final UpdateInfo? info;

  /// 下载进度 0..1（总大小未知时为 null）。
  final double? progress;
  final bool mirror;

  /// Android：已下载的 APK。
  final String? path;
  final EngineException? error;

  UpdateState copyWith({
    UpdatePhase? phase,
    UpdateInfo? info,
    double? Function()? progress,
    bool? mirror,
    String? Function()? path,
    EngineException? Function()? error,
  }) => UpdateState(
    phase: phase ?? this.phase,
    info: info ?? this.info,
    progress: progress != null ? progress() : this.progress,
    mirror: mirror ?? this.mirror,
    path: path != null ? path() : this.path,
    error: error != null ? error() : this.error,
  );
}

/// 平台安装动作（测试中替换）。
final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => const ApkInstaller(),
);

/// 退出本进程（Linux 重启时调用；测试中替换）。
final appExitProvider = Provider<void Function()>(
  (ref) =>
      () => exit(0),
);

class UpdateController extends Notifier<UpdateState> {
  StreamSubscription<UpdateProgress>? _download;
  bool _autoChecked = false;

  EngineClient get _engine => ref.read(engineProvider);

  @override
  UpdateState build() {
    ref.onDispose(() => _download?.cancel());
    return const UpdateState();
  }

  /// 启动后的自动检查：每个进程最多一次，设置里关闭或 Mock 引擎时跳过。
  Future<void> autoCheck() async {
    if (_autoChecked) return;
    _autoChecked = true;
    if (!ref.read(settingsProvider).autoUpdateCheck) return;
    if (_engine.backendName != 'ffi') return;
    await check(silent: true);
  }

  /// 查询最新版本。`silent` 时失败不进入 [UpdatePhase.failed]（不打扰用户）。
  Future<void> check({bool silent = false}) async {
    if (state.phase == UpdatePhase.checking ||
        state.phase == UpdatePhase.downloading) {
      return;
    }
    state = state.copyWith(phase: UpdatePhase.checking, error: () => null);
    try {
      final info = await _engine.updateCheck();
      state = UpdateState(
        phase: info.available ? UpdatePhase.available : UpdatePhase.upToDate,
        info: info,
      );
    } on EngineException catch (e) {
      state = silent
          ? const UpdateState()
          : UpdateState(phase: UpdatePhase.failed, error: e);
    }
  }

  /// 下载 → Linux 装入新版本（[UpdatePhase.ready] 后调用 [finish] 重启）/ Android 下载后直接调起安装。
  void start() {
    final info = state.info;
    if (info == null || !info.available) return;
    if (info.installMode == UpdateInstallMode.manual) return;
    _download?.cancel();
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      progress: () => 0,
      mirror: true,
      error: () => null,
    );
    _download = _engine.updateDownload().listen((p) async {
      switch (p) {
        case UpdateDownloading(:final done, :final total, :final mirror):
          state = state.copyWith(
            progress: () => total == null || total == 0 ? null : done / total,
            mirror: mirror,
          );
        case UpdateReady(:final path):
          await _onDownloaded(info, path);
        case final UpdateFailed f:
          state = f.cancelled
              ? state.copyWith(phase: UpdatePhase.available)
              : state.copyWith(phase: UpdatePhase.failed, error: () => f.error);
      }
    });
  }

  Future<void> _onDownloaded(UpdateInfo info, String path) async {
    try {
      if (info.installMode == UpdateInstallMode.selfUpdate) {
        await _engine.updateApply(path);
        state = state.copyWith(phase: UpdatePhase.ready, path: () => path);
      } else {
        state = state.copyWith(phase: UpdatePhase.ready, path: () => path);
        await finish();
      }
    } on EngineException catch (e) {
      state = state.copyWith(phase: UpdatePhase.failed, error: () => e);
    }
  }

  void cancel() => _engine.updateCancel();

  /// Linux：停止音频、约 1 秒后启动新版本并退出本进程。
  /// Android：把 APK 交给系统安装器（需要时先打开「安装未知应用」设置，返回 false）。
  Future<bool> finish() async {
    final info = state.info;
    final path = state.path;
    if (info == null || path == null || state.phase != UpdatePhase.ready) {
      return false;
    }
    try {
      if (info.installMode == UpdateInstallMode.selfUpdate) {
        await _engine.updateRelaunch();
        try {
          await _engine.audioStop();
        } on EngineException {
          // 退出前尽力释放音频设备
        }
        ref.read(appExitProvider)();
        return true;
      }
      final installer = ref.read(apkInstallerProvider);
      if (!await installer.canInstall()) {
        await installer.openSettings();
        return false;
      }
      await installer.install(path);
      return true;
    } on EngineException catch (e) {
      state = state.copyWith(phase: UpdatePhase.failed, error: () => e);
      return false;
    } catch (e) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: () => EngineException(ErrorCode.unknown, '$e'),
      );
      return false;
    }
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);
