# 更新记录

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循语义化版本。

## [Unreleased]

### 新增

- 用户上传（UGC）后端：登录用户可把自己的 Kit 上传到账号下（`/api/me/uploads*`，≤ 128 MB，每账号 ≤ 50 条，Worker 纯透传）。上传时必须声明署名、许可证与来源（自己的作品 / 按所列许可证获得授权），**默认私有**；本人可改为公开，公开后出现在曲库目录（`origin: ugc`）。公开条目可举报（`POST /api/catalog/<id>/report`，同一用户一次，累计 3 人自动隐藏待审），运营可恢复或下架（下架后 `410`）；注销账号连同上传一并删除。数据服务旧库自动补列。
- 用户上传（UGC）界面：曲库里新增「来源」筛选（含「社区上传」），社区条目详情有说明和「举报」；「我的上传」（曲库筛选条与设置 → 账号里的入口）列出自己的上传，可改公开 / 私有（公开前确认）、删除、取回到本机；上传表单填写署名、许可证、来源声明并确认有权分享后，导出 Kit 并流式上传（带进度，可取消，超过 128 MB 先拦住，失败自动清理空条目）。

- **导入歌曲拆成 Kit**：新 crate `up-split`——识别速度与小节，挑出最多 8 个 4 小节段落，按“一个音色组 = 一个完整段落、组内一个 pad = 一个乐器”的排布生成 Kit（同官方曲库）。可选 Demucs 本地分轨（鼓 / 贝斯 / 其他 / 人声；`Separator` 可插拔，纯 Rust 推理，首次使用下载约 158 MB 模型并校验 sha256），内存不足时只提供几秒完成的整曲快速拆分。入口：曲库 → 我的 → 导入歌曲拆成 Kit。
- 录音作品可导出 FLAC（16-bit，带 Vorbis 注释）；用到需署名的素材时，署名写进 WAV 的 `bext` 或 FLAC 的 `COMMENT`，并随分享文案一起带上。

### 变更

- 官方曲库的 Kit 排布改为**按段落分组**：每个音色组（A/B/C…）是歌曲的一个完整段落（4 小节），组内每个 pad 是一个乐器，同组 pad 全开即完整一段；同一乐器跨组互斥，可逐乐器换段落即兴。此前是按乐器分组。曲库内容在服务端重新发布，已下载的旧版本 Kit 重新下载即可更新；synth 曲目扩为 A–D 四个段落，album / online 优先取 16 小节（4 段）。

### 修复

- 分享录音时前端请求 `flac`，后端只认 `wav` / `dawproject`，导致分享失败（提示“暂不支持”）。

## [0.3.0] - 2026-10-18

新增**官方曲库**：应用内浏览、搜索并按需下载大量现成曲目，用来直接做单曲即兴重排；登录 PlutoKeating 账号后云端同步收藏。

### 新增

- 官方曲库（曲库页第三个 Tab）：按许可证、曲风、BPM 筛选与排序，查看署名与来源，下载后一键载入演奏。首批 65 首：原创 CC0 合成曲 40 首（house / hiphop / lofi / trap / dnb / funk / disco / synthwave / ambient / chiptune）、AlbumDB 真实分轨 4 首（CC BY 4.0）、ccMixter 多轨 21 首（CC BY / CC BY-NC）。每首都按乐器分音色组、按小节切好循环，默认按小节量化，打开就能玩。
- 逐条许可证标注：CC0 / BY / SA / NC 徽标和提示；保存、分享录音时若用了需署名的素材，附上署名。
- PlutoKeating 账号登录（设置页）：Android 用系统授权页，Linux 桌面用系统浏览器 + 本机回环。登录后云端同步收藏、最近使用与下载记录；不登录也能浏览和下载。
- 服务端：官网 Worker 新增 `/api/catalog*`（目录、筛选、详情、下载）与 `/api/me*`（收藏等），新增数据服务 `data/`（`ultrapads-data`）。接口见 `docs/API.md` §7，决策见 `docs/adr/0005-catalog-and-accounts.md`。
- 素材入库管线 `tools/catalog`：拉取、许可证校验（白名单）、BPM 与小节对齐、切片、打包 `.upkit`（内含 FLAC）、质检、试听预览、发布。

### 变更

- 官网、README、文档与设置页「关于」不再提及参考 App 的名称；删除两篇针对它的逆向分析文档。
- 私有素材包导入器改用中性命名：来源 ID 为 `compat-android` / `compat-ios`，私有素材目录改为
  `private-assets/compat-android/`、`private-assets/compat-ios/`（本机已有的目录需要手动改名）。
  来源 ID 参与 Kit ID 派生，所以已导入的私有 Kit 重新导入后会得到新 ID（旧 Kit 保留，可手动删除）。
- 官网 `/dl/` 镜像的缓存键加入 GitHub 记录的 sha256：同一版本的附件被替换后不再返回旧副本（此前安装脚本会因校验不符而失败）。
- 新增手动触发的「Rebuild release assets」流水线：按 tag 重新构建安装包并替换 Release 附件。

## [0.2.1] - 2026-10-18

修复在设置里切换输出设备后无声、设置页白屏的问题。

### 修复

- 选定的输出设备打不开时（例如连着蓝牙时选择手机扬声器）应用整个无声、重启也无法恢复：现在自动回退到系统默认输出。
  Android 始终以立体声打开输出流（部分机型拒绝单声道的低延迟轨道）。
- 音频未运行时设置页白屏（延迟计算得到 NaN）。
- 设置「输出设备」显示设备名称，选择未生效时注明「不可用，已使用系统默认输出」；新增「跟随系统」选项。

### 改进

- Android：默认使用设备原生输出采样率（不需要重采样才能拿到低延迟快速轨道），低延迟流打开后缓冲设为 2 个 burst。

> 关于延迟：连接**蓝牙耳机**时，系统报告的蓝牙链路延迟通常在 100–200 ms（vivo X200 Pro mini 实测约 140 ms），这是蓝牙 A2DP 的编码与传输缓冲，
> 应用无法绕过；演奏请使用手机扬声器、有线耳机或 USB-C 耳机（应用侧实测：快速轨道、48 kHz、512 帧缓冲约 10.7 ms）。

## [0.2.0] - 2026-10-18

即刻出声、触摸滑动触发、一首歌多组音色，演奏页精简。

> **Linux 系统要求变化**：0.2.0 起 Linux 版使用 PipeWire 原生音频通路，需要 PipeWire ≥ 0.3.65 与 glibc ≥ 2.36
> （Debian 12+、Ubuntu 23.04+、Fedora 38+、Arch 等）。**不再支持 Ubuntu 22.04**。安装脚本会自动补装缺少的运行库。

### 改进

- **按下即刻出声**（Linux）：音频改走 PipeWire 原生通路（cpal `pipewire`），不再经过 ALSA 兼容层的插件缓冲与线程交接；
  流线程经 rtkit 提为实时优先级（cpal `realtime-dbus`，SCHED_RR）。实测指令 → 发声约 3.8 ms（0.1.0 约 10–18 ms），
  高负载下欠载由数百次降到 0。没有 PipeWire 时自动回退 ALSA。
- **Android 独占音频通路**：输出流请求 AAudio `EXCLUSIVE`（MMAP）模式，支持的设备上绕过系统混音器、延迟最低；
  不支持时自动回落到共享模式（cpal 补丁版，见 `third_party/cpal/ULTRAPADS_PATCH.md`）。
- **触摸到即触发**：按下或手指滑进 pad 都立即发声（每次触碰都重触发），滑出 / 抬起时松开；在空 pad 上按下再滑进有声音的 pad 同样触发。
- pad 按下当帧即全亮（不再等动画控制器下一帧起步）。

### 新增

- **一首歌多组音色**：每首歌 1–7 组（A–G，每组 12 个 pad），演奏页功能行的切换条一键切换，已在播放的声音（包括 Loop）不中断；
  键盘 Tab 依次切组。编辑器可新增、左右移动、删除音色组（实时生效，删除有声音的组需确认）。
  Kit 格式 `layout.padCount` 支持 12 的倍数（最多 84）、`banks` 支持 A–G；1–2 组的 Kit 读写逐字节不变。
- 引擎：pad 混音并入采样器节点，音频图端口数不再随 pad 数增长（音频线程仍零分配）。

### 变更

- 演奏页顶栏直接显示歌名（去掉「音色包 / KIT」前缀），右上角改为设置入口（原视频教程按钮）；⋮ 展开行不再重复放设置。
- 移除「学习演奏」（教程模式、时间轴判定、速度框）与视频教程链接；引擎与 FFI 的教程能力保留。
- 发布版 Linux 包改在 Debian 12 容器中构建；安装脚本的依赖自动安装加入 PipeWire / D-Bus 运行库，
  root 下不经 sudo、GTK 依赖链归入 GTK 包、装后复查、失败重试一次（Ubuntu 24.04 / Debian 12 / Fedora 41 / Arch 容器实测）。
- up-cli 容器镜像加入 PipeWire / D-Bus 运行库。

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
`docs/research/v0.0.1-verification.md`。代码以 Apache-2.0 公开开源；私有素材包不随仓库分发。

### 引擎与运行基座（Rust）

- 实时采样引擎：Firewheel 音频图（Serial 参考后端）、24 pad + 试听声部、One-shot / Loop / Gate、
  choke（含非对称 `choked_by`）、量化启动、32 声部 + 16 尾巴的偷取策略，音频线程零分配零锁。
- 实时变速 `SetSpeed`（0.5–2.0，varispeed，transport 同比缩放）与 pad 实时 **pitch**（半音 ±12，播放速率实现，与 speed 相乘）。
- 试听声部：作品播放（可循环）、编辑器 `sample_preview`（任意区段，不占用 pad）。
- 录音（主输出 → WAV → 曲库作品，128 段波形）、麦克风采样、教程判定（`transport_clock` + `tutorial_judge`）、延迟探针。
- cpal 音频基座：Linux ALSA、Android AAudio（修复 AAudio 默认伪设备 `aaudio:-1` 无法打开）。
- 曲库 up-library：`.upkit`（SFZ + JSON 旁挂）、SFZ、WAV 文件夹、私有素材包导入器（Android / iOS 两种格式，含目录与计时教程）、
  DAWproject 导出、内容寻址存储；`library_import_bytes` 从内存导入；同一个包在多台设备导入得到相同 ID 与 manifest（同步不重复、不冲突）。
- 个人 Hub up-hub：mDNS 发现、6 位配对码 + SPAKE2、双向 TLS 公钥钉扎、版本向量清单增量同步（可续传）、UDP 控制器（HMAC、双发去重、防挂音）；
  FFI 覆盖服务、配对码（含 `hub_pairing_code`）、受信设备与撤销、发现 / 手动地址、同步进度、控制器与本地发声开关。
- `up-cli`：设备列表、离线渲染、单 pad 播放、延迟探针、WAV 检查。

### 应用（Flutter）

- 演奏页、教程（时间轴、PERFECT / TOO FAST / TOO SLOW / MISS）、曲库（KITS / FEED / PROFILE）、
  编辑 Kit（LOAD SOUND、EDIT PAD 含 PITCH ±、EDIT FILE 裁剪与试听）、录音与作品（循环播放、导出、分享）、皮肤（3 主题 + 16 套预设 + 自定义）、设置、引导、设计画廊。
- 速度控件：教程模式下速度按钮正下方的 1.0 / 0.7 / 0.5 下拉框，引擎实时变速并同比缩放教程时间轴。
- 首次启动：导入打包的 CC0 示例 Kit；注入了私有素材时导入私有素材包的 6 个内置 Kit；默认加载私有素材包的 Sunset → CC0 Starter。
- 首次引导浮层（FirstGuide）、视频教程入口（YouTube / BiliBili，链接在 `assets/config/links.json`）、平板 / 桌面宽屏布局、
  image 类皮肤在注入后使用私有素材包的位图、pad 渐变抖动着色器（消除 Android 同心淡环）。
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
