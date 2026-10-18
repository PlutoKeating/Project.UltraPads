#!/usr/bin/env bash
# 统一修改版本号：tools/release/bump.sh <X.Y.Z>
#   Cargo.toml [workspace.package] version（所有 crate 与 FFI app_version() 继承它）
#   app/ultrapads/pubspec.yaml version: X.Y.Z+<构建号>（构建号 = Android versionCode，自动 +1）
# 然后刷新 Cargo.lock。CHANGELOG 由人手写。发布：提交后 git tag vX.Y.Z && git push origin vX.Y.Z。
set -euo pipefail

version="${1:?usage: bump.sh X.Y.Z}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad version: $version" >&2; exit 1; }
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pubspec="$repo/app/ultrapads/pubspec.yaml"

build="$(sed -nE 's/^version: [0-9.]+\+([0-9]+)$/\1/p' "$pubspec")"
[ -n "$build" ] || { echo "cannot read build number from $pubspec" >&2; exit 1; }
sed -i -E "s/^version: [0-9.]+\+[0-9]+$/version: $version+$((build + 1))/" "$pubspec"
# 只改 [workspace.package] 段里的 version
sed -i -E '/^\[workspace\.package\]/,/^\[/ s/^version = "[0-9.]+"$/version = "'"$version"'"/' "$repo/Cargo.toml"
(cd "$repo" && cargo update --workspace --offline -q 2>/dev/null || cargo update --workspace -q)
"$repo/tools/release/check-version.sh" "$version"
echo "bumped to $version (build $((build + 1)))"
