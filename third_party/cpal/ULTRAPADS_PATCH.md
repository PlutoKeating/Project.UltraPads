# cpal 0.18.2（UltraPads 补丁版）

上游：<https://github.com/RustAudio/cpal>，版本 0.18.2，许可 Apache-2.0 OR MIT（见 `LICENSE`）。
根目录 `Cargo.toml` 的 `[patch.crates-io]` 用本目录替换 crates.io 上的 cpal。

## 补丁

| 文件 | 改动 | 原因 |
|---|---|---|
| `src/host/aaudio/mod.rs`（`build_output_stream_raw`） | 输出流请求 `AAUDIO_SHARING_MODE_EXCLUSIVE` | 支持的设备上走 MMAP 直通、绕过混音器，按键到发声延迟最低；不支持时 AAudio 自动回落到 SHARED。cpal 0.18 没有提供设置共享模式的接口 |
| `src/host/aaudio/mod.rs`（`build_output_stream`） | 低延迟流打开后把缓冲设为 2 个 burst（欠载时仍由原有逻辑加大） | AAudio 默认缓冲可能接近容量上限；Oboe 推荐从 2 个 burst 起步 |
| `src/host/aaudio/mod.rs`（`default_output_config`）、`java_interface/audio_manager.rs` | 默认输出配置优先用设备原生采样率（`AudioManager.getProperty(PROPERTY_OUTPUT_SAMPLE_RATE)`） | AudioFlinger 只给不需要重采样的流 FAST 轨道 |

除上表外与上游 0.18.2 完全一致（删除了上游的 `Cargo.lock`、`Dockerfile`、`Cross.toml`）。

## 升级

1. 用新版 cpal 替换本目录，重新应用上表的补丁；
2. 若上游已提供设置共享模式的接口（例如 `StreamConfig` 或平台扩展），改用上游接口并删除本目录与 `[patch.crates-io]`。
