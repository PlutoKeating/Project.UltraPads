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
    dart run tools/lint/no_hardcode.dart
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
