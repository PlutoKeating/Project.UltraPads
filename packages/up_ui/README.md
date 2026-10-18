# up_ui

UltraPads 组件库：纯展示，只接收数据和回调；**不依赖 up_engine**。颜色 / 尺寸 / 圆角 / 时长全部来自
`up_tokens`（`UpTheme.of(context)` 与 `Up*Tokens`），光效动效来自 `up_fx`，文案由调用方传入。

| 分组 | 组件 |
|---|---|
| Pad | `UpPad`（idle / 按下 / playing / pending / dimmed / empty / 教程填充 / 选中 / 编号；loop 闪烁与旋转；可选 Lottie 皮肤）、`PadGrid`（3×4、A/B 横移翻页、`Listener` 多点触控、键盘按下态） |
| 栏 | `UpTopBar`、`PerformMenuBar`、`BankButton`、`SpeedPill`、`TransportBar`、`TutorialBar`、`UpTabBar`、`UpSegmentTabs` |
| 基础 | `UpButton`（primary / secondary / outline / ghost / danger）、`UpIconButton`、`UpChip`、`UpBadge`、`UpSwatch(Row)`、`UpSlider`、`UpSearchField`、`UpText`、`PressScale` |
| 曲库 | `KitCover`、`KitCard`（下载 / 导入状态）、`BannerCarousel`、`GenreIcon`、`GenreRow` |
| 面板 | `UpSheet` + `showUpSheet`、`UpListItem`、`UpSwitchRow`、`UpDialog` + `showUpDialog` / `showUpConfirm`、`showUpToast` |
| 音频 | `WaveformView`（CustomPainter，进度 + 可拖动裁剪选区）、`UpMeter`、`UpProgressRing`、`RecordButton`、`TrackCard` |
| Hub | `PairingCodeDisplay`、`PairingCodeInput` |
| 皮肤 | `SkinTile`（用皮肤主题实时渲染迷你 pad，或私有缩略图） |

```bash
flutter test                  # golden（test/goldens）+ 多点触控 / 配对输入交互
flutter test --update-goldens # token 变化后
```
