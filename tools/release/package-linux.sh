#!/usr/bin/env bash
# 把 `flutter build linux --release` 的 bundle 打成发布包（CI 与本地共用）：
#   tools/release/package-linux.sh <版本> <x64|arm64> [bundle 目录] [输出目录]
# 产物 ultrapads-<版本>-linux-<架构>.tar.gz，顶层目录同名，内含：
#   ultrapads、lib/、data/（Flutter bundle）
#   share/applications/dev.ultrapads.ultrapads.desktop、share/icons/hicolor/512x512/apps/dev.ultrapads.ultrapads.png
# 安装脚本（website/public/install）与应用内更新（runtime/up-update）都依赖这个布局。
set -euo pipefail

version="${1:?version}"
arch="${2:?arch (x64|arm64)}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bundle="${3:-$repo/app/ultrapads/build/linux/$arch/release/bundle}"
out="${4:-$repo/dist}"
app_id="dev.ultrapads.ultrapads"
packaging="$repo/app/ultrapads/linux/packaging"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad version: $version" >&2; exit 1; }
[[ "$arch" == x64 || "$arch" == arm64 ]] || { echo "bad arch: $arch" >&2; exit 1; }
[ -x "$bundle/ultrapads" ] || { echo "no bundle at $bundle (run flutter build linux --release)" >&2; exit 1; }

name="ultrapads-$version-linux-$arch"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$name/share/applications" "$stage/$name/share/icons/hicolor/512x512/apps" "$out"
cp -a "$bundle/." "$stage/$name/"
install -m 644 "$packaging/$app_id.desktop" "$stage/$name/share/applications/$app_id.desktop"
install -m 644 "$packaging/$app_id.png" "$stage/$name/share/icons/hicolor/512x512/apps/$app_id.png"

# 可复现：固定文件顺序、属主与时间戳
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@${SOURCE_DATE_EPOCH:-0}" \
  -C "$stage" -czf "$out/$name.tar.gz" "$name"
echo "$out/$name.tar.gz"
