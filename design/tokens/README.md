# design/tokens — UltraPads 设计 token

UltraPads 设计系统的唯一事实源。token 源用 **W3C DTCG** 格式（`$value` / `$type` / `$description`），由 **Style Dictionary 5.7** 加上自定义格式构建成：

| 输出 | 路径 | 用途 |
|---|---|---|
| Dart 常量、语义值对象 | `packages/up_tokens/lib/src/generated/*.g.dart` | Flutter 运行时（`package:up_tokens`） |
| CSS 变量（每个主题一个文件） | `design/tokens/build/css/<theme>.css` | 文档、Figma 插件、Web 工具 |
| 扁平 JSON | `design/tokens/build/json/<theme>.json` | 对比、脚本 |
| Figma Variables | `design/tokens/build/json/figma-variables.json` | Figma 变量导入（Primitives / Components / Semantic，Semantic 每个主题一个 mode） |
| 皮肤预设 | `packages/up_tokens/lib/src/generated/skins.g.dart`、`design/tokens/build/json/skins.json` | 原版 16 套皮肤的 semantic 覆盖（皮肤面板展示和切换） |

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
├─ themes/<id>/    内置主题：只能覆盖 semantic 层已有的路径
└─ skins/<id>.skin.json  原版皮肤预设（UpSkin JSON + 元数据），值可以写字面量或引用 primitive（"{color.pad.blue.base}"）
themes.config.json 主题清单（id、明暗、说明；第一个是默认主题）
```

规则（构建时强制检查，违反即失败）：

1. **primitive** 只放原始值，UI 代码不直接用颜色 primitive。
2. **semantic** 的 `$type` 只能是 `color | gradient | number | dimension`。这一层是皮肤编辑器可以覆盖、能做 lerp、能序列化成 JSON 的全部内容。
3. **component** 只放与主题无关的几何、动效和光晕配方，**禁止颜色和渐变**（颜色放进 semantic，皮肤才能改）。
4. **themes/<id>/** 只能覆盖 `src/semantic` 中已经存在的路径，不能新增 token。所有主题的语义 key 集合必须完全一致。

### Pad 调色板

`pad.palette.<i>.{core,mid,edge,glow,pressed}` 是一组按序号排列的**颜色角色**（目前 8 个）。Kit 里 pad 的颜色只写角色序号，超出范围时按 `i % 8` 循环，从不写 RGB。0–3 号对应原 App Kit 配置里的 `rosa / amarelo / verde / azul(_loop)`（粉 `#F73470` / 橙 `#EB7F00` / 绿 `#00C200` / 蓝 `#00CBF7`，来自 4.7.0）；4–7 号是 UltraPads 的扩展色。`pressed` 是按下或 Loop 闪烁层的颜色：覆盖层类皮肤用白色，着色切换类皮肤用浅色，峰值不透明度由 `pad.pressed.flashOpacity` 决定。

### 比例型 token

`ratio.*` 和 `pad.shape.radiusRatio` 是相对 pad 边长的比例（4.7.0：圆角 ≈ 边长 × 10%；Circle 皮肤是 0.5），在运行时乘以实际尺寸使用。

### 尺寸换算

4.7.0 的界面用 FairyGUI 制作，设计画布 828×1472 px，scale factor 为 2。token 一律写**逻辑像素 = 设计 px ÷ 2**，`$description` 里注明原始 px 值。

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
| fontFamily | `["Open Sans"]`（打包在 up_tokens 中的字体族名） | `List<String>` |
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

## 皮肤预设（原版 16 套）

`src/skins/*.skin.json` 把 4.7.0 的 16 套皮肤（Default、Number、Christmas、Pets、Cover、Broken、Muertos、Crazy、Launchpad、Crafts、Polished、Clean、Circle、Square、LGBT、Halloween，按皮肤面板的顺序排列）整理成 semantic 覆盖：

```json
{ "id": "circle", "order": 13, "nameKey": "skinPresetCircle", "base": "neon",
  "technique": "scale", "fidelity": "full",
  "overrides": { "pad.palette.3.mid": "{color.skin.circle.blue}", "pad.shape.radiusRatio": 0.5, "pad.pressed.scale": 0.9 } }
```

- `technique`：`overlay`（白色覆盖层闪光）、`tint`（白图着色，按下换成浅色）、`image`（按颜色换位图）、`scale`（按下时缩放）。
- `fidelity`：`full` 表示 token 能完整还原；`partial` 表示只还原了配色和形状，装饰图层（雪花、骷髅、宠物、裂纹、彩虹边框等）需要 UI 层另外用私有素材实现。
- 构建时会检查：key 必须是已有的 semantic token，类型要匹配，引用的 primitive 必须存在，`id` 要和文件名一致。生成 `UpSkinPresets.all`（Dart）和 `build/json/skins.json`。
- 首期内置主题仍是 neon / outline / light，预设叠加在 `base` 主题上，用户也可以从任意预设出发保存自定义皮肤。

## 取值来源与校正状态

优先级：**4.7.0 IPA**（`docs/research/compat-ipa-4.7.0-analysis.md`，FairyGUI 包和皮肤位图实测）> APK 3.7.6 > 商店截图 > UltraPads 自定（UP）。每个 token 的 `$description` 都标了来源。

- 已按 4.7.0 校正：界面底色 `#242B2E` / `#262B2F` / `#2C3336` / `#252B2E` / `#1E2225` / `#363F43`，编辑 Kit 页 `#EE4286`；主色 `#FD1A68`，`#F73873` / `#F73470` 为辅；4 色 pad（底色、高光、边缘、按下浅色）；16 套皮肤的配色；遮罩 70% / 80% / 50%；分隔线白 10%；教程 pad 颜色；PERFECT 绿；pad 圆角 10%、间隙 2、边距 4.5；全部 FairyGUI 尺寸（÷2）；字号；字体 Open Sans；动效（按下 1 帧、松开 0.1 s QuadOut、Loop 闪烁 0.6 s 往返、图标 1.2 s 一圈、A/B 0.2 s QuadOut、皮肤面板 0.4 s、速度框 0.5 / 1.0 s、功能行 0.3 s Circ、录音 0.6 / 1.0 s、教程填充 1.0 s Linear 等）。
- 仍是 UP 自定或旧来源（原版没有对应物，或者分析里没有给出）：neon 的光晕 `glow.*` 和 `pad.*.glow`（原版没有光晕）、弹簧 `motion.spring.*`、`shadow.*`、`pad.idle.bevel`（截图）、light 和 outline 主题整体、pad 色板 4–7 号（截图）、loop 待启动闪烁、字间距（FairyGUI 不加字距，`caps` 设为 0）、页面转场时长（原版由代码实现，分析中【未知】）、`size.bar.toolbar/menu` 等 APK 旧值（保留给现有调用方）。
