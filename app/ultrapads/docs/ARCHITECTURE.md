# UltraPads 前端架构（app/ultrapads）

> 全局架构见仓库根 `docs/ARCHITECTURE.md`；接口契约见 `docs/API.md`；复刻依据见
> `docs/research/compat-ipa-4.7.0-analysis.md`（第一基准）和 `compat-apk-analysis.md`（补充）。

## 1. 分层与依赖

```
app/ultrapads ──► up_ui ──► up_tokens (UpTheme / Up*Tokens)
     │              └────► up_fx (光效 / 动效)
     ├──► up_i18n (UpL10n，全部文案)
     └──► up_engine (EngineClient 接口 + 数据类 + MockEngineClient)
              ▲
     lib/src/engine/ffi_engine_client.dart ──► lib/src/rust/（FRB 生成，引擎代理维护）
```

- `up_ui` 不依赖 `up_engine`：组件只接收纯数据（`PadData`、标签字符串）和回调。
- `up_engine` 是纯 Dart（库代码不 import flutter），FFI 适配放在应用里，这样 `up_engine`
  不依赖会变化的生成绑定。
- 所有颜色 / 尺寸 / 圆角 / 时长 / 曲线来自 `up_tokens`；文案来自 `up_i18n`。
  `dart run tools/lint/no_hardcode.dart` 检查 `up_ui`、`up_fx`、`app/ultrapads/lib`。

## 2. 目录

```
lib/
├─ main.dart                 启动：私有素材清单 → 字体 → 着色器 → 引擎 → ProviderScope
└─ src/
   ├─ app/app.dart           MaterialApp.router、主题（AnimatedTheme 皮肤过渡）、i18n、FxScope
   ├─ assets/private_assets.dart  私有素材清单解析（见 §6）
   ├─ engine/                engine_bootstrap.dart（UP_ENGINE=mock|ffi）、ffi_engine_client.dart
   ├─ library/first_run.dart 首次启动：导入内置 Kit（CC0 资源 / 注入的 4.7.0 Kit）并加载默认 Kit
   ├─ config/app_links.dart  外部链接（assets/config/links.json：视频教程搜索地址；页面不写 URL）
   ├─ dev/dev_hooks.dart     开发/验证环境变量（ULTRAPADS_HUB_AUTOSTART、ULTRAPADS_LOG_EVENTS、ULTRAPADS_UPDATE_SELFTEST）
   ├─ update/                应用内更新：update_controller.dart（状态机）、apk_installer.dart（Android 安装通道）
   ├─ routing/               routes.dart（路径常量）、router.dart（go_router + 转场）
   ├─ state/                 Riverpod：engine_state / perform_state / library_state / settings_state
   ├─ rust/                  FRB 生成代码（不要手改）
   └─ features/
      ├─ perform/            演奏页、功能按钮行、键盘映射、引擎→PadData 映射
      ├─ tutorial/           时间轴教程：判定反馈层、时间参数
      ├─ library/            曲库（KITS / FEED / PROFILE）、Kit 预览、曲风
      ├─ editor/             编辑 Kit（LOAD SOUND、EDIT PAD、EDIT FILE 裁剪）、采样选择器
      ├─ recorder/           麦克风采样页、保存录音面板、分享
      ├─ tracks/             我的录音（TRACK 卡）
      ├─ skins/              皮肤面板、自定义皮肤编辑器
      ├─ settings/           设置
      ├─ hub/                多设备协同
      ├─ onboarding/         首次引导（Walkthrough + 风格选择）
      └─ design_gallery/     设计画廊（token 浏览 / 组件 / 皮肤 / 动效）
```

## 3. 页面树与路由

| 路由 | 页面 | 转场 | 来源 |
|---|---|---|---|
| `/` | `PerformPage` 演奏页 | — | 4.7.0 `ScreenPads/Main` |
| `/onboarding` | `OnboardingPage` | 无 | 4.7.0 Walkthrough + CategoryPreference（试用页不做） |
| `/kits` | `LibraryPage`（KITS / FEED / PROFILE + 搜索） | 底部滑入 `sheet.enter` | 4.7.0 `MenuScene` |
| `/kits/:id` | `KitDetailPage` Kit 预览 | 右侧推入 `page.push` | 4.7.0 `modalUnlockKit`（去掉解锁/付费） |
| `/edit` | `EditorPage` 编辑 Kit | 底部滑入 | 4.7.0 `CreateKit/Main` |
| `/edit/mic` | `MicSamplerPage` 麦克风采样（返回 `SampleInfo`） | 推入 | 4.7.0 mic 面板 |
| `/tracks` | `TracksPage` 我的录音 | 推入 | 4.7.0 PROFILE → 我的录音 |
| `/skins/editor?id=` | `SkinEditorPage` 自定义皮肤 | 推入 | 新增 |
| `/settings` | `SettingsPage` | 推入 | 新增（4.7.0 无设置页） |
| `/hub` | `HubPage` 多设备协同 | 推入 | 新增（F10） |
| `/dev/gallery?tab=&skin=` | `DesignGalleryPage` | 推入 | 新增（ADR-0001 #13 修订：替代 Figma） |

弹层（不是路由）：皮肤面板 `showSkinsSheet`（0.4 s QuadOut 底部滑入）、速度框
`showSpeedModal`（4.7.0 `modalVelocities`：速度按钮正下方的下拉框，1.0 / 0.7 / 0.5，进 0.5 s、出 1.0 s QuadOut）、保存录音 `showSaveRecordingSheet`、采样选择、确认对话框。

- 未完成引导时 `redirect` 到 `/onboarding`；画廊路由不受影响。
- `--dart-define=UP_GALLERY=true` 时初始路由为 `/dev/gallery`；`--dart-define=UP_ROUTE=<路由>` 或桌面环境变量
  `ULTRAPADS_ROUTE` 指定初始路由（开发 / 截图）。
- 宽屏（平板 / 桌面）：除演奏页外的页面在 router 中统一包 `WideBody`（`routing/wide_body.dart`），限宽 600 居中；
  演奏页见 §3.2。

### 3.1 演奏页结构

```
UpTopBar: [♫ SONGS] KIT <名称> …… [速度 1.0（仅教程模式，点开下拉 1.0/0.7/0.5）] [▶ YouTube/BiliBili]
功能行 (functionRow 50pt) ──────────────────────────── [A/B 64.5×63]
  默认：[🎓 LEARN TO PLAY] | [⋮]
  ⋮ 展开（整行横移，0.3 s CircIn/CircOut）：[● 录音] [皮肤] [编辑] [分享] [设置] [◀]
  教程模式：[▶/■] ———o——— [✕]
PadGrid 3×4（A/B 两页横移 0.2 s QuadOut），教程模式叠加判定反馈层
首次引导浮层（FirstGuide，非教程模式、未看过时）
```

- **视频教程按钮**（4.7.0 `btnYoutube`，顶栏最右）：`url_launcher` 打开外部链接。链接来自
  `assets/config/links.json`（`appLinksProvider`）：Kit 自带 `videoUrl` 优先，否则按界面语言选搜索地址
  （zh → BiliBili，其余 → YouTube），搜索词 = Kit 名 + `videoQuerySuffix`。Android 11+ 在 Manifest 中声明
  VIEW https 的 `<queries>`。
- **首次引导**（`features/onboarding/first_guide.dart`，4.7.0 FirstGuide）：70% 遮罩挖洞、手指 1.0 s QuadIn
  上移、白色气泡、STEP x/4（从右滑入）、SKIP（0.25 s 滑入）；4 步：pad → LEARN TO PLAY → ⋮ → SONGS。
  完成或跳过后写入设置 `firstGuideSeen`；设置页「开发者 → 重新显示新手引导」可重置。

### 3.2 宽屏布局（`features/perform/perform_layout.dart`）

4.7.0 用 FairyGUI `fixed_height` 适配（画布 828×1472 px 按高度等比缩放）。手机布局不变；宽高比超过画布时，
pad 网格按 4.7.0 cell 几何的宽高比（约 0.78）由可用高度算出宽度并水平居中，顶栏与功能行与网格同宽。
golden：`perform_desktop_1280x800`、`perform_desktop_1024x768`、`perform_tablet_768x1024`、`settings_desktop_1280x800`。

## 4. 状态流（引擎为唯一事实源）

```
指针 (Listener.onPointerDown) ──同步──► EngineClient.padDown()  ──► 引擎无锁队列
        │                                               │
        └─► PadGrid 本地按下态（立即显示）                 └─► EngineEvent 流 ──► EngineProjection
                                                                         (engineViewProvider)
                                                                                │
                                         PadData.state（Playing/Pending…）◄──────┘
```

| Provider | 内容 | 来源 |
|---|---|---|
| `engineBootProvider` / `engineProvider` | 当前 `EngineClient`（ffi 或 mock） | `main.dart` 覆写 |
| `engineViewProvider` | pad 参数 / 发声状态、走带、Kit、录音状态（只读投影） | `snapshot()` + 事件 |
| `metersProvider` / `trackPlaybackProvider` / `engineErrorsProvider` | 高频 / 单类事件流 | 事件 |
| `kitsProvider` / `tracksProvider` | 曲库、作品（`LibraryChanged` / `KitLoaded` 时刷新） | 引擎查询 |
| `hubViewProvider` | Hub 服务、配对、同步进度、控制器 | Hub 事件 |
| `bankProvider` | 当前显示的页 A/B（纯 UI；加载 Kit 时回到 A） | UI |
| `tutorialProvider` | 教程会话：时间轴位置、速度、已判定步骤、反馈 | UI（消费引擎给的 `TutorialChart`） |
| `kitLoadProvider` / `favoritesProvider` | 加载中的 Kit；收藏（本机偏好） | UI / prefs |
| `settingsProvider` / `upThemeProvider` / `localeControllerProvider` | 皮肤、自定义皮肤、动画开关、音频偏好、自动检查更新、语言 | SharedPreferences |
| `updateProvider` | 应用内更新阶段（检查 / 可更新 / 下载进度 / 待重启或待安装 / 失败） | `update_*`（§11） |

规则：业务变更一律经 `EngineClient`（命令或异步函数）；Provider 只做投影。
`tryEngine` / `tryEngineDo` 把 `EngineNotImplemented` 转成 null / false，页面据此显示
「音频引擎暂不支持此功能」（`errorEngineUnsupported`）。

## 5. 触摸延迟

- `PadGrid` 外层一个 `Listener`（不进手势竞技场），按坐标命中 pad；每个 pointer 记录按下的 pad，
  抬起 / 取消时释放同一个 pad，支持多点触控。鼠标只有主键触发。
- 回调先同步调用 `padDown`（FRB `sync`，只推命令），再 `setState` 显示按下态。
- UI isolate 保持空闲，指针事件才能立即处理：演奏页只 `select` 自己用到的 `EngineView` 字段（走带位置播放时约 60 Hz，
  不触发整页重建）；`FfiEngineClient` 把 Transport 事件与缓存的走带状态合并，不为每个事件做一次同步 `snapshot()`。
- 音频侧延迟见根目录 `docs/ARCHITECTURE.md` §4（Android LowLatency、桌面默认 128 帧）。设置页的缓冲档位在 Android 上隐藏
  （由 AAudio 决定，显示为「系统」）。
- 键盘映射（桌面）：`1 2 3 / Q W E / A S D / Z X C` 对应当前页 12 个 pad，Tab 翻页，Space 停止全部，R 录音；
  键盘按下态通过 `PadGrid.externallyPressed` 同样立即显示。

## 6. 私有素材注入

- 入库：`assets/private_manifest/manifest.json`（占位，`available: false`）+ 目录内 `.gitignore`。
  pubspec 只声明这一个目录，**它永远存在**，所以没有私有素材时构建照常通过。
- 注入：`just inject-assets`（`tools/assets/inject_private_assets.dart`）把
  `private-assets/compat-ios/`（4.7.0，优先）和 `private-assets/compat/`（APK，补充）
  中 UI 需要的素材**平铺**复制到同一目录（`<来源>_<类别>__<路径>`，被 `.gitignore` 忽略），
  并生成 `injected.json`（`priority: [ios, apk]`、`entries: {ios/skin/…: assets/private_manifest/…}`）。
  付费墙 / GDPR / IDFA / 广告相关包不注入。`just clean-assets` 删除。
- 运行时：`PrivateAssets.load()` 先读 `injected.json`，失败读占位清单；`resolve(类别, 文件)` 按优先级查找。
  缺失时回退开源占位：Open Sans（up_tokens 打包）、Material Icons、程序化绘制的 pad / 封面。
- 当前用到的私有素材：皮肤缩略图（`ios/ui/ScreenPads__img_skins_*`）、Uni Sans 字体（APK，
  注册为 `UpFonts.privateFiles` 的家族名）、APK `normal_*` Lottie（设置「经典 Pad 动画」开启时）、
  image 类皮肤（Christmas / Pets / Muertos / Halloween）的整张 pad 位图（`PadImageSkin`：常态位图 +
  按下 / Loop 闪烁时淡入的亮态位图，`BoxFit.fill`，缺色退回 pink；未注入时保持 token 绘制）、
  4.7.0 的 6 个内置 Kit（`privateKits`，首次启动导入，见 §8.1）。

## 7. 复刻取舍（截图 / 4.7.0 IPA / 3.7.6 APK 冲突时的决定）

| 方面 | 决定 | 依据 / 原因 |
|---|---|---|
| 第一基准 | **4.7.0 IPA（FairyGUI 数据）+ App Store 截图**；APK 只补充 | 主代理通知；4.7.0 与截图一致 |
| Pad 外观 | 程序化绘制（token 渐变 + 白色/浅色覆盖层 + 光晕），不用 4.7.0 的 72px 位图 | 位图是 9 宫格小图，程序化能跟随皮肤 token 与 lerp；16 套预设由 token 代理转成 semantic 覆盖 |
| 默认皮肤 | `neon`（截图的霓虹径向渐变 + 光晕）；4.7.0 `Default` 等 16 套作为预设可选 | 用户要求以截图为准 |
| Pad 动效 | 按下 1 帧变亮（`pad.pressAttack` 17 ms），松开 0.1 s QuadOut；Loop 白色闪烁 0.6 s yoyo + 图标 1.2 s 一圈 | 4.7.0 Transition |
| Lottie | 保留 `SegmentedLottie`（按下播 0→0.5、松开 0.5→1），仅在设置「经典 Pad 动画」+ 注入了 APK 素材时使用 | 4.7.0 没有 Lottie；APK 的效果作为可选旧版皮肤 |
| Fragment Shader | 霓虹 bloom / 按下波纹 / Loop 描边呼吸作为光效增强（低端机和测试回退 BoxShadow） | 用户要求光效；原 App 没有 shader |
| ⋮ 菜单 | 整行横移展开（录音 / 皮肤 / 编辑 / 分享 / 设置 / 返回），不是弹出菜单 | 4.7.0 `navMoreButtons`；「设置」是我们新增的入口 |
| 传输栏 / 速度 | 只在教程模式出现：▶/■ + 进度条 + 速度 1.0/0.7/0.5 | 4.7.0 `btnNavController=tutorialVelocity`；截图中的传输栏属于教程模式 |
| 停止全部 | 键盘 Space；`StopAllCmd`。演奏页没有常驻停止按钮 | 4.7.0 没有 |
| 教程 | 时间轴：pad 提前 `tutorial.fill`(1 s) 从下往上填满，判 PERFECT / TOO FAST / TOO SLOW / MISS；窗口优先用引擎谱面的 `perfectMs`/`missMs` | 4.7.0 tutorial.json；APK 的无时间步骤格式仍兼容 |
| 速度 | 实时变速播放（引擎 `SetSpeed`，varispeed）+ 教程时间轴同比缩放；只在教程模式出现，退出教程恢复 1.0 | 已定决策（4.7.0 未确认音频是否变速，分析文档 §9-2）；引擎 `transport_clock.song_secs` 同样按 speed 推进 |
| 曲库 | 3 个 Tab（KITS / FEED / PROFILE）+ 搜索；订阅横幅换成「新曲推送卡」；解锁弹窗去掉付费按钮 | ADR-0001 #4 |
| 编辑 Kit | 整页 `#EE4286` 粉底（primitive `swatch.mediumPink`，暂无 semantic token）；EDIT PAD 含颜色 / Loop / Hold / 分组 / 音量 / PITCH ±（半音 ±12）/ 声像 / 裁剪 / 复制 / 清空；试听走 `sample_preview`（不占用 pad） | 4.7.0 |
| 录音 | 录音结束弹「保存录音」面板，导出 `.flac` 后分享 | 4.7.0 |
| 引导 | Walkthrough 4 页 + 风格选择；Splash 用系统启动页 | 4.7.0（试用 / 订阅页不做） |
| 设置 / Hub / 皮肤编辑器 / 画廊 | 原 App 没有，按设计系统新做 | 需求 F7、F8、F10、ADR-0001 #13 |

## 8. 引擎适配（FFI）

`FfiEngineClient` 以当前生成绑定（`lib/src/rust/api/{engine,library,tracks,hub,types}.dart`）为准，`EngineClient` 的每个函数都有对应 FFI：

| 能力 | FFI |
|---|---|
| 生命周期 / 音频 | init / audio_start / audio_stop / audio_status / audio_devices / snapshot / events / pad_down / pad_up / send |
| 曲库 | library_list_kits / load_kit / import / import_bytes / export_kit |
| 编辑 Kit | `library_kit_json` + `library_save_kit(kitJson)`：读取 `up_model::KitDoc` JSON，修改 pad 字段（含 `pitchSemitones`）后写回（保留 layers / meta 等未知字段；换采样时清空 layers） |
| 采样 | sample_waveform、sample_preview / sample_preview_stop、sampler_record_start/stop、library_list_samples（`sampleInfo` 由它查找） |
| 作品 | tracks_list / track_play(loop) / track_stop / track_export / track_rename / track_delete |
| 教程 | tutorial_get（带 perfectMs / missMs） |
| Hub | `docs/API.md` §3.1 全部函数；事件见 API.md 的 Dart 映射说明 |
| 版本 / 更新 | `app_version`（设置「关于」）、`update_check` / `update_download` / `update_cancel` / `update_apply` / `update_relaunch`（§11） |
| ColorRole | 与引擎同名同序；调色板下标只由 `ColorRole.paletteIndex` 决定（API.md §3.1 末尾的映射表） |

`--dart-define=UP_ENGINE=mock` 使用 `MockEngineClient`；FFI 库加载失败时也自动回退到 Mock，
设置页显示「原生音频引擎不可用，正在以演示模式运行」。设置页的音频状态读 `audio_status`（不再为读状态重启音频）。

### 8.1 首次启动（`lib/src/library/first_run.dart`）

`runApp` 之后在后台执行，每一步失败只记日志：

1. 曲库为空 → 导入 `assets/kits/*.upkit`（CC0，`content/kits` 的副本）：`library_import_bytes`；
2. 注入了私有素材（`injected.json` 有 `privateKits`）且该次注入尚未导入 → 把 4.7.0 内置 Kit 的文件按原目录结构还原到临时目录，`library_import(dir)`（原 App 素材导入器），记录注入时间戳；
3. 桌面开发便利：`--dart-define=UP_PRIVATE_KITS=<dir>` 直接 `library_import(dir)`；
4. 引擎还没有 Kit → 默认加载：原版 Sunset → CC0 `UltraPads Starter` → 第一个。

## 9. 动效分级（up_fx）

`FxScope.tierOf`：减少动效（`MediaQuery.disableAnimations`）→ `minimal`；Web / 测试 → `lite`
（BoxShadow 光晕，golden 稳定）；其它 → `full`（Fragment Shader）。着色器加载失败自动回退。
pad 主体的渐变在 `full` 档由 `DitheredGradient`（`shaders/dither_gradient.frag`，±1/255 三角噪声）绘制：
Impeller（Android Vulkan / GLES）不对渐变做抖动，大面积低对比径向渐变 8 bit 量化后会出现同心淡环；
`lite` 档与测试仍用普通渐变。
设置「动画 Pad」关闭时 Lottie 不播放（APK `preferences_animate`）。

## 10. 测试

- `test/app_test.dart`：用 `MockEngineClient(realtime: false)` 启动完整应用；覆盖 Listener 同步触发、
  功能行展开、皮肤切换、时间轴教程与速度框、A/B、键盘映射、各页面 golden、LET'S PLAY、录音保存、引导、中文。
- `test/gallery_test.dart`：画廊交互，以及 3 个内置主题 + 16 套预设各一份 golden（组件页）。
- `test/update_test.dart`：更新状态机（Linux 装入并重启、Android 申请「安装未知应用」后安装、手动安装不下载、Mock 不自动检查）与设置页「软件更新」。
- `test/first_run_test.dart`（默认 Kit 顺序、打包的 CC0 Kit 与 `content/kits` 一致、空曲库导入）、
  `layout_test.dart`、`video_link_test.dart`、`first_guide_test.dart`、`image_skin_test.dart`。
- golden 位于 `test/goldens/`，字体由 `test/flutter_test_config.dart` 加载（Open Sans + Material Icons）。

## 11. 应用内更新（`lib/src/update/`，接口见 `docs/API.md` §6）

- **触发**：演奏页首帧后 `UpdateController.autoCheck()`，每进程最多一次；设置「自动检查更新」关闭或 Mock 引擎时跳过；
  失败不打扰用户。发现新版时演奏页 toast 一次（同一版本只提示一次，记在偏好 `updateNotified`）。
- **设置 → 关于 → 软件更新**（`features/settings/update_section.dart`）：状态一行 + 当前可做的一个动作——检查 / 更新 /
  取消 / 重启以完成更新（Linux）/ 安装（Android）/ 重试 / 下载页（`assets/config/links.json` 的 `downloadPage`，手动安装的副本）；
  有新版时另有「更新内容」（Release 页面）；下方是自动检查开关。
- **状态机**：`idle → checking → upToDate | available → downloading → ready | failed`。Linux（`selfUpdate`）下载完成即 `update_apply`，
  `ready` 后点重启：`update_relaunch` → `audioStop` → 退出；Android（`apkInstaller`）下载完成直接交给系统安装器，
  未允许「安装未知应用」时先打开该设置页并提示再点一次「安装」。
- 测试替换：`apkInstallerProvider`、`appExitProvider`；`MockEngineClient(appVersion:, availableUpdate:)` 模拟有新版本与下载。

