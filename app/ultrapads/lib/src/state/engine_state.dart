import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';

import '../engine/engine_bootstrap.dart';

/// 启动时注入（`ProviderScope.overrides`）。
final engineBootProvider = Provider<EngineBoot>(
  (ref) => throw StateError('engineBootProvider must be overridden'),
);

final engineProvider = Provider<EngineClient>(
  (ref) => ref.watch(engineBootProvider).client,
);

/// 引擎事件广播流。
final engineEventsProvider = Provider<Stream<EngineEvent>>(
  (ref) => ref.watch(engineProvider).events,
);

/// 引擎状态的只读投影：快照初始化，事件增量更新。UI 不得私自修改。
class EngineView {
  const EngineView({
    required this.padStates,
    required this.pads,
    required this.transport,
    required this.kit,
    required this.recorder,
    required this.recordElapsed,
    required this.controllerMode,
    this.lastTrack,
  });

  factory EngineView.fromSnapshot(EngineSnapshot s) => EngineView(
    padStates: s.padStates,
    pads: s.pads,
    transport: s.transport,
    kit: s.kit,
    recorder: s.recorder,
    recordElapsed: 0,
    controllerMode: s.controllerMode,
  );

  final List<PadPlayState> padStates;
  final List<PadParams> pads;
  final TransportState transport;
  final KitSummary? kit;
  final RecorderState recorder;
  final double recordElapsed;
  final bool controllerMode;

  /// 最近一次录音生成的作品（录音结束 → 保存流程）。
  final TrackInfo? lastTrack;

  bool get anyPlaying => padStates.any((s) => s != PadPlayState.idle);

  EngineView copyWith({
    List<PadPlayState>? padStates,
    List<PadParams>? pads,
    TransportState? transport,
    KitSummary? kit,
    RecorderState? recorder,
    double? recordElapsed,
    bool? controllerMode,
    TrackInfo? lastTrack,
  }) => EngineView(
    padStates: padStates ?? this.padStates,
    pads: pads ?? this.pads,
    transport: transport ?? this.transport,
    kit: kit ?? this.kit,
    recorder: recorder ?? this.recorder,
    recordElapsed: recordElapsed ?? this.recordElapsed,
    controllerMode: controllerMode ?? this.controllerMode,
    lastTrack: lastTrack ?? this.lastTrack,
  );
}

class EngineProjection extends Notifier<EngineView> {
  @override
  EngineView build() {
    final engine = ref.watch(engineProvider);
    final sub = engine.events.listen(_on);
    ref.onDispose(sub.cancel);
    return EngineView.fromSnapshot(engine.snapshot());
  }

  void _on(EngineEvent e) {
    switch (e) {
      case PadStateEvent(:final pad, :final state):
        final next = List<PadPlayState>.of(this.state.padStates);
        next[pad.flat] = state;
        this.state = this.state.copyWith(padStates: next);
      case TransportEvent(:final transport):
        state = state.copyWith(transport: transport);
      case RecorderEvent(:final state, :final elapsedSecs, :final track):
        this.state = this.state.copyWith(
          recorder: state,
          recordElapsed: elapsedSecs,
          lastTrack: track,
        );
      case KitLoadedEvent(:final kit, :final pads):
        state = state.copyWith(
          kit: kit,
          pads: List.unmodifiable(pads),
          padStates: List.filled(PadId.total, PadPlayState.idle),
        );
      case HubEventWrapper(event: HubControllerChanged(:final connected)):
        state = state.copyWith(controllerMode: connected);
      case MetersEvent() ||
          LibraryChangedEvent() ||
          TrackPlaybackEvent() ||
          HubEventWrapper() ||
          ErrorEvent():
        break;
    }
  }
}

final engineViewProvider = NotifierProvider<EngineProjection, EngineView>(
  EngineProjection.new,
);

/// 电平（约 60Hz）：单独的流，避免整棵树重建。
final metersProvider = StreamProvider<Meters>(
  (ref) => ref
      .watch(engineEventsProvider)
      .where((e) => e is MetersEvent)
      .map((e) => (e as MetersEvent).meters),
);

/// 作品播放进度。
final trackPlaybackProvider = StreamProvider<TrackPlaybackEvent>(
  (ref) => ref
      .watch(engineEventsProvider)
      .where((e) => e is TrackPlaybackEvent)
      .cast<TrackPlaybackEvent>(),
);

/// 引擎错误（用于提示条）。
final engineErrorsProvider = StreamProvider<EngineException>(
  (ref) => ref
      .watch(engineEventsProvider)
      .where((e) => e is ErrorEvent)
      .map((e) => (e as ErrorEvent).error),
);

/// 曲库版本号：收到 LibraryChanged / KitLoaded 时递增，驱动列表刷新。
class LibraryRevision extends Notifier<int> {
  @override
  int build() {
    final sub = ref.watch(engineEventsProvider).listen((e) {
      if (e is LibraryChangedEvent || e is KitLoadedEvent) state++;
    });
    ref.onDispose(sub.cancel);
    return 0;
  }

  void bump() => state++;
}

final libraryRevisionProvider = NotifierProvider<LibraryRevision, int>(
  LibraryRevision.new,
);

final kitsProvider = FutureProvider<List<KitSummary>>((ref) {
  ref.watch(libraryRevisionProvider);
  return ref.watch(engineProvider).libraryListKits();
});

final tracksProvider = FutureProvider<List<TrackInfo>>((ref) {
  ref.watch(libraryRevisionProvider);
  return ref.watch(engineProvider).tracksList();
});

final tutorialChartProvider = FutureProvider.family<TutorialChart?, String>(
  (ref, kitId) => ref.watch(engineProvider).tutorialGet(kitId),
);

final waveformProvider =
    FutureProvider.family<List<double>, ({String sample, int buckets})>(
      (ref, a) => ref.watch(engineProvider).sampleWaveform(a.sample, a.buckets),
    );

/// Hub 投影。
class HubView {
  const HubView({
    this.server = const HubServerStatus(running: false),
    this.paired = const [],
    this.syncProgress = const {},
    this.lastSync,
    this.controllerPeer,
  });

  final HubServerStatus server;
  final List<PairedDevice> paired;
  final Map<String, double> syncProgress;
  final SyncReport? lastSync;
  final HubPeer? controllerPeer;

  HubView copyWith({
    HubServerStatus? server,
    List<PairedDevice>? paired,
    Map<String, double>? syncProgress,
    SyncReport? lastSync,
    HubPeer? Function()? controllerPeer,
  }) => HubView(
    server: server ?? this.server,
    paired: paired ?? this.paired,
    syncProgress: syncProgress ?? this.syncProgress,
    lastSync: lastSync ?? this.lastSync,
    controllerPeer: controllerPeer != null
        ? controllerPeer()
        : this.controllerPeer,
  );
}

class HubProjection extends Notifier<HubView> {
  @override
  HubView build() {
    final sub = ref.watch(engineEventsProvider).listen((e) {
      if (e is! HubEventWrapper) return;
      switch (e.event) {
        case HubServerChanged(:final status):
          state = state.copyWith(server: status);
        case HubPeerPaired(:final device):
          state = state.copyWith(
            paired: [
              ...state.paired.where((d) => d.peer.id != device.peer.id),
              device,
            ],
          );
        case HubSyncProgress(:final peerId, :final progress, :final report):
          state = state.copyWith(
            syncProgress: {...state.syncProgress, peerId: progress},
            lastSync: report,
          );
        case HubControllerChanged(:final connected, :final peer):
          state = state.copyWith(controllerPeer: () => connected ? peer : null);
      }
    });
    ref.onDispose(sub.cancel);
    return const HubView();
  }
}

final hubViewProvider = NotifierProvider<HubProjection, HubView>(
  HubProjection.new,
);

/// 把引擎调用包一层：未实现（[EngineNotImplemented]）或引擎报错时返回 null，
/// UI 据此降级（错误同时打印日志；引擎侧的错误事件另由演奏页提示）。
Future<T?> tryEngine<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on EngineNotImplemented {
    return null;
  } on EngineException catch (e) {
    debugPrint('UltraPads: $e');
    return null;
  }
}

/// void 调用版本：成功返回 true，引擎未实现返回 false。
Future<bool> tryEngineDo(Future<void> Function() call) async {
  try {
    await call();
    return true;
  } on EngineNotImplemented {
    return false;
  } on EngineException catch (e) {
    debugPrint('UltraPads: $e');
    return false;
  }
}

/// 订阅辅助：在 widget 外部等待某类事件。
Future<T> nextEvent<T extends EngineEvent>(Stream<EngineEvent> s) =>
    s.firstWhere((e) => e is T).then((e) => e as T);

/// 防止未使用告警（unawaited 辅助）。
void fireAndForget(Future<void> f) => unawaited(f);
