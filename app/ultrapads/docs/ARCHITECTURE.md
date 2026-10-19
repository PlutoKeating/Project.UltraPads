# UltraPads 前端架构（app/ultrapads）

> 全局架构见仓库根 `docs/ARCHITECTURE.md`；接口契约见 `docs/API.md`。

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
   ├─ library/first_run.dart 首次启动：导入内置 Kit（CC0 资源 / 注入的私有素材包 Kit）并加载默认 Kit
   ├─ config/app_links.dart  外部链接与服务地址（assets/config/links.json：下载页、官方站点 siteBase、账号 idIssuer / idClientId；页面不写 URL）
   ├─ account/               PlutoKeating 账号：auth_models（令牌 / 资料 / OIDC 配置）、auth_flow（Android 用 flutter_appauth，桌面用回环 + oauth2）、token_store（0600 文件）、account_state（登录 / 退出 / 刷新）
   ├─ dev/dev_hooks.dart     开发/验证环境变量（ULTRAPADS_HUB_AUTOSTART、ULTRAPADS_LOG_EVENTS、ULTRAPADS_UPDATE_SELFTEST）
   ├─ update/                应用内更新：update_controller.dart（状态机）、apk_installer.dart（Android 安装通道）
   ├─ routing/               routes.dart（路径常量）、router.dart（go_router + 转场）
   ├─ state/                 Riverpod：engine_state / perform_state / library_state / settings_state
   ├─ rust/                  FRB 生成代码（不要手改）
   └─ features/
      ├─ perform/            演奏页、功能按钮行、键盘映射、引擎→PadData 映射
      ├─ library/            曲库（KITS / FEED / 官方曲库 / PROFILE）、Kit 预览、曲风
      ├─ catalog/            官方曲库：目录客户端、列表 / 筛选 / 下载 / 云端收藏状态、详情页、署名（见 §12）
      ├─ account/            设置页账号区块（登录 / 退出、入口「我的上传」）
      ├─ ugc/                用户上传（UGC）界面：我的上传、上传表单、举报面板（客户端与状态在 `lib/src/ugc/`，见 §12）
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
| `/` | `PerformPage` 演奏页 | — | 参考设计 `ScreenPads/Main` |
| `/onboarding` | `OnboardingPage` | 无 | 参考设计 Walkthrough + CategoryPreference（试用页不做） |
| `/kits` | `LibraryPage`（KITS / FEED / 官方曲库 / PROFILE + 搜索） | 底部滑入 `sheet.enter` | 参考设计 `MenuScene` |
| `/kits/:id` | `KitDetailPage` Kit 预览 | 右侧推入 `page.push` | 参考设计 `modalUnlockKit`（去掉解锁/付费） |
| `/catalog/:id` | `CatalogDetailPage` 官方曲库条目详情（署名、许可证、下载 / 演奏；社区上传条目另有说明与举报） | 右侧推入 | 新增（docs/API.md §7） |
| `/uploads` | `MyUploadsPage` 我的上传（状态、公开 / 私有、删除、取回、选 Kit 上传） | 右侧推入 | 新增（docs/API.md §7.5） |
| `/uploads/new/:kitId` | `UploadFormPage` 上传表单（署名、许可证、来源声明、确认有权分享） | 右侧推入 | 新增（docs/API.md §7.5） |
| `/edit` | `EditorPage` 编辑 Kit | 底部滑入 | 参考设计 `CreateKit/Main` |
| `/edit/mic` | `MicSamplerPage` 麦克风采样（返回 `SampleInfo`） | 推入 | 参考设计 mic 面板 |
| `/tracks` | `TracksPage` 我的录音 | 推入 | 参考设计 PROFILE → 我的录音 |
| `/skins/editor?id=` | `SkinEditorPage` 自定义皮肤 | 推入 | 新增 |
| `/settings` | `SettingsPage` | 推入 | 新增（参考设计无设置页） |
| `/hub` | `HubPage` 多设备协同 | 推入 | 新增（F10） |
| `/dev/gallery?tab=&skin=` | `DesignGalleryPage` | 推入 | 新增（ADR-0001 #13 修订：替代 Figma） |

弹层（不是路由）：皮肤面板 `showSkinsSheet`（0.4 s QuadOut 底部滑入）、保存录音 `showSaveRecordingSheet`、采样选择、确认对话框。

- 未完成引导时 `redirect` 到 `/onboarding`；画廊路由不受影响。
- `--dart-define=UP_GALLERY=true` 时初始路由为 `/dev/gallery`；`--dart-define=UP_ROUTE=<路由>` 或桌面环境变量
  `ULTRAPADS_ROUTE` 指定初始路由（开发 / 截图）。
- 宽屏（平板 / 桌面）：除演奏页外的页面在 router 中统一包 `WideBody`（`routing/wide_body.dart`），限宽 600 居中；
  演奏页见 §3.2。

### 3.1 演奏页结构

```
UpTopBar: [♫ SONGS] <歌名> ………………………………………………………………… [⚙ 设置]
功能行 (functionRow 50pt)：[A][B][C]…（音色组切换条） | [⋮]
  ⋮ 展开（整行横移，0.3 s CircIn/CircOut）：[● 录音] [皮肤] [编辑] [分享] [◀]
PadGrid 3×4（当前音色组；组间横移 0.2 s QuadOut）
首次引导浮层（FirstGuide，未看过时）
```

- **顶栏**：标题直接显示歌名（Kit 名，不带「KIT / 音色包」前缀）；右上角 `TopBarTileButton` 是设置入口（原视频教程按钮的位置）。
- **音色组**：一首歌有 `KitSummary.groupCount` 组（A–G，最多 7 组），`PadGroupSwitcher` 点击切换（`bankProvider`）。
  切换只改变接下来触摸的 pad，已经在播放的声音（包括 Loop）继续——引擎始终为全部组的 pad 留位。键盘 Tab 依次切到下一组。
- **学习演奏 / 教程模式与速度控件已移除**（v0.2.0）；引擎与 FFI 的教程能力（`tutorial_get` 等）保留。
- **首次引导**（`features/onboarding/first_guide.dart`，参考设计 FirstGuide）：70% 遮罩挖洞、手指 1.0 s QuadIn
  上移、白色气泡、STEP x/4（从右滑入）、SKIP（0.25 s 滑入）；4 步：pad → 音色组切换条 → ⋮ → SONGS。
  完成或跳过后写入设置 `firstGuideSeen`；设置页「开发者 → 重新显示新手引导」可重置。

### 3.2 宽屏布局（`features/perform/perform_layout.dart`）

参考设计用 FairyGUI `fixed_height` 适配（画布 828×1472 px 按高度等比缩放）。手机布局不变；宽高比超过画布时，
pad 网格按参考设计 cell 几何的宽高比（约 0.78）由可用高度算出宽度并水平居中，顶栏与功能行与网格同宽。
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
| `bankProvider` | 当前显示的音色组（0 = A；纯 UI；加载 Kit 时回到 A） | UI |
| `kitLoadProvider` / `favoritesProvider` | 加载中的 Kit；收藏（本机偏好） | UI / prefs |
| `settingsProvider` / `upThemeProvider` / `localeControllerProvider` | 皮肤、自定义皮肤、动画开关、音频偏好、自动检查更新、语言 | SharedPreferences |
| `updateProvider` | 应用内更新阶段（检查 / 可更新 / 下载进度 / 待重启或待安装 / 失败） | `update_*`（§11） |
| `accountProvider` | 账号状态（加载中 / 未登录 / 登录中 / 已登录 + 邮箱），`accessToken()` 按需静默刷新 | 令牌文件 + OIDC（§12） |
| `catalogListProvider` / `catalogFacetsProvider` / `catalogItemProvider` | 目录分页列表与筛选、facets、单个条目 | `/api/catalog`（§12） |
| `catalogDownloadProvider` / `catalogRecordsProvider` | 进行中的下载进度；已下载条目记录（署名来源） | 目录下载 + 引擎导入 / prefs |
| `cloudStateProvider` | 官方曲库收藏、最近使用、待同步队列 | prefs + `/api/me/*` |
| `myUploadsProvider` / `uploadProvider` / `reportUploadProvider` | 我的上传列表与操作；导出 → 建条目 → 流式上传的流程状态；举报 | `/api/me/uploads*`、`/api/catalog/<id>/report`（§12） |

规则：业务变更一律经 `EngineClient`（命令或异步函数）；Provider 只做投影。
`tryEngine` / `tryEngineDo` 把 `EngineNotImplemented` 转成 null / false，页面据此显示
「音频引擎暂不支持此功能」（`errorEngineUnsupported`）。

## 5. 触摸延迟

- `PadGrid` 外层一个 `Listener`（不进手势竞技场），按坐标命中 pad。**触摸到即触发**：每个 pointer 记录它当前触摸的 pad，
  按下落在 pad 上或移动时滑进新的 pad 都立即 `padDown`（先松开上一个 pad），滑出 / 抬起 / 取消时 `padUp`；在空 pad 上按下再滑进有声音的 pad 同样触发。
  支持多点触控；鼠标只有按住主键时触发。
- pad 按下态当帧即全亮（不等动画控制器下一帧起步），松开 0.1 s 淡出。
- 回调先同步调用 `padDown`（FRB `sync`，只推命令），再 `setState` 显示按下态。
- UI isolate 保持空闲，指针事件才能立即处理：演奏页只 `select` 自己用到的 `EngineView` 字段（走带位置播放时约 60 Hz，
  不触发整页重建）；`FfiEngineClient` 把 Transport 事件与缓存的走带状态合并，不为每个事件做一次同步 `snapshot()`。
- 音频侧延迟见根目录 `docs/ARCHITECTURE.md` §4（Linux PipeWire 原生 + 实时优先级、Android LowLatency、桌面默认 128 帧）。设置页的缓冲档位在 Android 上隐藏
  （由 AAudio 决定，显示为「系统」）。
- 键盘映射（桌面）：`1 2 3 / Q W E / A S D / Z X C` 对应当前组 12 个 pad，Tab 切到下一组，Space 停止全部，R 录音；
  键盘按下态通过 `PadGrid.externallyPressed` 同样立即显示。

## 6. 私有素材注入

- 入库：`assets/private_manifest/manifest.json`（占位，`available: false`）+ 目录内 `.gitignore`。
  pubspec 只声明这一个目录，**它永远存在**，所以没有私有素材时构建照常通过。
- 注入：`just inject-assets`（`tools/assets/inject_private_assets.dart`）把
  `private-assets/compat-ios/`（iOS 格式，优先）和 `private-assets/compat-android/`（Android 格式，补充）
  中 UI 需要的素材**平铺**复制到同一目录（`<来源>_<类别>__<路径>`，被 `.gitignore` 忽略），
  并生成 `injected.json`（`priority: [ios, apk]`、`entries: {ios/skin/…: assets/private_manifest/…}`）。
  付费墙 / GDPR / IDFA / 广告相关包不注入。`just clean-assets` 删除。
- 运行时：`PrivateAssets.load()` 先读 `injected.json`，失败读占位清单；`resolve(类别, 文件)` 按优先级查找。
  缺失时回退开源占位：Open Sans（up_tokens 打包）、Material Icons、程序化绘制的 pad / 封面。
- 当前用到的私有素材：皮肤缩略图（`ios/ui/ScreenPads__img_skins_*`）、Uni Sans 字体（Android 格式素材，
  注册为 `UpFonts.privateFiles` 的家族名）、Android 格式素材的 `normal_*` Lottie（设置「经典 Pad 动画」开启时）、
  image 类皮肤（Christmas / Pets / Muertos / Halloween）的整张 pad 位图（`PadImageSkin`：常态位图 +
  按下 / Loop 闪烁时淡入的亮态位图，`BoxFit.fill`，缺色退回 pink；未注入时保持 token 绘制）、
  私有素材包的 6 个内置 Kit（`privateKits`，首次启动导入，见 §8.1）。

## 7. 设计取舍（截图 / 参考设计 / 旧版参考冲突时的决定）

| 方面 | 决定 | 依据 / 原因 |
|---|---|---|
| 第一基准 | **参考设计（FairyGUI 数据）+ 商店截图**；旧版参考只补充 | 主代理通知；参考设计与截图一致 |
| Pad 外观 | 程序化绘制（token 渐变 + 白色/浅色覆盖层 + 光晕），不用参考设计的 72px 位图 | 位图是 9 宫格小图，程序化能跟随皮肤 token 与 lerp；16 套预设由 token 代理转成 semantic 覆盖 |
| 默认皮肤 | `neon`（截图的霓虹径向渐变 + 光晕）；参考设计 `Default` 等 16 套作为预设可选 | 用户要求以截图为准 |
| Pad 动效 | 按下 1 帧变亮（`pad.pressAttack` 17 ms），松开 0.1 s QuadOut；Loop 白色闪烁 0.6 s yoyo + 图标 1.2 s 一圈 | 参考设计 Transition |
| Lottie | 保留 `SegmentedLottie`（按下播 0→0.5、松开 0.5→1），仅在设置「经典 Pad 动画」+ 注入了 Android 格式素材时使用 | 参考设计没有 Lottie；旧版参考的效果作为可选旧版皮肤 |
| Fragment Shader | 霓虹 bloom / 按下波纹 / Loop 描边呼吸作为光效增强（低端机和测试回退 BoxShadow） | 用户要求光效；参考设计没有 shader |
| ⋮ 菜单 | 整行横移展开（录音 / 皮肤 / 编辑 / 分享 / 返回），不是弹出菜单；设置入口在顶栏右上角 | 参考设计 `navMoreButtons`；v0.2.0 用户要求 |
| 功能行 / 顶栏 | 参考设计的 LEARN TO PLAY 与视频教程按钮移除，改为音色组切换条与设置入口；顶栏只显示歌名 | v0.2.0 用户要求 |
| 停止全部 | 键盘 Space；`StopAllCmd`。演奏页没有常驻停止按钮 | 参考设计没有 |
| 教程 / 速度 | 界面移除（v0.2.0）；引擎仍解析参考设计 `tutorial.json`、提供 `SetSpeed` 与 `tutorial_judge` | v0.2.0 用户要求 |
| 曲库 | 3 个 Tab（KITS / FEED / PROFILE）+ 搜索；订阅横幅换成「新曲推送卡」；解锁弹窗去掉付费按钮 | ADR-0001 #4 |
| 编辑 Kit | 整页 `#EE4286` 粉底（primitive `swatch.mediumPink`，暂无 semantic token）；pad 区左侧为当前音色组的 12 个迷你 pad，右侧为组切换与新增 / 左移 / 右移 / 删除（删除有声音的组需确认，组结构变化实时同步引擎，保存时组数变化则重载 Kit）；EDIT PAD 含颜色 / Loop / Hold / 分组 / 音量 / PITCH ±（半音 ±12）/ 声像 / 裁剪 / 复制 / 清空；试听走 `sample_preview`（不占用 pad） | 参考设计 |
| 录音 | 录音结束弹「保存录音」面板，导出 `.flac` 后分享 | 参考设计 |
| 引导 | Walkthrough 4 页 + 风格选择；Splash 用系统启动页 | 参考设计（试用 / 订阅页不做） |
| 设置 / Hub / 皮肤编辑器 / 画廊 | 参考设计没有，按设计系统新做 | 需求 F7、F8、F10、ADR-0001 #13 |

## 8. 引擎适配（FFI）

`FfiEngineClient` 以当前生成绑定（`lib/src/rust/api/{engine,library,tracks,hub,types}.dart`）为准，`EngineClient` 的每个函数都有对应 FFI：

| 能力 | FFI |
|---|---|
| 生命周期 / 音频 | init / audio_start / audio_stop / audio_status / audio_devices / snapshot / events / pad_down / pad_up / send |
| 曲库 | library_list_kits / load_kit / import / import_bytes / export_kit |
| 编辑 Kit | `library_kit_json` + `library_save_kit(kitJson)`：读取 `up_model::KitDoc` JSON，修改 pad 字段（含 `pitchSemitones`）后写回（保留 layers / meta 等未知字段；换采样时清空 layers） |
| 采样 | sample_waveform、sample_preview / sample_preview_stop、sampler_record_start/stop、library_list_samples（`sampleInfo` 由它查找） |
| 作品 | tracks_list / track_play(loop) / track_stop / track_export / track_rename / track_delete |
| 教程 | tutorial_get（带 perfectMs / missMs；v0.2.0 起界面不再使用） |
| Hub | `docs/API.md` §3.1 全部函数；事件见 API.md 的 Dart 映射说明 |
| 版本 / 更新 | `app_version`（设置「关于」）、`update_check` / `update_download` / `update_cancel` / `update_apply` / `update_relaunch`（§11） |
| ColorRole | 与引擎同名同序；调色板下标只由 `ColorRole.paletteIndex` 决定（API.md §3.1 末尾的映射表） |

`--dart-define=UP_ENGINE=mock` 使用 `MockEngineClient`；FFI 库加载失败时也自动回退到 Mock，
设置页显示「原生音频引擎不可用，正在以演示模式运行」。设置页的音频状态读 `audio_status`（不再为读状态重启音频）。

### 8.1 首次启动（`lib/src/library/first_run.dart`）

`runApp` 之后在后台执行，每一步失败只记日志：

1. 曲库为空 → 导入 `assets/kits/*.upkit`（CC0，`content/kits` 的副本）：`library_import_bytes`；
2. 注入了私有素材（`injected.json` 有 `privateKits`）且该次注入尚未导入 → 把私有素材包内置 Kit 的文件按原目录结构还原到临时目录，`library_import(dir)`（私有素材包导入器），记录注入时间戳；
3. 桌面开发便利：`--dart-define=UP_PRIVATE_KITS=<dir>` 直接 `library_import(dir)`；
4. 引擎还没有 Kit → 默认加载：私有素材包的 Sunset → CC0 `UltraPads Starter` → 第一个。

## 9. 动效分级（up_fx）

`FxScope.tierOf`：减少动效（`MediaQuery.disableAnimations`）→ `minimal`；Web / 测试 → `lite`
（BoxShadow 光晕，golden 稳定）；其它 → `full`（Fragment Shader）。着色器加载失败自动回退。
pad 主体的渐变在 `full` 档由 `DitheredGradient`（`shaders/dither_gradient.frag`，±1/255 三角噪声）绘制：
Impeller（Android Vulkan / GLES）不对渐变做抖动，大面积低对比径向渐变 8 bit 量化后会出现同心淡环；
`lite` 档与测试仍用普通渐变。
设置「动画 Pad」关闭时 Lottie 不播放（旧版参考 `preferences_animate`）。

## 10. 测试

- `test/app_test.dart`：用 `MockEngineClient(realtime: false)` 启动完整应用；覆盖 Listener 同步触发、
  功能行展开、皮肤切换、顶栏（歌名 + 设置入口）、音色组切换（切换不打断播放）、键盘映射、各页面 golden、LET'S PLAY、录音保存、引导、中文。
- `test/editor_groups_test.dart`：编辑器新增 / 右移 / 删除音色组（实时同步引擎、删除需确认）。
- `test/gallery_test.dart`：画廊交互，以及 3 个内置主题 + 16 套预设各一份 golden（组件页）。
- `test/update_test.dart`：更新状态机（Linux 装入并重启、Android 申请「安装未知应用」后安装、手动安装不下载、Mock 不自动检查）与设置页「软件更新」。
- `test/first_run_test.dart`（默认 Kit 顺序、打包的 CC0 Kit 与 `content/kits` 一致、空曲库导入）、
  `layout_test.dart`、`first_guide_test.dart`、`image_skin_test.dart`。
- `test/catalog_client_test.dart` / `catalog_state_test.dart` / `catalog_test.dart`：目录客户端（查询参数、分页、sha256 校验、取消、账号数据）、列表 / 下载 / 云端收藏状态、官方曲库页与详情页（筛选、搜索防抖、下载 → 演奏、署名提示）与设置页账号区块；假服务见 `test/catalog_fixtures.dart`（`FakeSite`，按 docs/API.md §7 行为，含 §7.5 的上传 / 举报）。
- `test/ugc_test.dart`：上传表单校验、`UgcClient`（超限不发请求、取消、`Content-Length` / `X-Sha256`）、来源筛选与社区条目举报流程、我的上传（各状态、公开确认、删除、取回入口）、上传流程（成功、文件被拒后清理、配额）。
- `test/account_test.dart`：令牌文件（0600）、登录 / 退出 / 恢复、并发刷新只发一次、`invalid_grant` 退出、桌面回环登录（真实 127.0.0.1 监听 + 假 IdP，核对 PKCE / state / 无密钥）。
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

## 12. 官方曲库与账号（`features/catalog/`、`account/`，接口见 `docs/API.md` §7，决策见 ADR-0005）

- **站点地址**：`assets/config/links.json` 的 `siteBase`（可用 `--dart-define=UP_SITE=<url>` 覆盖，联调本地 Worker）；`idIssuer` / `idClientId`（`ultrapads-app`）。页面里不写 URL。启动时配置还在读 asset，所以目录与登录都先 `await appLinksProvider.future`（`awaitCatalogClient`）。
- **曲库页**（`LibraryPage` 第三个 Tab「官方曲库」，第一次选中才构建并联网）：搜索（防抖）、收藏 / 排序 / 许可证 / 曲风 / 速度筛选芯片（选项来自 `/api/catalog/facets`）、分页（滚到距底部 400 px 预取；首页没填满视口时自动补页）、下拉刷新、离线 / 空结果状态。条目卡 = `KitCard` + 许可证徽标（CC0 / BY / BY-SA / BY-NC…，SA / NC 用醒目样式，长按显示说明）+ 收藏心形。
- **详情页**（`/catalog/:id`）：署名原文、许可证说明、来源与许可证链接；下载 → 进度 / 取消 → 校验 `sha256`（`CatalogClient.download` 边收边算，不符删除文件并报 `hash_mismatch`）→ `engine.libraryImport`（引擎转 WAV 入库）→ 「演奏」加载 Kit。已下载记录（`catalogRecordsProvider`，prefs `catalog.records`）含条目元数据与导入得到的 Kit 名，目录里 `sha256` 变了则显示「更新」。
- **云端收藏 / 最近使用**（`CloudStateController`）：本地先生效并持久化；每个改动进待发队列（prefs `catalog.pending`），登录且联网时按序送达，失败留队、404 条目丢弃；登录后 / 启动恢复登录后拉取 `/api/me/state` 与本地取并集（待发的取消收藏优先）。`UltraPadsApp` 常驻监听它，所以不必打开曲库页也会同步。
- **账号**（`account/`）：OIDC 授权码 + PKCE，签发方 `https://id.plutokeating.beer/`（Hydra），公共客户端 `ultrapads-app`。
  - Android / iOS / macOS：`flutter_appauth`（Custom Tabs），回调 `com.plutokeating.ultrapads://callback`（`build.gradle.kts` 的 `appAuthRedirectScheme`）。
  - **Linux 等桌面**：flutter_appauth 没有 Linux 实现，改走 RFC 8252 回环方案——`LoopbackAuthFlow` 在 `127.0.0.1` 随机端口起一次性 HTTP 监听，系统浏览器（`url_launcher`）打开授权页，回调后用 `oauth2` 包换令牌（PKCE S256 + 随机 `state`，无客户端密钥；5 分钟超时，可取消）。Hydra 对回环地址允许任意端口，`clients.json` 登记 `http://127.0.0.1/callback`。
  - 刷新（两个平台共用）：`refreshTokens` 向 token 端点 POST `refresh_token`；并发只刷一次；`invalid_grant` 退出登录，仅网络错误则沿用旧令牌。ID 令牌里没有邮箱时问一次 userinfo。
  - **令牌存储**：应用私有目录里的 `account.json`，权限 0600，写入走「临时文件 → rename」（`FileTokenStore`）。不用 flutter_secure_storage：它的 Linux 实现依赖 libsecret 与桌面 keyring，会给发布包新增系统库依赖，无 keyring 的环境读写还会失败。代价是令牌只受文件系统权限与应用沙盒保护（Android 沙盒内他人不可读），不是硬件密钥库。
- **署名与导出**：保存 / 分享录音时，若当前 Kit 来自需署名的目录条目（非 CC0 / PD），保存面板显示署名与限制（NC：仅限非商业；SA：以相同许可证分享），分享文字附上署名（`features/catalog/credits.dart`，按录音的 `kitName` 匹配已下载记录）。**未做**：写入 WAV `bext` 元数据——应用分享的是 FLAC，署名走分享文字。
- **用户上传（UGC）**（`lib/src/ugc/`、`features/ugc/`，契约见 docs/API.md §7.5）：
  - `UgcClient` 复用 `CatalogClient` 的站点地址、令牌与错误模型（`resolve` / `authHeaders` / `request` 几个公开口子），自己只管上传相关的请求。
  - **上传流程**（`UploadController`）：`libraryExportKit(kit, path, upkit)` 导出到临时文件（`ugcExportProvider`）→ 本地算 SHA-256 → `POST /api/me/uploads` 建条目（恒为私有）→ `PUT …/file` 流式上传，带 `Content-Length` 与 `X-Sha256`，进度来自已交给网络层的字节（`StreamSink.addStream` 带背压，不会把整个文件读进内存）→ 加入「我的上传」。超过 128 MB 在客户端先拦住；取消或任一步失败时尽力删除已建的空条目，不占账号配额；临时文件始终清理。
  - **表单**：标题（≤120）、署名（≤500，原样展示）、许可证（目录白名单，含 NC / SA）、来源声明（`own` / `licensed`）、来源链接（可空，须 http(s)），必须打开「我有权分享」才能提交；`validateUpload` 是纯函数，错误在第一次提交后才显示。状态码 400 / 411 / 413 / 422 / 429 / 401 / 403 / 410 / 409 映射成友好文案（`ugcErrorMessage`）。
  - **我的上传**：显示私有 / 公开 / 已隐藏（被举报待审）/ 已下架 / 还没有文件；设为公开前确认（说明会公开署名与许可证）；已下架的只能删除；「下载到本机」取回自己的文件（含私有）并导入曲库，用于换设备。退出登录清空列表。
  - **社区来源**：目录筛选条末尾的「来源」芯片（选项来自 facets 的 `origins`，`origin=ugc` 即社区上传）；社区条目详情页显示「社区上传」徽标、署名由上传者声明的说明和「举报」（需登录；本人上传不显示；原因 copyright / inappropriate / other + 可选说明，同一用户对同一条目只计一次）。
- **测试替换**：`ugcExportProvider`、`ugcTempDirProvider`、`catalogHttpClientProvider`、`catalogDownloadDirProvider`、`tokenStoreProvider`、`authFlowProvider`、`authHttpClientProvider`；`test/harness.dart` 的 `pumpApp` 默认全部换成假实现（`FakeSite`、`FakeAuthFlow`、内存令牌、临时目录）。

## 13. 导入歌曲拆成 Kit（`lib/src/split/`、`features/split/`，接口见 `docs/API.md` §8）

- 入口：曲库页「我的」→「导入歌曲拆成 Kit」，选本机音频文件后弹出 `SplitSongSheet`（`showSplitSongSheet`）。
- 两种模式：**按乐器分轨**（Demucs，本机处理；`EngineClient.splitCapabilities()` 按可用内存决定是否可选，不可选时给出所需内存）与**快速拆分**（整曲混音，几秒）。
- `ModelStore`（`split/model_store.dart`）：分轨模型（htdemucs ONNX fp16 权重，约 158 MB）不随应用分发，用户同意后经 `http` 下载到 `<应用数据目录>/models/`，先写 `.part`、边下边算 sha256，校验通过才改名；`installed()` 以文件大小判定。测试里 `modelDirProvider` / `modelStoreProvider` 可替换。
- `SplitController`（`splitProvider`）：必要时先下载模型（`downloadingModel`），再消费 `EngineClient.splitSong(...)` 进度流（`running` → `done` / `failed`）；取消同时停下载与引擎；失败原因是 `[tag]`（引擎）或 `model_<原因>`（下载），由面板映射成文案。完成后可「载入演奏」。
- 引擎侧在 Rust 线程里解码、分析、分轨并直接导入曲库（`library_changed` 事件刷新列表），Dart 侧只持有进度。
