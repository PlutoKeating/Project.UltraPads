# ADR-0001 核心技术决策（问卷定稿）

- 状态：已接受
- 日期：2026-10-17
- 决策人：项目所有者（问卷）

## 背景

UltraPads 以学习研究为目的，1:1 复刻 Ref（打击垫/DJ App）的界面、交互、动效，并在此基础上二次开发成"随手创作 + 大型复杂创作"兼顾的音乐软件。要求一份代码多端打包，并拆出 **纯引擎 + 运行基座 + 前端** 三层。

## 决策

| # | 主题 | 决定 |
|---|---|---|
| 1 | 复刻边界 | 仅私有研究，永不发布。除名称和 Logo 外，界面图标、Kit 音频、封面等沿用原 App 素材 |
| 2 | 素材来源 | 以从原 App 导入为主，以用户导入为主；缺失时可用 AI 生成等方式补足 |
| 3 | 私有素材存放 | `references/`、`private-assets/` 均 gitignore，仓库只含导入器和占位资源 |
| 4 | 商业化 | 完全不做（无付费墙、无广告、无订阅） |
| 5 | 许可证 | 代码 Apache-2.0；GPL 依赖（如 Ableton Link）只能作为默认关闭的可选 feature |
| 6 | 多端框架 | **Flutter 全栈 UI** + flutter_rust_bridge（FRB） |
| 7 | 引擎语言 | **Rust 为主 + C++ 库绑定**（如 Signalsmith Stretch、Ableton Link） |
| 8 | 平台 | 必须：Web、Android、Windows、Linux；预留：macOS、iOS、CLAP/VST3 插件、CLI/无头服务、Linux ARM |
| 9 | 触摸延迟 | Flutter 原始指针事件（Listener）同步 FFI 直连 Rust 无锁队列；保留 latency-probe 实测 |
| 10 | 状态架构 | **引擎为唯一事实源**：UI 发 Command，订阅 Event/快照；UI 状态只是只读投影 |
| 11 | 动效 | Flutter 动画体系（隐式/显式动画、spring 物理）+ Rive + Fragment Shader 光效；GSAP/Motion/WAAPI 这类 Web 技术的诉求由 Flutter 等价物承担 |
| 12 | Token | W3C DTCG JSON + Style Dictionary，生成 Dart（以及 CSS，供文档和工具使用） |
| 13 | 设计稿 | ~~先建 Figma 设计系统~~ → 2026-10-18 修订：跳过 Figma（可用的 Figma 账号不属于项目所有者），改为应用内的 Design Gallery（Storybook 式组件画廊），展示全部 token、组件、皮肤和动效 |
| 14 | 复刻精度 | 高保真 + 视觉回归（golden test） |
| 15 | 皮肤 | 霓虹渐变发光、深色描边、浅色、用户自定义皮肤编辑器 |
| 16 | MVP | 演奏、曲库下载、编辑 Kit、录音分享、教程、皮肤全部纳入 |
| 17 | 复杂创作底座 | 数据模型首期覆盖 Session/Step Seq、时间线 + 自动化、混音 + 效果链 + MIDI I/O、插件宿主 + Link |
| 18 | 音频图 | 自研薄抽象（trait），首个实现接 Firewheel |
| 19 | Kit 格式 | 采用业界最通用的开放格式，见 `docs/research/kit-and-project-formats.md` 与 ADR-0002 |
| 20 | 后端 | 不做公共服务。只做**个人多设备协同**：桌面端兼任个人 Hub + 局域网自动发现；设备间 P2P 直连；手机作为电脑的实时打击垫控制器 |
| 21 | 工程化 | Dart pub workspace + Melos + Cargo workspace + just |
| 22 | Android | minSdk 26（AAudio） |
| 23 | Web | 开启 COOP/COEP 跨源隔离，并保留降级模式 |
| 24 | i18n | 独立解耦的 i18n 包，页面内禁止硬编码任何语言文案；首期只做 zh、en，脚手架支持任意新增语言 |
| 25 | 首版验证范围 | v0.0.1 只在 **Linux + Android** 上构建和验证；其他平台只开发、不验证 |

## 后果

- 选择 Flutter 后，Android UI 是原生渲染，不经过 WebView，触摸延迟风险明显下降；代价是 Web 端要跑 Flutter Web（skwasm）加上 Rust WASM，复杂度集中在 Web。
- 引擎作为唯一事实源，因此所有可变业务状态必须经过 Command/Event 协议，UI 不得私自持有业务真值。
