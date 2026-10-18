# 视觉对比记录（v0.0.1 前端）

> 参考：App Store 4.7.0 截图（`m_us_iphone`、`m_cn_iphone`、`m_ipad`、`iphone_1..5`），
> 4.7.0 IPA 设计数据（`docs/research/compat-ipa-4.7.0-analysis.md`，828×1472 画布 ÷ 2）。
> 对比对象：golden 截图（`app/ultrapads/test/goldens/*.png`，414×736 逻辑像素，开源字体，无私有素材）
> 、Linux 实机运行截图（`flutter build linux --debug`，Mock / FFI 两种引擎）和 Android 模拟器
> （emulator-5554，API 34 x86_64，`adb exec-out screencap`）截图；运行截图不入库。

## 1. 截图清单

| 页面 | golden | 对应参考 |
|---|---|---|
| 演奏页（neon） | `perform_neon.png` | `iphone_1`（SONGS / TUTORIAL / ⋮ / A，3×4 霓虹 pad） |
| 演奏页 ⋮ 展开 | `perform_tools_expanded.png` | 4.7.0 `navMoreButtons` |
| 教程模式 | `perform_tutorial.png` | `m_cn_iphone` 第 4 张（■ + 进度条 + 1.0 速度） |
| 中文 | `perform_zh.png` | `m_cn_iphone` |
| 皮肤面板 | `skins_sheet.png` | 4.7.0 `modalSkins` |
| 曲库 KITS / FEED / PROFILE | `library_kits.png` / `library_feed.png` / `library_profile.png` | `iphone_4`、`m_cn_iphone` 第 2 张 |
| Kit 预览 | `kit_detail.png` | `m_cn_iphone` 第 3 张 |
| 编辑 Kit（LOAD SOUND） | `editor.png` | `iphone_3`、`m_cn_iphone` 第 5 张 |
| 保存录音 / 作品 | `save_recording.png` / `tracks.png` | `iphone_5`（TRACK 1 卡） |
| 引导 | `onboarding.png` / `onboarding_style.png` | 商店图标题文案、4.7.0 CategoryPreference |
| 设置 / Hub / 皮肤编辑器 | `settings.png` / `hub.png` / `skin_editor.png` | 新增页面，无参考 |
| 设计画廊 | `gallery_<主题>.png`（3 主题 + 16 预设）、`gallery_tokens.png`、`gallery_motion.png` | — |
| 组件 | `packages/up_ui/test/goldens/*.png` | — |

## 2. 已对齐

- 演奏页层次：粉色 SONGS 胶囊（深色图标格）+「Kit 名」；第二行粉色 LEARN TO PLAY + ⋮；右侧 A/B 方块；
  3×4 pad 占满剩余高度、2pt 间距、非正方形（与 4.7.0 cell 133.5×128 一致）。
- Pad：neon 径向渐变 + 底部斜面阴影；Loop pad 中列、蓝色、旋转图标；按下白色覆盖层 + 光晕；
  Loop 播放中白色闪烁（0.6 s yoyo）+ 图标 1.2 s 一圈；A/B 0.2 s QuadOut 横移。
- 教程：pad 从下往上填满；非目标 pad 暗化；▶/■ + 进度条 + 速度 1.0/0.7/0.5；判定 PERFECT / TOO FAST / TOO SLOW / MISS。
- 曲库：深色行（缩略图 + INSPIRED BY + 歌名 + 曲风）、选中粉色竖条、曲风圆形图标（HIP-HOP / FUNK BR / K-POP / ROCK / DISCO…）、底部 3 Tab（选中粉色圆）。
- 编辑 Kit：整页粉底、A/B 两个迷你面板（编号 1–9、A–C）、LOAD SOUND 五个来源行（小字 IMPORT FROM + 粗体标题 + 图标格）。
- TRACK 卡：标题 + 循环 / 分享图标 + ■ + 粉色已播放波形。
- 皮肤：3 个主题 + 16 套 4.7.0 预设实时 lerp 切换；注入素材后皮肤面板使用原版缩略图。

## 3. 差异与后续修正

| # | 差异 | 原因 | 修正项 |
|---|---|---|---|
| 1 | 字体：golden 用 Open Sans（与 4.7.0 一致）；商店截图的粗体更圆 | 截图是营销合成图 | 无需修正；注入 APK 素材后可选 Uni Sans（`UpFontSet.uniSans`） |
| 2 | Loop 待机 pad 颜色：截图 2 是紫色底 + 角色色描边；当前 neon 主题为深青底 | token `pad.loop.idleFill` 的取值 | 请 token 代理按截图 2 复核 neon 的 `pad.loop.idleFill` |
| 3 | 演奏页顶部 YouTube / BiliBili 视频按钮未做 | 没有视频源 | 有教学视频源后加回（`performVideoTutorial` 文案已有） |
| 4 | 演奏页底部 logo / 背景区（4.7.0 y 1365–1471）未做 | 原为广告区 + 远程 loader | 可放品牌 logo（私有素材） |
| 5 | 首次教学（FirstGuide：遮罩挖洞、手指动画、文字气泡、STEP x/4）未做 | 时间 | 用 `UpTutorialTokens` 的 bubble / hand / highlightHole 实现 |
| 6 | 曲库封面是程序化渐变 + 文字，不是 Kit 封面图 | 原 App 封面来自远程 CDN，素材中没有 | Kit 带 `coverPath` 时显示（`KitCover.image` 已支持） |
| 7 | FEED 页的大卡斜 6.8°「KIT」字标、ARTISTS 圆角缩略未完全复刻 | 时间 | 用 `UpKitCardTokens.bigLabelAngle` / `smallWidth` 补齐 |
| 8 | 皮肤 image / tint / scale 类（Christmas、Pets、Square…）只复刻颜色，没有装饰位图和 5 层方块缩放 | token 代理标注 `fidelity: partial` | 用注入的 `ios/skin/*` 位图做 `PadImageSkin`（`UpPad` 已有 Lottie 皮肤钩子，可同样扩展） |
| 9 | 编辑 Kit 缺 PITCH ± | `PadParams` 没有 pitch 字段 | 需要引擎在 `PadParams` / KitDoc 中暴露 `pitchSemitones` |
| 10 | 编辑 Kit 页底色用 primitive `swatch.mediumPink` | 没有对应 semantic token | 请 token 代理增加 `surface.editor` |
| 11 | 速度药丸图标、TRACK 卡图标是 Material Icons | 开源占位 | 注入素材后可替换为 `ios/icon/*`（未接线） |
| 12 | FFI 模式下真实曲库为空时显示 NO KIT LOADED | 曲库需先导入 | 首启时自动导入内置 Kit（需要引擎提供内置包路径或打包内置 Kit） |
| 14 | Android 模拟器（Impeller/Vulkan）上 pad 径向渐变能看到一圈淡淡的同心环（Linux 无） | 渐变色带 / 采样精度 | 渐变增加中间色标或改用着色器绘制 pad 主体 |
| 13 | iPad 布局：只有居中限宽（maxWidth 600），没有 `m_ipad` 的放大排版 | v0.0.1 只验证手机 / 桌面 | 按 `fixed_height` 等比缩放实现平板布局 |
