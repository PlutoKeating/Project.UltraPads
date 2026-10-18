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

  /// 当前音频设备状态（`audio_status`）。
  Future<AudioStatus> audioStatus();
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

  /// 从内存字节导入（`.upkit` / ZIP；打包在应用资源里的内置 Kit）。
  Future<ImportReport> libraryImportBytes(String name, List<int> bytes);
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

  /// 试听采样（编辑页）：在试听声部播放，不占用 pad。
  Future<void> samplePreview(
    String sampleId, {
    int startFrame = 0,
    int? endFrame,
  });

  /// 停止试听。
  Future<void> samplePreviewStop();

  // ---- 作品 ----
  Future<List<TrackInfo>> tracksList();
  Future<void> trackPlay(String trackId, {bool loop = false});
  Future<void> trackStop();
  Future<void> trackExport(String trackId, String path, ExportFormat format);
  Future<void> trackDelete(String trackId);
  Future<void> trackRename(String trackId, String name);

  // ---- 教程 ----
  Future<TutorialChart?> tutorialGet(String kitId);

  // ---- Hub（API.md §3.1）----
  /// 启动本机 Hub（TLS 控制面 + 控制器 UDP + mDNS 广播）。
  Future<HubServerStatus> hubStartServer(String name);
  Future<void> hubStopServer();

  /// 正在运行的 Hub；未运行时为 null。
  Future<HubServerStatus?> hubServerInfo();

  /// 新的 6 位一次性配对码（作废旧码）。
  Future<PairingCode> hubNewPairingCode();
  Future<void> hubCancelPairing();

  /// 当前仍有效的配对码（重新打开 Hub 页时显示）；没有时为 null。
  Future<PairingCode?> hubPairingCode();

  /// 受信设备（新→旧）。
  Future<List<PairedDevice>> hubTrustedDevices();

  /// 撤销信任；返回之前是否受信。
  Future<bool> hubRevoke(String deviceId);

  /// 本机 Hub 上的远端控制器会话。
  Future<List<ControllerSession>> hubControllerStats();

  /// 配对时发送给 Hub 的本机名。
  Future<void> hubSetDeviceName(String name);
  Future<String> hubDeviceId();

  /// mDNS 发现；同一时刻只有一个会话，用 [hubDiscoverStop] 停止。
  Stream<HubPeerEvent> hubDiscover();
  Future<void> hubDiscoverStop();

  /// 手动输入地址（`ip`、`ip:port`、`host[:port]`）。
  Future<HubPeer> hubProbe(String address);

  /// 本次发现 / 探测到的与以前配对过的 Hub。
  Future<List<HubPeer>> hubKnownPeers();
  Future<PairedDevice> hubPair(HubPeer peer, String code);

  /// 本地取消对某 Hub 的信任。
  Future<bool> hubForget(String peerId);
  Future<SyncReport> hubSync(HubPeer peer);
  Future<HubControllerStatus> hubControllerConnect(HubPeer peer);
  Future<void> hubControllerDisconnect();

  /// 同步读取（热路径可调用）。
  HubControllerStatus hubControllerStatus();

  /// 控制器模式下本机是否同时发声（默认关）。
  void hubControllerSetLocalEcho(bool enabled);

  // ---- 应用内更新（docs/API.md §6） ----
  /// 当前应用版本（`X.Y.Z`）。
  String get appVersion;

  /// 查询最新正式版；`site` 为空时用正式站点。只发 GET，不上报设备信息。
  Future<UpdateInfo> updateCheck({String? site});

  /// 下载最近一次 [updateCheck] 找到的发布包，以 [UpdateReady] / [UpdateFailed] 结束。
  Stream<UpdateProgress> updateDownload();
  void updateCancel();

  /// Linux（[UpdateInstallMode.selfUpdate]）：装入下载好的包并切换版本。
  Future<void> updateApply(String path);

  /// Linux：约 1 秒后启动新版本；调用方随即停止音频并退出。
  Future<void> updateRelaunch();

  /// 释放资源。
  Future<void> dispose();
}
