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

  /// 由平铺下标 0..[total) 构造。
  factory PadId.flat(int flat) =>
      PadId(flat ~/ padsPerBank, flat % padsPerBank);

  /// 音色组上限（A–G，与引擎 `up_core::BANK_COUNT` 一致）；一首歌实际的组数见
  /// [KitSummary.groupCount]。
  static const int banks = 7;
  static const int padsPerBank = 12;
  static const int total = banks * padsPerBank;
  static const int columns = 3;
  static const int rows = 4;

  final int bank;
  final int index;

  int get flat => bank * padsPerBank + index;
  int get row => index ~/ columns;
  int get column => index % columns;

  /// 全部 [total] 个 pad，按平铺顺序。
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
  String toString() => 'PadId(${groupName(bank)}${index + 1})';

  /// 音色组名：0 → A，1 → B …
  static String groupName(int group) => String.fromCharCode(0x41 + group);
}

enum PadMode { oneShot, loop, gate }

enum PadPlayState { idle, pending, playing, stopping }

enum Quantize { none, beat, bar }

/// Pad 颜色角色：引用 token 的语义角色，而不是 RGB（API.md §2 `ColorRole`）。
///
/// 与引擎 `up_core::ColorRole` **同名同序**（FFI 按名字一一映射，不再有损转换）。
/// 引擎角色比 token 调色板（`pad.palette.0..7`，见
/// `design/tokens/src/semantic/pad.tokens.json`）多，UI 一律经 [paletteIndex]
/// 取调色板下标——**这是 ColorRole ↔ token 调色板映射的唯一定义处**：
///
/// | 角色 | 调色板 | token |
/// |---|---|---|
/// | pink | 0 | `color.pad.pink`（原 Kit `rosa`） |
/// | orange | 1 | `color.pad.orange`（`amarelo`） |
/// | green | 2 | `color.pad.green`（`verde`） |
/// | blue | 3 | `color.pad.blue`（`azul` / `azul_loop`） |
/// | red | 4 | `color.neon.magenta`（霓虹主题没有纯红） |
/// | yellow | 5 | `color.neon.yellow` |
/// | cyan | 6 | `color.neon.cyan` |
/// | purple | 7 | `color.skin.halloween.purple` |
/// | lime | 2 | 同 green |
/// | grey / neutral | 6 | 同 cyan（空 pad 不显示颜色） |
enum ColorRole {
  blue,
  orange,
  pink,
  green,
  purple,
  yellow,
  red,
  cyan,
  lime,
  grey,
  neutral;

  /// token 调色板（`UpTheme.padRole(i)`）下标，见类型文档的映射表。
  int get paletteIndex => switch (this) {
    ColorRole.pink => 0,
    ColorRole.orange => 1,
    ColorRole.green || ColorRole.lime => 2,
    ColorRole.blue => 3,
    ColorRole.red => 4,
    ColorRole.yellow => 5,
    ColorRole.cyan || ColorRole.grey || ColorRole.neutral => 6,
    ColorRole.purple => 7,
  };

  /// 调色板每个下标的代表角色（编辑器色板、皮肤预览按此顺序）。
  static const List<ColorRole> palette = [
    ColorRole.pink,
    ColorRole.orange,
    ColorRole.green,
    ColorRole.blue,
    ColorRole.red,
    ColorRole.yellow,
    ColorRole.cyan,
    ColorRole.purple,
  ];

  /// 调色板下标 → 代表角色（越界取模）。
  static ColorRole fromPalette(int index) => palette[index % palette.length];
}

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
    this.pitch = 0,
  });

  /// pitch 的范围（半音）。
  static const double pitchMin = -12;
  static const double pitchMax = 12;

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

  /// 实时移调（半音，±12）：引擎以播放速率实现（`2^(pitch/12)`），与速度相乘。
  final double pitch;

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
    double? pitch,
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
    pitch: pitch ?? this.pitch,
  );

  @override
  bool operator ==(Object other) =>
      other is PadParams &&
      other.pitch == pitch &&
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
    pitch,
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
    this.groupCount = 1,
    this.hasTutorial = false,
    this.isNew = false,
    this.isFeatured = false,
    this.downloaded = true,
    this.source = KitSource.builtin,
    this.color = ColorRole.pink,
    this.coverAsset,
    this.videoUrl,
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

  /// 音色组数（A、B、C…，每组 12 个 pad），至少 1。
  final int groupCount;
  final bool hasTutorial;
  final bool isNew;
  final bool isFeatured;
  final bool downloaded;
  final KitSource source;
  final ColorRole color;

  /// 可选的封面资源键（相对素材清单），缺失时 UI 用渐变占位。
  final String? coverAsset;

  /// Kit 自带的视频教程链接（私有素材包目录的 videoUrl）；null 时演奏页按配置搜索。
  final String? videoUrl;

  bool get hasBankB => groupCount > 1;

  KitSummary copyWith({bool? downloaded, String? name}) => KitSummary(
    id: id,
    name: name ?? this.name,
    artist: artist,
    song: song,
    genre: genre,
    bpm: bpm,
    padCount: padCount,
    groupCount: groupCount,
    hasTutorial: hasTutorial,
    isNew: isNew,
    isFeatured: isFeatured,
    downloaded: downloaded ?? this.downloaded,
    source: source,
    color: color,
    coverAsset: coverAsset,
    videoUrl: videoUrl,
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
    int groupCount = 0,
  }) : assert(pads.length == PadId.total),
       pads = List.unmodifiable(pads),
       groupCount = _groups(pads, groupCount);

  final String id;
  final String name;
  final double bpm;
  final String genre;
  final List<PadParams> pads;

  /// 音色组数（A、B…）：显式组数与有声音的 pad 用到的组取较大者，1..[PadId.banks]。
  final int groupCount;

  static int _groups(List<PadParams> pads, int explicit) {
    var used = 1;
    for (var i = 0; i < pads.length; i++) {
      if (!pads[i].isEmpty) used = i ~/ PadId.padsPerBank + 1;
    }
    return (explicit > used ? explicit : used).clamp(1, PadId.banks);
  }

  PadParams pad(PadId id) => pads[id.flat];

  KitDoc withPad(PadId id, PadParams params) {
    final next = List<PadParams>.of(pads);
    next[id.flat] = params;
    return _with(next, groupCount);
  }

  KitDoc copyWith({String? name, double? bpm, String? genre}) => KitDoc(
    id: id,
    name: name ?? this.name,
    pads: pads,
    bpm: bpm ?? this.bpm,
    genre: genre ?? this.genre,
    groupCount: groupCount,
  );

  KitDoc _with(List<PadParams> next, int groups) => KitDoc(
    id: id,
    name: name,
    pads: next,
    bpm: bpm,
    genre: genre,
    groupCount: groups,
  );

  bool get canAddGroup => groupCount < PadId.banks;

  /// 末尾新增一个空组。
  KitDoc addGroup() => canAddGroup ? _with(pads, groupCount + 1) : this;

  /// 删除第 [group] 组（连同它的 pad），后面的组前移；至少保留一组。
  KitDoc removeGroup(int group) {
    if (groupCount <= 1 || group < 0 || group >= groupCount) return this;
    final next = List<PadParams>.filled(PadId.total, PadParams.empty);
    for (var g = 0, to = 0; g < groupCount; g++) {
      if (g == group) continue;
      _copyGroup(pads, g, next, to++);
    }
    return _with(next, groupCount - 1);
  }

  /// 把第 [from] 组移到第 [to] 组的位置（其它组顺次移动）。
  KitDoc moveGroup(int from, int to) {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= groupCount ||
        to >= groupCount) {
      return this;
    }
    final order = List<int>.generate(groupCount, (g) => g)
      ..removeAt(from)
      ..insert(to, from);
    final next = List<PadParams>.filled(PadId.total, PadParams.empty);
    for (var i = 0; i < order.length; i++) {
      _copyGroup(pads, order[i], next, i);
    }
    return _with(next, groupCount);
  }

  static void _copyGroup(
    List<PadParams> src,
    int from,
    List<PadParams> dst,
    int to,
  ) {
    for (var i = 0; i < PadId.padsPerBank; i++) {
      dst[to * PadId.padsPerBank + i] = src[from * PadId.padsPerBank + i];
    }
  }
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
    this.waveform = const [],
  });

  final String id;
  final String name;
  final double durationSecs;
  final DateTime createdAt;
  final String kitName;

  /// 波形概要（0..1，引擎给 128 段）；为空时 UI 另行读取。
  final List<double> waveform;
}

enum ExportFormat { wav, flac, upkit, sfz }

/// 教程步骤类型（参考设计 `tutorial.json` 的 color/state 语义）。
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
/// 参考设计的教程是**时间轴**格式：每步有时间点，pad 提前 `tutorial.fill` 时长开始
/// 「填满」，在填满那一刻按下判定 PERFECT，早按 TOO FAST，晚按 TOO SLOW。
/// [timeSecs] 为 null 时退化为旧版（Android 格式）的无时间顺序模式。
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
    this.bufferFrames = 128,
    this.device = '',
    this.latencyMs = 0,
    this.host = '',
    this.channels = 2,
    this.sampleFormat = '',
  });
  final bool running;
  final int sampleRate;
  final int bufferFrames;
  final String device;
  final double latencyMs;

  /// 音频后端（ALSA / AAudio / …）。
  final String host;
  final int channels;
  final String sampleFormat;
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

/// 发现 / 探测到的 Hub（API.md §3.1 `HubPeer`）。
final class HubPeer {
  const HubPeer({
    required this.id,
    required this.name,
    this.kind = HubPeerKind.desktop,
    this.address = '',
    this.port = 0,
    this.addresses = const [],
    this.paired = false,
  });
  final String id;
  final String name;
  final HubPeerKind kind;

  /// 首选 IP（不含端口）。
  final String address;
  final int port;

  /// 全部候选 `ip:port`。
  final List<String> addresses;

  /// 本机信任该 Hub（配对过）。
  final bool paired;

  /// 显示用 `ip:port`。
  String get endpoint =>
      address.isEmpty ? '' : (port == 0 ? address : '$address:$port');

  HubPeer copyWith({bool? paired, String? name}) => HubPeer(
    id: id,
    name: name ?? this.name,
    kind: kind,
    address: address,
    port: port,
    addresses: addresses,
    paired: paired ?? this.paired,
  );
}

/// `hub_discover` 流的事件。
sealed class HubPeerEvent {
  const HubPeerEvent();
}

final class HubPeerFound extends HubPeerEvent {
  const HubPeerFound(this.peer);
  final HubPeer peer;
}

final class HubPeerLost extends HubPeerEvent {
  const HubPeerLost(this.id);
  final String id;
}

/// 受信设备（配对过的手机 / Hub，`PairedDevice`）。
final class PairedDevice {
  const PairedDevice({required this.id, required this.name, this.pairedAt});
  final String id;
  final String name;
  final DateTime? pairedAt;
}

/// Hub 上的一次性 6 位配对码。
final class PairingCode {
  const PairingCode({required this.code, required this.expiresAt, this.ttl});
  final String code;
  final DateTime expiresAt;
  final Duration? ttl;
}

final class SyncReport {
  const SyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.bytes = 0,
    this.uploadedBlobs = 0,
    this.downloadedBlobs = 0,
    this.durationMs = 0,
  });

  /// 本地变化的条目数。
  final int pulled;

  /// Hub 上变化的条目数。
  final int pushed;
  final int conflicts;
  final int bytes;
  final int uploadedBlobs;
  final int downloadedBlobs;
  final int durationMs;
}

/// 本机 Hub 服务（`HubServerInfo`）。
final class HubServerStatus {
  const HubServerStatus({
    required this.running,
    this.id = '',
    this.name = '',
    this.port = 0,
    this.udpPort = 0,
    this.addresses = const [],
    this.advertising = false,
  });
  final bool running;

  /// 本机设备 ID。
  final String id;
  final String name;
  final int port;
  final int udpPort;

  /// 本机局域网 `ip:port`（供手机手动输入）。
  final List<String> addresses;

  /// mDNS 广播中。
  final bool advertising;
}

/// 本机作为控制器的连接状态（`HubControllerStatus`）。
final class HubControllerStatus {
  const HubControllerStatus({
    this.connected = false,
    this.peerId,
    this.peerName,
    this.localEcho = false,
    this.rttMs,
  });

  static const HubControllerStatus disconnected = HubControllerStatus();

  final bool connected;
  final String? peerId;
  final String? peerName;

  /// 连接时本机是否同时发声。
  final bool localEcho;

  /// 往返延迟中位数（毫秒），尚无样本时为 null。
  final double? rttMs;
}

/// Hub 上的远端控制器会话（`ControllerSessionStats`）。
final class ControllerSession {
  const ControllerSession({
    required this.deviceId,
    required this.name,
    this.packets = 0,
    this.heldPads = 0,
  });
  final String deviceId;
  final String name;
  final int packets;
  final int heldPads;
}

// ---- 应用内更新（docs/API.md §6） ----

/// 本平台怎样完成更新。
enum UpdateInstallMode {
  /// Linux，由安装脚本安装：应用内下载、切换版本并重启。
  selfUpdate,

  /// Android：下载 APK 后交给系统安装器。
  apkInstaller,

  /// 其它（手动解压的包、开发构建）：只提示，打开下载页。
  manual,
}

/// 一次更新检查的结果（`update_check`）。
class UpdateInfo {
  const UpdateInfo({
    required this.current,
    required this.latest,
    required this.available,
    required this.notesUrl,
    required this.installMode,
    this.assetName,
    this.assetSize,
  });
  final String current;
  final String latest;

  /// 有更新且本平台有发布包。
  final bool available;
  final String notesUrl;
  final UpdateInstallMode installMode;
  final String? assetName;
  final int? assetSize;
}

/// 下载进度（`update_download` 流），以 [UpdateReady] 或 [UpdateFailed] 结束。
sealed class UpdateProgress {
  const UpdateProgress();
}

final class UpdateDownloading extends UpdateProgress {
  const UpdateDownloading(this.done, this.total, {this.mirror = true});
  final int done;
  final int? total;

  /// `false` = 镜像不可用，已回退 GitHub 直链。
  final bool mirror;
}

/// 已下载并通过 SHA-256 校验。
final class UpdateReady extends UpdateProgress {
  const UpdateReady(this.path);
  final String path;
}

final class UpdateFailed extends UpdateProgress {
  const UpdateFailed(this.error);
  final EngineException error;

  /// 用户取消（`update_cancel`）。
  bool get cancelled => error.message.startsWith('[cancelled]');
}

/// 本机分轨能力（`split_capabilities`）。
final class SplitCapabilities {
  const SplitCapabilities({
    required this.separationAvailable,
    required this.separationMemoryMb,
    this.availableMemoryMb,
  });

  /// 当前可用内存足以跑 Demucs 分轨。
  final bool separationAvailable;
  final int? availableMemoryMb;

  /// 分轨一首 4 分钟的歌需要的内存（MB）。
  final int separationMemoryMb;
}

/// 拆分的阶段。
enum SplitStage {
  loadingModel,
  decoding,
  analyzing,
  separating,
  building,
  importing,
}

/// 导入歌曲并拆成 Kit 的进度流（`split_song`），以 [SplitDone] 或 [SplitFailed] 结束。
sealed class SplitProgress {
  const SplitProgress();
}

final class SplitRunning extends SplitProgress {
  const SplitRunning(this.stage, this.fraction);
  final SplitStage stage;

  /// 0..1，该阶段内的完成比例。
  final double fraction;
}

final class SplitDone extends SplitProgress {
  const SplitDone({
    required this.kit,
    required this.bpm,
    required this.sections,
    required this.reliable,
    required this.separated,
  });
  final KitSummary kit;
  final double bpm;
  final int sections;

  /// 速度 / 小节估计是否可靠（不可靠时界面应提示可能偏拍）。
  final bool reliable;
  final bool separated;
}

final class SplitFailed extends SplitProgress {
  const SplitFailed(this.error);
  final EngineException error;

  /// 错误消息开头的 `[tag]`：cancelled / too_short / no_grid / insufficient_memory / model / decode …
  String? get tag =>
      RegExp(r'^\[([a-z_]+)\]').firstMatch(error.message)?.group(1);
  bool get cancelled => tag == 'cancelled';
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
