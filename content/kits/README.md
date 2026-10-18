# 示例 Kit

| 文件 | 内容 | 许可证 |
|---|---|---|
| `ultrapads-starter.upkit` | 12 pad，120 BPM：8 个鼓 one-shot + 鼓/低音/和弦/琶音 4 个 1 小节 loop，带 `first-beat` 教程 | CC0-1.0 |
| `ultrapads-night-drive.upkit` | 8 pad，90 BPM Lo-Fi：5 个 one-shot + 3 个 loop | CC0-1.0 |

所有声音都由 `runtime/up-library/src/kitgen.rs` 用代码合成（确定性伪随机噪声 + 振荡器 + 简单滤波），没有任何录音或第三方素材，可以公开分发。重新生成：

```bash
cargo run -p up-library --example kitgen -- content/kits
```

应用把这两个文件的副本打包为资源（`app/ultrapads/assets/kits/`，`just bundle-kits` 同步，`app/ultrapads/test/first_run_test.dart` 检查一致），首次启动曲库为空时自动导入。

输出是确定性的（固定 ID、固定时间戳、ZIP 时间戳为 1980-01-01）；`up-library` 的测试会检查这里提交的文件与生成器输出一致。

> 私有素材包只能放在被 gitignore 的 `private-assets/` 中，通过曲库导入器导入到本机数据目录，**永不复制到这里**。
