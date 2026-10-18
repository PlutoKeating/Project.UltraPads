# design/tokens — UltraPads 设计 token

UltraPads 设计系统的唯一事实源。token 源用 **W3C DTCG** 格式（`$value` / `$type` / `$description`），由 **Style Dictionary 5.7** 加上自定义格式构建成：

| 输出 | 路径 | 用途 |
|---|---|---|
| Dart 常量、语义值对象 | `packages/up_tokens/lib/src/generated/*.g.dart` | Flutter 运行时（`package:up_tokens`） |
| CSS 变量（每个主题一个文件） | `design/tokens/build/css/<theme>.css` | 文档、Figma 插件、Web 工具 |
| 扁平 JSON | `design/tokens/build/json/<theme>.json` | 对比、脚本 |
| Figma Variables | `design/tokens/build/json/figma-variables.json` | Figma 变量导入（Primitives / Components / Semantic，Semantic 每个主题一个 mode） |

**生成产物入库**，Flutter 构建不依赖 Node。改了 token 以后必须重新构建并提交产物。

## 构建

```bash
just tokens                 # = cd design/tokens && pnpm run build
cd design/tokens
pnpm install                # 首次
pnpm run build              # 生成全部产物（会调用 dart format 格式化 Dart 产物）
pnpm run check              # 生成到临时目录并与已入库产物比较，过期则退出码 1（给 CI 用）
```

依赖：Node ≥ 22、pnpm、`dart`（在 PATH 中，用于格式化）。

## 分层

```
src/
├─ primitive/      原始值：color gradient radius ratio spacing size font/typography
│                  shadow glow motion(duration/easing/spring) opacity blur zIndex borderWidth
├─ semantic/       语义 token（基础值 = neon）：surface border text icon accent status brand focus
│                  pad（palette / shape / fill / idle / pressed / playing / pending / disabled /
│                  selected / loop / empty / tutorial）transport chip card banner sheet list badge
│                  button input slider dialog toast meter waveform progressRing record genre swatch hub
├─ component/      组件 token：pad padGrid topBar tabBar chip kitCard banner sheet page listItem
│                  skinItem waveform meter progressRing slider button iconButton dialog genreIcon
│                  swatch badge transport trackCard toast tutorial searchField
└─ themes/<id>/    皮肤：只能覆盖 semantic 层已有的路径
themes.config.json 主题清单（id、明暗、说明；第一个是默认主题）
```

规则（构建时强制检查，违反即失败）：

1. **primitive** 只放原始值，UI 代码不直接用颜色 primitive。
2. **semantic** 的 `$type` 只能是 `color | gradient | number | dimension`。这一层是皮肤编辑器可以覆盖、能做 lerp、能序列化成 JSON 的全部内容。
3. **component** 只放与主题无关的几何、动效和光晕配方，**禁止颜色和渐变**（颜色放进 semantic，皮肤才能改）。
4. **themes/<id>/** 只能覆盖 `src/semantic` 中已经存在的路径，不能新增 token。所有主题的语义 key 集合必须完全一致。

### Pad 调色板

`pad.palette.<i>.{core,mid,edge,glow}` 是一组按序号排列的**颜色角色**（目前 8 个）。Kit 里 pad 的颜色只写角色序号，超出范围时按 `i % 8` 循环，从不写 RGB。0–3 号对应原 App Kit 配置里的 `rosa / amarelo / verde / azul`。各皮肤可以给同一个角色换颜色（neon 用当前商店版的霓虹色，outline 用 APK 的经典色）。

### 比例型 token

`ratio.*` 和 `pad.shape.radiusRatio` 是相对 pad 边长的比例（APK：圆角 ≈ 边长 × 12%，编号字号 = 宽 × 0.12），在运行时乘以实际尺寸使用。

## 命名

- 路径用 lowerCamelCase 段，用 `.` 分隔：`pad.pressed.flashOpacity`、`motion.duration.loopRevolution`。
- 数字段可以用作有序刻度或角色序号：`color.grey.900`、`pad.palette.3.core`。
- Dart 名称 = 路径的 camelCase：semantic `pad.palette.0.core` → `UpSemantic.padPalette0Core`；component `pad.gap` → `UpPadTokens.gap`；primitive `motion.duration.slow` → `UpDurations.slow`（前缀和类的映射见 `scripts/lib/model.mjs` 里的 `PRIMITIVE_CLASSES`）。
- CSS 变量 = `--up-` + kebab-case 路径：`--up-pad-palette-0-core`。
- 扩展字段：`$extensions.up.textCase: "upper"`（排版角色全大写）、`$extensions.up.int: true`（Dart 生成 `int`）。
- 弹簧 = 包含 `stiffness / damping / mass` 三个 number 子 token 的组，生成 `SpringDescription`。
- 光晕 = `glow.*` 下的 shadow token（或引用它的 token）：颜色的 alpha 就是该层的不透明度，RGB 在运行时换成 pad 角色色（`UpGlowSpec.shadows(color)`）。

## 值格式

| `$type` | 写法 | Dart |
|---|---|---|
| color | `"#RRGGBB"` / `"#RRGGBBAA"`（也接受 DTCG 2025 的颜色对象） | `Color` |
| dimension | `{ "value": 4, "unit": "px" }`（也支持 `rem`） | `double`（逻辑像素） |
| duration | `{ "value": 300, "unit": "ms" }` | `Duration` |
| cubicBezier | `[x1, y1, x2, y2]` | `Cubic` |
| number | `0.75` | `double` / `int` |
| fontFamily | `["Uni Sans Heavy", "Montserrat"]`（私有字体名，开源回退字体名） | `List<String>` |
| fontWeight | `800` | `FontWeight` |
| shadow | DTCG shadow 对象或数组 | `List<BoxShadow>` / `UpGlowSpec` |
| gradient | `[{ "color": …, "position": 0 }, …]` | `UpGradient` |
| typography | DTCG typography 组合值 | `UpTextRoleSpec` + `UpTextRole` 枚举 |

## 新增 token

1. 放进正确的层和文件（primitive 放原始值，semantic 放会随皮肤变化的值，component 放组件几何和动效）。
2. semantic 和 component 尽量引用 primitive：`"$value": "{spacing.md}"`。
3. `pnpm run build`，提交 `src/` 和全部产物。
4. 新增 semantic token 会出现在 `UpSemantic` 的字段、`copyWith`、`lerp`、JSON 编解码和皮肤编辑器元数据（`UpSemantic.tokens`）里，不需要手写任何代码。

## 新增主题

1. 在 `themes.config.json` 里追加 `{ "id": "midnight", "brightness": "dark", "description": "…" }`。
2. 新建 `src/themes/midnight/midnight.tokens.json`，只写要覆盖的 semantic 路径。
3. `pnpm run build` 会生成 `semantic_midnight.g.dart`、`build/css/midnight.css`，同时更新 `UpSemanticThemes` 和 Figma 的 mode。Dart 端通过 `UpThemes.byId('midnight')` 使用。

原 App 有 15 套皮肤（NORMAL、NUMBER、WORLD CUP、CHRISTMAS、MUERTOS、PETS、COVER、BROKEN、CRAZY、LAUNCHPAD、CRAFT、POLISHED、CLEAN、CIRCLE、SQUARE，见 `docs/research/compat-apk-analysis.md` §7）。其中大多数靠 Lottie 动画实现，只有配色、形状这一类差异可以用 semantic 主题表达；首期只做 neon / outline / light / custom。

## 取值来源与校正状态

- 已按 APK v3.7.6 校正（`docs/research/compat-apk-analysis.md`）：中性色、强调色 `#F73873`、经典 pad 渐变、空 pad 渐变、编辑器 8 色色板、圆角 3/4/6/8/12、pad 圆角比例 12%、pad 间隙 2、页面内边距 10、栏高 56/50/36/44、按钮 335×54、精选卡 300×160、动效时长（A/B 翻页 100ms decelerate、面板/子页 300ms、按下闪光 317ms、峰值 75%、Loop 一圈 817ms、进度 1250ms、录音 367ms/2s）、字体 Uni Sans（Regular/Heavy/Thin）。
- **待校正**（来自商店截图，等 4.7.0 IPA 分析 `docs/research/compat-ipa-4.7.0-analysis.md` 出来后以它为准）：`color.neon.*`（霓虹 pad 色）、`color.brand.magenta/berry/plum`（品牌渐变）、`color.brand.raspberryDeep`、`color.grey.920/820/700/500`、loop pad 底色 `color.neon.violet.*`、光晕配方 `glow.*`、阴影 `shadow.*`、`pad.pressed.scale`、弹簧参数、light 主题整体、kitCard / chip / sheet / dialog 的尺寸。
