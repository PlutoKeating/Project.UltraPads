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
`showSpeedModal`（1.0 / 0.7 / 0.5）、保存录音 `showSaveRecordingSheet`、采样选择、确认对话框。

- 未完成引导时 `redirect` 到 `/onboarding`；画廊路由不受影响。
- `--dart-define=UP_GALLERY=true` 时初始路由为 `/dev/gallery`。

### 3.1 演奏页结构

```
UpTopBar: [♫ SONGS] KIT <名称> ……………… [速度 1.0×（仅教程模式）]
功能行 (functionRow 50pt) ──────────────────────────── [A/B 64.5×63]
  默认：[🎓 LEARN TO PLAY] | [⋮]
  ⋮ 展开（整行横移，0.3 s CircIn/CircOut）：[● 录音] [皮肤] [编辑] [分享] [设置] [◀]
  教程模式：[▶/■] ———o——— [✕]
PadGrid 3×4（A/B 两页横移 0.2 s QuadOut），教程模式叠加判定反馈层
```

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
| `settingsProvider` / `upThemeProvider` / `localeControllerProvider` | 皮肤、自定义皮肤、动画开关、音频偏好、语言 | SharedPreferences |

规则：业务变更一律经 `EngineClient`（命令或异步函数）；Provider 只做投影。
`tryEngine` / `tryEngineDo` 把 `EngineNotImplemented` 转成 null / false，页面据此显示
「音频引擎暂不支持此功能」（`errorEngineUnsupported`）。

## 5. 触摸延迟

- `PadGrid` 外层一个 `Listener`（不进手势竞技场），按坐标命中 pad；每个 pointer 记录按下的 pad，
  抬起 / 取消时释放同一个 pad，支持多点触控。鼠标只有主键触发。
- 回调先同步调用 `padDown`（FRB `sync`，只推命令），再 `setState` 显示按下态。
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
  注册为 `UpFonts.privateFiles` 的家族名）、APK `normal_*` Lottie（设置「经典 Pad 动画」开启时）。

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
| 速度 | 只缩放教程时间轴，不改变演奏音频速度 | 4.7.0 未确认音频是否变速（分析文档 §9-2） |
| 曲库 | 3 个 Tab（KITS / FEED / PROFILE）+ 搜索；订阅横幅换成「新曲推送卡」；解锁弹窗去掉付费按钮 | ADR-0001 #4 |
| 编辑 Kit | 整页 `#EE4286` 粉底（primitive `swatch.mediumPink`，暂无 semantic token）；EDIT PAD 含颜色 / Loop / Hold / 分组 / 音量 / 声像 / 裁剪 / 复制 / 清空 | 4.7.0；Pitch 暂缺（`PadParams` 没有 pitch 字段） |
| 录音 | 录音结束弹「保存录音」面板，导出 `.flac` 后分享 | 4.7.0 |
| 引导 | Walkthrough 4 页 + 风格选择；Splash 用系统启动页 | 4.7.0（试用 / 订阅页不做） |
| 设置 / Hub / 皮肤编辑器 / 画廊 | 原 App 没有，按设计系统新做 | 需求 F7、F8、F10、ADR-0001 #13 |

## 8. 引擎适配（FFI）

`FfiEngineClient` 以当前生成绑定（`lib/src/rust/api/{engine,library,tracks,hub,types}.dart`）为准：

| 能力 | 状态 |
|---|---|
| init / audio_start / audio_stop / audio_devices / snapshot / events / pad_down / pad_up / send | 已接 |
| library_list_kits / load_kit / import / export_kit | 已接 |
| 编辑 Kit：`library_kit_json` + `library_save_kit(kitJson)` | 已接：读取 `up_model::KitDoc` JSON，修改 pad 字段后写回（保留 layers / meta 等未知字段；换采样时清空 layers） |
| 采样：sample_waveform、sampler_record_start/stop、library_list_samples | 已接（`sample_info` 用 list_samples 查找） |
| 采样试听 `sample_preview` | **缺**，抛 `EngineNotImplemented` |
| 作品：tracks_list / play / stop / export / rename / delete | 已接（`track_play` 没有 loop 参数） |
| tutorial_get | 已接（带 perfectMs / missMs） |
| Hub：start / stop / discover / pair / sync / controller | 已接；引擎侧目前返回 NotImplemented 时 UI 降级；**服务启动后没有配对码** |
| ColorRole | 引擎是命名枚举（blue/orange/…/neutral），映射到 token 调色板下标（purple→magenta、red→rose、lime→green、grey/neutral→cyan） |

`--dart-define=UP_ENGINE=mock` 使用 `MockEngineClient`；FFI 库加载失败时也自动回退到 Mock，
设置页显示「原生音频引擎不可用，正在以演示模式运行」。

## 9. 动效分级（up_fx）

`FxScope.tierOf`：减少动效（`MediaQuery.disableAnimations`）→ `minimal`；Web / 测试 → `lite`
（BoxShadow 光晕，golden 稳定）；其它 → `full`（Fragment Shader）。着色器加载失败自动回退。
设置「动画 Pad」关闭时 Lottie 不播放（APK `preferences_animate`）。

## 10. 测试

- `test/app_test.dart`：用 `MockEngineClient(realtime: false)` 启动完整应用；覆盖 Listener 同步触发、
  功能行展开、皮肤切换、时间轴教程与速度框、A/B、键盘映射、各页面 golden、LET'S PLAY、录音保存、引导、中文。
- `test/gallery_test.dart`：画廊交互，以及 3 个内置主题 + 16 套预设各一份 golden（组件页）。
- golden 位于 `test/goldens/`，字体由 `test/flutter_test_config.dart` 加载（Open Sans + Material Icons）。
