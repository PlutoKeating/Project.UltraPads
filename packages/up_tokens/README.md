# up_tokens

UltraPads 设计 token 的 Dart 端：

- `lib/src/generated/`：由 `design/tokens` 生成（**不要手改**，用 `just tokens` 重新生成）
  - `primitives.g.dart`：`UpPrimitiveColors`、`UpSpacing`、`UpRadii`、`UpRatios`、`UpSizes`、`UpDurations`、`UpEasings`、`UpSprings`、`UpShadows`、`UpGlows`、`UpOpacities`、`UpBlurs`、`UpZIndex`、`UpBorderWidths`、`UpFont*`、`UpTextRoles` 和 `enum UpTextRole`
  - `components.g.dart`：`UpPadTokens`、`UpPadGridTokens`、`UpTopBarTokens`、`UpChipTokens`、`UpKitCardTokens`、`UpBannerTokens`、`UpSheetTokens`、`UpListItemTokens`、`UpWaveformTokens`、`UpMeterTokens`、`UpProgressRingTokens`、`UpSliderTokens`、`UpButtonTokens`、`UpDialogTokens`、`UpGenreIconTokens` 等
  - `semantic.g.dart`：`UpSemantic`（全部语义 token 的值对象，带 `copyWith`、`lerp`、`withValues`、`valueOf`、`padRole`，以及给皮肤编辑器用的 `tokens` 元数据）
  - `semantic_<theme>.g.dart`、`themes.g.dart`：内置主题的值和注册表 `UpSemanticThemes`
  - `skins.g.dart`：原版 16 套皮肤预设 `UpSkinPresets`
- `lib/src/runtime/`：手写的运行时 —— `UpTheme`（`ThemeExtension`）、`UpThemes`、`UpSkin` / `UpSemanticOverrides`（自定义皮肤和 JSON）、`UpSkinPreset`、`UpGlowSpec`、`UpGradient`、`UpPadRole`、`UpTypography`、`UpFonts`、`UpMotion`

## 规则

| 取什么 | 从哪里取 |
|---|---|
| 颜色、渐变、pad 状态参数（随皮肤变化） | `UpTheme.of(context).colors.*` |
| 文字样式 | `UpTheme.of(context).text[UpTextRole.x]` |
| 组件几何、动效、光晕配方（与皮肤无关） | `Up<Component>Tokens.*` |
| 通用刻度 | `UpSpacing` / `UpRadii` / `UpDurations` / `UpEasings` / `UpSprings` … |

UI 代码中禁止出现 `Color(0x…)`、`Colors.*`、数字字面量的圆角、时长、内边距和字号（由 `tools/lint/no_hardcode.dart` 检查）。

## 接入

```dart
import 'package:up_tokens/up_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UpFonts.loadPrivate();   // 可选：注册已注入的 Uni Sans（默认字体 Open Sans 已打包，无需加载）
  runApp(MaterialApp(theme: UpThemes.neon.toThemeData(), home: const Home()));
}
```

用 `MaterialApp.theme` 换主题时，`ThemeData.lerp` → `UpTheme.lerp` 会逐个插值全部语义 token 和文字样式，切换主题自带过渡动画（时长由 `themeAnimationDuration` 控制，例如设成 `UpDurations.slow`）。

## 组件取值示例

```dart
final t = UpTheme.of(context);
final role = t.padRole(kitPad.colorIndex);            // Kit 里只存角色序号，超出范围会循环
final side = constraints.biggest.shortestSide;

DecoratedBox(
  decoration: BoxDecoration(
    gradient: role.gradient(radial: t.colors.padFillRadial,
                            opacity: t.colors.padIdleFillOpacity),
    borderRadius: BorderRadius.circular(side * t.colors.padShapeRadiusRatio),
    border: Border.all(color: role.mid, width: t.colors.padIdleBorderWidth),
    boxShadow: UpPadTokens.glowPressed.shadows(role.glow,
        intensity: t.colors.padPressedGlow * pressAnimation.value),
  ),
);

// 按下 / Loop 闪烁层：颜色取角色的 pressed，峰值不透明度取 semantic
ColoredBox(color: role.pressed.withValues(alpha: t.colors.padPressedFlashOpacity * flash.value));

// 动效（4.7.0：按下 1 帧点亮，松开 0.1 s QuadOut；Loop 0.6 s 往返、图标 1.2 s 一圈）
AnimationController(vsync: this, duration: UpPadTokens.pressAttack,
    reverseDuration: UpPadTokens.pressRelease);
CurvedAnimation(parent: c, curve: UpPadTokens.pressCurve);
SpringSimulation(UpPadTokens.scaleSpring, 1, t.colors.padPressedScale, 0);
Padding(padding: EdgeInsets.all(UpSpacing.md));

// 文字：ARB 里保存正常大小写，由排版角色决定是否全大写
final style = t.text[UpTextRole.title];
Text(t.text.format(UpTextRole.title, UpL10n.of(context).navSongs), style: style);
```

## 自定义皮肤

```dart
final skin = UpSkin(
  id: 'my-skin', name: '我的皮肤', baseId: 'outline',
  overrides: UpSemanticOverrides({'pad.palette.0.core': const Color(0xFFFF00AA),
                                  'pad.shape.radiusRatio': 0.2}),
);
final json = skin.encode();                    // 持久化
final theme = UpTheme.fromSkin(UpSkin.decode(json));
// 编辑器：遍历 UpSemantic.tokens（key、类型、说明、分组），用 theme.colors.valueOf(key) 读当前值，
// 用 UpSemanticOverrides.put/remove 修改；UpSemanticOverrides.diff(base, edited) 得到差异。
```

JSON 格式：`{"schema":1,"id":…,"name":…,"base":"neon|outline|light","overrides":{"<dotted key>": "#RRGGBB[AA]" | number | [{"color","position"}…]}}`。新版本加入的未知 key 会被跳过，并通过 `onUnknownKey` 回调报告；值格式错误时抛出 `FormatException`。

## 皮肤预设

```dart
for (final p in UpSkinPresets.all) {            // 按原版皮肤面板的顺序
  final name = lookupName(p.nameKey);           // up_i18n 中的 skinPreset* key
  final theme = p.toTheme();                     // 直接切换
  // p.technique / p.fidelity：partial 表示装饰图层需要 UI 层另外用私有素材实现
}
final mySkin = UpSkinPresets.byId('circle')!.toSkin(name: '我的圆形');  // 作为编辑起点
```

## 字体

- 默认字体 **Open Sans**（Regular 400 / ExtraBold 800 / Light 300，SIL OFL 1.1，来自 googlefonts/opensans 官方仓库，`assets/fonts/` 附 `OFL.txt`）。Ref 4.7.0 用的就是这款字体，所以它是默认字体，不需要任何加载。
- **Uni Sans**（Fontfabric 商业字体，3.x 版使用）保留为可选的皮肤字体，**不入库**：`just inject-assets` 把它复制到 `app/ultrapads/assets/private_manifest/font__*.ttf`，应用启动时用 `UpFonts.loadPrivate()` 注册。之后通过 `theme.withFontSet(UpFontSet.uniSans)` 或在皮肤 JSON 中写 `"font": "uniSans"` 启用。私有字体按字重映射到 Thin / Regular / Heavy；它们都是单字重字族，命中时按 `w400` 渲染，避免引擎合成粗体；没有注入时自动回到 Open Sans。
- 中日韩字形由平台字体补齐（4.7.0 同样如此）。

## 测试

`flutter test` 覆盖：4.7.0 校正值、16 套皮肤预设、字体集切换、主题 key 一致性、调色板循环、lerp（含不同色标数的渐变）、`ThemeData.lerp`、自定义覆盖和校验、JSON 往返、未知 key、diff、光晕强度、字体回退和注入、`UpTheme.of`。
