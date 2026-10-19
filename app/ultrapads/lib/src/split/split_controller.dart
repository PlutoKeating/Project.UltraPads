import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:up_engine/up_engine.dart';

import '../state/engine_state.dart';
import 'model_store.dart';

/// 分轨模型存放目录（测试中替换）。
final modelDirProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}models');
  },
);

final modelStoreProvider = Provider<ModelStore>(
  (ref) => ModelStore(dir: ref.watch(modelDirProvider)),
);

/// 是否已下载分轨模型。
final modelInstalledProvider = FutureProvider.autoDispose<bool>(
  (ref) async => await ref.watch(modelStoreProvider).installed() != null,
);

enum SplitPhase { idle, downloadingModel, running, done, failed }

class SplitUiState {
  const SplitUiState({
    this.phase = SplitPhase.idle,
    this.stage,
    this.fraction,
    this.done,
    this.failure,
  });

  final SplitPhase phase;
  final SplitStage? stage;

  /// 当前阶段 / 下载的完成比例 0..1（未知为 null）。
  final double? fraction;
  final SplitDone? done;

  /// 失败原因：`[tag]` 或 `model_<reason>`（模型下载失败）。
  final String? failure;

  bool get busy =>
      phase == SplitPhase.downloadingModel || phase == SplitPhase.running;
}

/// 导入歌曲并拆成 Kit：必要时先下载分轨模型，再调用引擎（本地处理，云端不参与）。
class SplitController extends Notifier<SplitUiState> {
  ModelCancel? _modelCancel;
  StreamSubscription<SplitProgress>? _sub;

  @override
  SplitUiState build() {
    ref.onDispose(() {
      _modelCancel?.cancel();
      unawaited(_sub?.cancel());
    });
    return const SplitUiState();
  }

  void reset() {
    if (!state.busy) state = const SplitUiState();
  }

  void cancel() {
    _modelCancel?.cancel();
    if (state.phase == SplitPhase.running) {
      ref.read(engineProvider).splitCancel();
    }
  }

  /// [separate] = true：每个乐器一个 pad（需要模型）；false：只拆整曲混音。
  Future<void> start({
    required String path,
    required bool separate,
    String? title,
    double? knownBpm,
  }) async {
    if (state.busy) return;
    final engine = ref.read(engineProvider);
    String? modelPath;
    if (separate) {
      final store = ref.read(modelStoreProvider);
      var file = await store.installed();
      if (file == null) {
        final cancel = _modelCancel = ModelCancel();
        state = const SplitUiState(
          phase: SplitPhase.downloadingModel,
          fraction: 0,
        );
        try {
          file = await store.download(
            cancel: cancel,
            onProgress: (got, total) => state = SplitUiState(
              phase: SplitPhase.downloadingModel,
              fraction: total == 0 ? null : got / total,
            ),
          );
        } on ModelDownloadCancelled {
          state = const SplitUiState(
            phase: SplitPhase.failed,
            failure: '[cancelled]',
          );
          return;
        } on ModelDownloadFailed catch (e) {
          state = SplitUiState(
            phase: SplitPhase.failed,
            failure: 'model_${e.reason}',
          );
          return;
        } finally {
          _modelCancel = null;
        }
        ref.invalidate(modelInstalledProvider);
      }
      modelPath = file.path;
    }
    state = const SplitUiState(phase: SplitPhase.running, fraction: 0);
    final done = Completer<void>();
    _sub = engine
        .splitSong(
          path: path,
          title: title,
          modelPath: modelPath,
          knownBpm: knownBpm,
        )
        .listen(
          (p) {
            switch (p) {
              case SplitRunning(:final stage, :final fraction):
                state = SplitUiState(
                  phase: SplitPhase.running,
                  stage: stage,
                  fraction: fraction,
                );
              case SplitDone():
                state = SplitUiState(phase: SplitPhase.done, done: p);
              case SplitFailed(:final error):
                state = SplitUiState(
                  phase: SplitPhase.failed,
                  failure: _failureOf(error),
                );
            }
          },
          onError: (Object e) {
            state = SplitUiState(
              phase: SplitPhase.failed,
              failure: '[internal] $e',
            );
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
  }

  static String _failureOf(EngineException e) => e.message;
}

final splitProvider = NotifierProvider<SplitController, SplitUiState>(
  SplitController.new,
);
