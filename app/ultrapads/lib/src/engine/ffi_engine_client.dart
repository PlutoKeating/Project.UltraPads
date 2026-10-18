import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:up_engine/up_engine.dart';

import '../rust/api/engine.dart' as ffi;
import '../rust/api/hub.dart' as ffi_hub;
import '../rust/api/library.dart' as ffi_lib;
import '../rust/api/tracks.dart' as ffi_tracks;
import '../rust/api/types.dart' as t;
import '../rust/frb_generated.dart';

/// 基于 flutter_rust_bridge 生成绑定（`lib/src/rust/`，引擎代理维护）的 [EngineClient]。
///
/// - FRB 类型 ↔ `up_engine` 数据类在本文件的 `_to*` / `_from*` 中转换；
/// - 引擎返回 `UpError(code: notImplemented)` 或绑定里还没有对应函数时，
///   抛出 [EngineNotImplemented]，UI 优雅降级；
/// - 热路径（[padDown] / [padUp] / [send] / [snapshot]）是 FRB `sync` 调用，
///   出错时不抛异常，只上报一次 [ErrorEvent]。
///
/// 说明（以生成绑定为准，见 app/ultrapads/docs/ARCHITECTURE.md「引擎适配」）：
/// 编辑 Kit 通过 `library_kit_json` / `library_save_kit(kitJson)` 交换
/// `up_model::KitDoc` JSON；`ColorRole` 与引擎同名一一对应（调色板映射见
/// `ColorRole.paletteIndex`）；`sample_info` 由 `library_list_samples` 查找。
class FfiEngineClient implements EngineClient {
  FfiEngineClient._();

  /// 加载原生库并初始化 FRB。失败时抛出，由调用方回退到 Mock。
  static Future<FfiEngineClient> create() async {
    await RustLib.init();
    return FfiEngineClient._();
  }

  final _events = StreamController<EngineEvent>.broadcast();
  final Set<String> _reported = {};
  StreamSubscription<t.EngineEvent>? _sub;

  /// 编辑中的 Kit 原始 JSON（保存时就地修改，保留 UI 不认识的字段）。
  final Map<String, Map<String, dynamic>> _kitJson = {};

  final Map<String, HubPeer> _peers = {};

  @override
  String get backendName => 'ffi';

  @override
  Stream<EngineEvent> get events => _events.stream;

  /// 应用生命周期内只保持一个 `events()` 订阅（引擎 init 之后建立）。
  void _listen() {
    if (_sub != null) return;
    try {
      _sub = ffi.events().listen((e) {
        final mapped = _event(e);
        if (mapped != null) _events.add(mapped);
      }, onError: (Object e) => _events.add(ErrorEvent(_error(e, 'events'))));
    } catch (e) {
      _reportOnce('events', e);
    }
  }

  // ------------------------------------------------------------- errors

  static EngineException _error(Object e, String fn) {
    if (e is t.UpError) {
      return e.code == t.ErrorCode.notImplemented
          ? EngineNotImplemented(fn)
          : EngineException(_code(e.code), e.message);
    }
    return EngineException(ErrorCode.unknown, '$fn: $e');
  }

  static ErrorCode _code(t.ErrorCode c) => switch (c) {
    t.ErrorCode.invalidArgument ||
    t.ErrorCode.format => ErrorCode.invalidArgument,
    t.ErrorCode.notFound => ErrorCode.notFound,
    t.ErrorCode.notInitialized ||
    t.ErrorCode.invalidState ||
    t.ErrorCode.queueFull => ErrorCode.busy,
    t.ErrorCode.audio => ErrorCode.audioDevice,
    t.ErrorCode.codec || t.ErrorCode.io => ErrorCode.io,
    t.ErrorCode.permissionDenied => ErrorCode.permissionDenied,
    t.ErrorCode.notImplemented => ErrorCode.notImplemented,
    t.ErrorCode.internal => ErrorCode.unknown,
  };

  /// 包装异步调用：把 FRB 错误转成 EngineException。
  Future<T> _call<T>(String fn, Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw _error(e, fn);
    }
  }

  /// 热路径不能抛异常：出错时只报告一次错误事件。
  void _reportOnce(String fn, Object e) {
    if (_reported.add(fn)) {
      debugPrint('FfiEngineClient: $fn failed: $e');
      _events.add(ErrorEvent(_error(e, fn)));
    }
  }

  // ------------------------------------------------------------ mapping

  static ColorRole _color(t.ColorRole c) => ColorRole.values.byName(c.name);

  static t.ColorRole _colorOut(ColorRole c) =>
      t.ColorRole.values.byName(c.name);

  /// KitDoc JSON 里的颜色名（PascalCase）。
  static String _colorJson(ColorRole c) {
    final n = _colorOut(c).name;
    return n[0].toUpperCase() + n.substring(1);
  }

  static ColorRole _colorFromJson(Object? v) {
    final s = v is String && v.isNotEmpty
        ? v[0].toLowerCase() + v.substring(1)
        : 'blue';
    return _color(
      t.ColorRole.values.firstWhere(
        (c) => c.name == s,
        orElse: () => t.ColorRole.blue,
      ),
    );
  }

  static PadMode _mode(t.PadMode m) => switch (m) {
    t.PadMode.oneShot => PadMode.oneShot,
    t.PadMode.loop => PadMode.loop,
    t.PadMode.gate => PadMode.gate,
  };

  static t.PadMode _modeOut(PadMode m) => switch (m) {
    PadMode.oneShot => t.PadMode.oneShot,
    PadMode.loop => t.PadMode.loop,
    PadMode.gate => t.PadMode.gate,
  };

  static PadPlayState _state(t.PadPlayState s) => switch (s) {
    t.PadPlayState.idle => PadPlayState.idle,
    t.PadPlayState.pending => PadPlayState.pending,
    t.PadPlayState.playing => PadPlayState.playing,
    t.PadPlayState.stopping => PadPlayState.stopping,
  };

  static Quantize _quantize(t.Quantize q) => switch (q) {
    t.Quantize.none => Quantize.none,
    t.Quantize.sixteenth ||
    t.Quantize.eighth ||
    t.Quantize.beat => Quantize.beat,
    t.Quantize.bar || t.Quantize.twoBars || t.Quantize.fourBars => Quantize.bar,
  };

  static t.Quantize _quantizeOut(Quantize q) => switch (q) {
    Quantize.none => t.Quantize.none,
    Quantize.beat => t.Quantize.beat,
    Quantize.bar => t.Quantize.bar,
  };

  static RecorderState _recorder(t.RecorderState s) => switch (s) {
    t.RecorderState.idle => RecorderState.idle,
    t.RecorderState.recording => RecorderState.recording,
    t.RecorderState.saving => RecorderState.saving,
  };

  static PadId _pad(t.PadId p) => PadId(p.bank, p.index);
  static t.PadId _padOut(PadId p) => t.PadId(bank: p.bank, index: p.index);

  static PadParams _params(t.PadParams p) => PadParams(
    mode: _mode(p.mode),
    gain: p.gain,
    pan: p.pan,
    chokeGroup: p.chokeGroup,
    color: _color(p.color),
    sample: p.sample,
    startFrame: p.startFrame.toInt(),
    endFrame: p.endFrame?.toInt(),
    quantizeOverride: p.quantizeOverride == null
        ? null
        : _quantize(p.quantizeOverride!),
    pitch: p.pitch,
  );

  static t.PadParams _paramsOut(PadParams p) => t.PadParams(
    mode: _modeOut(p.mode),
    gain: p.gain,
    pan: p.pan,
    chokeGroup: p.chokeGroup,
    selfChoke: p.mode == PadMode.oneShot,
    retrigger: t.Retrigger.restart,
    color: _colorOut(p.color),
    sample: p.sample,
    startFrame: BigInt.from(p.startFrame),
    endFrame: p.endFrame == null ? null : BigInt.from(p.endFrame!),
    quantizeOverride: p.quantizeOverride == null
        ? null
        : _quantizeOut(p.quantizeOverride!),
    pitch: p.pitch,
  );

  static KitSummary _kit(t.KitSummary k) => KitSummary(
    id: k.id,
    name: k.name,
    artist: k.inspiredBy ?? (k.authors.isEmpty ? '' : k.authors.first),
    song: k.description ?? '',
    genre: k.genres.isEmpty ? '' : k.genres.first.toLowerCase(),
    bpm: k.bpm ?? TransportState().bpm,
    padCount: k.padCount > PadId.padsPerBank ? PadId.total : PadId.padsPerBank,
    hasTutorial: k.hasTutorial,
    downloaded: true,
    source: switch (k.sourceKind) {
      'user' => KitSource.user,
      'hub' => KitSource.hub,
      'compat' || 'builtin' || 'generated' => KitSource.builtin,
      _ => KitSource.imported,
    },
    color: ColorRole.fromPalette(k.id.hashCode.abs()),
    coverAsset: k.coverPath,
  );

  static TrackInfo _track(t.TrackInfo tr) => TrackInfo(
    id: tr.id,
    name: tr.name,
    durationSecs: tr.durationSecs,
    createdAt: DateTime.fromMillisecondsSinceEpoch(tr.createdUnixMs.toInt()),
    waveform: tr.waveform.toList(),
  );

  static SampleInfo _sample(t.SampleInfo s) => SampleInfo(
    id: s.id,
    name: s.name,
    durationSecs: s.durationSecs,
    sampleRate: s.sampleRate,
    channels: s.channels,
  );

  static HubPeer _peer(t.HubPeer p) => HubPeer(
    id: p.id,
    name: p.name,
    address: p.address,
    port: p.port,
    addresses: p.addresses,
    paired: p.paired,
  );

  static PairedDevice _device(t.PairedDevice d) => PairedDevice(
    id: d.id,
    name: d.name,
    pairedAt: DateTime.fromMillisecondsSinceEpoch(d.pairedUnixMs.toInt()),
  );

  static HubServerStatus _server(t.HubServerInfo i) => HubServerStatus(
    running: true,
    id: i.id,
    name: i.name,
    port: i.port,
    udpPort: i.udpPort,
    addresses: i.addresses,
    advertising: i.advertising,
  );

  static PairingCode _pairing(t.PairingCode c) => PairingCode(
    code: c.code,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(c.expiresUnixMs.toInt()),
    ttl: Duration(seconds: c.ttlSecs),
  );

  static SyncReport _report(t.SyncReport r) => SyncReport(
    pulled: r.pulled,
    pushed: r.pushed,
    conflicts: r.conflicts,
    bytes: r.bytes.toInt(),
    uploadedBlobs: r.uploadedBlobs,
    downloadedBlobs: r.downloadedBlobs,
    durationMs: r.durationMs.toInt(),
  );

  static HubControllerStatus _controller(t.HubControllerStatus s) =>
      HubControllerStatus(
        connected: s.connected,
        peerId: s.peer,
        peerName: s.peerName,
        localEcho: s.localEcho,
        rttMs: s.latency == null || s.latency!.samples == 0
            ? null
            : s.latency!.rttP50Us.toDouble() /
                  Duration.microsecondsPerMillisecond,
      );

  EngineEvent? _event(t.EngineEvent e) => switch (e) {
    t.EngineEvent_PadState(:final pad, :final state) => PadStateEvent(
      _pad(pad),
      _state(state),
    ),
    t.EngineEvent_Transport(
      :final playing,
      :final beat,
      :final bpm,
      :final barLenBeats,
    ) =>
      TransportEvent(
        snapshot().transport.copyWith(
          playing: playing,
          beat: beat,
          bpm: bpm,
          barLenBeats: barLenBeats,
        ),
      ),
    t.EngineEvent_Meters(
      :final masterPeak,
      :final masterRms,
      :final padLevels,
    ) =>
      MetersEvent(
        Meters(
          masterPeak: masterPeak.toList(),
          masterRms: masterRms.toList(),
          padLevels: padLevels.toList(),
        ),
      ),
    t.EngineEvent_Recorder(:final state, :final elapsedSecs) => RecorderEvent(
      _recorder(state),
      elapsedSecs,
    ),
    t.EngineEvent_TrackSaved(:final track) => RecorderEvent(
      RecorderState.idle,
      track.durationSecs,
      track: _track(track),
    ),
    t.EngineEvent_KitLoaded(:final kit) => KitLoadedEvent(
      _kit(kit),
      snapshot().pads,
    ),
    t.EngineEvent_TrackPlayback(:final track) => TrackPlaybackEvent(
      track,
      0,
      playing: track != null,
    ),
    t.EngineEvent_LibraryChanged() => const LibraryChangedEvent(),
    t.EngineEvent_Hub(:final field0) => _hubEvent(field0),
    t.EngineEvent_Error(:final field0) => ErrorEvent(_error(field0, 'engine')),
  };

  EngineEvent? _hubEvent(t.HubEvent e) {
    final HubEvent? mapped = switch (e) {
      // 端口等完整信息由 hub_server_info 读取；事件只触发刷新。
      t.HubEvent_ServerStarted(:final port) => HubServerChanged(
        HubServerStatus(running: true, port: port),
      ),
      t.HubEvent_ServerStopped() => const HubServerChanged(
        HubServerStatus(running: false),
      ),
      t.HubEvent_Paired(:final id, :final name) => HubPeerPaired(
        PairedDevice(id: id, name: name),
      ),
      t.HubEvent_SyncStarted(:final peer) => HubSyncStarted(peer),
      t.HubEvent_SyncProgress(:final peer, :final done, :final total) =>
        HubSyncProgress(peer, done.toInt(), total.toInt()),
      t.HubEvent_SyncFinished(:final peer, :final report) => HubSyncFinished(
        peer,
        _report(report),
      ),
      t.HubEvent_ControllerConnected(:final peer) => HubControllerChanged(
        connected: true,
        peer: _peers[peer] ?? HubPeer(id: peer, name: peer),
      ),
      t.HubEvent_ControllerDisconnected() => const HubControllerChanged(
        connected: false,
      ),
      t.HubEvent_RemoteControllerConnected(:final device, :final name) =>
        HubRemoteControllerChanged(
          connected: true,
          deviceId: device,
          name: name,
        ),
      t.HubEvent_RemoteControllerDisconnected(:final device) =>
        HubRemoteControllerChanged(connected: false, deviceId: device),
      t.HubEvent_Error(:final op, :final peer, :final error) => HubErrorEvent(
        op,
        _error(error, 'hub_$op'),
        peerId: peer,
      ),
      t.HubEvent_PeerDiscovered() || t.HubEvent_PeerLost() => null,
    };
    return mapped == null ? null : HubEventWrapper(mapped);
  }

  // ------------------------------------------------- lifecycle / audio

  @override
  Future<EngineInfo> init(AppDirs dirs) async {
    try {
      final info = await _call(
        'init',
        () => ffi.init(
          appDirs: t.AppDirs(dataDir: dirs.dataDir, cacheDir: dirs.cacheDir),
        ),
      );
      return EngineInfo(
        version: info.version,
        backend: '${info.graphBackend}/${info.platform}',
      );
    } finally {
      // 事件流必须在 init 之后订阅，否则引擎返回 notInitialized。
      _listen();
    }
  }

  static AudioStatus _status(t.AudioStatus s) => AudioStatus(
    running: s.running,
    sampleRate: s.sampleRate,
    bufferFrames: s.bufferFrames ?? 0,
    device: s.device,
    host: s.host,
    channels: s.channels,
    sampleFormat: s.sampleFormat,
    latencyMs:
        s.outputLatencyMs ??
        ((s.bufferFrames ?? 0) / s.sampleRate * Duration.millisecondsPerSecond),
  );

  @override
  Future<AudioStatus> audioStart(AudioConfig cfg) =>
      _call('audio_start', () async {
        final s = await ffi.audioStart(
          cfg: t.AudioConfig(
            bufferFrames: cfg.bufferFrames,
            sampleRate: cfg.sampleRate,
            outputDevice: cfg.outputDevice,
          ),
        );
        return _status(s);
      });

  @override
  Future<void> audioStop() => _call('audio_stop', ffi.audioStop);

  @override
  Future<AudioStatus> audioStatus() =>
      _call('audio_status', () async => _status(await ffi.audioStatus()));

  @override
  Future<List<AudioDeviceInfo>> audioDevices() =>
      _call('audio_devices', () async {
        final list = await ffi.audioDevices();
        return [
          for (final d in list)
            AudioDeviceInfo(
              id: d.id,
              name: d.name,
              isDefault: d.isDefaultOutput || d.isDefaultInput,
              isInput: d.isInput && !d.isOutput,
            ),
        ];
      });

  // ------------------------------------------------------- snapshot

  @override
  EngineSnapshot snapshot() {
    try {
      final s = ffi.snapshot();
      final states = List.filled(PadId.total, PadPlayState.idle);
      final pads = List.filled(PadId.total, PadParams.empty);
      for (final p in s.pads) {
        final id = _pad(p.pad);
        states[id.flat] = _state(p.state);
        pads[id.flat] = _params(p.params);
      }
      final tr = s.transport;
      return EngineSnapshot(
        padStates: states,
        pads: pads,
        transport: TransportState(
          playing: tr.playing,
          beat: tr.beat,
          bpm: tr.bpm,
          barLenBeats: tr.beatsPerBar.toDouble(),
          speed: tr.speed,
          quantize: _quantize(tr.quantize),
        ),
        kit: s.kit == null ? null : _kit(s.kit!),
        recorder: _recorder(s.recorder),
        controllerMode: hubControllerStatus().connected,
      );
    } catch (e) {
      _reportOnce('snapshot', e);
      return EngineSnapshot.empty();
    }
  }

  // ------------------------------------------------------- hot path

  @override
  void padDown(PadId pad, {double velocity = 1.0}) {
    try {
      ffi.padDown(bank: pad.bank, index: pad.index, velocity: velocity);
    } catch (e) {
      _reportOnce('pad_down', e);
    }
  }

  @override
  void padUp(PadId pad) {
    try {
      ffi.padUp(bank: pad.bank, index: pad.index);
    } catch (e) {
      _reportOnce('pad_up', e);
    }
  }

  @override
  void send(Command cmd) {
    final t.Command out = switch (cmd) {
      PadDownCmd(:final pad, :final velocity) => t.Command.padDown(
        pad: _padOut(pad),
        velocity: velocity,
      ),
      PadUpCmd(:final pad) => t.Command.padUp(pad: _padOut(pad)),
      StopAllCmd() => const t.Command.stopAll(),
      SetTempoCmd(:final bpm) => t.Command.setTempo(bpm: bpm),
      SetSpeedCmd(:final ratio) => t.Command.setSpeed(ratio: ratio),
      SetQuantizeCmd(:final q) => t.Command.setQuantize(q: _quantizeOut(q)),
      SetPadParamsCmd(:final pad, :final params) => t.Command.setPadParams(
        pad: _padOut(pad),
        params: _paramsOut(params),
      ),
      SetMasterGainCmd(:final gain) => t.Command.setMasterGain(gain: gain),
      StartRecordingCmd() => const t.Command.startRecording(),
      StopRecordingCmd() => const t.Command.stopRecording(),
      TransportCmd(:final action, :final beat) => t.Command.transport(
        switch (action) {
          TransportAction.play => const t.TransportCmd.play(),
          TransportAction.stop => const t.TransportCmd.stop(),
          TransportAction.seek => t.TransportCmd.seek(beat),
        },
      ),
    };
    try {
      ffi.send(cmd: out);
    } catch (e) {
      _reportOnce('send', e);
    }
  }

  // ---------------------------------------------------------- library

  @override
  Future<List<KitSummary>> libraryListKits() => _call(
    'library_list_kits',
    () async => [for (final k in await ffi_lib.libraryListKits()) _kit(k)],
  );

  @override
  Future<void> libraryLoadKit(String kitId) =>
      _call('library_load_kit', () => ffi_lib.libraryLoadKit(kit: kitId));

  @override
  Future<ImportReport> libraryImport(String path) => _call(
    'library_import',
    () async => _importReport(await ffi_lib.libraryImport(path: path)),
  );

  @override
  Future<ImportReport> libraryImportBytes(String name, List<int> bytes) =>
      _call(
        'library_import_bytes',
        () async => _importReport(
          await ffi_lib.libraryImportBytes(
            name: name,
            bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          ),
        ),
      );

  Future<ImportReport> _importReport(t.ImportReport r) async {
    final samples = r.samples.isEmpty
        ? const <t.SampleInfo>[]
        : await ffi_lib.libraryListSamples();
    return ImportReport(
      kits: [for (final k in r.kits) _kit(k)],
      samples: [
        for (final s in samples)
          if (r.samples.contains(s.id)) _sample(s),
      ],
      warnings: r.warnings,
    );
  }

  @override
  Future<void> libraryExportKit(
    String kitId,
    String path,
    ExportFormat format,
  ) => _call(
    'library_export_kit',
    () => ffi_lib.libraryExportKit(kit: kitId, path: path, format: format.name),
  );

  @override
  Future<KitDoc> libraryGetKit(String kitId) =>
      _call('library_kit_json', () async {
        final json =
            jsonDecode(await ffi_lib.libraryKitJson(kit: kitId))
                as Map<String, dynamic>;
        _kitJson[kitId] = json;
        return _docFromJson(kitId, json);
      });

  @override
  Future<void> librarySaveKit(KitDoc kit) =>
      _call('library_save_kit', () async {
        final base =
            _kitJson[kit.id] ??
            <String, dynamic>{'id': kit.id, 'pads': <dynamic>[]};
        final json = _docToJson(kit, base);
        await ffi_lib.librarySaveKit(kitJson: jsonEncode(json));
        _kitJson[kit.id] = json;
      });

  @override
  Future<List<SampleInfo>> libraryKitSamples(String kitId) => _call(
    'library_kit_samples',
    () async {
      final doc = await libraryGetKit(kitId);
      final all = {for (final s in await ffi_lib.libraryListSamples()) s.id: s};
      final out = <SampleInfo>[];
      for (final p in doc.pads) {
        final id = p.sample;
        if (id == null) continue;
        final info = all[id];
        out.add(info != null ? _sample(info) : SampleInfo(id: id, name: id));
      }
      return out;
    },
  );

  static KitDoc _docFromJson(String id, Map<String, dynamic> json) {
    final pads = List<PadParams>.filled(PadId.total, PadParams.empty);
    for (final raw in (json['pads'] as List? ?? const [])) {
      final p = raw as Map<String, dynamic>;
      final addr = p['pad'] as Map<String, dynamic>;
      final pid = PadId(
        (addr['bank'] as num).toInt(),
        (addr['index'] as num).toInt(),
      );
      final sample = p['sample'] is Map
          ? ((p['sample'] as Map)['id'] as String?)
          : null;
      final layers = p['layers'] as List? ?? const [];
      final layerSample = layers.isNotEmpty && layers.first is Map
          ? (((layers.first as Map)['sample'] as Map?)?['id'] as String?)
          : null;
      pads[pid.flat] = PadParams(
        mode: switch (p['mode']) {
          'Loop' => PadMode.loop,
          'Gate' => PadMode.gate,
          _ => PadMode.oneShot,
        },
        gain: (p['gain'] as num?)?.toDouble() ?? 1,
        pan: (p['pan'] as num?)?.toDouble() ?? 0,
        chokeGroup: (p['chokeGroup'] as num?)?.toInt(),
        color: _colorFromJson(p['color']),
        sample: layerSample ?? sample,
        startFrame: (p['startFrame'] as num?)?.toInt() ?? 0,
        endFrame: (p['endFrame'] as num?)?.toInt(),
        pitch: (p['pitchSemitones'] as num?)?.toDouble() ?? 0,
      );
    }
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final genres = meta['genre'] as List? ?? const [];
    return KitDoc(
      id: id,
      name: json['name'] as String? ?? id,
      pads: pads,
      bpm: (json['bpm'] as num?)?.toDouble() ?? TransportState().bpm,
      genre: genres.isEmpty ? '' : '${genres.first}'.toLowerCase(),
    );
  }

  /// 把 UI 的修改写回原始 KitDoc JSON（保留其它字段：layers、note、meta…）。
  static Map<String, dynamic> _docToJson(
    KitDoc doc,
    Map<String, dynamic> base,
  ) {
    final json = Map<String, dynamic>.of(base)..['name'] = doc.name;
    final existing = <int, Map<String, dynamic>>{};
    for (final raw in (base['pads'] as List? ?? const [])) {
      final p = Map<String, dynamic>.of(raw as Map<String, dynamic>);
      final a = p['pad'] as Map<String, dynamic>;
      existing[PadId(
            (a['bank'] as num).toInt(),
            (a['index'] as num).toInt(),
          ).flat] =
          p;
    }
    final pads = <Map<String, dynamic>>[];
    for (var i = 0; i < PadId.total; i++) {
      final p = doc.pads[i];
      final id = PadId.flat(i);
      if (p.isEmpty) continue;
      final out =
          existing[i] ??
          <String, dynamic>{
            'pad': {'bank': id.bank, 'index': id.index},
          };
      final prevSample = out['sample'] is Map
          ? (out['sample'] as Map)['id']
          : null;
      out
        ..['mode'] = switch (p.mode) {
          PadMode.loop => 'Loop',
          PadMode.gate => 'Gate',
          PadMode.oneShot => 'OneShot',
        }
        ..['gain'] = p.gain
        ..['pan'] = p.pan
        ..['chokeGroup'] = p.chokeGroup
        ..['color'] = _colorJson(p.color)
        ..['startFrame'] = p.startFrame
        ..['endFrame'] = p.endFrame
        ..['pitchSemitones'] = p.pitch;
      if (prevSample != p.sample) {
        // 换了采样：清掉旧的分层，按单层 sample 引用保存。
        out
          ..['sample'] = {'id': p.sample, 'name': p.sample}
          ..['layers'] = <dynamic>[];
      }
      pads.add(out);
    }
    json['pads'] = pads;
    return json;
  }

  // ---------------------------------------------------------- samples

  @override
  Future<List<double>> sampleWaveform(String sampleId, int buckets) =>
      _call('sample_waveform', () async {
        final w = await ffi.sampleWaveform(sample: sampleId, buckets: buckets);
        return w.toList();
      });

  @override
  Future<SampleInfo> sampleInfo(String sampleId) =>
      _call('sample_info', () async {
        for (final s in await ffi_lib.libraryListSamples()) {
          if (s.id == sampleId) return _sample(s);
        }
        throw EngineException(ErrorCode.notFound, sampleId);
      });

  @override
  Future<void> samplerRecordStart({String? inputDevice}) => _call(
    'sampler_record_start',
    () => ffi.samplerRecordStart(inputDevice: inputDevice),
  );

  @override
  Future<SampleInfo> samplerRecordStop() =>
      _call('sampler_record_stop', () async {
        final id = await ffi.samplerRecordStop();
        try {
          return await sampleInfo(id);
        } on EngineException {
          return SampleInfo(id: id, name: id);
        }
      });

  @override
  Future<void> samplePreview(
    String sampleId, {
    int startFrame = 0,
    int? endFrame,
  }) => _call(
    'sample_preview',
    () => ffi.samplePreview(
      sample: sampleId,
      startFrame: BigInt.from(startFrame),
      endFrame: endFrame == null ? null : BigInt.from(endFrame),
    ),
  );

  @override
  Future<void> samplePreviewStop() =>
      _call('sample_preview_stop', ffi.samplePreviewStop);

  // ----------------------------------------------------------- tracks

  @override
  Future<List<TrackInfo>> tracksList() => _call(
    'tracks_list',
    () async => [for (final tr in await ffi_tracks.tracksList()) _track(tr)],
  );

  @override
  Future<void> trackPlay(String trackId, {bool loop = false}) => _call(
    'track_play',
    () => ffi_tracks.trackPlay(id: trackId, looping: loop),
  );

  @override
  Future<void> trackStop() => _call('track_stop', ffi_tracks.trackStop);

  @override
  Future<void> trackExport(String trackId, String path, ExportFormat format) =>
      _call(
        'track_export',
        () => ffi_tracks.trackExport(id: trackId, path: path, fmt: format.name),
      );

  @override
  Future<void> trackDelete(String trackId) =>
      _call('track_delete', () => ffi_tracks.trackDelete(id: trackId));

  @override
  Future<void> trackRename(String trackId, String name) => _call(
    'track_rename',
    () => ffi_tracks.trackRename(id: trackId, name: name),
  );

  // --------------------------------------------------------- tutorial

  @override
  Future<TutorialChart?> tutorialGet(String kitId) =>
      _call('tutorial_get', () async {
        final c = await ffi.tutorialGet(kit: kitId);
        if (c == null || c.events.isEmpty) return null;
        return TutorialChart(
          kit: kitId,
          bpm: c.bpm,
          perfectMs: c.perfectMs,
          missMs: c.missMs,
          steps: [
            for (final e in c.events)
              TutorialStep(
                timeSecs: c.timed ? e.timeSecs : null,
                pads: e.pad == null ? const [] : [_pad(e.pad!)],
                page: e.pageSwitch?.index,
                kind: e.pageSwitch != null
                    ? TutorialStepKind.page
                    : e.action == t.TutorialAction.loopToggle
                    ? TutorialStepKind.loopOn
                    : TutorialStepKind.tap,
              ),
          ],
        );
      });

  // -------------------------------------------------------------- hub

  @override
  Future<HubServerStatus> hubStartServer(String name) => _call(
    'hub_start_server',
    () async => _server(await ffi_hub.hubStartServer(name: name)),
  );

  @override
  Future<void> hubStopServer() =>
      _call('hub_stop_server', ffi_hub.hubStopServer);

  @override
  Future<HubServerStatus?> hubServerInfo() =>
      _call('hub_server_info', () async {
        final i = await ffi_hub.hubServerInfo();
        return i == null ? null : _server(i);
      });

  @override
  Future<PairingCode> hubNewPairingCode() =>
      _call('hub_new_pairing_code', () async {
        return _pairing(await ffi_hub.hubNewPairingCode());
      });

  @override
  Future<PairingCode?> hubPairingCode() => _call('hub_pairing_code', () async {
    final c = await ffi_hub.hubPairingCode();
    return c == null ? null : _pairing(c);
  });

  @override
  Future<void> hubCancelPairing() =>
      _call('hub_cancel_pairing', ffi_hub.hubCancelPairing);

  @override
  Future<List<PairedDevice>> hubTrustedDevices() => _call(
    'hub_trusted_devices',
    () async => [for (final d in await ffi_hub.hubTrustedDevices()) _device(d)],
  );

  @override
  Future<bool> hubRevoke(String deviceId) =>
      _call('hub_revoke', () => ffi_hub.hubRevoke(id: deviceId));

  @override
  Future<List<ControllerSession>> hubControllerStats() => _call(
    'hub_controller_stats',
    () async => [
      for (final s in await ffi_hub.hubControllerStats())
        ControllerSession(
          deviceId: s.deviceId,
          name: s.name,
          packets: s.packets.toInt(),
          heldPads: s.heldPads,
        ),
    ],
  );

  @override
  Future<void> hubSetDeviceName(String name) =>
      _call('hub_set_device_name', () => ffi_hub.hubSetDeviceName(name: name));

  @override
  Future<String> hubDeviceId() => _call('hub_device_id', ffi_hub.hubDeviceId);

  @override
  Stream<HubPeerEvent> hubDiscover() async* {
    try {
      await for (final e in ffi_hub.hubDiscover()) {
        switch (e) {
          case t.HubPeerEvent_Found(:final field0):
            final peer = _peer(field0);
            _peers[peer.id] = peer;
            yield HubPeerFound(peer);
          case t.HubPeerEvent_Lost(:final id):
            yield HubPeerLost(id);
        }
      }
    } catch (e) {
      throw _error(e, 'hub_discover');
    }
  }

  @override
  Future<void> hubDiscoverStop() =>
      _call('hub_discover_stop', ffi_hub.hubDiscoverStop);

  @override
  Future<HubPeer> hubProbe(String address) => _call('hub_probe', () async {
    final peer = _peer(await ffi_hub.hubProbe(address: address));
    return _peers[peer.id] = peer;
  });

  @override
  Future<List<HubPeer>> hubKnownPeers() => _call('hub_known_peers', () async {
    final out = [for (final p in await ffi_hub.hubKnownPeers()) _peer(p)];
    for (final p in out) {
      _peers[p.id] = p;
    }
    return out;
  });

  @override
  Future<PairedDevice> hubPair(HubPeer peer, String code) => _call(
    'hub_pair',
    () async => _device(await ffi_hub.hubPair(peer: peer.id, code: code)),
  );

  @override
  Future<bool> hubForget(String peerId) =>
      _call('hub_forget', () => ffi_hub.hubForget(peer: peerId));

  @override
  Future<SyncReport> hubSync(HubPeer peer) => _call(
    'hub_sync',
    () async => _report(await ffi_hub.hubSync(peer: peer.id)),
  );

  @override
  Future<HubControllerStatus> hubControllerConnect(HubPeer peer) {
    _peers[peer.id] = peer;
    return _call(
      'hub_controller_connect',
      () async =>
          _controller(await ffi_hub.hubControllerConnect(peer: peer.id)),
    );
  }

  @override
  Future<void> hubControllerDisconnect() =>
      _call('hub_controller_disconnect', ffi_hub.hubControllerDisconnect);

  @override
  HubControllerStatus hubControllerStatus() {
    try {
      return _controller(ffi_hub.hubControllerStatus());
    } catch (e) {
      _reportOnce('hub_controller_status', e);
      return HubControllerStatus.disconnected;
    }
  }

  @override
  void hubControllerSetLocalEcho(bool enabled) {
    try {
      ffi_hub.hubControllerSetLocalEcho(enabled: enabled);
    } catch (e) {
      _reportOnce('hub_controller_set_local_echo', e);
    }
  }

  @override
  Future<void> dispose() async {
    // FRB 流：不要 await cancel()（主代理约定），只发出取消。
    unawaited(_sub?.cancel());
    _sub = null;
    await _events.close();
  }
}
