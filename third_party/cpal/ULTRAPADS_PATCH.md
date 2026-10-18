# cpal 0.18.2（UltraPads 补丁版）

上游：<https://github.com/RustAudio/cpal>，版本 0.18.2，许可 Apache-2.0 OR MIT（见 `LICENSE`）。
根目录 `Cargo.toml` 的 `[patch.crates-io]` 用本目录替换 crates.io 上的 cpal。

## 补丁

| 文件 | 改动 | 原因 |
|---|---|---|
| `src/host/aaudio/mod.rs`（`build_output_stream_raw`） | 输出流请求 `AAUDIO_SHARING_MODE_EXCLUSIVE` | 支持的设备上走 MMAP 直通、绕过混音器，按键到发声延迟最低；不支持时 AAudio 自动回落到 SHARED。cpal 0.18 没有提供设置共享模式的接口 |

除上表外与上游 0.18.2 完全一致（删除了上游的 `Cargo.lock`、`Dockerfile`、`Cross.toml`）。

## 升级

1. 用新版 cpal 替换本目录，重新应用上表的补丁；
2. 若上游已提供设置共享模式的接口（例如 `StreamConfig` 或平台扩展），改用上游接口并删除本目录与 `[patch.crates-io]`。
