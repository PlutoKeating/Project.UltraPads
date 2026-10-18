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

## 4. Hub 协议（局域网，`runtime/up-hub`）

设计决策见 `docs/adr/0004-personal-hub.md`。协议版本 `v=1`（mDNS TXT、`/v1/info`、UDP 报文 `ver` 三处一致）。

### 4.1 身份

- 每台设备一对 Ed25519 密钥，私钥种子存于数据目录 `identity.key`（0600），受信设备列表存于 `trusted.json`
- **设备 ID** = 公钥的小写 RFC 4648 base32（无填充，52 字符）
- **blob 地址** = BLAKE3-256 的 64 位小写十六进制

### 4.2 发现（mDNS / DNS-SD）

- 服务类型 `_ultrapads._tcp.local.`，实例名 `<设备名> (<ID 前 8 位>)`
- TXT：`v=1`、`id=<设备 ID>`、`name=<设备名>`、`port=<控制面 TCP 端口>`
- TXT 中的 `id` 只是声称；连接时以 TLS 公钥钉扎为准。Hub 绑定 IPv4 时只广播 IPv4 地址
- Android 需持有 `WifiManager.MulticastLock`（见 ADR-0004 §Android）

### 4.3 控制面传输与鉴权

- **TLS 1.3（rustls + ring）+ HTTP/1.1 JSON**（axum）。证书由设备 Ed25519 密钥自签，不用 CA
- 客户端按 Hub 设备 ID **钉扎**服务端证书公钥；客户端必须出示自己的证书（双向 TLS），Hub 从证书取出调用者设备 ID
- 授权：除 `GET /v1/info`、`POST /v1/pair/*` 外，调用者必须在 Hub 的受信列表中，否则 `403 {"error":"not_paired"}`
- 错误体统一为 `{ "error": <code>, "message": <text>, "expected_offset"?: u64, "missing"?: [hash] }`

| 方法与路径 | 鉴权 | 请求 | 响应 |
|---|---|---|---|
| `GET /v1/info` | 任意证书 | — | `{ v, id, name, version, paired, pairing_open }`；客户端核对 `id` == TLS 公钥 |
| `POST /v1/pair/start` | 任意证书 | `{ name, spake: b64(SPAKE2 A 消息) }` | `{ pair_id, spake: b64(B 消息), confirm: b64(HMAC(K,"hub"‖T)) }`；无有效配对码 `410 pairing_closed` |
| `POST /v1/pair/finish` | 同一证书 | `{ pair_id, confirm: b64(HMAC(K,"device"‖T)) }` | `{ hub_id, hub_name }`；码错误 `403 pairing_failed`，会话未知 `404 unknown_pair` |
| `GET /v1/manifest` | 已配对 | — | `LibraryManifest` |
| `POST /v1/manifest/merge` | 已配对 | `{ manifest }` | `{ manifest, conflicts: [id], changed }`；引用了 Hub 缺失的 blob 时 `409 missing_blobs` + `missing` |
| `POST /v1/blobs/missing` | 已配对 | `{ hashes: [hash] }`（≤ 100000） | `{ missing: [{ hash, offset }] }`，`offset` = Hub 已有的部分字节数 |
| `GET /v1/blob/{hash}` | 已配对 | 可选 `Range: bytes=N-` | `200`/`206` 流式字节，头 `x-up-blob-size`；越界 `416` |
| `PUT /v1/blob/{hash}` | 已配对 | 流式字节，可选 `x-up-offset: N`（续传） | `201 {hash,size,status:"stored"}`；已存在 `200 status:"exists"`；偏移不符 `409 offset_mismatch` + `expected_offset`；内容与哈希不符 `422 hash_mismatch`（部分数据丢弃）；超限 `413` |
| `POST /v1/controller/open` | 已配对 | `{}` | `{ session_id: u32, key: b64(32B), udp_port, ping_interval_ms, idle_timeout_ms }` |
| `POST /v1/controller/close` | 已配对 | `{ session_id }` | `204` |

### 4.4 配对（6 位一次性码 + SPAKE2）

1. Hub 生成 6 位数字码（默认 5 分钟有效、最多 5 次尝试、成功一次即作废），在桌面 UI 显示
2. 手机：`SPAKE2-Ed25519`，A 身份 `ultrapads/pair/device`、B 身份 `ultrapads/pair/hub`，口令 = 配对码
3. `T = "ultrapads/pair/v1" ‖ HubID(32B) ‖ DeviceID(32B) ‖ len(msgA) u32be ‖ msgA ‖ len(msgB) u32be ‖ msgB`，两侧的 HubID/DeviceID 均取自 TLS 证书
4. 手机先校验 Hub 的 `confirm`（不符即"配对码错误或中间人"），再发送自己的 `confirm`；Hub 校验通过后把手机写入受信列表，手机把 Hub 写入受信列表

### 4.5 曲库清单与同步

`LibraryManifest = { schema: 1, entries: [ManifestEntry] }`；
`ManifestEntry = { id, kind: kit|sample|track|project, name, blobs: [{hash, size, role}], modified_at_ms, origin: 设备ID, version: {设备ID: u64}, deleted, conflict_of?, meta: JSON }`。
曲库每次修改条目必须调用 `ManifestEntry::touch(本机ID)`（递增版本向量并更新时间与来源设备）。

合并规则（交换律、幂等，任意两端结果一致）：版本向量一方支配 → 取新者；并发且内容相同 → 合并版本向量；并发且内容不同 → `modified_at_ms`、`origin`、内容摘要依次比较取最后写入者，败者保留为 `"<id>~conflict~<摘要前 12 位 hex>"`，`conflict_of = <id>`（败者为删除墓碑时不保留）。

同步（客户端驱动，`HubClient::sync`）：
1. `GET /v1/manifest`，与本地合并得到 M
2. 下载 M 引用、本地缺失的 blob（本地有部分数据则 `Range` 续传）
3. `POST /v1/blobs/missing`，上传 Hub 缺失的 blob（按返回的 `offset` 续传）
4. `POST /v1/manifest/merge {M}`；收到 `409 missing_blobs`（期间有第三台设备写入）则重来一轮（最多 4 轮）
5. 把 Hub 返回的清单合并回本地；**清单只在其引用的 blob 全部就位后写入**，任何一步中断后重跑只传缺失部分
6. 返回 `SyncReport { uploaded_blobs, uploaded_bytes, downloaded_blobs, downloaded_bytes, resumed_blobs, conflicts, conflict_ids, local_changed, remote_changed, duration_ms }`

### 4.6 控制器数据面（UDP）

报文（大端）：

```text
0   u8   ver = 1
1   u8   kind      1=PadDown 2=PadUp 3=StopAll 4=Ping 5=Pong 6=Close
2   u32  seq       每个会话、每个方向从 1 递增
6   u32  session   /v1/controller/open 返回的 session_id
10  ..   payload   PadDown{bank u8, index u8, vel u8(0..=127)} | PadUp{bank u8, index u8} | Ping/Pong{t_us u64} | 空
end 16B  tag       HMAC-SHA256(会话密钥, 前面所有字节) 的前 16 字节
```

- 发送端：pad 事件每个 `seq` 连发 2 次；每 `ping_interval_ms`（默认 1000）发 Ping 兼保活；关闭时连发 2 次 Close
- 接收端：HMAC 校验 → 1024 位滑动窗口去重/防重放 → 同一 pad 上 `seq` 小于已应用事件或早于最近 StopAll 的事件作废（避免"抬起先到、按下后到"造成挂音）；不同 pad 的乱序事件立即应用
- Hub 对 Ping 回 Pong（回显 `t_us`），客户端据此统计 RTT（`LatencyStats`，单程估计 = RTT 中位数 / 2）
- 会话关闭、空闲超时（默认 10 s）、设备被撤销或 Hub 停止时，Hub 对仍按住的 pad 补发 `pad_up`
- 会话密钥 32 字节随机数，只经 TLS 下发；同一设备同时只有一个会话

### 4.7 Rust API（供 `bridge/up-ffi` 暴露给 Dart）

| Rust | 对应 FFI（§3） |
|---|---|
| `HubServer::start(HubConfig, Arc<dyn LibraryStore>, Arc<dyn PadSink>) -> HubServer` / `stop()` | `hub_start_server` / `hub_stop_server` |
| `HubServer::new_pairing_code() -> PairingCode { code, expires_at }`、`trusted_devices()`、`revoke(id)`、`controller_stats()` | 桌面配对界面 |
| `HubClient::new(ClientConfig)`、`discover() -> Discovery: Stream<DiscoveryEvent::{Found(HubPeer), Lost(DeviceId)}>` | `hub_discover` |
| `HubClient::probe(PeerAddr) -> (HubPeer, InfoResponse)` | 手动输入 IP / 扫码 |
| `HubClient::pair(&HubPeer, code) -> TrustedDevice` | `hub_pair` |
| `HubClient::sync(&HubPeer, &dyn LibraryStore) -> SyncReport` | `hub_sync` |
| `HubClient::controller_connect(&HubPeer) -> ControllerHandle`；`pad_down/pad_up/stop_all`（同步、非阻塞）、`latency()`、`close()` | `hub_controller_connect` / `hub_controller_disconnect` |

由上层实现的 trait：`LibraryStore`（up-library 实现，参考实现 `FsLibraryStore`）、`PadSink`（接到引擎 `pad_down/pad_up/stop_all`，调用在 Hub 的 UDP 任务上，必须非阻塞）、`HubTransport`（v0.0.1 只有 `LanTransport`，iroh 预留）。

## 5. 曲库（`runtime/up-library`）与格式层（`engine/up-format`）Rust API

供 `bridge/up-ffi` 的 `library_*` / `tracks_*` / `sample_*` 接线。`Library` 内部加锁，方法都取 `&self`，放进 `Arc` 共享；不得在音频线程调用。

| Rust API | 对应 FFI | 说明 |
|---|---|---|
| `Library::open(root) -> Library` / `open_with(root, LibraryOptions)` | `init` | 数据根目录布局见 `docs/ARCHITECTURE.md` §8；`LibraryOptions { limits: ImportLimits, compat_sources }` |
| `list_kits(&KitQuery) -> Vec<KitSummary>` | `library_list_kits` | `KitQuery { text, genre, favorites_only, used_only, sort: Name/RecentlyUsed/RecentlyAdded/Favorited, limit }`；`KitSummary::to_protocol()` 转 `up_protocol::KitSummary` |
| `genres()` / `recent_kits(n)` / `set_favorite(id, bool)` / `mark_used(id)` / `delete_kit(id)` | | 曲风筛选、最近使用、收藏 |
| `load_kit_assets(id) -> LoadedKit` / `load_kit_assets_with(id, LoadOptions)` | `library_load_kit` | `LoadedKit { doc: up_format::KitDoc, model: up_model::KitDoc, summary, samples: 包内路径 → LoadedSample { sample_id, file, sample_rate, channels, frames, pcm: Option<DecodedPcm> }, warnings }`；`model` 中 `SampleRef.id` = BLAKE3 = `LoadedSample.sample_id`；`pcm` 为交错 f32；会记为最近使用 |
| `kit_model(id) -> up_model::KitDoc` / `save_kit_model(&up_model::KitDoc) -> KitSummary` | `library_current_kit_json` / `library_save_kit` | 保存时合并到原 Kit，保留模型表达不了的力度层/轮替/非对称 choke/教程；新采样用 `SampleRef.blake3`（或 `id`）引用曲库样本 |
| `kit_doc(id)` / `save_kit(&up_format::KitDoc)` / `kit_package(id)` / `kit_manifest(id)` / `kit_tutorials(id)` | | 完整格式层文档（`.upkit` 无损） |
| `import(path) -> ImportReport` / `import_zip_bytes(name, bytes)` / `import_fs(&dyn SourceFs, force_upkit)` | `library_import` | 自动识别：原 App 素材（多来源，见下）→ `.upkit`（ZIP/文件夹）→ SFZ → 音频文件夹；单个 `.wav` 作为样本入库。`ImportReport { kind, kits: [ImportedKit { kit_id, name, pad_count, pads_used, duplicate }], samples, catalog_entries, warnings }` |
| `export_kit(id, dest, ExportFormat)` | `library_export_kit` | `ExportFormat::parse("upkit"/"upkit-folder"/"sfz"/"dawproject")` |
| `catalog_entries(source)` / `catalog_categories(source)` | | 外部目录（原 App list.json / fetch.json）：`CatalogEntry { status: NotDownloaded / Downloaded{kitId}, genres, tags, difficulty, themeColor, videoUrl, … }` |
| `add_sample(bytes, name, SampleOrigin)` / `add_sample_file(path, origin)` / `list_samples()` / `sample_path(id)` / `delete_sample(id)` | `sampler_record_stop` | 麦克风录音/导入的样本入库（内容寻址，`SampleId` = BLAKE3） |
| `sample_waveform(id, buckets) -> Vec<f32>` | `sample_waveform` | 峰值概要 |
| `tracks_list()` / `track_add(bytes, name, kit, bpm)` / `track_add_file` / `track_rename` / `track_delete` / `track_export(id, dest, TrackExportFormat::{Wav, DawProject})` / `track_to_sample(id)` / `track_path(id)` | `tracks_*` / `track_export` / `track_delete` | 录音作品；WAV 导出写 BWF `bext` |
| `hub_store::LibraryHubStore::new(Arc<Library>, DeviceId)` | `hub_start_server` / `hub_sync` | 实现 `up_hub::LibraryStore`（feature `hub`，默认开）：Kit/样本/作品 ↔ 清单条目，blob = 内容寻址存储 |

原 App 素材导入器是可插拔的 `CompatSource`（`detect` + `import(emit)`）：内置 `compat-android`（APK 3.x：WAV + `list.json` + 顺序教程）与 `compat-ios`（IPA 4.x：Ogg/MP3 入库时转 WAV + `fetch.json`/`fetch_next.json` + 计时教程 `tutorial.json` + 分课 `<id>_lesson.json`）。`library_import("private-assets/compat-ios")` 一次导入全部 6 个内置 Kit 并合并 1259 个目录条目。

格式层（无 I/O）：`up_format::sfz`（解析/白名单/序列化，`#include` 走 `IncludeResolver` 回调）、`kit_json` / `manifest` / `tutorial`（serde 模型，Schema 在 `content/schema/`）、`wav`（`smpl`/`acid`/`inst`/`cue `/`bext` 读写、PCM 编解码、loop/BPM 推断）、`smf`（教程谱）、`upkit`（`KitDoc` ↔ 包）、`model`（`KitDoc` ↔ `up_model::KitDoc`）、`dawproject`（DAWproject 1.0 导出，官方 XSD 在 `content/schema/dawproject/`）。
