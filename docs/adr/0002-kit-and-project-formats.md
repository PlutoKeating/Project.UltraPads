# ADR-0002 Kit 与项目文件格式

- 状态：已接受
- 日期：2026-10-18
- 依据：`docs/research/kit-and-project-formats.md`

## 决策

1. **原生 Kit `.upkit`**：ZIP 包，也可以是同名文件夹。
   - `kit.sfz`：只使用标准 SFZ opcode，覆盖 one-shot、loop、choke（`group`/`off_by`）、轮替、力度层、`sync_beats`
   - `ultrapads-kit.json`：SFZ 表达不了的部分，包括 A/B 分组、pad 布局、启动模式、小节量化、loop BPM/小节数、颜色角色、教程引用
   - `manifest.json`：每个文件的 BLAKE3 和 SPDX 许可证
   - `samples/`、`tutorials/`（`chart.mid` + `tutorial.json`）
   - pad 对应 MIDI 音符 36 + 平铺序号；没有 JSON 时按默认布局降级加载
2. **项目 `.ultrapads`**：ZIP 包，其中 `project.xml` 和 `metadata.xml` 严格遵循 DAWproject 1.0；UltraPads 独有数据放在 `ultrapads/*.json`，通过 `id` 关联；用 `project.xml` 哈希检测外部修改，修改过则以 XML 为准降级加载。
3. **导入/导出分批**
   - v0.0.1：`.upkit`、SFZ、WAV 文件夹、私有素材包导入器、SMF
   - 后续：DAWproject 导出/导入、`.multisample`、DecentSampler、SF2/SF3、MPC `.xpm`、Ableton `.adg`
4. **自研**：SFZ 解析器（以 sfizz 行为为对照，有 opcode 白名单）、DAWproject serde 模型（CI 中用 XSD 校验）、WAV 元数据 chunk 读写。
5. **许可证闸门**：用 cargo-deny 禁止 GPL/LGPL 依赖进入默认构建。
6. **安全**：解包 ZIP 时防路径穿越、限制大小、校验哈希。
