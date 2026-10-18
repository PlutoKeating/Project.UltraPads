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

/// Hub 投影（只读）：事件增量更新，再按需从引擎重读服务信息与受信列表。
class HubView {
  const HubView({
    this.server = const HubServerStatus(running: false),
    this.pairingCode,
    this.trusted = const [],
    this.sync = const {},
    this.lastSync,
    this.controller = HubControllerStatus.disconnected,
    this.controllerPeer,
    this.remoteControllers = const {},
  });

  final HubServerStatus server;

  /// 当前配对码（本机为 Hub 时）。
  final PairingCode? pairingCode;
  final List<PairedDevice> trusted;

  /// 进行中的同步：peerId → 进度。
  final Map<String, HubSyncProgress> sync;
  final SyncReport? lastSync;

  /// 本机作为控制器。
  final HubControllerStatus controller;
  final HubPeer? controllerPeer;

  /// 本机作为 Hub：正在控制本机的设备（id → 名称）。
  final Map<String, String> remoteControllers;

  HubView copyWith({
    HubServerStatus? server,
    PairingCode? Function()? pairingCode,
    List<PairedDevice>? trusted,
    Map<String, HubSyncProgress>? sync,
    SyncReport? lastSync,
    HubControllerStatus? controller,
    HubPeer? Function()? controllerPeer,
    Map<String, String>? remoteControllers,
  }) => HubView(
    server: server ?? this.server,
    pairingCode: pairingCode != null ? pairingCode() : this.pairingCode,
    trusted: trusted ?? this.trusted,
    sync: sync ?? this.sync,
    lastSync: lastSync ?? this.lastSync,
    controller: controller ?? this.controller,
    controllerPeer: controllerPeer != null
        ? controllerPeer()
        : this.controllerPeer,
    remoteControllers: remoteControllers ?? this.remoteControllers,
  );
}

class HubProjection extends Notifier<HubView> {
  EngineClient get _engine => ref.read(engineProvider);

  @override
  HubView build() {
    final sub = ref.watch(engineEventsProvider).listen((e) {
      if (e is HubEventWrapper) _on(e.event);
    });
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return HubView(controller: ref.read(engineProvider).hubControllerStatus());
  }

  void _on(HubEvent e) {
    switch (e) {
      case HubServerChanged(:final status):
        state = state.copyWith(
          server: status,
          pairingCode: status.running ? null : () => null,
        );
        refresh();
      case HubPeerPaired():
        refresh();
      case HubSyncStarted(:final peerId):
        state = state.copyWith(
          sync: {...state.sync, peerId: HubSyncProgress(peerId, 0, 0)},
        );
      case HubSyncProgress(:final peerId):
        state = state.copyWith(sync: {...state.sync, peerId: e});
      case HubSyncFinished(:final peerId, :final report):
        state = state.copyWith(
          sync: {...state.sync}..remove(peerId),
          lastSync: report,
        );
      case HubErrorEvent(:final op, :final peerId):
        if (op == 'sync' && peerId != null) {
          state = state.copyWith(sync: {...state.sync}..remove(peerId));
        }
        if (op == 'controller') _refreshController(null);
      case HubControllerChanged(:final connected, :final peer):
        _refreshController(connected ? peer : null);
      case HubRemoteControllerChanged(:final connected, :final deviceId):
        final next = {...state.remoteControllers};
        if (connected) {
          next[deviceId] = e.name.isEmpty ? deviceId : e.name;
        } else {
          next.remove(deviceId);
        }
        state = state.copyWith(remoteControllers: next);
    }
  }

  void _refreshController(HubPeer? peer) {
    if (!ref.mounted) return;
    final status = _engine.hubControllerStatus();
    state = state.copyWith(
      controller: status,
      controllerPeer: () => status.connected
          ? (peer ??
                state.controllerPeer ??
                HubPeer(
                  id: status.peerId ?? '',
                  name: status.peerName ?? status.peerId ?? '',
                ))
          : null,
    );
  }

  /// 从引擎重读服务信息、受信设备与控制器状态（失败时保留旧值）。
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final engine = _engine;
    final info = await tryEngine(engine.hubServerInfo);
    final trusted = await tryEngine(engine.hubTrustedDevices);
    if (!ref.mounted) return;
    state = state.copyWith(
      server: info ?? const HubServerStatus(running: false),
      trusted: trusted,
      pairingCode: info == null ? () => null : null,
    );
    _refreshController(null);
  }

  Future<PairingCode?> newPairingCode() async {
    final code = await tryEngine(_engine.hubNewPairingCode);
    if (code != null) state = state.copyWith(pairingCode: () => code);
    return code;
  }

  Future<void> revoke(String deviceId) async {
    await tryEngine(() => _engine.hubRevoke(deviceId));
    await refresh();
  }

  void setLocalEcho(bool enabled) {
    _engine.hubControllerSetLocalEcho(enabled);
    _refreshController(null);
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
