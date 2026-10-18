# UltraPads API 契约

本文件定义三层之间的接口：引擎协议（`engine/up-protocol`）、FFI 面（`bridge/up-ffi`，经 flutter_rust_bridge 暴露给 Dart），以及 Hub 网络协议（`runtime/up-hub`）。
**修改接口必须同步修改本文档。**

## 1. 基本约定

- 采样时间用 `u64` 帧数；音乐时间用 `f64` 拍（beat），小节由拍号换算
- Pad 编址：`PadId { bank: u8 /*0=A,1=B*/, index: u8 /*0..11*/ }`；平铺下标 = `bank*12 + index`
- 资源 ID：`SampleId`、`KitId`、`TrackId`、`ProjectId` 一律为 BLAKE3 内容哈希或 UUIDv7 字符串
- 所有 FFI 函数返回 `Result<T, UpError>`；`UpError { code: ErrorCode, message: String }`
- 标注 `#[frb(sync)]` 的函数在 UI 线程同步执行，**只允许推送无锁命令**，不得阻塞

## 2. 引擎协议（up-protocol）

```rust
pub enum Command {
    PadDown { pad: PadId, velocity: f32 },
    PadUp { pad: PadId },
    StopAll,
    SetTempo { bpm: f64 },
    SetSpeed { ratio: f64 },            // 0.5..=2.0，界面上的 1.0x
    SetQuantize { q: Quantize },        // None | Beat | Bar
    SetPadParams { pad: PadId, params: PadParams },
    SetMasterGain { gain: f32 },
    StartRecording, StopRecording,
    Transport(TransportCmd),            // Play | Stop | Seek(beat)
}

pub enum PadMode { OneShot, Loop, Gate }

pub struct PadParams {
    pub mode: PadMode,
    pub gain: f32,
    pub pan: f32,
    pub choke_group: Option<u8>,
    pub color: ColorRole,               // 引用 token 角色，不是 RGB
    pub sample: Option<SampleId>,
    pub start_frame: u64, pub end_frame: Option<u64>,
    pub quantize_override: Option<Quantize>,
}

pub enum PadPlayState { Idle, Pending, Playing, Stopping }

pub enum EngineEvent {
    PadState { pad: PadId, state: PadPlayState },
    Transport { playing: bool, beat: f64, bpm: f64, bar_len_beats: f64 },
    Meters { master_peak: [f32; 2], master_rms: [f32; 2], pad_levels: Vec<f32> /*24*/ },
    Recorder { state: RecorderState, elapsed_secs: f64 },
    KitLoaded { kit: KitSummary },
    LibraryChanged,
    Hub(HubEvent),
    Error(UpError),
}
```

- 事件以约 60Hz 合并推送：Meters 只保留最新值；PadState 和 Transport 变化立即排队。

## 3. FFI 面（bridge/up-ffi → Dart `package:up_engine`）

| 函数 | 同步 | 说明 |
|---|---|---|
| `init(app_dirs: AppDirs) -> EngineInfo` | | 初始化存储根目录和日志 |
| `audio_start(cfg: AudioConfig) -> AudioStatus` | | `AudioConfig { buffer_frames: Option<u32>, sample_rate: Option<u32>, output_device: Option<String> }` |
| `audio_stop()` | | |
| `audio_devices() -> Vec<AudioDeviceInfo>` | | |
| `events() -> Stream<EngineEvent>` | | FRB `StreamSink` |
| `snapshot() -> EngineSnapshot` | ✅ | 全部 pad 状态、transport、当前 kit |
| `pad_down(bank, index, velocity)` / `pad_up(bank, index)` | ✅ | 热路径 |
| `send(cmd: Command)` | ✅ | 通用命令 |
| `library_list_kits() -> Vec<KitSummary>` | | |
| `library_load_kit(kit: KitId)` | | 解码 + 交给引擎；完成后推送 `KitLoaded` |
| `library_import(path: String) -> ImportReport` | | 支持原生 Kit 包、SFZ、WAV 文件夹、原 App 素材目录 |
| `library_export_kit(kit, path, format)` | | |
| `library_save_kit(kit: KitDoc)` | | 编辑 Kit 后保存 |
| `sample_waveform(sample, buckets: u32) -> Vec<f32>` | | 峰值概要，供 UI 绘制 |
| `sampler_record_start(input_device: Option<String>)` / `sampler_record_stop() -> SampleId` | | 麦克风采样 |
| `tracks_list() -> Vec<TrackInfo>` / `track_play(id)` / `track_stop()` / `track_export(id, path, fmt)` / `track_delete(id)` | | 录音作品 |
| `tutorial_get(kit) -> Option<TutorialChart>` | | 教程谱 |
| `hub_start_server(name)` / `hub_stop_server()` | | 桌面 Hub |
| `hub_discover() -> Stream<HubPeer>` | | mDNS 发现 |
| `hub_pair(peer, code) -> PairedDevice` | | |
| `hub_sync(peer) -> SyncReport` | | 增量同步曲库 |
| `hub_controller_connect(peer)` / `hub_controller_disconnect()` | | 手机变成远端打击垫，之后 `pad_down/up` 改为转发 |

Dart 侧：`package:up_engine` 导出 `abstract class EngineClient`，提供 `FfiEngineClient`（FRB）和 `MockEngineClient`（UI 开发和 golden test 用）两种实现。

## 4. Hub 协议（局域网）

- 发现：mDNS 服务 `_ultrapads._tcp.local`，TXT 记录：`v=1`、`id=<device pubkey b32>`、`name=<设备名>`
- 控制面：HTTP/1.1 JSON（axum），端口取自 TXT 记录
  - `POST /v1/pair { code, device_pubkey, name } -> { hub_pubkey, token }`
  - `GET /v1/manifest -> LibraryManifest`（需 `Authorization: Bearer`）
  - `GET /v1/blob/{blake3}` / `PUT /v1/blob/{blake3}`
  - `POST /v1/manifest/merge { manifest } -> MergeResult`
- 控制器数据面：UDP，报文 = `[u8 ver=1][u8 kind][u32 seq][payload]`，kind：`1=PadDown{bank,index,vel_u8}`、`2=PadUp`、`3=StopAll`；同一 `seq` 发送 2 次以抗丢包，接收端去重
