# 更新记录

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循语义化版本。

## [0.1.0] - 2026-10-18

一键安装、应用内更新与正式签名，外加按键延迟优化。

> **从 0.0.1 升级 Android 版**：0.1.0 起 APK 改用正式密钥签名（证书 SHA-256
> `bb7dd4d8…f8362816`），与 0.0.1 的调试签名不同，需要**先卸载旧版再安装**（会清空本机曲库，
> 可先用「我的设备」同步到电脑）。之后的版本都能在应用内直接更新。Linux 不受影响。

### 新增

- **Linux 一键安装 / 更新**：`curl -fsSL https://ultrapads.plutokeating.beer/install | bash`。
  免 sudo，装到 `~/.local/opt/ultrapads/versions/<版本>`（`current` 原子切换、保留上一版可回滚），
  写入 `~/.local/bin/ultrapads`、桌面项与图标；再运行即升级；下载走 Cloudflare 边缘镜像（失败回退 GitHub）并核对 SHA-256；
  缺少 GTK 3 / ALSA 时询问后用系统包管理器安装。选项 `--version`、`--prefix`、`--no-desktop`、`--no-modify-path`、`--uninstall`、`--yes`。
- **官网与发布接口** `ultrapads.plutokeating.beer`（`website/`，Cloudflare Worker）：下载落地页（中 / 英）、
  `/api/version`（最新正式版清单，`?format=sh` 供脚本读取）、`/dl/<tag>/<文件>`（按 GitHub 记录的 sha256 核对后边缘缓存的镜像）、
  `/dl/latest/<平台>`。
- **应用内更新**（新 crate `runtime/up-update` + FFI `update_*`）：启动后静默检查一次（只发 GET，设置里可关），
  有新版时提示一次；「设置 → 关于 → 软件更新」可下载、查看更新内容。Linux（脚本安装）就地装入新版本并重启；
  Android 下载并校验 APK 后交给系统安装器；手动解压的副本只提示并打开下载页。
- **Linux arm64** 发布包（树莓派 / ARM 笔记本）。
- 发布流水线 `.github/workflows/release.yml`：推送 tag 即构建 Linux x64 / arm64、Android 三个 ABI，
  核对 APK 签名证书，生成 `SHA256SUMS.txt` 并创建 Release；`just bump` / `just release` / `just package-linux`。
- 品牌标志定稿：UP 组合字（粉紫果冻 U + 青色 pad 竖笔 + PlutoKeating 琥珀 orb），源文件 `design/brand/ultrapads-mark.svg`。
  `just icons` 由它生成 Linux、Windows、macOS、iOS、Android（含 adaptive icon）、Web 与官网的全部图标；
  Flutter Web 的 manifest / 页面标题改为 UltraPads 与品牌底色，替换模板默认值。
- Linux 桌面项（`dev.ultrapads.ultrapads.desktop`，类别 Audio / Music）；窗口标题与应用名统一为 UltraPads。

### 变更

- Android release 包使用正式签名（密钥不入库，见 `docs/QUICK_START.md`「发布」）；新增 `REQUEST_INSTALL_PACKAGES` 权限（应用内更新）。
- 设置页「关于」的版本号改为运行时读取（`app_version`），不再写死。

### 改进

- 按键响应延迟：
  - Android：启用 cpal `realtime` feature，AAudio 流请求 `PERFORMANCE_MODE_LOW_LATENCY`（之前为 NONE，走普通混音路径，
    拿不到 FAST 轨道）；缓冲始终交给 AAudio 按 burst 回调，不再接受固定缓冲请求。设置页在 Android 上不再显示缓冲档位。
  - 桌面默认缓冲 256 → 128 帧（本机 PipeWire 实测：命令 → DAC 估计由约 18 ms 降到约 10 ms，无 xrun）。
  - UI：演奏页不再随走带位置（播放时约 60 Hz）整页重建；FFI 客户端不再为每个 Transport 事件同步调用一次 `snapshot()`。

## [0.0.1] - 2026-10-18

首个可用版本：在 **Linux x64** 与 **Android**（API 26+，模拟器验证）上构建、运行并验证。验证记录见
`docs/research/v0.0.1-verification.md`。代码以 Apache-2.0 公开开源；原 App 素材不随仓库分发。

### 引擎与运行基座（Rust）

- 实时采样引擎：Firewheel 音频图（Serial 参考后端）、24 pad + 试听声部、One-shot / Loop / Gate、
  choke（含非对称 `choked_by`）、量化启动、32 声部 + 16 尾巴的偷取策略，音频线程零分配零锁。
- 实时变速 `SetSpeed`（0.5–2.0，varispeed，transport 同比缩放）与 pad 实时 **pitch**（半音 ±12，播放速率实现，与 speed 相乘）。
- 试听声部：作品播放（可循环）、编辑器 `sample_preview`（任意区段，不占用 pad）。
- 录音（主输出 → WAV → 曲库作品，128 段波形）、麦克风采样、教程判定（`transport_clock` + `tutorial_judge`）、延迟探针。
- cpal 音频基座：Linux ALSA、Android AAudio（修复 AAudio 默认伪设备 `aaudio:-1` 无法打开）。
- 曲库 up-library：`.upkit`（SFZ + JSON 旁挂）、SFZ、WAV 文件夹、原 App 素材导入器（APK 3.x / IPA 4.x，含目录与计时教程）、
  DAWproject 导出、内容寻址存储；`library_import_bytes` 从内存导入；同一个包在多台设备导入得到相同 ID 与 manifest（同步不重复、不冲突）。
- 个人 Hub up-hub：mDNS 发现、6 位配对码 + SPAKE2、双向 TLS 公钥钉扎、版本向量清单增量同步（可续传）、UDP 控制器（HMAC、双发去重、防挂音）；
  FFI 覆盖服务、配对码（含 `hub_pairing_code`）、受信设备与撤销、发现 / 手动地址、同步进度、控制器与本地发声开关。
- `up-cli`：设备列表、离线渲染、单 pad 播放、延迟探针、WAV 检查。

### 应用（Flutter）

- 按 Ref 4.7.0 复刻的演奏页、教程（时间轴、PERFECT / TOO FAST / TOO SLOW / MISS）、曲库（KITS / FEED / PROFILE）、
  编辑 Kit（LOAD SOUND、EDIT PAD 含 PITCH ±、EDIT FILE 裁剪与试听）、录音与作品（循环播放、导出、分享）、皮肤（3 主题 + 16 套预设 + 自定义）、设置、引导、设计画廊。
- 速度控件：教程模式下速度按钮正下方的 1.0 / 0.7 / 0.5 下拉框，引擎实时变速并同比缩放教程时间轴。
- 首次启动：导入打包的 CC0 示例 Kit；注入了私有素材时导入 4.7.0 的 6 个内置 Kit；默认加载原版 Sunset → CC0 Starter。
- 首次引导浮层（4.7.0 FirstGuide）、视频教程入口（YouTube / BiliBili，链接在 `assets/config/links.json`）、平板 / 桌面宽屏布局、
  image 类皮肤在注入后使用原版位图、pad 渐变抖动着色器（消除 Android 同心淡环）。
- 多设备页：桌面显示配对码、本机地址、受信设备与撤销、远端控制器；手机发现 / 手动输入地址、配对、同步进度、控制器模式（演奏页状态条，可退出）、本机同时发声。
- `EngineClient` 契约与 `MockEngineClient` 覆盖全部 FFI；`ColorRole` 与引擎同名同序，`ColorRole.paletteIndex` 为调色板映射的唯一定义。
- 设计系统：W3C DTCG token → Dart / CSS，i18n（zh / en），`no_hardcode` lint 零违规。
- 开发 / 验证：`UP_ENGINE`、`UP_GALLERY`、`UP_ROUTE` / `ULTRAPADS_ROUTE`、`UP_PRIVATE_KITS`、`ULTRAPADS_WINDOW_SIZE`、
  `ULTRAPADS_HUB_AUTOSTART` / `UP_HUB_AUTOSTART`、`ULTRAPADS_LOG_EVENTS` / `UP_LOG_EVENTS`。

### 构建

- Android release 开启 R8：新增 keep 规则，修复 shared_preferences / path_provider（经 package:jni 调用）启动即崩溃。
- Linux release：放宽 rive_common 插件的 unused 告警（新版 clang + `-Werror`）。

- 无头 CLI 容器镜像：`runtime/up-cli/Dockerfile`（`just docker-cli`），发布为 `ghcr.io/plutokeating/ultrapads-cli`。

### 发布产物

- Linux x64 release 包（tar.gz）、Android release APK（arm64-v8a / armeabi-v7a / x86_64，暂用调试密钥签名）、`up-cli` 容器镜像。

### 已知限制

见 `docs/research/v0.0.1-verification.md`「已知问题」。
