import 'dart:async';
import 'dart:math' as math;

import '../engine_client.dart';
import '../models.dart';
import '../protocol.dart';
import 'demo_library.dart';

/// 内存中的引擎模拟器：pad 状态机、Loop 量化、choke、走带、电平、录音、
/// 曲库、教程和 Hub。供 UI 开发、widget test 与 golden test 使用。
///
/// - `realtime: true`（默认）时用 `Timer.periodic` 推进时钟；
/// - `realtime: false` 时时间完全由 [advance] 驱动，测试可确定性复现。
class MockEngineClient implements EngineClient {
  MockEngineClient({
    this.realtime = true,
    this.tick = const Duration(milliseconds: 16),
    List<DemoKit>? kits,
    String? initialKit,
  }) : _kits = {for (final k in kits ?? DemoLibrary.kits()) k.summary.id: k} {
    final first = initialKit ?? _kits.keys.first;
    _applyKit(first, emit: false);
    if (realtime) {
      _timer = Timer.periodic(tick, (_) => advance(tick));
    }
  }

  final bool realtime;
  final Duration tick;

  final Map<String, DemoKit> _kits;
  final _events = StreamController<EngineEvent>.broadcast();
  Timer? _timer;

  double _now = 0; // 秒
  final List<PadParams> _pads = List.filled(PadId.total, PadParams.empty);
  final List<PadPlayState> _states = List.filled(
    PadId.total,
    PadPlayState.idle,
  );
  final List<double> _oneShotEnd = List.filled(PadId.total, -1);
  final List<double> _levels = List.filled(PadId.total, 0);
  TransportState _transport = const TransportState();
  KitSummary? _kit;
  RecorderState _recorder = RecorderState.idle;
  double _recStart = 0;
  double _masterGain = 1;
  final List<TrackInfo> _tracks = [];
  int _trackCounter = 0;
  String? _playingTrack;
  bool _trackLoop = false;
  double _trackPos = 0;
  bool _samplerRecording = false;
  double _samplerStart = 0;
  int _micCounter = 0;
  final Map<String, SampleInfo> _extraSamples = {};

  HubServerStatus _hub = const HubServerStatus(running: false);
  bool _controller = false;
  bool _localEcho = false;
  HubPeer? _controllerPeer;
  PairingCode? _pairingCode;
  String _deviceName = 'UltraPads mock';
  final Map<String, PairedDevice> _trusted = {};
  final Map<String, HubPeer> _knownPeers = {};
  StreamController<HubPeerEvent>? _discovery;
  String? _previewSample;

  /// 控制器模式下被转发到远端的 pad 事件计数（测试可读）。
  int forwardedPadEvents = 0;

  /// 最近发送的命令（测试可读）。
  final List<Command> sentCommands = [];

  @override
  String get backendName => 'mock';

  @override
  Stream<EngineEvent> get events => _events.stream;

  void _emit(EngineEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  // ------------------------------------------------------------------ 时钟

  /// 推进模拟时钟。
  void advance(Duration dt) {
    final d = dt.inMicroseconds / 1e6;
    final prevBeat = _transport.beat;
    _now += d;

    if (_transport.playing) {
      final beat = prevBeat + d * _transport.bpm / 60 * _transport.speed;
      _transport = _transport.copyWith(beat: beat);
      _resolvePending(prevBeat, beat);
      _emit(TransportEvent(_transport));
    }

    for (var i = 0; i < PadId.total; i++) {
      if (_states[i] == PadPlayState.playing &&
          _oneShotEnd[i] >= 0 &&
          _now >= _oneShotEnd[i]) {
        _setState(i, PadPlayState.idle);
      }
      final target = _states[i] == PadPlayState.playing
          ? 0.55 + 0.35 * math.sin(_now * 9 + i).abs()
          : 0.0;
      _levels[i] = target > _levels[i]
          ? target
          : math.max(0, _levels[i] - d * 3);
    }
    _maybeStopTransport();

    final peak = _levels.fold<double>(0, math.max) * _masterGain;
    _emit(
      MetersEvent(
        Meters(
          masterPeak: [peak, peak * 0.96],
          masterRms: [peak * 0.7, peak * 0.68],
          padLevels: List.of(_levels),
        ),
      ),
    );

    if (_recorder == RecorderState.recording) {
      _emit(RecorderEvent(_recorder, _now - _recStart));
    }

    if (_playingTrack != null) {
      final track = _tracks.where((t) => t.id == _playingTrack).firstOrNull;
      if (track == null) {
        _playingTrack = null;
      } else {
        _trackPos += d;
        if (_trackPos >= track.durationSecs) {
          if (_trackLoop) {
            _trackPos = 0;
          } else {
            _playingTrack = null;
            _emit(TrackPlaybackEvent(track.id, 0, playing: false));
            return;
          }
        }
        _emit(TrackPlaybackEvent(track.id, _trackPos));
      }
    }
  }

  void _resolvePending(double from, double to) {
    final q = _transport.quantize;
    final unit = switch (q) {
      Quantize.none => 0.0,
      Quantize.beat => 1.0,
      Quantize.bar => _transport.barLenBeats,
    };
    final crossed = unit <= 0 || (from / unit).floor() != (to / unit).floor();
    if (!crossed) return;
    for (var i = 0; i < PadId.total; i++) {
      if (_states[i] == PadPlayState.pending) {
        _setState(i, PadPlayState.playing);
      } else if (_states[i] == PadPlayState.stopping) {
        _setState(i, PadPlayState.idle);
      }
    }
  }

  void _maybeStopTransport() {
    if (!_transport.playing) return;
    final anyLoop = List.generate(PadId.total, (i) => i).any(
      (i) => _pads[i].mode == PadMode.loop && _states[i] != PadPlayState.idle,
    );
    if (!anyLoop) {
      _transport = _transport.copyWith(playing: false, beat: 0);
      _emit(TransportEvent(_transport));
    }
  }

  void _setState(int flat, PadPlayState s) {
    if (_states[flat] == s) return;
    _states[flat] = s;
    if (s != PadPlayState.playing) _oneShotEnd[flat] = -1;
    _emit(PadStateEvent(PadId.flat(flat), s));
  }

  // ------------------------------------------------------------- 生命周期

  @override
  Future<EngineInfo> init(AppDirs dirs) async =>
      const EngineInfo(version: '0.0.1-mock', backend: 'mock');

  @override
  Future<AudioStatus> audioStart(AudioConfig cfg) async => AudioStatus(
    running: true,
    sampleRate: cfg.sampleRate ?? 48000,
    bufferFrames: cfg.bufferFrames ?? 128,
    device: cfg.outputDevice ?? 'mock-out',
    latencyMs: (cfg.bufferFrames ?? 128) / (cfg.sampleRate ?? 48000) * 1000,
  );

  @override
  Future<void> audioStop() async {}

  @override
  Future<AudioStatus> audioStatus() async => const AudioStatus(
    running: true,
    device: 'mock-out',
    host: 'mock',
    sampleFormat: 'f32',
    latencyMs: 256 / 48000 * 1000,
  );

  @override
  Future<List<AudioDeviceInfo>> audioDevices() async => const [
    AudioDeviceInfo(id: 'mock-out', name: 'Mock Output', isDefault: true),
    AudioDeviceInfo(id: 'mock-usb', name: 'Mock USB Interface'),
    AudioDeviceInfo(id: 'mock-mic', name: 'Mock Microphone', isInput: true),
  ];

  @override
  EngineSnapshot snapshot() => EngineSnapshot(
    padStates: List.of(_states),
    pads: List.of(_pads),
    transport: _transport,
    kit: _kit,
    recorder: _recorder,
    controllerMode: _controller,
  );

  // ----------------------------------------------------------------- pads

  @override
  void padDown(PadId pad, {double velocity = 1.0}) {
    if (_controller) {
      forwardedPadEvents++;
      if (!_localEcho) return;
    }
    final i = pad.flat;
    final p = _pads[i];
    if (p.isEmpty) return;

    // choke：同组其它 pad 立即停止
    final group = p.chokeGroup;
    if (group != null) {
      for (var j = 0; j < PadId.total; j++) {
        if (j != i &&
            _pads[j].chokeGroup == group &&
            _states[j] != PadPlayState.idle) {
          _setState(j, PadPlayState.idle);
        }
      }
    }

    switch (p.mode) {
      case PadMode.oneShot:
        _states[i] = PadPlayState.idle; // 重新触发
        _setState(i, PadPlayState.playing);
        _oneShotEnd[i] = _now + _sampleDuration(p) / _transport.speed;
      case PadMode.gate:
        _setState(i, PadPlayState.playing);
      case PadMode.loop:
        final s = _states[i];
        if (s == PadPlayState.playing) {
          if (_quantizeActive) {
            _setState(i, PadPlayState.stopping);
          } else {
            _setState(i, PadPlayState.idle);
          }
        } else if (s == PadPlayState.pending || s == PadPlayState.stopping) {
          _setState(i, PadPlayState.idle);
        } else if (_quantizeActive) {
          _setState(i, PadPlayState.pending);
        } else {
          if (!_transport.playing) {
            _transport = _transport.copyWith(playing: true, beat: 0);
            _emit(TransportEvent(_transport));
          }
          _setState(i, PadPlayState.playing);
        }
    }
  }

  /// 已有 loop 在走、且量化开启时，新 loop 进入 Pending 等小节线。
  bool get _quantizeActive =>
      _transport.playing && _transport.quantize != Quantize.none;

  double _sampleDuration(PadParams p) {
    final s = p.sample;
    if (s == null) return 0;
    final info = _sample(s);
    final frames = (p.endFrame ?? info.frames) - p.startFrame;
    return frames / info.sampleRate;
  }

  @override
  void padUp(PadId pad) {
    if (_controller) {
      forwardedPadEvents++;
      if (!_localEcho) return;
    }
    final i = pad.flat;
    if (_pads[i].mode == PadMode.gate) _setState(i, PadPlayState.idle);
  }

  @override
  void send(Command cmd) {
    sentCommands.add(cmd);
    switch (cmd) {
      case PadDownCmd(:final pad, :final velocity):
        padDown(pad, velocity: velocity);
      case PadUpCmd(:final pad):
        padUp(pad);
      case StopAllCmd():
        for (var i = 0; i < PadId.total; i++) {
          _setState(i, PadPlayState.idle);
        }
        _maybeStopTransport();
      case SetTempoCmd(:final bpm):
        _transport = _transport.copyWith(bpm: bpm);
        _emit(TransportEvent(_transport));
      case SetSpeedCmd(:final ratio):
        _transport = _transport.copyWith(speed: ratio.clamp(0.5, 2.0));
        _emit(TransportEvent(_transport));
      case SetQuantizeCmd(:final q):
        _transport = _transport.copyWith(quantize: q);
        _emit(TransportEvent(_transport));
      case SetPadParamsCmd(:final pad, :final params):
        _pads[pad.flat] = params;
      case SetMasterGainCmd(:final gain):
        _masterGain = gain;
      case StartRecordingCmd():
        if (_recorder == RecorderState.idle) {
          _recorder = RecorderState.recording;
          _recStart = _now;
          _emit(RecorderEvent(_recorder, 0));
        }
      case StopRecordingCmd():
        if (_recorder == RecorderState.recording) {
          final elapsed = _now - _recStart;
          _trackCounter++;
          final track = TrackInfo(
            id: 'track-$_trackCounter',
            name: 'TRACK $_trackCounter',
            durationSecs: math.max(elapsed, 1),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              1760000000000 + _trackCounter * 60000,
            ),
            kitName: _kit?.name ?? '',
          );
          _tracks.insert(0, track);
          _recorder = RecorderState.idle;
          _emit(RecorderEvent(_recorder, elapsed, track: track));
          _emit(const LibraryChangedEvent());
        }
      case TransportCmd(:final action, :final beat):
        switch (action) {
          case TransportAction.play:
            _transport = _transport.copyWith(playing: true);
          case TransportAction.stop:
            _transport = _transport.copyWith(playing: false, beat: 0);
          case TransportAction.seek:
            _transport = _transport.copyWith(beat: beat);
        }
        _emit(TransportEvent(_transport));
    }
  }

  // --------------------------------------------------------------- 曲库

  void _applyKit(String id, {bool emit = true}) {
    final kit = _kits[id];
    if (kit == null) throw EngineException(ErrorCode.notFound, id);
    for (var i = 0; i < PadId.total; i++) {
      _pads[i] = kit.doc.pads[i];
      _states[i] = PadPlayState.idle;
      _oneShotEnd[i] = -1;
    }
    _kit = kit.summary.copyWith(downloaded: true);
    _kits[id] = DemoKit(_kit!, kit.doc, kit.samples, kit.tutorial);
    _transport = TransportState(
      bpm: kit.doc.bpm,
      quantize: _transport.quantize,
    );
    if (emit) {
      _emit(KitLoadedEvent(_kit!, List.of(_pads)));
      _emit(TransportEvent(_transport));
    }
  }

  @override
  Future<List<KitSummary>> libraryListKits() async =>
      _kits.values.map((k) => k.summary).toList(growable: false);

  @override
  Future<void> libraryLoadKit(String kitId) async {
    await Future<void>.delayed(Duration.zero);
    _applyKit(kitId);
  }

  @override
  Future<ImportReport> libraryImport(String path) async {
    final name = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;
    final base = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (RegExp(
      r'\.(wav|flac|mp3|ogg|aif|aiff)$',
      caseSensitive: false,
    ).hasMatch(name)) {
      final s = SampleInfo(id: 'import:$name', name: base, durationSecs: 2);
      _extraSamples[s.id] = s;
      _emit(const LibraryChangedEvent());
      return ImportReport(samples: [s]);
    }
    final kit = DemoLibrary.makeKit(
      id: 'imported:$base',
      name: base.toUpperCase(),
      genre: 'pop',
      source: KitSource.imported,
      color: ColorRole.green,
    );
    _kits[kit.summary.id] = kit;
    _emit(const LibraryChangedEvent());
    return ImportReport(kits: [kit.summary]);
  }

  @override
  Future<ImportReport> libraryImportBytes(String name, List<int> bytes) =>
      libraryImport(name);

  @override
  Future<void> libraryExportKit(
    String kitId,
    String path,
    ExportFormat format,
  ) async {
    if (!_kits.containsKey(kitId)) {
      throw EngineException(ErrorCode.notFound, kitId);
    }
  }

  @override
  Future<void> librarySaveKit(KitDoc kit) async {
    final prev = _kits[kit.id];
    final summary =
        prev?.summary.copyWith(name: kit.name) ??
        KitSummary(
          id: kit.id,
          name: kit.name,
          genre: kit.genre,
          bpm: kit.bpm,
          source: KitSource.user,
          padCount:
              kit.pads.lastIndexWhere((p) => !p.isEmpty) + 1 > PadId.padsPerBank
              ? PadId.total
              : PadId.padsPerBank,
        );
    _kits[kit.id] = DemoKit(
      summary,
      kit,
      prev?.samples ?? const [],
      prev?.tutorial,
    );
    if (_kit?.id == kit.id) {
      for (var i = 0; i < PadId.total; i++) {
        _pads[i] = kit.pads[i];
      }
      _emit(KitLoadedEvent(summary, List.of(_pads)));
    }
    _emit(const LibraryChangedEvent());
  }

  @override
  Future<KitDoc> libraryGetKit(String kitId) async {
    final k = _kits[kitId];
    if (k == null) throw EngineException(ErrorCode.notFound, kitId);
    if (_kit?.id == kitId) {
      return KitDoc(
        id: k.doc.id,
        name: k.doc.name,
        pads: List.of(_pads),
        bpm: k.doc.bpm,
        genre: k.doc.genre,
      );
    }
    return k.doc;
  }

  @override
  Future<List<SampleInfo>> libraryKitSamples(String kitId) async {
    final k = _kits[kitId];
    if (k == null) throw EngineException(ErrorCode.notFound, kitId);
    return k.samples;
  }

  // --------------------------------------------------------------- 采样

  SampleInfo _sample(String id) {
    final extra = _extraSamples[id];
    if (extra != null) return extra;
    for (final k in _kits.values) {
      for (final s in k.samples) {
        if (s.id == id) return s;
      }
    }
    return SampleInfo(id: id, name: id, durationSecs: 1.5);
  }

  @override
  Future<SampleInfo> sampleInfo(String sampleId) async => _sample(sampleId);

  @override
  Future<List<double>> sampleWaveform(String sampleId, int buckets) async =>
      DemoLibrary.waveform(sampleId, buckets);

  @override
  Future<void> samplerRecordStart({String? inputDevice}) async {
    _samplerRecording = true;
    _samplerStart = _now;
  }

  @override
  Future<SampleInfo> samplerRecordStop() async {
    if (!_samplerRecording) {
      throw const EngineException(ErrorCode.invalidArgument, 'not recording');
    }
    _samplerRecording = false;
    _micCounter++;
    final s = SampleInfo(
      id: 'mic:$_micCounter',
      name: 'MIC $_micCounter',
      durationSecs: math.max(_now - _samplerStart, 0.5),
    );
    _extraSamples[s.id] = s;
    return s;
  }

  @override
  Future<void> samplePreview(
    String sampleId, {
    int startFrame = 0,
    int? endFrame,
  }) async {
    _sample(sampleId);
    _previewSample = sampleId;
  }

  /// 正在试听的采样（测试可读）。
  String? get previewSample => _previewSample;

  @override
  Future<void> samplePreviewStop() async => _previewSample = null;

  // --------------------------------------------------------------- 作品

  /// 测试辅助：直接插入作品。
  void seedTrack(TrackInfo t) => _tracks.add(t);

  @override
  Future<List<TrackInfo>> tracksList() async => List.unmodifiable(_tracks);

  @override
  Future<void> trackPlay(String trackId, {bool loop = false}) async {
    if (!_tracks.any((t) => t.id == trackId)) {
      throw EngineException(ErrorCode.notFound, trackId);
    }
    _playingTrack = trackId;
    _trackLoop = loop;
    _trackPos = 0;
    _emit(TrackPlaybackEvent(trackId, 0));
  }

  @override
  Future<void> trackStop() async {
    final id = _playingTrack;
    _playingTrack = null;
    _emit(TrackPlaybackEvent(id, 0, playing: false));
  }

  @override
  Future<void> trackExport(
    String trackId,
    String path,
    ExportFormat format,
  ) async {
    if (!_tracks.any((t) => t.id == trackId)) {
      throw EngineException(ErrorCode.notFound, trackId);
    }
  }

  @override
  Future<void> trackDelete(String trackId) async {
    _tracks.removeWhere((t) => t.id == trackId);
    if (_playingTrack == trackId) _playingTrack = null;
    _emit(const LibraryChangedEvent());
  }

  @override
  Future<void> trackRename(String trackId, String name) async {
    final i = _tracks.indexWhere((t) => t.id == trackId);
    if (i < 0) throw EngineException(ErrorCode.notFound, trackId);
    final t = _tracks[i];
    _tracks[i] = TrackInfo(
      id: t.id,
      name: name,
      durationSecs: t.durationSecs,
      createdAt: t.createdAt,
      kitName: t.kitName,
    );
    _emit(const LibraryChangedEvent());
  }

  // --------------------------------------------------------------- 教程

  @override
  Future<TutorialChart?> tutorialGet(String kitId) async =>
      _kits[kitId]?.tutorial;

  // ----------------------------------------------------------------- Hub

  void _hubEmit(HubEvent e) => _emit(HubEventWrapper(e));

  @override
  Future<HubServerStatus> hubStartServer(String name) async {
    _hub = HubServerStatus(
      running: true,
      id: 'mock-hub-id',
      name: name,
      port: 47100,
      udpPort: 47101,
      addresses: const ['192.168.1.10:47100'],
      advertising: true,
    );
    _hubEmit(HubServerChanged(_hub));
    return _hub;
  }

  @override
  Future<void> hubStopServer() async {
    _hub = const HubServerStatus(running: false);
    _pairingCode = null;
    _hubEmit(HubServerChanged(_hub));
  }

  @override
  Future<HubServerStatus?> hubServerInfo() async => _hub.running ? _hub : null;

  @override
  Future<PairingCode> hubNewPairingCode() async {
    if (!_hub.running) {
      throw const EngineException(ErrorCode.busy, '[closed] hub not running');
    }
    final code = (100000 + (_hub.name.hashCode.abs() % 900000)).toString();
    return _pairingCode = PairingCode(
      code: code,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(1760000000000 + 5 * 60000),
      ttl: const Duration(minutes: 5),
    );
  }

  /// 当前配对码（测试可读）。
  PairingCode? get pairingCode => _pairingCode;

  @override
  Future<void> hubCancelPairing() async => _pairingCode = null;

  @override
  Future<PairingCode?> hubPairingCode() async => _pairingCode;

  @override
  Future<List<PairedDevice>> hubTrustedDevices() async =>
      _trusted.values.toList().reversed.toList(growable: false);

  @override
  Future<bool> hubRevoke(String deviceId) async {
    final had = _trusted.remove(deviceId) != null;
    final peer = _knownPeers[deviceId];
    if (peer != null) _knownPeers[deviceId] = peer.copyWith(paired: false);
    return had;
  }

  @override
  Future<List<ControllerSession>> hubControllerStats() async => const [];

  @override
  Future<void> hubSetDeviceName(String name) async => _deviceName = name;

  /// 配对时发送的本机名（测试可读）。
  String get deviceName => _deviceName;

  @override
  Future<String> hubDeviceId() async => 'mock-device-id';

  @override
  Stream<HubPeerEvent> hubDiscover() {
    _discovery?.close();
    final c = _discovery = StreamController<HubPeerEvent>();
    () async {
      for (final p in DemoLibrary.peers) {
        await Future<void>.delayed(
          realtime ? const Duration(milliseconds: 400) : Duration.zero,
        );
        if (c.isClosed) return;
        final known = _knownPeers[p.id] ?? p;
        _knownPeers[p.id] = known;
        c.add(HubPeerFound(known));
      }
    }();
    return c.stream;
  }

  @override
  Future<void> hubDiscoverStop() async {
    await _discovery?.close();
    _discovery = null;
  }

  @override
  Future<HubPeer> hubProbe(String address) async {
    final host = address.split(':').first;
    if (!RegExp(r'^[\w.-]+$').hasMatch(host) || host.isEmpty) {
      throw const EngineException(ErrorCode.invalidArgument, '[invalid_input]');
    }
    final port = address.contains(':')
        ? int.tryParse(address.split(':').last) ?? 47100
        : 47100;
    final peer = HubPeer(
      id: 'probe:$host',
      name: host,
      address: host,
      port: port,
      addresses: ['$host:$port'],
      paired: _trusted.containsKey('probe:$host'),
    );
    return _knownPeers[peer.id] = peer;
  }

  @override
  Future<List<HubPeer>> hubKnownPeers() async =>
      _knownPeers.values.toList(growable: false);

  @override
  Future<PairedDevice> hubPair(HubPeer peer, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const EngineException(
        ErrorCode.pairingFailed,
        '[pairing_failed] bad code',
      );
    }
    final device = PairedDevice(
      id: peer.id,
      name: peer.name,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );
    _trusted[peer.id] = device;
    _knownPeers[peer.id] = peer.copyWith(paired: true);
    _hubEmit(HubPeerPaired(device));
    return device;
  }

  @override
  Future<bool> hubForget(String peerId) => hubRevoke(peerId);

  @override
  Future<SyncReport> hubSync(HubPeer peer) async {
    _hubEmit(HubSyncStarted(peer.id));
    for (var done = 1; done <= 3; done++) {
      _hubEmit(HubSyncProgress(peer.id, done, 4));
      await Future<void>.delayed(Duration.zero);
    }
    const report = SyncReport(
      pulled: 3,
      pushed: 1,
      bytes: 4 << 20,
      downloadedBlobs: 3,
      uploadedBlobs: 1,
    );
    _hubEmit(HubSyncProgress(peer.id, 4, 4));
    _hubEmit(HubSyncFinished(peer.id, report));
    _emit(const LibraryChangedEvent());
    return report;
  }

  @override
  Future<HubControllerStatus> hubControllerConnect(HubPeer peer) async {
    _controller = true;
    _controllerPeer = peer;
    _hubEmit(HubControllerChanged(connected: true, peer: peer));
    return hubControllerStatus();
  }

  @override
  Future<void> hubControllerDisconnect() async {
    _controller = false;
    final peer = _controllerPeer;
    _controllerPeer = null;
    _hubEmit(HubControllerChanged(connected: false, peer: peer));
  }

  @override
  HubControllerStatus hubControllerStatus() => HubControllerStatus(
    connected: _controller,
    peerId: _controllerPeer?.id,
    peerName: _controllerPeer?.name,
    localEcho: _localEcho,
    rttMs: _controller ? 1.2 : null,
  );

  @override
  void hubControllerSetLocalEcho(bool enabled) => _localEcho = enabled;

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _discovery?.close();
    await _events.close();
  }
}
