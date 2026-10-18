# UltraPads 快速上手

> 适用版本：v0.1.0。完整验证过的平台是 **Linux x64** 与 **Android**（API 26+）；Linux arm64 由发布 CI 原生构建；其它平台只保证能开发。
> 命令都在仓库根目录执行，除非另有说明。

## 1. 环境要求

| 工具 | 版本（v0.0.1 验证所用） | 用途 |
|---|---|---|
| Flutter（含 Dart） | 3.47 stable（Dart ≥ 3.9） | 应用、Dart 包、melos |
| Rust | stable ≥ 1.85（验证用 1.99） | 引擎、运行基座、FFI |
| Android SDK + NDK | NDK **28.2**（`28.2.13676358`），compileSdk 37，minSdk 26 | Android 构建 |
| cargo-ndk | 4.x | Android 交叉编译（cargokit 调用） |
| flutter_rust_bridge_codegen | **2.13.0**（与 `flutter_rust_bridge: 2.13.0` 严格一致） | 生成 Rust↔Dart 绑定 |
| just | 1.x | 统一命令入口（`just --list`） |
| melos | 8.x（根 `pubspec.yaml` 的 dev 依赖，用 `dart run melos` 调用即可） | Dart 多包分析与测试 |
| Node.js + pnpm | Node ≥ 22，pnpm 12 | 设计 token 构建（Style Dictionary）、图标生成、官网测试（`website/`，node --test） |
| ImageMagick + Chromium | magick 7.x；chromium / google-chrome / Playwright headless shell 任一（或 `CHROME=<路径>`） | 仅 `just icons` 需要 |
| Linux 桌面依赖 | GTK 3 开发包、clang、cmake、ninja、pkg-config、ALSA / PipeWire / D-Bus 开发包（`libasound2-dev libpipewire-0.3-dev libspa-0.2-dev libdbus-1-dev`，PipeWire ≥ 0.3.65） | Linux 构建与音频 |

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
cargo install just
```

## 2. 拉依赖与生成代码

```bash
just bootstrap   # flutter pub get（工作区）+ pnpm install（design/tokens）+ cargo fetch
just tokens      # 由 DTCG 源生成 up_tokens（产物已入库，改 token 时才需要）
just codegen     # 修改 bridge/up-ffi/src/api 后重新生成 FRB 绑定（产物已入库）
just icons       # 修改 design/brand/ultrapads-mark.svg 后重新生成全平台图标（产物已入库；需 ImageMagick 7 + Chromium）
```

i18n：改 `packages/up_i18n/lib/l10n/app_{zh,en}.arb` 后执行 `cd packages/up_i18n && dart run up_i18n:gen`。

## 3. 运行与构建

### Linux

```bash
just run-linux        # flutter run -d linux（FFI 引擎；加载失败自动回退 Mock）
just run-mock         # 内存 MockEngineClient，不需要 Rust 引擎
just build-linux      # flutter build linux --release → app/ultrapads/build/linux/x64/release/bundle/ultrapads
```

音频走 cpal：有 PipeWire 时用原生通路（流线程经 rtkit 提为实时优先级），否则回退 ALSA。用 `pw-top` 可以看到 UltraPads 节点的 quantum 与欠载计数（ERR）。

开发 / 截图用的启动参数：

| 参数 | 作用 |
|---|---|
| `--dart-define=UP_ENGINE=mock` | 使用 MockEngineClient |
| `--dart-define=UP_GALLERY=true` | 直接进入设计画廊 |
| `--dart-define=UP_ROUTE=/kits` 或环境变量 `ULTRAPADS_ROUTE=/kits` | 启动直接打开某个路由（仍遵守引导重定向） |
| `--dart-define=UP_PRIVATE_KITS=<dir>` | 桌面开发便利：首次启动直接用曲库导入器读取该目录（如 `private-assets/compat-ios`） |
| 环境变量 `ULTRAPADS_WINDOW_SIZE=414x736` | Linux 窗口初始尺寸（默认 1280×720） |
| 环境变量 `ULTRAPADS_HUB_AUTOSTART=<名字>` | 启动后自动开启 Hub，配对码等打印到 stdout |
| 环境变量 `ULTRAPADS_LOG_EVENTS=1` | 把 pad 状态、Hub 事件和非零电平打印到 stdout |

无界面截图（Xvfb）：必须让 GTK 走 X11，否则窗口会出现在当前 Wayland 桌面上：

```bash
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 xvfb-run -a -s "-screen 0 414x736x24" bash -c '
  ULTRAPADS_WINDOW_SIZE=414x736 ULTRAPADS_ROUTE=/kits app/ultrapads/build/linux/x64/release/bundle/ultrapads &
  sleep 10; import -window root kits.png; kill %1'
```

用 `XDG_DATA_HOME=<临时目录>` 可以得到一个全新的数据目录（曲库与偏好设置都在 `$XDG_DATA_HOME/dev.ultrapads.ultrapads/`）。

### Android

```bash
just build-android    # flutter build apk --release --split-per-abi
adb install -r app/ultrapads/build/app/outputs/flutter-apk/app-x86_64-release.apk   # 模拟器
adb install -r app/ultrapads/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk # 真机
adb shell am start -n dev.ultrapads.ultrapads/.MainActivity
```

release 包用正式密钥签名：Gradle 依次查找 `UP_KEY_PROPERTIES`、`app/ultrapads/android/key.properties`、
`~/.config/ultrapads/key.properties`（字段 `storeFile` / `storePassword` / `keyAlias` / `keyPassword`），都没有时回退调试密钥
（本地开发可用，但装不上正式版之上；CI 中缺失直接失败）。

模拟器（x86_64，API 34）：

```bash
~/Android/Sdk/emulator/emulator -avd <AVD 名> -no-window -gpu swiftshader_indirect &
adb wait-for-device
adb exec-out screencap -p > screen.png        # 截图
adb shell input tap <x> <y>                   # 按 pad（物理像素坐标）
adb logcat -s flutter                         # Dart 日志
```

模拟器的音频输出可能是空设备，判断引擎是否工作以引擎事件（电平、pad 状态）为准。

### 无头 CLI 与容器镜像

```bash
just cli --help                 # cargo run -p up-cli
just docker-cli 0.0.1           # 构建 ghcr.io/plutokeating/ultrapads-cli:0.0.1
```

镜像只包含 `up-cli` 和 ALSA / PipeWire / D-Bus 运行库（基于 Debian 12）。构建上下文由根目录 `.dockerignore` 白名单限定为 Rust 工作区（`Cargo.*`、`engine/`、`runtime/`、`bridge/`），私有素材和构建产物不会进入镜像。

## 4. 首次启动与内置 Kit

- 曲库为空时自动导入应用资源中的 CC0 示例 Kit（`app/ultrapads/assets/kits/`，是 `content/kits/*.upkit` 的副本；`just bundle-kits` 同步，测试校验一致）。
- 默认加载顺序：私有素材包的 Sunset（注入了私有素材时）→ CC0 `UltraPads Starter` → 第一个 Kit。

### 私有素材注入（可选，不入库）

私有素材包只放在被 gitignore 的 `private-assets/` 和 `references/` 中，不随仓库分发。

```bash
just inject-assets    # 把 private-assets/compat-ios（iOS 格式）与 private-assets/compat-android（Android 格式）中需要的文件
                      # 平铺复制到 app/ultrapads/assets/private_manifest/（被忽略），生成 injected.json
just clean-assets     # 删除注入的文件，回到纯开源占位
```

注入后：UI 使用私有素材包的皮肤缩略图、字体、图片型皮肤位图等；`injected.json` 的 `privateKits` 记录私有素材包的 6 个内置 Kit（音频 + 配置 + 目录 + 教程），应用首次启动把它们还原到临时目录，交给曲库的私有素材包导入器导入（按注入时间戳只导入一次）。桌面也可以不注入，直接 `--dart-define=UP_PRIVATE_KITS=<private-assets/compat-ios 的路径>`。

## 5. 检查

```bash
just check            # = rust-check + dart-check
# rust-check：cargo fmt --all --check；cargo clippy --workspace --all-targets -- -D warnings；cargo test --workspace
# dart-check：design/tokens pnpm run check；no_hardcode lint 及其测试；up_i18n:check；melos run analyze；melos run test
```

- golden：`cd app/ultrapads && flutter test --update-goldens`（token 或界面变化后）。
- 发声冒烟（真实音频设备）：`UP_REQUIRE_AUDIO=1 cargo test -p up_ffi --test ffi_audio -- --nocapture`。
- 私有素材包导入（本机）：`cargo test -p up_ffi -- --ignored private_assets`。

## 6. Hub（多设备协同）联调

协议与 FFI 见 `docs/API.md` §3.1、§4，设计见 ADR-0004。

**两台真实设备（同一 Wi-Fi）**：桌面「设置 → 我的设备」打开「在本机运行 Hub」，页面显示 6 位配对码和本机 `ip:port`；手机在同一页面的「附近的设备」里发现桌面（或手动输入地址）→ 配对 → 同步曲库 → 用作控制器。演奏页顶部出现「正在控制 <设备名>」状态条，点 ✕ 退出。

**Linux 桌面 + Android 模拟器**：模拟器在 NAT 后面，收不到宿主机的 mDNS，用手动输入地址：

1. 桌面：`ULTRAPADS_HUB_AUTOSTART=Desk ULTRAPADS_LOG_EVENTS=1 app/ultrapads/build/linux/x64/release/bundle/ultrapads`，stdout 打印端口与配对码；
2. 模拟器：Hub 页「手动输入地址」填 `10.0.2.2:<端口>`（10.0.2.2 是模拟器访问宿主机回环的地址；TCP 控制面和控制器 UDP 都是模拟器主动发出的连接，经模拟器 NAT 即可到达宿主机，回包也能返回，不需要 `adb forward`/`adb reverse`）；
3. 配对（输入配对码）→ 同步 → 用作控制器；在模拟器上按 pad，桌面 stdout 出现远端控制器连接、pad 状态和电平日志。

**同一台 Linux 上的两个进程 / 集成测试**：`cargo test -p up_ffi --test ffi_hub`（FFI 全流程：服务、配对、同步、控制器转发）。

## 6.1 官方曲库（数据服务与素材管线）

```bash
# 数据服务（data/）：本地开发与测试
cd data && npm ci && npm run typecheck && npm test
npm run dev                      # 127.0.0.1:8791，数据在 .dev/（不入库）
# 部署：把 data/ 同步到服务器后 ./start.sh（首次生成 .env 与两把密钥；./start.sh --key / --admin-key 打印）
# Worker 需要 Secret：cd website && npx wrangler secret put ULTRAPADS_DATA_KEY

# 素材入库管线（tools/catalog，详见其 README）
just catalog-test
cd tools/catalog && python3 -m upcatalog build --source synth    # 生成 → out/，预览 out/preview/index.html
ULTRAPADS_DATA_URL=… ULTRAPADS_DATA_KEY=… ULTRAPADS_ADMIN_KEY=… python3 -m upcatalog publish --id <id> [--publish]
```

应用内站点地址在 `app/ultrapads/assets/config/links.json`，调试时可用 `--dart-define=UP_SITE=<url>` 覆盖。

## 7. 发布

一次发布 = 改版本号 → 写 CHANGELOG → 推送 tag，其余由 `.github/workflows/release.yml` 完成（约 20–30 分钟）。

```bash
just bump 0.1.1          # Cargo.toml workspace 版本 + pubspec（构建号 +1，即 Android versionCode）+ Cargo.lock
# 在 CHANGELOG.md 写 "## [0.1.1] - YYYY-MM-DD" 一节（会作为 Release 说明；没有这一节 CI 会失败）
git commit -am "chore(release): v0.1.1" && git push
just release             # 核对版本后打 tag v0.1.1 并推送 → CI：Linux x64 / arm64、Android ×3、SHA256SUMS → GitHub Release
```

- 发布后立即生效：官网 `/api/version`、安装脚本与应用内更新都读取 GitHub 最新正式版（边缘缓存最多 5 分钟），不需要重新部署站点。
- **重建已发布版本的附件**：Actions →「Rebuild release assets」（`.github/workflows/rebuild-release.yml`，手动触发），
  或 `gh workflow run rebuild-release.yml -f tag=v0.2.1 -f linux_env=debian12`。检出该 tag 的源码重新构建，
  `gh release upload --clobber` 覆盖同名附件与 `SHA256SUMS.txt`，Release 说明不变。`linux_env=ubuntu2204` 用于 v0.1.0
  （当时在 Ubuntu 22.04 主机上构建，只有 ALSA）。`/dl/` 镜像的缓存键含 sha256，替换后旧副本自动失效。
- **Android 签名密钥**：`~/.config/ultrapads/release.jks` 与 `key.properties`（不入库，**请异地备份**；丢失后新版本无法覆盖安装）。
  CI 使用仓库 Secret `ANDROID_KEYSTORE_BASE64`（`base64 -w0 release.jks`）、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`，
  并核对 APK 证书 SHA-256 等于 `release.yml` 中的 `ANDROID_CERT_SHA256`。
- **官网**（`website/`）：Cloudflare Worker `ultrapads` 已关联本仓库（Workers Builds，根目录 `website`），推送 `main` 自动部署；
  自定义域名在 Cloudflare 控制台绑定。本地：`cd website && npx wrangler dev`；测试 `just website-test`（安装脚本端到端 + 清单映射）。
  可选 Worker Secret `GITHUB_TOKEN` 提高 GitHub API 限额。
- **本地打包**：`just package-linux`（`dist/ultrapads-<版本>-linux-x64.tar.gz`，布局与 CI 相同）。
- **验证应用内更新**：用低于最新正式版的版本号构建并按安装脚本布局安装，然后
  `ULTRAPADS_UPDATE_SELFTEST=1 ~/.local/bin/ultrapads`（Android：`--dart-define=UP_UPDATE_SELFTEST=true`，日志见 `adb logcat -s flutter`），
  会依次打印检查、下载进度、校验、装入与重启（Android：交给系统安装器）。
- `up-update` 联网测试：`cargo test -p up-update --test live -- --ignored`。

