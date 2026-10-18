# UltraPads 架构

> 决策依据：`docs/adr/`。需求依据：`docs/REQUIREMENTS.md`。接口契约：`docs/API.md`。

## 1. 分层

```
┌──────────────────────────────────────────────────────────────┐
│ ③ 前端 Frontend（Flutter / Dart，一份代码）                     │
│   app/ultrapads  ← features（perform/library/editor/recorder/…）│
│   packages/up_ui ← 组件库；packages/up_fx ← 动效/光效/着色器     │
│   packages/up_tokens ← 由 DTCG 生成；packages/up_i18n ← 文案      │
│   packages/up_engine ← EngineClient（FRB 绑定 + mock）           │
├─────────────────────── FFI（flutter_rust_bridge）──────────────┤
│ ② 运行基座 Runtime（Rust，平台适配）                             │
│   bridge/up-ffi      ← FRB API 面（唯一给 Dart 的入口）           │
│   runtime/up-host    ← 音频设备(cpal/AAudio/ALSA/WASAPI/WebAudio)、│
│                        文件存储、MIDI(midir)、时钟                │
│   runtime/up-library ← 曲库：Kit/样本/作品存储、导入导出           │
│   runtime/up-hub     ← 个人多设备协同：mDNS 发现、配对、同步、控制器 │
│   runtime/up-cli     ← 无头：离线渲染、Kit 打包、Hub 守护进程       │
│   runtime/up-plugin  ← CLAP/VST3 外壳（预留）                     │
├──────────────────────────────────────────────────────────────┤
│ ① 纯引擎 Engine（Rust，零平台依赖，不做 I/O）                     │
│   up-core  up-rt  up-dsp  up-graph  up-sampler  up-transport     │
│   up-sequencer  up-mixer  up-recorder  up-model  up-codec         │
│   up-protocol  up-engine（门面）                                  │
└──────────────────────────────────────────────────────────────┘
```

**依赖方向（单向，CI 检查）**
- `app → up_ui → up_tokens`
- `app → up_engine → (FFI) up-ffi → runtime/* → engine/*`
- `engine/*` 不得依赖 `runtime/*`、`bridge/*`，也不得做任何文件、网络或设备 I/O
- `up_ui` 不得依赖 `up_engine`；组件只接收数据和回调

## 2. 线程模型

| 线程 | 职责 | 约束 |
|---|---|---|
| 音频线程（设备回调） | `AudioProcessor::process(out, channels)`：图依次执行 Sampler（消费命令 → 量化调度 → 渲染 24 路 pad 总线 + 试听）→ Mixer（pad 电平）→ Master（增益平滑、限幅、电平、录音环形缓冲） | 不分配、不加锁、不做系统调用；测试用计数分配器证明零分配（`up_rt::alloc_check`） |
| 引擎控制线程（`up-engine-control`） | 拥有音频图（Firewheel context 非 `Send`）；4 ms 轮询事件环、回收被替换的 `Arc<Sample>`、约 60 Hz 合并 Meters、维护快照（`ArcSwap`）、收尾录音（交给 runtime 写盘） | 可分配；不做文件 I/O（engine 层无 I/O） |
| 运行基座线程（`up-host`） | cpal 输出/输入流各占一个宿主线程（stream 非 `Send`）；解码、重采样、Kit 加载、录音落盘、事件总线转发 | 资源准备好后以 `Arc` 送进音频线程 |
| UI 线程（Dart） | 指针事件 → `pad_down/pad_up`（FRB `sync`，只往无锁队列推命令，微秒级）；订阅事件流驱动动画 | UI 按下态立即生效，不等音频回调 |

队列：控制/UI → 音频为**多生产者**（UI、Hub、控制线程），使用无锁有界 `crossbeam_queue::ArrayQueue`（rtrb 是 SPSC，无法多生产者）；音频 → 控制（事件、回收、录音 PCM）使用 rtrb SPSC。停止设备时回调把 `AudioProcessor` 经 SPSC 槽交还，引擎可在 stop/start 之间保持。音频图见 ADR-0003。

## 3. 引擎为唯一事实源

- UI → 引擎：`Command`（如 PadDown、SetTempo、AssignSample、StartRecording）
- 引擎 → UI：`EngineEvent` 流（PadState、Transport、Meters、Recorder、Library、Hub、Error），外加 `snapshot()` 全量快照
- Dart 端用 Riverpod 维护**只读投影**；任何业务变更必须走 Command。

## 4. 平台适配

| 平台 | 外壳 | 音频后端 | 验证（v0.0.1） |
|---|---|---|---|
| Linux x64 | Flutter linux（GTK） | cpal → ALSA（PipeWire/Pulse 兼容） | ✅（`docs/research/v0.0.1-verification.md`） |
| Android | Flutter android，minSdk 26；release 开启 R8，keep 规则见 `android/app/proguard-rules.pro` | cpal → AAudio（需 `ndk_context` 初始化，见 bridge 文档；默认设备为伪设备 `aaudio:-1`） | ✅ 模拟器（真机待验收） |
| Windows | Flutter windows | cpal → WASAPI | 仅开发 |
| macOS/iOS | Flutter | cpal → CoreAudio | 仅开发 |
| Web | Flutter web（skwasm） | Rust→WASM，AudioWorklet，需 COOP/COEP；不支持时降级 | 仅开发 |
| Linux ARM | 交叉编译 aarch64 | ALSA | 仅开发 |
| 插件 | nih-plug CLAP/VST3 | 宿主提供 | 预留 |

## 5. 设计系统

- 事实源：`design/tokens/src/{primitive,semantic,component,themes}/`（W3C DTCG），主题清单在 `design/tokens/themes.config.json`
- 构建：`pnpm run build` 生成 `packages/up_tokens/lib/src/generated/*.g.dart`、`design/tokens/build/css/`、`design/tokens/build/json/`（产物入库，Flutter 构建不依赖 Node）；`pnpm run check` 校验产物是最新的
- 分层：primitive → semantic → component；皮肤 = semantic 层覆盖（neon / outline / light，用户自定义皮肤以 JSON 保存）；component 层不得含颜色
- Dart 侧以 `ThemeExtension<UpTheme>` 注入，组件只能通过 `UpTheme.of(context)` 取值；`UpTheme.lerp` 让主题切换自动带动画
- Pad 渐变：`full` 动效档由带三角抖动的片元着色器绘制（Impeller 不对渐变抖动，否则 Android 上出现同心淡环），见 `app/ultrapads/docs/ARCHITECTURE.md` §9
- 颜色角色：Dart `ColorRole` 与引擎同名同序，`ColorRole.paletteIndex` 是到 `pad.palette.N` 的唯一映射（`docs/API.md` §3.1 末尾）
- 字体：Uni Sans 是商业字体，不入库，由 `just inject-assets` 注入，`UpFonts.loadPrivate()` 加载；缺失时回退到 Montserrat（OFL）
- i18n：`packages/up_i18n`（ARB，zh/en），`UpL10n.of(context)`、`LocaleController`；`dart run up_i18n:add_locale <code>` 新增语言，`dart run up_i18n:check` 检查缺失
- lint：`tools/lint/no_hardcode.dart` 扫描 `packages/up_ui`、`packages/up_fx`、`app/ultrapads/lib`（排除生成代码），禁止 `Color(0x…)`、`Colors.*`、数字字面量的圆角/时长/间距/字号，以及 `Text('…')` 字面量；行级豁免写 `// up-lint-ignore: <原因>`

## 6. 个人多设备协同（up-hub）

详细设计见 `docs/adr/0004-personal-hub.md`，协议见 `docs/API.md` 第 4 节。

- **发现**：mDNS `_ultrapads._tcp.local`（桌面广播；Android 需持有 MulticastLock）；AP 隔离时可手动输入地址（`probe`）
- **配对与鉴权**：6 位一次性配对码 + SPAKE2；设备身份为 Ed25519，控制面采用双向 TLS + 公钥钉扎，撤销立即生效
- **同步**：曲库以内容寻址（BLAKE3）blob + 带版本向量的清单组织；增量、可续传；并发冲突时"最后写入者胜 + 保留副本"
- **控制器**：手机 Pad 事件经 UDP（序号 + 会话密钥 HMAC，双发去重，按 pad 处理乱序）发送到桌面引擎；会话结束时补发 pad_up。TCP/WebSocket 回退尚未实现
- **P2P**：`HubTransport` trait 预留 iroh 实现（跨局域网直连），v0.0.1 只实现局域网
- **FFI 接入（`bridge/up-ffi/src/hub_rt.rs`，函数见 `docs/API.md` §3.1）**：
  - 一个全局多线程 tokio runtime（2 worker，`up-hub`）承载所有 Hub 任务；FRB `async fn` 只把工作 spawn 上去并等待 `JoinHandle`
  - 身份、受信列表、记住的 Hub、上次端口存于 `<data_dir>/hub`；Hub 与客户端两个角色共用同一身份
  - 曲库 = `up_library::hub_store::LibraryHubStore`，外包一层：Hub 侧合并改动曲库、客户端同步改动曲库时发 `LibraryChanged`；客户端同步按 blob 统计 `SyncProgress`
  - 远端控制器 → `PadSink` → 引擎无锁命令队列（与 UI 热路径同一个 `EngineHandle`，多生产者）
  - 本机作为控制器时，FFI `pad_down/pad_up`（FRB sync）经 `ArcSwap` 读取当前 `ControllerHandle` 并同步转发（HMAC + 非阻塞 UDP），默认本地不发声（`hub_controller_set_local_echo` 可开）；Pong 超时 5 s 自动断开
  - Hub 事件与引擎事件合并进同一个 `events()` 流（`EngineEvent::Hub`）
  - Android：Manifest 声明 `INTERNET`/`ACCESS_NETWORK_STATE`/`ACCESS_WIFI_STATE`/`CHANGE_WIFI_MULTICAST_STATE`；MulticastLock 由 Rust 经 JNI（仅框架类）在 `hub_discover`/`hub_start_server` 前获取、停止时释放，`MainActivity.onStart/onStop` 通过 `nativeSetForeground` 让它只在前台持有

## 7. 目录结构

见 `README.md` 中的"仓库结构"一节。

## 8. 曲库与文件格式（up-library / up-format）

- **格式层 `engine/up-format`**：纯函数，输入输出都是字节/字符串/回调；包含 SFZ（UltraPads SFZ Profile 白名单）、`ultrapads-kit.json`/`manifest.json`/`tutorial.json` 模型、WAV 元数据 chunk、SMF、`.upkit` 逻辑包、DAWproject 1.0 导出，以及 `KitDoc` ↔ `up_model::KitDoc` 适配。格式规格见 `docs/research/kit-and-project-formats.md`，决策见 ADR-0002。
- **曲库 `runtime/up-library`** 的数据根目录：

```
<root>/
├── library.json                 索引（content/schema/library-1.schema.json）：Kit/样本/作品摘要、收藏、最近使用、外部目录、删除墓碑
├── kits/<kit-id>/manifest.json  Kit 的包清单；包内其它文件都在 samples/
├── samples/<hh>/<blake3>        内容寻址存储（所有 Kit 文件与独立样本，同内容只存一份）
├── samples/.partial/            同步中未完成的 blob（可续传）
├── sync-manifest.json           Hub 同步清单（LibraryHubStore）
├── tracks/<track-id>.wav        录音作品
└── projects/                    编曲工程（预留）
```

- 导入安全：ZIP 条目路径规范化（拒绝绝对路径/`..`/盘符/符号链接）、条目数/单文件/总大小/压缩比限额、manifest 哈希校验后才入库；写文件一律"临时文件 → fsync → rename"。
- 所有导入的音频在入库时统一为 WAV（Ogg/MP3/FLAC 等经 up-codec 解码转码），引擎只需解析 WAV。
- 示例 Kit：`content/kits/*.upkit` 由 `cargo run -p up-library --example kitgen -- content/kits` 用代码合成生成（CC0-1.0）。应用把它们的副本打包为资源（`app/ultrapads/assets/kits/`），首次启动曲库为空时经 `library_import_bytes` 导入。原 App 素材只在被忽略的 `private-assets/` 中，经 `just inject-assets` 注入后由应用首次启动导入到用户自己的数据目录（或桌面开发时 `--dart-define=UP_PRIVATE_KITS=<dir>` 直接导入），不入库、不随仓库分发。默认加载：原版 Sunset → CC0 Starter → 第一个。

## 9. 音频引擎实现要点（engine/*、runtime/up-host、runtime/up-cli）

- **量化**：transport 以拍（四分音符）计位置，有效速度 = bpm × speed；`next_boundary(beat, grid)` 求下一个网格点，换算为块内帧偏移，Pending 的 Loop 在该偏移处采样级精确起播（浮点误差 1e-6 帧内吸附）。
- **声部**：每 pad 一个主声部（`self_choke=false` 时 one-shot 可叠加），停止/截断/偷取都转为 5 ms（或 `choke_release_ms`）淡出尾巴；上限 `max_voices`（默认 32）+ 16 个尾巴槽。
- **采样**：加载时 symphonia 解码（WAV/MP3/Ogg Vorbis/FLAC/AAC-M4A/ALAC/AIFF/CAF）→ rubato FFT 重采样到设备采样率；设备采样率变化时引擎重建并按原始音频重新重采样当前 Kit。
- **Pitch**：`PadParams.pitch`（半音 ±12）在声部起播时换算为速率倍数 `2^(pitch/12)`，与 speed 相乘，对在播声部实时生效。
- **试听声部**：作品播放（可循环）与编辑器 `sample_preview`（任意区段）共用一个不占用 pad 的立体声声部，不受 speed 影响。
- **录音**：Master 限幅后的立体声写入 rtrb 环形缓冲 → 控制线程汇总为 `Take`（时长 + 128 段波形）→ runtime 写 WAV（FFI 下存入曲库 `tracks/`）→ `TrackSaved` 事件。
- **CLI**：`up-cli devices | render --kit-dir <dir> --events <json> --out <wav> | play --kit-dir <dir> --pad A0 | latency-probe | inspect <wav>`（`cargo run -p up-cli -- …`）。
