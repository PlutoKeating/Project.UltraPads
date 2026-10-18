# UltraPads 统一命令入口：`just --list`

set shell := ["bash", "-cu"]

app := "app/ultrapads"

default:
    @just --list

# 安装/拉取全部依赖
bootstrap:
    flutter pub get
    cd design/tokens && pnpm install
    cargo fetch

# 由 DTCG 源生成 Dart/CSS token
tokens:
    cd design/tokens && pnpm run build

# 由 design/brand/ultrapads-mark.svg 生成图标 SVG 与全平台位图（需 magick + Chromium）
icons:
    node tools/brand/build_icons.mjs

# 由 Rust API 生成 FRB 绑定
codegen:
    cd {{app}} && flutter_rust_bridge_codegen generate

# 引擎 + 运行基座：格式、lint、测试
rust-check:
    cargo fmt --all --check
    cargo clippy --workspace --all-targets -- -D warnings
    cargo test --workspace

# Dart：分析 + 测试 + 硬编码检查
dart-check:
    cd design/tokens && pnpm run check
    dart run tools/lint/test/no_hardcode_test.dart
    dart run tools/lint/no_hardcode.dart
    cd packages/up_i18n && dart run up_i18n:check
    melos run analyze
    melos run test

check: rust-check dart-check

run-linux:
    cd {{app}} && flutter run -d linux

run-android:
    cd {{app}} && flutter run -d android

build-linux:
    cd {{app}} && flutter build linux --release

build-android:
    cd {{app}} && flutter build apk --release --split-per-abi

# 仅开发、不在 v0.0.1 验证的平台
build-web:
    cd {{app}} && flutter build web --wasm

# 无头 CLI（离线渲染、Kit 打包、Hub 守护进程）
cli *ARGS:
    cargo run -p up-cli -- {{ARGS}}

# 把 content/kits 的 CC0 示例 Kit 复制为应用资源（首次启动导入；测试检查两处一致）
bundle-kits:
    cp content/kits/*.upkit {{app}}/assets/kits/

# 把 private-assets/ 的 UI 素材与私有素材包内置 Kit 注入应用（不入库；缺失时用开源占位）
inject-assets:
    dart run tools/assets/inject_private_assets.dart

# 删除已注入的私有素材，回到纯开源占位
clean-assets:
    dart run tools/assets/inject_private_assets.dart --clean

# 用 MockEngineClient 运行 Linux 版（无需 Rust 引擎）
run-mock:
    cd {{app}} && flutter run -d linux --dart-define=UP_ENGINE=mock

# 构建无头 CLI 容器镜像（发布到 ghcr.io/plutokeating/ultrapads-cli）
docker-cli tag="dev":
    docker build -f runtime/up-cli/Dockerfile -t ghcr.io/plutokeating/ultrapads-cli:{{tag}} .

# 统一修改版本号（Cargo workspace + pubspec，构建号 +1）：just bump 0.1.1
bump version:
    tools/release/bump.sh {{version}}

# 本地打 Linux 发布包到 dist/（CI 用同一脚本）：just package-linux（默认当前版本、x64）
package-linux arch="x64":
    cd {{app}} && flutter build linux --release
    tools/release/package-linux.sh "$(tools/release/check-version.sh | cut -d' ' -f2)" {{arch}}

# 发布：核对版本后打 tag 并推送，GitHub Actions（.github/workflows/release.yml）构建并创建 Release
release:
    tools/release/check-version.sh
    git tag "v$(tools/release/check-version.sh | cut -d' ' -f2)"
    git push origin "v$(tools/release/check-version.sh | cut -d' ' -f2)"

# 站点（website/）测试：安装脚本端到端 + 发布清单
website-test:
    cd website && npm test

# 曲库入库管线（tools/catalog）的测试：Rust 工具 + Python 管线
catalog-test:
    cargo test -p up-catalog-pack
    cd tools/catalog && python3 -m unittest discover -s tests -t .
