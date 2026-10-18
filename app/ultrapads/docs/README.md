# UltraPads 应用（app/ultrapads）

Flutter 应用组装层：页面、路由、Riverpod 状态、引擎接入、私有素材注入。
架构与复刻取舍见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，视觉对比见 [`visual-review.md`](visual-review.md)。

## 运行

```bash
just bootstrap                 # 拉依赖（仓库根）
just inject-assets             # 可选：注入私有素材（没有也能运行，见下）
just run-mock                  # Linux + MockEngineClient（不需要 Rust 引擎）
just run-linux                 # Linux + FFI 引擎（加载失败自动回退 Mock）
```

| 启动参数 | 含义 |
|---|---|
| `--dart-define=UP_ENGINE=mock` | 使用内存模拟引擎（UI 开发、演示） |
| `--dart-define=UP_ENGINE=ffi`（默认） | 使用 Rust 引擎（`lib/src/rust/` 绑定） |
| `--dart-define=UP_GALLERY=true` | 启动直接进入设计画廊 `/dev/gallery` |

设计画廊也可从「设置 → 开发者 → 设计画廊」进入：token 浏览、全部组件状态、3 个主题 + 16 套
4.7.0 皮肤预设实时切换、动效演示。

## 私有素材

原 App 素材不入库、不随（公开的）仓库分发。`assets/private_manifest/` 是**入库**的目录，只含：

- `manifest.json`：占位清单（`available: false`）
- `.gitignore`：忽略该目录下其它所有文件

`just inject-assets` 会把 `private-assets/compat-ios/`（4.7.0，优先）和
`private-assets/compat/`（APK 3.7.6）中 UI 需要的素材平铺复制到这个目录并生成
`injected.json`；`just clean-assets` 删除。pubspec 只声明这个永远存在的目录，所以
**没有私有素材时构建和运行都正常**，应用回退到开源占位（Open Sans、Material Icons、程序化绘制）。
详见 `ARCHITECTURE.md` §6。

## 测试

```bash
flutter test                         # 页面 widget test + golden（MockEngineClient）
flutter test --update-goldens        # token 变化后重新生成 golden
dart run tools/lint/no_hardcode.dart # 仓库根：硬编码检查（必须零违规）
```

## 构建

```bash
flutter build linux --debug
flutter build apk --debug --target-platform android-x64,android-arm64
```

release 构建、正式签名与发版流程（`just bump` / `just release`）见根目录 `docs/QUICK_START.md` §7；
应用内更新见 `ARCHITECTURE.md` §11。

## 目录

见 `ARCHITECTURE.md` §2。
