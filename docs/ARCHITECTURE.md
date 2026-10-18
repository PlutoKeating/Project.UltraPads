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
| 音频线程（设备回调） | `Engine::process(out, in)`：消费命令队列 → 调度 → 渲染 → 写电平/录音环形缓冲 | 不分配、不加锁、不做系统调用；命令走 `rtrb` SPSC |
| 控制线程（Rust 后台） | 解码、重采样、加载 Kit、生成波形概要、写录音文件、Hub 网络 | 资源准备好后以 `Arc` 送进音频线程；旧资源由回收队列在控制线程释放 |
| UI 线程（Dart） | 指针事件 → `pad_down/pad_up`（FRB `sync`，只往队列推命令，微秒级）；订阅事件流驱动动画 | UI 按下态立即生效，不等音频回调 |

## 3. 引擎为唯一事实源

- UI → 引擎：`Command`（如 PadDown、SetTempo、AssignSample、StartRecording）
- 引擎 → UI：`EngineEvent` 流（PadState、Transport、Meters、Recorder、Library、Hub、Error），外加 `snapshot()` 全量快照
- Dart 端用 Riverpod 维护**只读投影**；任何业务变更必须走 Command。

## 4. 平台适配

| 平台 | 外壳 | 音频后端 | 验证（v0.0.1） |
|---|---|---|---|
| Linux x64 | Flutter linux（GTK） | cpal → ALSA（PipeWire/Pulse 兼容） | ✅ |
| Android | Flutter android，minSdk 26 | cpal → AAudio（需 `ndk_context` 初始化，见 bridge 文档） | ✅（模拟器 + 真机待验收） |
| Windows | Flutter windows | cpal → WASAPI | 仅开发 |
| macOS/iOS | Flutter | cpal → CoreAudio | 仅开发 |
| Web | Flutter web（skwasm） | Rust→WASM，AudioWorklet，需 COOP/COEP；不支持时降级 | 仅开发 |
| Linux ARM | 交叉编译 aarch64 | ALSA | 仅开发 |
| 插件 | nih-plug CLAP/VST3 | 宿主提供 | 预留 |

## 5. 设计系统

- 事实源：`design/tokens/*.tokens.json`（W3C DTCG）
- 构建：`design/tokens` 下的 Style Dictionary 构建出 `packages/up_tokens/lib/src/generated/`（Dart）和 `design/tokens/build/css/`
- 分层：primitive → semantic → component；皮肤 = semantic 层覆盖（neon / outline / light / custom）
- Dart 侧以 `ThemeExtension<UpTheme>` 注入；组件只能通过 `UpTheme.of(context)` 取值
- lint：`tools/lint/no_hardcode.dart` 禁止 `packages/up_ui`、`app/ultrapads/lib/features` 中出现 `Color(0x…)`、`Colors.*`、数字字面量的圆角/时长，以及硬编码文案（中文字符或 `Text('…')` 字面量）

## 6. 个人多设备协同（up-hub）

详细设计见 `docs/adr/0004-personal-hub.md`，协议见 `docs/API.md` 第 4 节。

- **发现**：mDNS `_ultrapads._tcp.local`（桌面广播；Android 需持有 MulticastLock）；AP 隔离时可手动输入地址（`probe`）
- **配对与鉴权**：6 位一次性配对码 + SPAKE2；设备身份为 Ed25519，控制面采用双向 TLS + 公钥钉扎，撤销立即生效
- **同步**：曲库以内容寻址（BLAKE3）blob + 带版本向量的清单组织；增量、可续传；并发冲突时"最后写入者胜 + 保留副本"
- **控制器**：手机 Pad 事件经 UDP（序号 + 会话密钥 HMAC，双发去重，按 pad 处理乱序）发送到桌面引擎；会话结束时补发 pad_up。TCP/WebSocket 回退尚未实现
- **P2P**：`HubTransport` trait 预留 iroh 实现（跨局域网直连），v0.0.1 只实现局域网

## 7. 目录结构

见 `README.md` 中的"仓库结构"一节。
