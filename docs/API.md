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
    PadDown { pad: PadId, velocity: f32 },  // velocity 0..=1，增益 = velocity²
    PadUp { pad: PadId },
    StopAll,
    SetTempo { bpm: f64 },                  // 20..=400
    SetSpeed { ratio: f64 },                // 0.5..=2.0；实时变速变调（varispeed），transport 同比缩放
    SetQuantize { q: Quantize },            // 全局量化，默认 None（与原 App 一致：Loop 按下立即从头播）
    SetPadParams { pad: PadId, params: PadParams },
    SetMasterGain { gain: f32 },            // 线性 0..=4
    StartRecording, StopRecording,          // 录制主输出 → TrackSaved
    Transport(TransportCmd),                // Play | Stop | Seek(beat)
}

pub enum PadMode { OneShot, Loop, Gate }    // 原 Kit behaviour 200 / 100 / 300
pub enum Quantize { None, Sixteenth, Eighth, Beat, Bar, TwoBars, FourBars }  // 拍 = 四分音符
pub enum Retrigger { Restart, Continue }     // 正在播放的 one-shot/gate 再按：重新开始 | 忽略

pub struct PadParams {                       // serde 缺省字段取默认值
    pub mode: PadMode,
    pub gain: f32,                           // 线性增益 0..=4（不是 dB）
    pub pan: f32,                            // -1..=1，等功率声像，居中 0 dB
    pub choke_group: Option<u8>,             // 本 pad 所属组（SFZ group）
    pub choked_by: Option<u8>,               // 被哪个组截断（SFZ off_by）；None = 同 choke_group（对称互斥）
    pub choke_release_ms: Option<f32>,       // 被截断时的淡出；None = 5 ms
    pub self_choke: bool,                    // 默认 true：重触发截断自身旧声部（false = one-shot 可叠加）
    pub retrigger: Retrigger,
    pub color: ColorRole,                    // Blue Orange Pink Green Purple Yellow Red Cyan Lime Grey Neutral（token 角色）
    pub sample: Option<SampleId>,            // 必须已注册（已加载 Kit / 麦克风采样 / library_use_sample）
    pub start_frame: u64, pub end_frame: Option<u64>,   // end 为开区间
    pub loop_start: Option<u64>, pub loop_end: Option<u64>, // Loop 模式的循环区（默认 start..end）
    pub quantize_override: Option<Quantize>, // None = Loop 跟随全局，OneShot/Gate 立即
}

pub enum PadPlayState { Idle, Pending, Playing, Stopping }
pub enum RecorderState { Idle, Recording, Saving }

pub enum EngineEvent {
    PadState { pad: PadId, state: PadPlayState },
    Transport { playing: bool, beat: f64, bpm: f64 /*有效 = 基础 × speed*/, bar_len_beats: f64,
                song_secs: f64 /*= beat × 60 / 基础 bpm*/ },
    Meters { master_peak: [f32; 2], master_rms: [f32; 2], pad_levels: Vec<f32> /*24*/ },
    Recorder { state: RecorderState, elapsed_secs: f64 },
    KitLoaded { kit: KitSummary },
    TrackSaved { track: TrackInfo },         // 录音完成并入库（新增）
    TrackPlayback { track: Option<TrackId> },// 作品试听开始 / 结束（新增）
    LibraryChanged,
    Hub(HubEvent),
    Error(UpError),
}

pub struct TransportClock { playing: bool, beat: f64, song_secs: f64, bpm: f64 /*基础*/, speed: f64 }
pub struct EngineSnapshot { pads: Vec<PadSnapshot /*24*/>, transport: TransportState, kit: Option<KitSummary>,
                            master_gain, recorder, recorder_elapsed_secs, sample_rate, active_voices }
pub struct RenderScript { duration_secs: f64, events: Vec<TimedCommand { at_secs: f64, cmd: Command }> }
```

行为规则（对齐 `docs/research/compat-*-analysis.md`）：
- **Loop**：默认不量化，按下立即从头循环，再按停止（≈5 ms 淡出）。量化开启时：`Idle → Pending →`（下一个网格边界，采样级精确）`Playing`；Playing 时再按 → `Stopping`（等边界）→ `Idle`；Pending/等待中的 Stopping 再按可取消。第一个量化 Loop 会从 beat 0 启动 transport，最后一个 Loop 结束后自动停止。
- **One-shot**：再按从头重触发（旧声部 5 ms 淡出）；**Gate**：松手淡出。
- **Choke**：触发 pad X（组 g）时，所有 `choked_by.or(choke_group) == g` 的其它 pad 停止（Loop 也关掉，Pending 取消）。
- **复音**：默认最多 32 个发声声部 + 16 个淡出尾巴；超限时偷取最老的 one-shot/gate（Loop 最后被偷），被偷声部淡出。
- **速度**：`SetSpeed` 对所有声部做 4 点 Hermite 插值变速变调，transport 同比缩放；原 App 的三档 1.0 / 0.7 / 0.5 是推荐预设。离线 pitch/tempo 接口见 `up_dsp::stretch::OfflineStretcher`（后续接 Signalsmith Stretch）。
- 事件约 60 Hz 合并：Meters 只保留最新值（无声时不重复发送）；PadState、Transport、Recorder 变化立即排队（控制线程 4 ms 轮询）。

## 3. FFI 面（bridge/up-ffi → Dart `lib/src/rust/api/*.dart`）

DTO 定义在 `bridge/up-ffi/src/api/types.rs`（与引擎类型一一对应，Dart 侧由 FRB 生成，带数据的枚举用 freezed）。所有函数返回 `Result<T, UpError>`，Dart 中以 `UpError` 异常抛出。

| 函数 | 同步 | 说明 |
|---|---|---|
| `init(app_dirs: AppDirs { data_dir, cache_dir }) -> EngineInfo` | | 创建引擎（48 kHz，`audio_start` 时按设备采样率重建）并打开曲库 `<data_dir>/library`；幂等（热重启后再次调用返回现有实例） |
| `audio_start(cfg: AudioConfig) -> AudioStatus` | | `AudioConfig { buffer_frames: Option<u32> /*默认 256*/, sample_rate: Option<u32>, output_device: Option<String> /*id 或名称*/ }`；`AudioStatus { running, host, device, sample_rate, channels, buffer_frames, sample_format, output_latency_ms }` |
| `audio_stop()` / `audio_status() -> AudioStatus` | | |
| `audio_devices() -> Vec<AudioDeviceInfo>` | | `{ id, name, is_input, is_output, is_default_output, is_default_input, default_sample_rate, max_output_channels, max_input_channels, min/max_buffer_frames }` |
| `events() -> Stream<EngineEvent>` | | 引擎事件与 Hub 事件（`EngineEvent::Hub`，§3.1）合并在同一个流里。每次调用一个独立订阅。**建议在应用生命周期内保持一个订阅；取消时不要 `await sub.cancel()`**——FRB 的 `async*` 流要等到下一个事件才完成取消 |
| `snapshot() -> EngineSnapshot` | ✅ | 无锁读取 |
| `pad_down(bank, index, velocity)` / `pad_up(bank, index)` | ✅ | 热路径：无锁入队（微秒级）。连接为 Hub 控制器时改为转发到 Hub（§3.1） |
| `send(cmd: Command)` | ✅ | 通用命令（无锁）；`PadDown`/`PadUp`/`StopAll` 与 `pad_down` 同样遵循控制器转发规则 |
| `transport_clock() -> TransportClock` | ✅ | 由最近一个音频块外推到“现在”的精确时钟，供教程判定 |
| `tutorial_judge(expected_secs, actual_secs, speed, perfect_ms, miss_ms) -> Judgement` | ✅ | `Perfect` / `TooFast` / `TooSlow` / `Miss`；窗口为真实时间毫秒 |
| `tutorial_get(kit: String) -> Option<TutorialChart>` | | 见下方教程格式 |
| `latency_probe_arm()` / `latency_probe_result() -> Option<[enqueue_to_output_ms, callback_to_playback_ms]>` | ✅ | 实测触摸→出声 |
| `library_list_kits() -> Vec<KitSummary>` | | 按名称排序 |
| `library_search_kits(text, genre, favorites_only, sort: KitSort, limit) -> Vec<KitSummary>` | | `KitSort { Name, RecentlyUsed, RecentlyAdded, Favorited }` |
| `library_genres() -> Vec<String>` / `library_set_favorite(kit, bool) -> KitSummary` / `library_delete_kit(kit)` | | |
| `library_load_kit(kit: String) -> KitSummary` | | 解码 + 重采样 + 交给引擎（先 StopAll），推送 `KitLoaded`。开发便利：若 `kit` 不是曲库 ID 而是一个文件夹路径，则按"音频文件按名排序 → pad"加载 |
| `library_import(path) -> ImportReport` | | `.upkit`（ZIP/文件夹）、SFZ、音频文件夹、单个音频文件（入库为样本）、原 App 素材目录；`ImportReport { kind, kits, duplicates, samples, catalog_entries, warnings }` |
| `library_export_kit(kit, path, format) -> String` | | `format`：`upkit` / `upkit-folder` / `sfz` / `dawproject`；返回写出的路径 |
| `library_save_kit(kit_json: String) -> KitSummary` | | `kit_json` = `up_model::KitDoc` 的 camelCase JSON（避免在 FFI 镜像整套文档模型） |
| `library_current_kit_json() -> Option<String>` / `library_kit_json(kit) -> String` | | 当前 / 任意 Kit 的 `KitDoc` JSON（编辑器读取→修改→`library_save_kit`） |
| `library_list_samples() -> Vec<SampleInfo>` / `library_use_sample(sample)` | | 独立样本（麦克风/导入）；`use` 把样本注册进引擎后即可用 `SetPadParams` 分配 |
| `sample_waveform(sample, buckets) -> Vec<f32>` | | 峰值概要 0..=1（引擎已加载的样本优先，其次曲库） |
| `sampler_record_start(input_device: Option<String>)` / `sampler_record_stop() -> String` | | 麦克风采样（最长 30 s）；停止后存入曲库（`Microphone` 样本）并注册进引擎，返回 `SampleId`（BLAKE3） |
| `tracks_list() -> Vec<TrackInfo>` / `track_play(id)` / `track_stop()` / `track_rename(id, name) -> TrackInfo` / `track_export(id, path, fmt) -> String` / `track_delete(id)` | | 录音作品（曲库 `tracks/`），`fmt`：`wav`（BWF）/ `dawproject`；`TrackInfo.waveform` 为 128 段概要 |
| `hub_*` | | 个人多设备 Hub（`runtime/up-hub`），见 §3.1 |

`KitSummary`（FFI）= 引擎字段 `{ id, name, pad_count, bpm, has_tutorial }` + 曲库字段 `{ description, authors, genres, tags, theme_color, inspired_by, cover_path, favorite, source_kind, last_used_at_ms }`（引擎事件中曲库字段为空）。

**教程格式（`TutorialChart`，时间单位 = 秒，速度 1.0 时的歌曲时间）**

```rust
pub struct TutorialChart {
    events: Vec<TutorialEvent>,      // 按 time_secs 排序
    lessons: Vec<TutorialLesson { events, duration_secs, song_start_secs }>,
    bpm: Option<f64>,
    perfect_ms: f64,                 // 默认 80：|误差| ≤ 80 ms → PERFECT
    miss_ms: f64,                    // 默认 600：超出视为 Miss；其间按早/晚 → TOO FAST / TOO SLOW
    timed: bool,                     // false = 旧版只规定顺序的教程（步骤相隔 1 s）
}
pub struct TutorialEvent { time_secs: f64, pad: Option<PadId>, page_switch: Option<Bank>,
                           color: Option<ColorRole>, action: TutorialAction /* Tap | LoopToggle */ }
```

- 来源：原 App 4.x `tutorial.json` 的 `[{time, pad 1..24 | 100/101, color, state}]`（`state 0` → `LoopToggle`），`<id>_lesson.json` → `lessons`；旧版 3.x `sequence` → `timed=false`。
- 判定：UI 在 `Transport(Play)` 后按下 pad 时读 `transport_clock().song_secs`，与事件 `time_secs` 比较（`tutorial_judge`）。慢速练习时 `SetSpeed { ratio: 0.7 | 0.5 }`：音频变速，`song_secs` 以 `speed × 真实时间` 推进，事件时间无需换算；拖动进度条 = `Transport(Seek(time_secs × bpm / 60))`。

**Android 平台通道**：`MainActivity` 在 `onCreate` 中 `System.loadLibrary("up_ffi")` 并调用 JNI `nativeInit(context)` 初始化 `ndk_context`（cpal/AAudio 需要；Dart 的 `dlopen` 不会触发 `JNI_OnLoad`），同一调用也为 Hub 组播锁保存 JavaVM 与 Context。`onStart`/`onStop` 调用 JNI `nativeSetForeground(bool)`（组播锁见 §3.1）。麦克风权限走 **MethodChannel `dev.ultrapads/permissions`**：`recordAudioStatus` → `"granted" | "denied"`，`requestRecordAudio` → `bool`；在 `sampler_record_start` 之前调用。Manifest 声明 `RECORD_AUDIO`、`INTERNET`、`ACCESS_NETWORK_STATE`、`ACCESS_WIFI_STATE`、`CHANGE_WIFI_MULTICAST_STATE`（后四个为普通权限，无需运行时申请）。

### 3.1 Hub FFI（`bridge/up-ffi/src/api/hub.rs` → `runtime/up-hub`）

- 都需要先 `init()`。设备身份（`identity.key`）、受信列表（`trusted.json`）、记住的 Hub（`peers.json`，只存已配对的 Hub 及其最近地址）、上次的服务端口（`server.json`）存放在 `<data_dir>/hub`。Hub 角色与客户端角色**共用同一个设备身份和同一份受信列表**。
- 曲库通过 `up_library::hub_store::LibraryHubStore` 接入；远端控制器的 pad 事件经 `PadSink` 直接推入引擎无锁命令队列（`EngineHandle::pad_down/pad_up/send(StopAll)`，velocity `0..=127` → `/127`）。
- 标"异步"的函数在 FFI 内一个全局多线程 tokio runtime（2 个 worker，线程名 `up-hub`）上执行：FRB 的 `async fn` 只是 spawn 到该 runtime 并等待 `JoinHandle`，与 FRB 自身的执行器无关。其余非 `sync` 函数在 FRB 线程池上执行，只做短暂加锁/读文件。
- 错误：沿用 `ErrorCode`，`message` 以稳定标签开头：`[not_paired]`（PermissionDenied）、`[pairing_failed]`（PermissionDenied，配对码错误/过期/用尽或中间人）、`[timeout]`/`[tls]`/`[io]`/`[discovery]`/`[store]`（Io）、`[protocol]`/`[hash_mismatch]`（Format）、`[invalid_input]`（InvalidArgument）、`[closed]`/`[busy]`/`[offset_mismatch]`（InvalidState）；Hub 返回的 HTTP 错误以其错误码为标签（如 `[pairing_closed]`）。

| 函数 | 同步 | 说明 |
|---|---|---|
| `hub_start_server(name) -> HubServerInfo` | 异步 | 启动 Hub（TLS 控制面 + 控制器 UDP + mDNS 广播）。端口依次尝试上次端口 → `47100` → 随机。同名再次调用返回现有实例，改名则重启。Android 上自动持有组播锁。推送 `ServerStarted` |
| `hub_stop_server()` | 异步 | 停止（释放远端控制器按住的 pad、释放组播锁），推送 `ServerStopped`；未运行时为 no-op |
| `hub_server_info() -> Option<HubServerInfo>` | | `HubServerInfo { id, name, listen_address /*0.0.0.0:47100*/, port, udp_port, addresses: Vec<"ip:port"> /*本机局域网 IPv4，供手动输入*/, advertising }` |
| `hub_new_pairing_code() -> PairingCode` | | `{ code /*6 位*/, expires_unix_ms, ttl_secs }`；默认 5 分钟、5 次尝试，作废旧码。设备用此码配对成功后推送 `Paired { id, name }` |
| `hub_cancel_pairing()` | | 关闭配对窗口 |
| `hub_trusted_devices() -> Vec<PairedDevice>` / `hub_revoke(id) -> bool` | | 受信设备（新→旧；含作为客户端配对过的 Hub）/ 撤销（Hub 运行时立即关闭其控制器会话，之后请求一律 403） |
| `hub_controller_stats() -> Vec<ControllerSessionStats>` | | `{ session_id, device_id, name, packets, accepted_events, duplicates, reordered_dropped, too_old, bad_mac, idle_ms, held_pads }`；Hub 未运行时为空 |
| `hub_set_device_name(name)` / `hub_device_id() -> String` | | 配对时发送给 Hub 的本机名（默认：已启动 Hub 的名字，否则 `UltraPads <os>`）/ 本机设备 ID |
| `hub_discover() -> Stream<HubPeerEvent>` | | mDNS 浏览：`Found(HubPeer)` / `Lost { id }`（同时推送 `PeerDiscovered`/`PeerLost`）。同一时刻只有一个发现会话，再次调用会结束上一个流。**用 `hub_discover_stop()` 停止**（仅取消 Dart 订阅要等到下一个事件才会被察觉）；Android 上发现期间持有组播锁 |
| `hub_discover_stop()` | | 停止发现并释放组播锁 |
| `hub_probe(address) -> HubPeer` | 异步 | 手动输入地址：`ip`、`ip:port`、`[v6]:port`、`host[:port]`，缺省端口 `47100`；身份取自 TLS 证书并与 `/v1/info` 核对 |
| `hub_known_peers() -> Vec<HubPeer>` | | 本次发现/探测到的与以前配对过的 Hub（已配对在前） |
| `hub_pair(peer, code) -> PairedDevice` | 异步 | `peer` = 发现/探测得到的设备 ID（也可直接给地址，先自动 probe）。成功后推送 `Paired`，并写入 `peers.json` |
| `hub_forget(peer) -> bool` | 异步 | 本地取消对某 Hub 的信任 |
| `hub_sync(peer) -> SyncReport` | 异步 | 双向增量同步（同一时刻只跑一个）。事件：`SyncStarted` → `SyncProgress{done,total}`* → `SyncFinished{report}`；失败时抛出并推送 `Error{op:"sync"}`；本地曲库有变化时推送 `LibraryChanged`。Hub 一侧在客户端合并改动了本机曲库时也推送 `LibraryChanged` |
| `hub_controller_connect(peer) -> HubControllerStatus` | 异步 | 成为该 Hub 的远端打击垫（替换已有连接），推送 `ControllerConnected { peer }` |
| `hub_controller_disconnect()` | 异步 | 断开，推送 `ControllerDisconnected`；之后 pad 恢复本地发声 |
| `hub_controller_status() -> HubControllerStatus` | ✅ | `{ connected, peer, peer_name, session_id, local_echo, latency: Option<HubLatency { samples, pings_sent, pongs_received, rtt_min/p50/p95/max/mean_us, one_way_estimate_us }> }` |
| `hub_controller_set_local_echo(enabled)` | ✅ | 连接控制器时是否**同时**在本机发声，默认关 |

`HubPeer { id, name, address /*首选 IP*/, port, paired /*本机是否信任*/, addresses: Vec<"ip:port"> }`；`PairedDevice { id, name, paired_unix_ms }`；
`SyncReport { pulled /*= local_changed，本地变化的条目*/, pushed /*= remote_changed*/, conflicts, bytes /*上下行字节合计*/, uploaded_blobs, uploaded_bytes, downloaded_blobs, downloaded_bytes, resumed_blobs, conflict_ids, duration_ms }`。

**控制器热路径**：`hub_controller_connect` 之后，`pad_down`/`pad_up`（以及 `send(PadDown|PadUp|StopAll)`）仍是 FRB `sync` 调用：先校验 pad 范围，再 `ArcSwap` 无锁读取当前控制器，调用 `ControllerHandle::pad_down/pad_up/stop_all`（一次 HMAC + 两次非阻塞 UDP `send`，velocity `0..=1` → `round(v×127)`），返回后**不在本地发声**（`local_echo` 打开时两边都发声）。`ControllerHandle` 不是 `Sync`，因此包在一个只在单次非阻塞调用期间持有的 `Mutex` 里（微秒级，无 I/O 等待）。后台看门狗每 500 ms 检查 Pong，5 s 未收到即判定 Hub 失联：自动断开、推送 `Error{op:"controller"}` + `ControllerDisconnected`，pad 恢复本地发声。

**Hub 事件**（经 `events()` 的 `EngineEvent::Hub(HubEvent)` 推送，不另设流）：

```rust
pub enum HubEvent {
    ServerStarted { port: u16 }, ServerStopped,
    PeerDiscovered { id, name }, PeerLost { id },
    Paired { id, name },                              // 客户端配对成功，或本机作为 Hub 时有设备用当前配对码配对成功
    SyncStarted { peer }, SyncProgress { peer, done: u64, total: u64 /*已知需要传输的 blob 数，同步中会增长*/ },
    SyncFinished { peer, report: SyncReport },
    ControllerConnected { peer }, ControllerDisconnected,          // 本机作为控制器
    RemoteControllerConnected { device, name }, RemoteControllerDisconnected { device },  // 本机作为 Hub
    Error { op: String /*discover|sync|controller|server*/, peer: Option<String>, error: UpError },  // 后台操作失败
}
```

同步调用的失败直接以 `UpError` 抛出；`Error` 事件只用于后台任务（以及 `hub_sync`，便于进度 UI 收尾）。

**Android 组播锁**：在 Rust 内经 JNI 管理（只调用框架类 `Context.getSystemService("wifi")` → `WifiManager.createMulticastLock("ultrapads-mdns")`，`setReferenceCounted(false)`，不受 R8 混淆影响），Dart 无需调用任何 MethodChannel。`hub_discover` 与 `hub_start_server` 在启动 mDNS **之前**登记一个持有者，`hub_discover_stop`/新的 `hub_discover`/`hub_stop_server` 时注销；只有"至少一个持有者且 Activity 在前台"时才真正持锁——`onStop` 释放、`onStart` 重新获取。

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
| `HubServer::new_pairing_code() -> PairingCode { code, expires_at }`、`trusted_devices()`、`revoke(id)`、`controller_stats()` | `hub_new_pairing_code` / `hub_trusted_devices` / `hub_revoke` / `hub_controller_stats` |
| `HubClient::new(ClientConfig)`、`discover() -> Discovery: Stream<DiscoveryEvent::{Found(HubPeer), Lost(DeviceId)}>` | `hub_discover` |
| `HubClient::probe(PeerAddr) -> (HubPeer, InfoResponse)` | `hub_probe`（手动输入 IP / 扫码） |
| `HubClient::pair(&HubPeer, code) -> TrustedDevice` | `hub_pair` |
| `HubClient::sync(&HubPeer, &dyn LibraryStore) -> SyncReport` | `hub_sync` |
| `HubClient::controller_connect(&HubPeer) -> ControllerHandle`；`pad_down/pad_up/stop_all`（同步、非阻塞）、`latency()`、`close()` | `hub_controller_connect` / `hub_controller_disconnect` / `hub_controller_status`；连接期间 FFI `pad_down/pad_up` 转发 |

由上层实现的 trait：`LibraryStore`（up-library 实现，参考实现 `FsLibraryStore`）、`PadSink`（接到引擎 `pad_down/pad_up/stop_all`，调用在 Hub 的 UDP 任务上，必须非阻塞）、`HubTransport`（v0.0.1 只有 `LanTransport`，iroh 预留）。

## 5. 曲库（`runtime/up-library`）与格式层（`engine/up-format`）Rust API

供 `bridge/up-ffi` 的 `library_*` / `tracks_*` / `sample_*` 接线。`Library` 内部加锁，方法都取 `&self`，放进 `Arc` 共享；不得在音频线程调用。

| Rust API | 对应 FFI | 说明 |
|---|---|---|
| `Library::open(root) -> Library` / `open_with(root, LibraryOptions)` | `init` | 数据根目录布局见 `docs/ARCHITECTURE.md` §8；`LibraryOptions { limits: ImportLimits, compat_sources }` |
| `list_kits(&KitQuery) -> Vec<KitSummary>` | `library_list_kits` | `KitQuery { text, genre, favorites_only, used_only, sort: Name/RecentlyUsed/RecentlyAdded/Favorited, limit }`；`KitSummary::to_protocol()` 转 `up_protocol::KitSummary` |
| `genres()` / `recent_kits(n)` / `set_favorite(id, bool)` / `mark_used(id)` / `delete_kit(id)` | | 曲风筛选、最近使用、收藏 |
| `load_kit_assets(id) -> LoadedKit` / `load_kit_assets_with(id, LoadOptions)` | `library_load_kit` | `LoadedKit { doc: up_format::KitDoc, model: up_model::KitDoc, summary, samples: 包内路径 → LoadedSample { sample_id, file, sample_rate, channels, frames, pcm: Option<DecodedPcm> }, warnings }`；`model` 中 `SampleRef.id` = BLAKE3 = `LoadedSample.sample_id`；`pcm` 为交错 f32；会记为最近使用 |
| `kit_model(id) -> up_model::KitDoc` / `save_kit_model(&up_model::KitDoc) -> KitSummary` | `library_current_kit_json` / `library_save_kit` | 保存时合并到原 Kit（模型已覆盖多采样层/轮替/loop 点/非对称 choke/细粒度量化，直接映射；教程保留在包内）；新采样用 `SampleRef.blake3`（或 `id`）引用曲库样本 |
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
