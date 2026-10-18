# UltraPads

Flutter + Rust 实现的打击垫与音乐创作软件，一份代码多端打包（Linux、Android、Windows、Web、macOS/iOS 预留）。
以学习研究为目的复刻 Ref 的界面和交互，并扩展为兼顾随手创作和复杂编曲的工具。

> ⚠️ 私有研究项目。原 App 的素材（图标、Kit 音频、封面）只存放在被 gitignore 的 `private-assets/` 和 `references/` 中，永不入库、永不分发。

## 文档

| 文档 | 内容 |
|---|---|
| `docs/ARCHITECTURE.md` | 分层、线程模型、平台适配、设计系统、多设备协同 |
| `docs/API.md` | 引擎协议、FFI 接口、Hub 协议 |
| `docs/REQUIREMENTS.md` | 功能和非功能需求 |
| `docs/QUICK_START.md` | 环境准备、构建、运行 |
| `docs/adr/` | 架构决策记录 |
| `docs/research/` | 竞品拆解、格式调研、延迟实测 |

## 仓库结构

```
engine/        ① 纯引擎（Rust，零平台依赖）
runtime/       ② 运行基座：up-host（音频/存储/MIDI）up-library（曲库）up-hub（多设备协同）up-cli
bridge/up-ffi  FRB API 面（Dart 的唯一入口）
app/ultrapads  ③ Flutter 应用（rust_builder = cargokit 构建胶水）
packages/      up_tokens up_ui up_fx up_i18n up_engine
design/tokens  W3C DTCG token 源 + Style Dictionary 构建
content/       Kit schema 与可公开的示例 Kit
tools/         lint、kit 打包、latency-probe
```

## 常用命令

```bash
just bootstrap     # 拉依赖
just tokens        # 生成设计 token
just codegen       # 生成 Rust↔Dart 绑定
just check         # Rust + Dart 全量检查
just run-linux     # 运行 Linux 版
just build-android # 构建 Android APK
```

## 许可证

代码采用 Apache-2.0。可选的 GPL 组件（如 Ableton Link）默认关闭。
