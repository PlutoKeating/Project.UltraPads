import 'models.dart';
import 'protocol.dart';

/// UI 访问引擎的唯一接口（`docs/API.md` §3）。
///
/// - 引擎是唯一事实源：UI 通过命令改变状态，通过 [events] / [snapshot] 读取。
/// - [padDown] / [padUp] / [send] / [snapshot] 是同步热路径（FRB `sync`），
///   只往无锁队列推命令，必须可以在指针回调里直接调用。
/// - 其它函数都是异步的；尚未实现的函数抛出 [EngineNotImplemented]。
abstract class EngineClient {
  /// 实现名称（`ffi` / `mock`），用于设置页的「关于」。
  String get backendName;

  // ---- 生命周期 / 音频 ----
  Future<EngineInfo> init(AppDirs dirs);
  Future<AudioStatus> audioStart(AudioConfig cfg);
  Future<void> audioStop();
  Future<List<AudioDeviceInfo>> audioDevices();

  // ---- 事件 / 快照 ----
  /// 广播流，约 60Hz 合并推送。
  Stream<EngineEvent> get events;
  EngineSnapshot snapshot();

  // ---- 热路径 ----
  void padDown(PadId pad, {double velocity = 1.0});
  void padUp(PadId pad);
  void send(Command cmd);

  // ---- 曲库 ----
  Future<List<KitSummary>> libraryListKits();
  Future<void> libraryLoadKit(String kitId);
  Future<ImportReport> libraryImport(String path);
  Future<void> libraryExportKit(String kitId, String path, ExportFormat format);
  Future<void> librarySaveKit(KitDoc kit);

  /// 读出某个 Kit 的完整文档，供编辑页使用。
  Future<KitDoc> libraryGetKit(String kitId);

  /// 某个 Kit 内的采样（LOAD SOUND →「其他 Kit / 内置歌曲」）。
  Future<List<SampleInfo>> libraryKitSamples(String kitId);

  // ---- 采样 ----
  Future<List<double>> sampleWaveform(String sampleId, int buckets);
  Future<SampleInfo> sampleInfo(String sampleId);
  Future<void> samplerRecordStart({String? inputDevice});
  Future<SampleInfo> samplerRecordStop();

  /// 试听采样（编辑页）。
  Future<void> samplePreview(
    String sampleId, {
    int startFrame = 0,
    int? endFrame,
  });

  // ---- 作品 ----
  Future<List<TrackInfo>> tracksList();
  Future<void> trackPlay(String trackId, {bool loop = false});
  Future<void> trackStop();
  Future<void> trackExport(String trackId, String path, ExportFormat format);
  Future<void> trackDelete(String trackId);
  Future<void> trackRename(String trackId, String name);

  // ---- 教程 ----
  Future<TutorialChart?> tutorialGet(String kitId);

  // ---- Hub ----
  Future<HubServerStatus> hubStartServer(String name);
  Future<void> hubStopServer();
  Stream<HubPeer> hubDiscover();
  Future<PairedDevice> hubPair(HubPeer peer, String code);
  Future<SyncReport> hubSync(HubPeer peer);
  Future<void> hubControllerConnect(HubPeer peer);
  Future<void> hubControllerDisconnect();

  /// 释放资源。
  Future<void> dispose();
}
