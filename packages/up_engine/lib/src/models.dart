/// 引擎数据类（纯 Dart，不依赖 FRB 生成的类型）。
///
/// 结构对照 `docs/API.md` 第 2、3 节。FfiEngineClient 负责在 FRB 类型与
/// 这里的类型之间转换；UI 只认识这里的类型。
library;

import 'dart:collection';

/// Pad 编址：bank 0 = A，1 = B；index 0..11（行优先，第 1 行 = 0,1,2）。
final class PadId implements Comparable<PadId> {
  const PadId(this.bank, this.index)
    : assert(bank >= 0 && bank < banks),
      assert(index >= 0 && index < padsPerBank);

  /// 由平铺下标 0..23 构造。
  factory PadId.flat(int flat) =>
      PadId(flat ~/ padsPerBank, flat % padsPerBank);

  static const int banks = 2;
  static const int padsPerBank = 12;
  static const int total = banks * padsPerBank;
  static const int columns = 3;
  static const int rows = 4;

  final int bank;
  final int index;

  int get flat => bank * padsPerBank + index;
  int get row => index ~/ columns;
  int get column => index % columns;

  /// 全部 24 个 pad，按平铺顺序。
  static final List<PadId> all = List.unmodifiable(
    List.generate(total, PadId.flat),
  );

  @override
  bool operator ==(Object other) =>
      other is PadId && other.bank == bank && other.index == index;

  @override
  int get hashCode => flat;

  @override
  int compareTo(PadId other) => flat.compareTo(other.flat);

  @override
  String toString() => 'PadId(${bank == 0 ? 'A' : 'B'}${index + 1})';
}

enum PadMode { oneShot, loop, gate }

enum PadPlayState { idle, pending, playing, stopping }

enum Quantize { none, beat, bar }

/// Pad 颜色角色：引用 token 的语义角色，而不是 RGB（API.md `ColorRole`）。
///
/// 顺序与 `design/tokens/src/semantic/pad.tokens.json` 的 `pad.palette.N`
/// 一致：[index] 就是调色板下标（APK 的 rosa/amarelo/verde/azul = 0..3）。
enum ColorRole { pink, yellow, green, blue, magenta, cyan, orange, rose }

final class PadParams {
  const PadParams({
    this.mode = PadMode.oneShot,
    this.gain = 1.0,
    this.pan = 0.0,
    this.chokeGroup,
    this.color = ColorRole.pink,
    this.sample,
    this.startFrame = 0,
    this.endFrame,
    this.quantizeOverride,
  });

  /// 没有采样的空 pad。
  static const PadParams empty = PadParams();

  final PadMode mode;
  final double gain;
  final double pan;
  final int? chokeGroup;
  final ColorRole color;
  final String? sample;
  final int startFrame;
  final int? endFrame;
  final Quantize? quantizeOverride;

  bool get isEmpty => sample == null;

  PadParams copyWith({
    PadMode? mode,
    double? gain,
    double? pan,
    int? Function()? chokeGroup,
    ColorRole? color,
    String? Function()? sample,
    int? startFrame,
    int? Function()? endFrame,
    Quantize? Function()? quantizeOverride,
  }) => PadParams(
    mode: mode ?? this.mode,
    gain: gain ?? this.gain,
    pan: pan ?? this.pan,
    chokeGroup: chokeGroup != null ? chokeGroup() : this.chokeGroup,
    color: color ?? this.color,
    sample: sample != null ? sample() : this.sample,
    startFrame: startFrame ?? this.startFrame,
    endFrame: endFrame != null ? endFrame() : this.endFrame,
    quantizeOverride: quantizeOverride != null
        ? quantizeOverride()
        : this.quantizeOverride,
  );

  @override
  bool operator ==(Object other) =>
      other is PadParams &&
      other.mode == mode &&
      other.gain == gain &&
      other.pan == pan &&
      other.chokeGroup == chokeGroup &&
      other.color == color &&
      other.sample == sample &&
      other.startFrame == startFrame &&
      other.endFrame == endFrame &&
      other.quantizeOverride == quantizeOverride;

  @override
  int get hashCode => Object.hash(
    mode,
    gain,
    pan,
    chokeGroup,
    color,
    sample,
    startFrame,
    endFrame,
    quantizeOverride,
  );
}

final class TransportState {
  const TransportState({
    this.playing = false,
    this.beat = 0,
    this.bpm = 120,
    this.barLenBeats = 4,
    this.speed = 1.0,
    this.quantize = Quantize.bar,
  });

  final bool playing;
  final double beat;
  final double bpm;
  final double barLenBeats;
  final double speed;
  final Quantize quantize;

  /// 当前小节内进度 0..1。
  double get barProgress =>
      barLenBeats <= 0 ? 0 : (beat % barLenBeats) / barLenBeats;

  TransportState copyWith({
    bool? playing,
    double? beat,
    double? bpm,
    double? barLenBeats,
    double? speed,
    Quantize? quantize,
  }) => TransportState(
    playing: playing ?? this.playing,
    beat: beat ?? this.beat,
    bpm: bpm ?? this.bpm,
    barLenBeats: barLenBeats ?? this.barLenBeats,
    speed: speed ?? this.speed,
    quantize: quantize ?? this.quantize,
  );
}

final class Meters {
  const Meters({
    this.masterPeak = const [0, 0],
    this.masterRms = const [0, 0],
    this.padLevels = const [],
  });

  static const Meters silent = Meters();

  final List<double> masterPeak;
  final List<double> masterRms;

  /// 24 个 pad 的电平（0..1）。
  final List<double> padLevels;
}

enum RecorderState { idle, recording, saving }

/// Kit 来源。
enum KitSource { builtin, imported, user, hub }

final class KitSummary {
  const KitSummary({
    required this.id,
    required this.name,
    this.artist = '',
    this.song = '',
    this.genre = '',
    this.bpm = 120,
    this.padCount = 12,
    this.hasTutorial = false,
    this.isNew = false,
    this.isFeatured = false,
    this.downloaded = true,
    this.source = KitSource.builtin,
    this.color = ColorRole.pink,
    this.coverAsset,
  });

  final String id;
  final String name;

  /// 「启发自」原曲艺人 / 曲名。
  final String artist;
  final String song;

  /// 曲风键（如 `hiphop`、`rock`），UI 用它查 i18n 和图标。
  final String genre;
  final double bpm;
  final int padCount;
  final bool hasTutorial;
  final bool isNew;
  final bool isFeatured;
  final bool downloaded;
  final KitSource source;
  final ColorRole color;

  /// 可选的封面资源键（相对素材清单），缺失时 UI 用渐变占位。
  final String? coverAsset;

  bool get hasBankB => padCount > PadId.padsPerBank;

  KitSummary copyWith({bool? downloaded, String? name}) => KitSummary(
    id: id,
    name: name ?? this.name,
    artist: artist,
    song: song,
    genre: genre,
    bpm: bpm,
    padCount: padCount,
    hasTutorial: hasTutorial,
    isNew: isNew,
    isFeatured: isFeatured,
    downloaded: downloaded ?? this.downloaded,
    source: source,
    color: color,
    coverAsset: coverAsset,
  );
}

/// 编辑 Kit 时的完整文档（`library_save_kit`）。
final class KitDoc {
  KitDoc({
    required this.id,
    required this.name,
    required List<PadParams> pads,
    this.bpm = 120,
    this.genre = '',
  }) : assert(pads.length == PadId.total),
       pads = List.unmodifiable(pads);

  final String id;
  final String name;
  final double bpm;
  final String genre;
  final List<PadParams> pads;

  PadParams pad(PadId id) => pads[id.flat];

  KitDoc withPad(PadId id, PadParams params) {
    final next = List<PadParams>.of(pads);
    next[id.flat] = params;
    return KitDoc(id: this.id, name: name, pads: next, bpm: bpm, genre: genre);
  }

  KitDoc copyWith({String? name, double? bpm, String? genre}) => KitDoc(
    id: id,
    name: name ?? this.name,
    pads: pads,
    bpm: bpm ?? this.bpm,
    genre: genre ?? this.genre,
  );
}

final class SampleInfo {
  const SampleInfo({
    required this.id,
    required this.name,
    this.durationSecs = 0,
    this.sampleRate = 44100,
    this.channels = 1,
  });

  final String id;
  final String name;
  final double durationSecs;
  final int sampleRate;
  final int channels;

  int get frames => (durationSecs * sampleRate).round();
}

final class EngineSnapshot {
  EngineSnapshot({
    required List<PadPlayState> padStates,
    required List<PadParams> pads,
    this.transport = const TransportState(),
    this.kit,
    this.recorder = RecorderState.idle,
    this.controllerMode = false,
  }) : assert(padStates.length == PadId.total),
       assert(pads.length == PadId.total),
       padStates = UnmodifiableListView(padStates),
       pads = UnmodifiableListView(pads);

  factory EngineSnapshot.empty() => EngineSnapshot(
    padStates: List.filled(PadId.total, PadPlayState.idle),
    pads: List.filled(PadId.total, PadParams.empty),
  );

  final List<PadPlayState> padStates;
  final List<PadParams> pads;
  final TransportState transport;
  final KitSummary? kit;
  final RecorderState recorder;

  /// 手机作为桌面控制器时为 true：pad 事件转发到 Hub。
  final bool controllerMode;

  PadPlayState stateOf(PadId id) => padStates[id.flat];
  PadParams paramsOf(PadId id) => pads[id.flat];
}

final class TrackInfo {
  const TrackInfo({
    required this.id,
    required this.name,
    required this.durationSecs,
    required this.createdAt,
    this.kitName = '',
  });

  final String id;
  final String name;
  final double durationSecs;
  final DateTime createdAt;
  final String kitName;
}

enum ExportFormat { wav, flac, upkit, sfz }

/// 教程步骤类型（4.7.0 `tutorial.json` 的 color/state 语义）。
enum TutorialStepKind {
  /// 普通敲击（one-shot）。
  tap,

  /// 开启 loop（state 0）。
  loopOn,

  /// 关闭 loop。
  loopOff,

  /// 翻页（pad 100 / 101）。
  page,
}

/// 教程一步：在 [timeSecs] 时刻要按下的 pad；[page] 非空表示这一步要切到该页（0=A,1=B）。
///
/// 4.7.0 的教程是**时间轴**格式：每步有时间点，pad 提前 `tutorial.fill` 时长开始
/// 「填满」，在填满那一刻按下判定 PERFECT，早按 TOO FAST，晚按 TOO SLOW。
/// [timeSecs] 为 null 时退化为旧版（APK）的无时间顺序模式。
final class TutorialStep {
  const TutorialStep({
    this.pads = const [],
    this.page,
    this.timeSecs,
    this.kind = TutorialStepKind.tap,
  });
  final List<PadId> pads;
  final int? page;
  final double? timeSecs;
  final TutorialStepKind kind;
}

final class TutorialChart {
  TutorialChart({
    required this.kit,
    required List<TutorialStep> steps,
    this.bpm,
    this.durationSecs,
    this.perfectMs,
    this.missMs,
  }) : steps = List.unmodifiable(steps);

  final String kit;
  final List<TutorialStep> steps;
  final double? bpm;

  /// 引擎给出的判定窗口（毫秒）；null 时 UI 用默认值。
  final double? perfectMs;
  final double? missMs;

  /// 整曲时长；null 时取最后一步时间。
  final double? durationSecs;

  bool get timed => steps.any((s) => s.timeSecs != null);

  double get length =>
      durationSecs ??
      steps.fold<double>(0, (m, s) => (s.timeSecs ?? 0) > m ? s.timeSecs! : m);
}

final class ImportReport {
  const ImportReport({
    this.kits = const [],
    this.samples = const [],
    this.warnings = const [],
  });
  final List<KitSummary> kits;
  final List<SampleInfo> samples;
  final List<String> warnings;
}

final class AppDirs {
  const AppDirs({
    required this.dataDir,
    required this.cacheDir,
    this.documentsDir,
  });
  final String dataDir;
  final String cacheDir;
  final String? documentsDir;
}

final class EngineInfo {
  const EngineInfo({required this.version, this.backend = 'mock'});
  final String version;
  final String backend;
}

final class AudioConfig {
  const AudioConfig({this.bufferFrames, this.sampleRate, this.outputDevice});
  final int? bufferFrames;
  final int? sampleRate;
  final String? outputDevice;
}

final class AudioStatus {
  const AudioStatus({
    required this.running,
    this.sampleRate = 48000,
    this.bufferFrames = 256,
    this.device = '',
    this.latencyMs = 0,
  });
  final bool running;
  final int sampleRate;
  final int bufferFrames;
  final String device;
  final double latencyMs;
}

final class AudioDeviceInfo {
  const AudioDeviceInfo({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.isInput = false,
  });
  final String id;
  final String name;
  final bool isDefault;
  final bool isInput;
}

enum HubPeerKind { desktop, phone, tablet }

final class HubPeer {
  const HubPeer({
    required this.id,
    required this.name,
    this.kind = HubPeerKind.desktop,
    this.address = '',
    this.paired = false,
  });
  final String id;
  final String name;
  final HubPeerKind kind;
  final String address;
  final bool paired;
}

final class PairedDevice {
  const PairedDevice({required this.peer, required this.token});
  final HubPeer peer;
  final String token;
}

final class SyncReport {
  const SyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.bytes = 0,
  });
  final int pulled;
  final int pushed;
  final int conflicts;
  final int bytes;
}

final class HubServerStatus {
  const HubServerStatus({
    required this.running,
    this.name = '',
    this.pairingCode = '',
    this.port = 0,
  });
  final bool running;
  final String name;

  /// 6 位配对码。
  final String pairingCode;
  final int port;
}

enum ErrorCode {
  unknown,
  notImplemented,
  notFound,
  invalidArgument,
  io,
  audioDevice,
  permissionDenied,
  network,
  pairingFailed,
  busy,
}

/// 引擎返回的错误（`UpError`）。
class EngineException implements Exception {
  const EngineException(this.code, [this.message = '']);
  final ErrorCode code;
  final String message;

  @override
  String toString() => 'EngineException(${code.name}): $message';
}

/// 某个 FFI 函数尚未实现（引擎还在建设中）；UI 应优雅降级。
class EngineNotImplemented extends EngineException {
  const EngineNotImplemented(this.function)
    : super(ErrorCode.notImplemented, function);
  final String function;

  @override
  String toString() => 'EngineNotImplemented($function)';
}
