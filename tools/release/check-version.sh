#!/usr/bin/env bash
# 核对版本号一致：Cargo workspace、pubspec 与（可选的）期望版本 / tag。
#   tools/release/check-version.sh [X.Y.Z | vX.Y.Z]
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cargo_v="$(sed -nE '/^\[workspace\.package\]/,/^\[/ s/^version = "([0-9.]+)"$/\1/p' "$repo/Cargo.toml")"
pub_v="$(sed -nE 's/^version: ([0-9.]+)\+[0-9]+$/\1/p' "$repo/app/ultrapads/pubspec.yaml")"
want="${1:-}"
want="${want#v}"
status=0
if [ "$cargo_v" != "$pub_v" ]; then
  echo "version mismatch: Cargo.toml=$cargo_v pubspec.yaml=$pub_v" >&2
  status=1
fi
if [ -n "$want" ] && [ "$cargo_v" != "$want" ]; then
  echo "version mismatch: expected $want, Cargo.toml=$cargo_v" >&2
  status=1
fi
[ "$status" -eq 0 ] && echo "version $cargo_v"
exit "$status"
