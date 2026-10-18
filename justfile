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

# 把 private-assets/compat 的 UI 素材注入应用（不入库；缺失时用开源占位）
inject-assets:
    dart run tools/assets/inject_private_assets.dart

# 删除已注入的私有素材，回到纯开源占位
clean-assets:
    dart run tools/assets/inject_private_assets.dart --clean

# 用 MockEngineClient 运行 Linux 版（无需 Rust 引擎）
run-mock:
    cd {{app}} && flutter run -d linux --dart-define=UP_ENGINE=mock
