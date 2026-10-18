# UltraPads Kit 与项目文件格式调研

- 调研日期：2026-10-18
- 范围：采样乐器/鼓组格式、项目/编曲交换格式、Loop 元数据、包容器最佳实践、Rust 生态
- 结论先行：**Kit = "SFZ v2 + 旁挂 JSON" 的 ZIP 包（`.upkit`）；项目 = "DAWproject 1.0 超集" 的 ZIP 包（`.ultrapads`，内部本身就是合法的 `.dawproject`）**。导入/导出以 SFZ、Bitwig/PreSonus `.multisample`、DecentSampler、SF2/SF3、DAWproject、SMF 为一等公民，其余专有格式走"只读导入"或外部转换器。

> 说明：标注"（已核实）"的条目来自规范原文/官方仓库/crates.io API；标注"（社区资料）"的条目来自论坛或逆向工程，落地前需再验证。

---

## 1. 需求拆解：格式必须表达什么

| 维度 | "随手玩"侧 | "大型创作"侧 |
|---|---|---|
| 声音定义 | one-shot / loop 采样、力度层、轮替（round robin）、choke 组 | 多采样乐器、调制、效果链 |
| 交互定义 | 12/24 Pad、A/B 两组、量化启动（loop）、toggle/gate、pad 颜色/皮肤、教程谱 | Clip Launcher、Step Sequencer、时间线编排 |
| 工程数据 | — | 自动化、混音台、发送、插件状态（CLAP/VST3）、MIDI、速度/拍号、Ableton Link 设置 |
| 资产 | 采样 WAV/FLAC + BPM/小节/根音元数据 | 音频、MIDI、插件预设 |

关键观察：**"声音怎么发"** 与 **"人怎么玩"** 是两层。前者业界已有成熟开放标准（SFZ），后者（教程谱、皮肤、A/B 分组、启动模式）没有任何标准能完整表达，必须以旁挂方式扩展。

---

## 2. 采样乐器 / 鼓组格式对比

### 2.1 总表

| 格式 | 载体 | 开放程度 | 规范文档 | 鼓组关键能力 | 支持广度 | Rust 现状 |
|---|---|---|---|---|---|---|
| **SFZ v1/v2 (+ARIA/sfizz 扩展)** | 纯文本 + 外部采样文件夹 | 完全开放、免版税，社区维护 | sfzformat.com（逐 opcode 标注 v1/v2/ARIA/sfizz 版本）（已核实） | `loop_mode=one_shot`、`group`/`off_by`/`off_mode`（choke）、`trigger`、`seq_length`/`seq_position`、`lorand/hirand`、`polyphony`/`note_polyphony`、`sync_beats`（按拍同步启动）、`key/lokey/hikey/pitch_keycenter`、`#define/#include`、`default_path` | 最广：sfizz（BSD-2）、ARIA/Sforzando、LinuxSampler、liquidsfz、Bitwig/多数转换器等 | `sofiza`（MIT/Apache-2.0，0.3.1，2022-09 后无更新，仅实现部分 opcode）；无成熟完整解析器 |
| **Bitwig/PreSonus `.multisample`** | ZIP（STORED）+ `multisample.xml` + WAV | 开放，MIT（github.com/bitwig/multisample）（已核实） | 仓库 README + XML 说明 | 只描述"采样映射"（键位/力度/轮替/分组），**刻意不含**播放与音色参数；明确把"一组 loop 变体"列为 non-goal | Bitwig、Studio One、ConvertWithMoss 等 | 无专用 crate，结构极简，自写 < 300 行 |
| **DecentSampler `.dspreset` / `.dslibrary`** | XML（+ ZIP 打包的 `.dslibrary`） | 格式公开文档化；播放器为免费闭源 | decentsampler-developers-guide.readthedocs.io（已核实） | `<groups>/<group>/<sample>`，`trigger`(attack/release/first/legato)、`tags` + `silencedByTags` + `silencingMode`/`silencingDecay`（choke）、`seqMode/seqLength/seqPosition`、`loopStart/loopEnd/loopEnabled/loopCrossfade`、`ampEnvEnabled="false"` 实现 one-shot；还有 UI（`<ui>` 控件/背景图） | 免费采样库生态非常大（Pianobook 等） | 无专用 crate，用 quick-xml + serde 自写 |
| **SoundFont 2 (.sf2)** | RIFF 二进制，样本内嵌 | 开放（E-mu/Creative 公开的 2.01/2.04 规范） | SF2.04 规范 PDF | 预设/乐器/zone、`exclusiveClass`（choke）、loop 模式；无轮替、无同步启动 | GM 生态最广（FluidSynth、MuseScore、几乎所有 tracker） | `rustysynth`（MIT，1.3.7，2026-10 更新，13 万下载）、`soundfont`（MIT，0.1.0，WIP） |
| **SoundFont 3 (.sf3)** | SF2 结构 + Ogg Vorbis 压缩样本 | MuseScore 发起，事实标准 | 无正式规范文档，以 MuseScore/FluidSynth 实现为准（社区资料） | 同 SF2 | FluidSynth ≥1.1.7、MuseScore | `soundfont` crate README 标注 sf3 进行中 |
| Ableton Drum Rack `.adg` / `.adv` | gzip 压缩的 XML | 专有、无公开规范 | 仅逆向（Sample-Offline/ableton-under-the-hood、daw-schemas）（社区资料） | 完整（choke、pad、宏） | 仅 Ableton | 无；gzip + XML 可读但结构随版本漂移 |
| Bitwig Drum Machine 预设 | Bitwig 专有二进制 | 专有 | 无 | — | 仅 Bitwig | 无 |
| Akai MPC `.xpm`（Drum/Keygroup Program） | XML 文本 | 专有、无官方文档 | 论坛推测（社区资料）；ConvertWithMoss 可读写 | 完整（16 pad × 多层、mute group、pad 颜色等） | MPC/Force 生态 | 无 |
| Renoise `.xrni` | ZIP + XML + FLAC | 半公开（XML 可读，无正式规范） | Renoise 工具社区 | 完整 | 仅 Renoise | 无 |
| Polyend Tracker `.pti` / Elektron（Tonverk `.emulti`/`TVPST`、Digitakt 依赖 Transfer）/ Koala `.koala` | 二进制或私有 | 专有 | 无（ConvertWithMoss v19 已支持 PTI、Tonverk）（社区资料） | 各自完整 | 各自硬件/应用 | 无 |
| Kontakt `.nki`、EXS24 `.exs` | 专有二进制 | 专有/加密 | 无 | 完整 | 很广但封闭 | 无 |

### 2.2 SFZ 对鼓组/打击垫需求的覆盖（已核实，sfzformat.com）

| UltraPads 需求 | SFZ 原生 opcode | 版本 | 备注 |
|---|---|---|---|
| one-shot | `loop_mode=one_shot` | v1 | 播放到结尾，忽略 note-off |
| loop | `loop_mode=loop_continuous` / `loop_sustain`，`loop_start`/`loop_end` | v1 | 有 loop 点时默认 `loop_continuous` |
| choke 组 | `group=N` + `off_by=M` + `off_mode=fast/normal/time` + `off_time` | v1（`time` 为 ARIA） | 经典开闭镲：闭镲 `group=3`，开镲 `off_by=3` |
| 同 pad 重触发自截断 | `note_selfmask`、`polyphony`、`note_polyphony` | v2 | |
| 轮替/随机 | `seq_length`/`seq_position`、`lorand`/`hirand` | v1 | |
| 力度层 | `lovel`/`hivel`、`amp_velcurve_N`、`xfin_*` | v1 | |
| 触发时机 | `trigger=attack/release/first/legato/release_key` | v1（`release_key` 为 v2） | |
| 量化启动（拍同步） | `sync_beats`（等到下一个 N 拍整数倍才发声）、`sync_offset`，`delay_beats`、`stop_beats` | v1/v2 | 语义正好对应"loop 按小节量化启动"，但播放器支持程度不一；需要宿主提供 ppqPos |
| 速度范围条件 | `lobpm`/`hibpm` | v1 | |
| pad 名称 | `label_keyN`（sfizz 扩展）、`sw_label`（ARIA） | sfizz/ARIA | |
| 封面图 | `image` | v2 | |
| 宏/CC | `<control>` 下的 `set_ccN`、`label_ccN`、`default_path`、`#define` | v2 | `#include` 广泛支持 |

**SFZ 表达不了的**：pad 启动模式（toggle/latch/gate）、按"小节"而不是"拍"量化以及与 Clip Launcher 一致的全局量化、loop 原始 BPM 与时间拉伸策略、A/B 分组与 pad 网格布局、pad 颜色/皮肤、教程谱、作者/许可证等包级元数据。

**自定义 opcode 的风险**：SFZ 没有官方的"厂商私有 opcode"命名空间；sfizz 遇到未知 opcode 记录 `Unknown opcodes: ...` 并继续加载，liquidsfz 输出 `unsupported opcode` 警告（社区资料）。注释（`//`）会被所有解析器丢弃，不能作为可靠的数据载体。因此**扩展数据不放进 .sfz**，统一放旁挂 JSON。

### 2.3 选择 SFZ 作为声音层的理由

1. 开放、文本、可 diff、可手写，唯一一个"逐 opcode 有版本标注的公开规范"的采样格式。
2. 鼓组能力（choke、one-shot、轮替、力度层、拍同步）几乎全覆盖，甚至有 `sync_beats` 这种对应量化启动的 opcode。
3. 支持面最广：导出的 Kit 用户可以直接拖进 sfizz / Sforzando / 其他 DAW 采样器播放——这是"最普适"的直接体现。
4. 外部采样文件夹结构天然适合 ZIP 打包，且与 `.multisample`、DecentSampler 可以无损/近无损互转（ConvertWithMoss 证明了互转可行）。
5. 不选 DecentSampler 作为原生的原因：其参考实现闭源，格式由单一厂商随版本演进；不选 `.multisample`：刻意不含播放参数和 loop 语义，表达力不足（但非常适合作为导入/导出格式）；不选 SF2：样本内嵌二进制、无轮替/同步、编辑不友好。

---

## 3. 项目 / 编曲交换格式对比

| 格式 | 载体 | 开放程度 | 能表达的内容 | 主要支持者 | 评价 |
|---|---|---|---|---|---|
| **DAWproject 1.0** | ZIP（`.dawproject`）：`project.xml` + `metadata.xml` + 媒体 + 插件状态 | MIT，github.com/bitwig/dawproject，1.0 稳定，有 `Project.xsd` / `MetaData.xsd`（已核实） | 轨道/通道/混音（Volume/Pan/Mute/Sends）、时间线（Arrangement/Lanes/Clips/Notes/Audio/Warps/Markers）、**Scenes + ClipSlot（Clip Launcher）**、自动化（Points + Target，含速度/拍号/插件参数/MIDI CC/表情）、设备链（`Vst2Plugin`/`Vst3Plugin`/`ClapPlugin`/`AuPlugin`/`BuiltinDevice` 及 Equalizer/Compressor/NoiseGate/Limiter），插件状态以 `State path=` 文件引用嵌入 | Bitwig 5.0.9+、Studio One 6.5+、Cubase 14.0.20+ / Nuendo 14、Cubasis 3.7.x、VST Live 2.2、n-Track 10.2.2、Fender Studio；转换器 DawVert（GPL-3）、ProjectConverter（Reaper） | **唯一有多家主流 DAW 实装的开放项目格式**，首选 |
| AAF | 结构化存储二进制 | 开放（AMWA），SDK 复杂 | 音频剪辑/淡变/基础自动化，无 MIDI/插件/launcher | Pro Tools、Nuendo、视频后期 | 面向影视后期交换，复杂且对本项目价值低 |
| OMF/OMFI | 二进制 | 已过时 | 同上更少 | 老版 Pro Tools/Avid | 不建议 |
| SMF（MIDI 1.0 Standard MIDI File） | 二进制 | 开放 | 音符、CC、速度/拍号、文本/marker 元事件 | 全部 DAW/硬件 | 必须支持；最适合 Step Sequencer/教程谱的导入导出 |
| MIDI 2.0 Clip File（M2-116-U，SMF2） | UMP 序列 | 开放（MIDI Association），1.0 规范 2023 | 单序列 UMP，高分辨率力度/每音符控制 | 少量 | 可后续支持；容器格式（多轨 + XML manifest）截至调研时仍在制定中 |
| MusicXML | XML | 开放（W3C 社区组） | 记谱 | 记谱软件 | 与教程谱可能有关，但不是工程格式 |
| Ableton `.als` | gzip XML | 专有、无规范 | 全部 | Ableton | 仅可逆向只读（DawVert、daw-schemas） |
| Reaper `.rpp` | 文本 | 半公开 | 全部 | Reaper | 可经 ProjectConverter 与 DAWproject 互转 |

### 3.1 DAWproject 结构要点（来自 `Project.xsd`，已核实）

- 根：`<Project version="1.0">` → `Application`、`Transport`(Tempo, TimeSignature)、`Structure`(Track / Channel)、`Arrangement`、`Scenes`。
- 通用基类：`nameable` 提供 `name` / `color` / `comment`；`referenceable` 增加 `id`（xs:ID）；`timeline` 增加 `timeUnit`（beats/seconds）与 `track`（IDREF）。
- `Track`：`contentType`（audio/notes/automation/…）、`loaded`、可嵌套 Track，含一个 `Channel`。
- `Clip`：`time`(必填)、`duration`、`contentTimeUnit`、`playStart`/`playStop`、`loopStart`/`loopEnd`、`fadeInTime`/`fadeOutTime`、`enable`、`reference`（引用别处定义的内容）。
- `ClipSlot`：继承 timeline，可含 0~1 个 `Clip`，属性 `hasStop`；`Scene` 中放 Lanes/ClipSlot → 可表达 Session 网格。
- `Note`：`time`、`duration`、`channel`、`key`、`vel`、`rel`，Note 内还可嵌 Points（每音符表情）。
- `Points`：`Target`（`parameter` IDREF / `expression` / `channel` / `key` / `controller`）+ `RealPoint`/`BoolPoint`/`EnumPoint`/`IntegerPoint`/`TimeSignaturePoint`，`unit` 属性。
- `Device`：`deviceID`、`deviceName`(必填)、`deviceRole`(必填)、`deviceVendor`、`loaded`，子元素 `Parameters`、`Enabled`、`State`（`fileReference`: `path` + `external`）。
- `Audio`：`File path`、`duration`、`channels`、`sampleRate`、`algorithm`（拉伸算法名）。
- `MetaData.xsd`：Title、Artist、Album、OriginalArtist、Composer、Songwriter、Producer、Arranger、Year、Genre、Copyright、Website、Comment。
- **扩展性**：XSD 中没有 `xs:any` / `xs:anyAttribute`，即 project.xml 是封闭模式；但规范明确"导出方可自由决定媒体与插件文件的目录结构"。因此**唯一安全的扩展方式是在 ZIP 内放额外文件**（其他 DAW 会忽略），并通过 `id` 引用 project.xml 中的对象。README 侧栏提到 "Custom properties"，但 1.0 XSD 中未见对应结构，落地前需复查最新版本。

### 3.2 DAWproject 的已知局限

- 无 launch quantize、follow action、clip 启动模式等 launcher 行为字段；Studio One 不读取 Bitwig 的 Clip Launcher 数据；Steinberg 文档列出 scenes、markers、folder track、MIDI effects、CLAP/AU 插件、部分自动化暂不支持导入。即：**Scenes 能写，但跨 DAW 往返不保证**。
- 无 Step Sequencer 网格概念（只能落成 Notes）。
- 无采样器/鼓机的通用描述（只能是 `BuiltinDevice` + 私有 State 文件，或插件）。

---

## 4. Loop 元数据：BPM / 小节 / 根音如何随音频携带

| 载体 | 内容 | 开放性 | 读写建议 |
|---|---|---|---|
| **WAV `acid` chunk**（ACIDized） | flags（bit0 one-shot、bit1 有根音、bit2 可拉伸、bit3 磁盘流）、root note、beats 数、拍号分子/分母、tempo（float32） | 事实标准，无官方规范，字段布局以 libsndfile 实现为准（社区资料） | 读：作为 BPM/小节首要来源；写：导出 loop 时写入 |
| **WAV `smpl` chunk** | MIDI unity note（根音）、pitch fraction、loop 列表（类型 forward/pingpong/backward、start/end 样本帧、play count） | Microsoft/IBM RIFF 规范 | 读写；loop 点、根音的标准来源。注意 JUCE 曾在 loop 数为 0 时丢弃整个 chunk |
| **WAV `inst` chunk** | unshifted note、fine tune、gain、键位/力度范围 | RIFF 规范 | 读；作为 smpl 缺失时的根音补充 |
| **WAV `cue ` + `LIST/adtl`** | 标记点与标签（可做切片） | RIFF 规范 | 读写切片点 |
| **BWF `bext`** | Description、Originator、TimeReference、UMID、Loudness（v2） | EBU Tech 3285 开放 | 读写来源/版权/响度；**不含 BPM** |
| **iXML** | 场记/项目元数据 XML | 开放 | 可选读取 |
| Apple Loops（AIFF/CAF 私有 chunk） | tempo、key、beats、transients、tags | **无公开规范** | 不实现写入；读取仅作尽力而为 |
| 文件名约定 | `loop_120bpm_Am_4bars.wav` | 社区习惯 | 作为最后兜底解析 |

**落地规则**：解析优先级 = Kit JSON 显式声明 > `acid` > `smpl`/`inst` > 文件名 > 时长推算（`beats = round(duration * bpm / 60)` 取 2 的幂）。导出时把 BPM/beats/root 同时写回 `acid` + `smpl`，使采样脱离 UltraPads 也能被 Acid/Ableton/FL 等识别。

---

## 5. 包容器与内容寻址最佳实践

参考 EPUB/ODF（`mimetype` 首条目不压缩）、`.multisample`（采样用 STORED 以便流式读取）、DAWproject（ZIP + XML + 媒体）、OCI/Git（内容哈希）：

1. **ZIP 容器**：音频 STORED（可 mmap/流式读取，压缩收益也很小），XML/JSON 用 Deflate；支持 ZIP64；文件名 UTF-8、正斜杠、相对路径。
2. **首条目 `mimetype`**（STORED、无 extra field），内容如 `application/vnd.ultrapads.kit+zip`，便于嗅探；对 DAWproject 读取方无害。
3. **manifest**：列出每个文件的 `path`、`size`、`blake3`、`mediaType`；包级 `formatVersion`、`generator`、`license`（SPDX 标识）。
4. **内容寻址只用于去重与缓存，不用于包内文件名**：包内保留人类可读路径；用户本地库用 `~/.ultrapads/cas/blake3/ab/cdef…` 去重，同一采样被多个 Kit/项目引用只存一份。
5. **同时支持"文件夹形态"**：`.upkit` 解压后的目录可以被直接打开（与 `.multisample` 规范一致），便于 git 管理和手工编辑。
6. **安全**：拒绝绝对路径和 `..`（zip-slip）、限制解压后总大小与条目数（zip bomb）、校验 blake3 后再加载、不执行包内任何脚本。
7. **原子保存**：写入同目录临时文件 → fsync → rename；保留上一版本 `.bak`。
8. **版本演进**：`formatVersion` 用 semver；读取方忽略未知 JSON 字段（前向兼容），major 变化时拒绝并提示升级。

---

## 6. 推荐方案

### 6.1 一句话结论

- **UltraPads 原生 Kit 格式 = `.upkit`**：ZIP（或同名文件夹），核心为一个**只用标准 SFZ v1/v2 opcode 的 `kit.sfz`**（声音行为的唯一真相源）+ 旁挂 `ultrapads-kit.json`（pad 布局、A/B 组、启动模式、量化、颜色、皮肤、BPM、教程引用）+ `manifest.json` + `samples/`（WAV/FLAC，内嵌 `acid`/`smpl`）+ `tutorials/`（SMF + JSON）。
- **项目格式 = `.ultrapads`**：ZIP，其 `project.xml` / `metadata.xml` **严格符合 DAWproject 1.0 XSD**（文件改扩展名为 `.dawproject` 即可被 Bitwig/Studio One/Cubase 打开），UltraPads 独有数据放在 `ultrapads/` 子目录的 JSON 中，通过 DAWproject 的 `id` 关联；Kit 以 `BuiltinDevice` 的 `State` 文件引用嵌入（`kits/<name>.upkit/`）。
- **导入**：SFZ、`.multisample`、DecentSampler（`.dspreset`/`.dslibrary`）、SF2/SF3、WAV 文件夹（读 acid/smpl/文件名）、DAWproject、SMF；第二阶段：MPC `.xpm`、Ableton `.adg`（只读、尽力而为）；其余（Kontakt、Elektron、Polyend、EXS…）引导用户用 ConvertWithMoss（LGPL-3，作为外部工具，不链接）先转成 SFZ/`.multisample`。
- **导出**：Kit → 独立 SFZ 文件夹、`.multisample`、`.dspreset`；项目 → `.dawproject`、SMF（每轨/每 pattern）、WAV/BWF stems。
- **为什么**：两个核心层都直接是现有开放标准（SFZ 规范公开且支持最广；DAWproject 是 MIT、多家主流 DAW 已实装的唯一开放项目格式），UltraPads 只在标准"表达不了"的地方旁挂 JSON，且旁挂数据丢失时仍能降级为可用的标准文件。

### 6.2 `.upkit` 结构

```
808-street.upkit                     (ZIP，或同名文件夹)
├── mimetype                         "application/vnd.ultrapads.kit+zip"（首条目，STORED）
├── manifest.json                    包元数据 + 每个文件的 blake3
├── kit.sfz                          标准 SFZ：声音行为唯一真相源
├── ultrapads-kit.json               交互/布局/外观扩展（UltraPads 专有）
├── samples/
│   ├── kick_01.wav                  one-shot
│   ├── hh_closed_rr1.wav / rr2.wav
│   ├── hh_open.wav
│   └── loop_drums_92bpm_4bar.wav    内嵌 acid(bpm=92,beats=16) + smpl(loop)
├── tutorials/
│   └── first-beat/
│       ├── chart.mid                SMF type 1：pad 音符 = 要按的 pad 与时刻
│       └── tutorial.json            分步说明、提示文字、判定窗口、多语言
├── skin/
│   ├── theme.json                   颜色 token、字体、pad 形状
│   └── cover.png
└── LICENSE.txt                      采样许可（与代码的 Apache-2.0 分开）
```

**Pad ↔ 音符映射约定**：每个 pad 对应一个 MIDI 音符；默认 `note = 36 + padIndex`（与 MPC/Push 的 C1=36 习惯一致），A 组 pad 0–11 → 36–47，B 组 pad 12–23 → 48–59；12-pad 模式只用 A 组。SFZ 中属于该音符的所有 region 即这个 pad 的声音；JSON 通过 `note` 引用 pad，不重复描述声音参数。这样：
- 把 `kit.sfz` 拖进 sfizz，用任何 MIDI 控制器按 36–59 就能玩到同样的声音；
- 删除 JSON 后 UltraPads 仍能按默认布局加载（降级可用）。

#### `kit.sfz` 示例（只用标准 opcode）

```sfz
// UltraPads Kit: 808 Street  (声音定义；交互信息见 ultrapads-kit.json)
<control>
default_path=samples/
label_cc1=Tone

<global>
loop_mode=one_shot
off_mode=normal
amp_veltrack=100

// ---- Pad A1: Kick ----
<group> key=36 note_selfmask=on
<region> sample=kick_01.wav

// ---- Pad A2: Closed HH（choke 开镲）----
<group> key=42 group=3 seq_length=2
<region> sample=hh_closed_rr1.wav seq_position=1
<region> sample=hh_closed_rr2.wav seq_position=2

// ---- Pad A3: Open HH（被组 3 截断）----
<group> key=46 group=4 off_by=3 off_time=0.03
<region> sample=hh_open.wav

// ---- Pad B1: Drum loop（按 4 拍同步启动，循环）----
<group> key=48 loop_mode=loop_continuous sync_beats=4 group=10 off_by=10
<region> sample=loop_drums_92bpm_4bar.wav
```

说明：choke（`group`/`off_by`）、one-shot、轮替、loop 点、按拍同步（`sync_beats`）都用标准 opcode 表达，UltraPads 引擎把它们视为权威；JSON 只补充 SFZ 没有的东西。注：示例中 `key` 采用 GM 风格音符以便说明，实际默认映射按上文约定生成。

#### `ultrapads-kit.json` 示例

```json
{
  "$schema": "https://ultrapads.dev/schema/kit-1.json",
  "formatVersion": "1.0.0",
  "sfz": "kit.sfz",
  "layout": { "padCount": 24, "grid": [4, 3], "banks": ["A", "B"] },
  "pads": [
    { "note": 36, "bank": "A", "index": 0, "name": "Kick",   "color": "#FF5A36", "icon": "kick" },
    { "note": 42, "bank": "A", "index": 1, "name": "HH Cl",  "color": "#F7C948" },
    { "note": 46, "bank": "A", "index": 2, "name": "HH Op",  "color": "#F7C948" },
    {
      "note": 48, "bank": "B", "index": 0, "name": "Groove", "color": "#3FA7FF",
      "kind": "loop",
      "launch": { "mode": "toggle", "quantize": "1bar", "retrigger": "restart" },
      "tempo": { "bpm": 92.0, "beats": 16, "timeSignature": [4, 4], "stretch": "beats" },
      "exclusive": "loops-B"
    }
  ],
  "defaults": { "oneShot": { "launch": { "mode": "trigger", "quantize": "none" } } },
  "tutorials": [ { "id": "first-beat", "path": "tutorials/first-beat/tutorial.json" } ],
  "skin": "skin/theme.json"
}
```

- `launch.quantize` 取值 `none | 1/16 | 1/8 | 1/4 | 1beat | 1bar | 2bar | 4bar | global`，与项目的 Clip Launcher 全局量化共用同一套枚举；
- 当 `quantize` 能用拍数表达时，写导出 SFZ 时同步写 `sync_beats`，保持两边一致；冲突时以 SFZ 为准并在加载时警告；
- `tempo` 缺省时从 `acid` → `smpl` → 文件名 → 时长推算。

#### `manifest.json` 示例

```json
{
  "mediaType": "application/vnd.ultrapads.kit+zip",
  "formatVersion": "1.0.0",
  "id": "urn:uuid:6f1c2a7e-0b8e-4c55-9b0a-2b7f2f0f6a11",
  "name": "808 Street",
  "authors": ["UltraPads Team"],
  "license": "CC-BY-4.0",
  "generator": "UltraPads 0.1.0",
  "created": "2026-10-18T00:00:00Z",
  "files": [
    { "path": "kit.sfz", "size": 812, "blake3": "9a1f…", "mediaType": "text/plain" },
    { "path": "samples/kick_01.wav", "size": 88244, "blake3": "c03e…", "mediaType": "audio/wav" }
  ]
}
```

#### 教程谱：`chart.mid` + `tutorial.json`

- `chart.mid`（SMF type 1）：track 0 放速度/拍号，track 1 的 note-on 音符号 = pad 音符、时刻 = 应按时刻、力度 = 期望力度；可用 Marker 元事件标注段落。任何 DAW 都能打开查看/编辑。
- `tutorial.json`：

```json
{
  "id": "first-beat",
  "title": { "zh-CN": "你的第一个节拍", "en": "Your first beat" },
  "chart": "chart.mid",
  "tempo": { "start": 80, "target": 92 },
  "judge": { "perfectMs": 30, "goodMs": 80 },
  "steps": [
    { "fromBar": 1, "toBar": 2, "hint": { "zh-CN": "只按 Kick，跟着节拍器" }, "pads": [36] },
    { "fromBar": 3, "toBar": 4, "hint": { "zh-CN": "加入闭镲" }, "pads": [36, 42], "loop": true }
  ]
}
```

### 6.3 `.ultrapads` 项目结构

```
my-song.ultrapads                    (ZIP；改名为 .dawproject 即可被其他 DAW 打开)
├── mimetype                         "application/vnd.ultrapads.project+zip"
├── project.xml                      严格符合 DAWproject 1.0 Project.xsd
├── metadata.xml                     符合 MetaData.xsd
├── audio/                           录音、渲染、冻结音频
├── plugins/                         插件状态：*.clap-preset / *.vstpreset（DAWproject 惯例）
├── kits/
│   └── 808-street.upkit/            嵌入的 Kit（文件夹形态，其他 DAW 用户可手动载入 kit.sfz）
└── ultrapads/
    ├── manifest.json                blake3 清单 + "projectXmlBlake3"
    ├── session.json                 launcher 行为：量化、follow action、启动模式、A/B
    ├── sequencer.json               Step Sequencer 网格（步长、概率、微移、锁参）
    ├── link.json                    Ableton Link / 同步设置
    └── ui.json                      视图状态、缩放、颜色主题
```

**往返一致性规则**：`ultrapads/manifest.json` 记录保存时 `project.xml` 的 blake3。
- 哈希一致 → 用 project.xml + 扩展 JSON 完整还原；
- 哈希不一致（文件被其他 DAW 重新保存过）→ 以 project.xml 为准，扩展 JSON 只按 `id` 尽力合并，找不到的对象丢弃并提示。
- 因此任何 UltraPads 数据都必须"先尽量落到 DAWproject 原生结构里"：Step Sequencer pattern 同时渲染成 `ClipSlot/Clip/Notes`；量化/启动模式只是附加行为。

#### `project.xml` 片段示例（元素/属性均出自 Project.xsd）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Project version="1.0">
  <Application name="UltraPads" version="0.1.0"/>
  <Transport>
    <Tempo id="tempo" unit="bpm" value="92.0" min="20" max="999"/>
    <TimeSignature id="ts" numerator="4" denominator="4"/>
  </Transport>
  <Structure>
    <Track id="trk_pads" name="Pads" color="#FF5A36" contentType="notes" loaded="true">
      <Channel id="ch_pads" role="regular" audioChannels="2" destination="ch_master">
        <Devices>
          <BuiltinDevice id="dev_kit" deviceRole="instrument" deviceName="UltraPads Kit"
                         deviceVendor="UltraPads" deviceID="dev.ultrapads.kit">
            <State path="kits/808-street.upkit"/>
          </BuiltinDevice>
          <ClapPlugin id="dev_comp" deviceRole="audioFX" deviceName="Some Compressor"
                      deviceID="com.vendor.comp" pluginVersion="1.2.0">
            <State path="plugins/dev_comp.clap-preset"/>
          </ClapPlugin>
        </Devices>
        <Volume id="vol_pads" unit="linear" value="0.8"/>
        <Pan id="pan_pads" unit="normalized" value="0.5"/>
        <Mute id="mute_pads" value="false"/>
      </Channel>
    </Track>
    <Track id="trk_master" name="Master" contentType="audio notes" loaded="true">
      <Channel id="ch_master" role="master" audioChannels="2"/>
    </Track>
  </Structure>
  <Arrangement id="arr">
    <Lanes timeUnit="beats" id="arr_lanes">
      <Lanes track="trk_pads" id="lane_pads">
        <Clips id="clips_pads">
          <Clip time="0" duration="16" playStart="0" name="Verse beat" reference="notes_p1"/>
        </Clips>
      </Lanes>
      <Points track="trk_pads" id="auto_vol" unit="linear">
        <Target parameter="vol_pads"/>
        <RealPoint time="0" value="0.6"/>
        <RealPoint time="16" value="0.8"/>
      </Points>
    </Lanes>
  </Arrangement>
  <Scenes>
    <Scene id="scene_1" name="Intro">
      <Lanes timeUnit="beats">
        <ClipSlot track="trk_pads" id="slot_pads_1" hasStop="true">
          <Clip time="0" duration="4" loopStart="0" loopEnd="4" name="Pattern 1">
            <Notes id="notes_p1">
              <Note time="0" duration="0.25" channel="0" key="36" vel="0.9"/>
              <Note time="1" duration="0.25" channel="0" key="42" vel="0.7"/>
            </Notes>
          </Clip>
        </ClipSlot>
      </Lanes>
    </Scene>
  </Scenes>
</Project>
```

> 落地前务必用 `xmllint --schema Project.xsd project.xml` 在 CI 中校验示例与导出结果（上面示例的个别属性如 `Tempo` 的 `min/max`、`contentType` 的组合写法需以 XSD 为准微调）。

#### `ultrapads/session.json` 示例

```json
{
  "formatVersion": "1.0.0",
  "globalQuantize": "1bar",
  "slots": {
    "slot_pads_1": { "launch": { "mode": "toggle", "quantize": "global" },
                     "followAction": { "after": "4bar", "action": "next", "chance": 1.0 } }
  },
  "padBanks": { "trk_pads": { "active": "A" } }
}
```

### 6.4 导入/导出矩阵

| 格式 | 导入 | 导出 | 阶段 | 实现方式 |
|---|---|---|---|---|
| SFZ | 是（原生） | 是 | P0 | 自写解析器（覆盖 v1 + 常用 v2/ARIA/sfizz 子集） |
| `.upkit` | 是 | 是 | P0 | zip + serde_json |
| WAV/FLAC 文件夹 | 是 | — | P0 | 读 acid/smpl/inst/cue/bext + 文件名规则 |
| Bitwig/PreSonus `.multisample` | 是 | 是 | P1 | quick-xml |
| DecentSampler `.dspreset/.dslibrary` | 是 | 是 | P1 | quick-xml；`silencedByTags`↔`off_by`，`ampEnvEnabled=false`↔one_shot |
| SF2 / SF3 | 是 | 否 | P1 | `soundfont` 或 `rustysynth` 解析；SF3 需 Vorbis 解码（symphonia/lewton） |
| DAWproject | 是 | 是 | P0（导出）/ P1（导入） | 自定义 serde 结构 + quick-xml，XSD 校验 |
| SMF | 是 | 是 | P0 | `midly` |
| MIDI 2.0 Clip File | 待定 | 待定 | P3 | 观察 MIDI Association 容器规范进展 |
| MPC `.xpm` | 是（尽力） | 否 | P2 | 逆向 XML，参考 ConvertWithMoss 行为 |
| Ableton `.adg` | 是（尽力） | 否 | P2 | gzip + XML 逆向 |
| Kontakt/EXS/Elektron/Polyend/Koala | 否 | 否 | — | 文档引导用户用 ConvertWithMoss 转换 |
| AAF / OMF / MusicXML / `.als` | 否 | 否 | — | 价值低或封闭；`.als` 可建议经 DawVert（GPL-3，外部工具）转 DAWproject |

---

## 7. Rust 依赖评估（数据来自 crates.io API，2026-10-18）

| crate | 版本 / 最近更新 | 许可证 | 下载量 | 用途 | 结论 |
|---|---|---|---|---|---|
| `zip`（zip-rs/zip2） | 9.0.5 / 2026-10 | MIT | 3 亿+ | 容器读写 | 采用 |
| `quick-xml`（含 serde 特性） | 0.42.0 / 2026-08 | MIT | 4.7 亿+ | DAWproject、multisample、dspreset | 采用（0.x，升级需关注 API 变化） |
| `serde` / `serde_json` | 1.0.x / 2026-10 | MIT OR Apache-2.0 | — | 旁挂 JSON | 采用 |
| `blake3` | 1.8.7 / 2026-08 | CC0 / Apache-2.0 / Apache-2.0 WITH LLVM-exception | 2 亿+ | 内容哈希 | 采用 |
| `hound` | 3.5.1 / 2023-09 | Apache-2.0 | 2000 万+ | WAV PCM 读写 | 采用（只处理 fmt/data，不读 smpl/acid） |
| `riff` | 2.0.0 / 2023-06 | MIT | 1300 万+ | 通用 RIFF chunk 遍历 | 采用，或自写 ~200 行 chunk 解析（acid/smpl/inst/cue/bext） |
| `symphonia` | 0.6.1 / 2026-08 | MPL-2.0 | 1700 万+ | FLAC/Ogg/MP3 等解码 | 采用；MPL-2.0 为文件级 copyleft，作为未修改依赖与 Apache-2.0 兼容 |
| `midly` | 0.5.3 / 2023-01 | Unlicense | 50 万 | SMF 读写 | 采用（稳定、零依赖） |
| `rustysynth` | 1.3.7 / 2026-10 | MIT | 13 万 | SF2 解析/渲染 | 可用于 SF2 导入 |
| `soundfont` | 0.1.0 / 2024-12 | MIT | 4 万 | SF2 纯解析 | 备选，WIP，sf3 未完成 |
| `sofiza` | 0.3.1 / 2022-09 | MIT/Apache-2.0 | 1.5 万 | SFZ 解析 | **不依赖**：停更、opcode 覆盖不全；仅作参考 |
| `dawproject-rs` | 0.1.1 / 2024-04 | 非标准（GitHub 显示 NOASSERTION） | 2.7 千 | DAWproject | **不依赖**：许可证不明确、成熟度低 |
| `oxisynth` | 0.1.0 / 2025-05 | LGPL-2.1 | 3 万 | SF2 合成 | 避免（LGPL 静态链接合规成本） |
| `nidhi` | 1.1.0 / 2026-03 | GPL-3.0-only | 300+ | 含 SFZ 导入的采样引擎 | **禁止**（GPL 与 Apache-2.0 分发不兼容） |

参考实现（非依赖）：sfizz（BSD-2-Clause，C++，可作为 SFZ 行为与测试语料的对照）、ConvertWithMoss（LGPL-3，Java，格式互转行为参考）、DawVert（GPL-3，Python，仅作外部工具建议，不可复制代码）。

**需要自研的模块**：
1. `sfz` 解析器：词法（注释、`#define $VAR`、`#include`、header、`opcode=value` 中含空格的 sample 路径）→ 层级继承（control/global/master/group/region）→ 类型化 opcode；未知 opcode 保留原文以便无损回写。
2. DAWproject 的 serde 结构：按 Project.xsd 手写或用 XSD 代码生成后手工整理；CI 用官方 XSD 校验。
3. WAV 元数据 chunk 读写（acid/smpl/inst/cue/bext）。

---

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| SFZ 方言碎片化（v1/v2/ARIA/sfizz 各有扩展，播放器支持不一，如 `sync_beats` 支持程度不明） | 导出的 Kit 在第三方播放器里行为不完全一致 | 定义"UltraPads SFZ Profile"（明确支持的 opcode 白名单）；导出时只写白名单；用 sfizz 做对照测试 |
| 无成熟 Rust SFZ 解析器 | 需自研，工作量 | 语法简单，先覆盖鼓组所需子集；用 sfizz 测试语料做回归 |
| DAWproject 1.0 XSD 封闭、launcher 往返不保证 | 其他 DAW 打开后丢失 UltraPads 行为数据 | 扩展数据放 `ultrapads/` 旁挂并用哈希检测；核心音乐数据始终落在原生结构 |
| DAWproject 版本演进（如未来加入 Custom properties） | 结构需要迁移 | 关注 bitwig/dawproject 仓库；扩展 JSON 设计成可迁移到官方扩展机制 |
| `acid` chunk 无官方规范，根音编码存在歧义 | BPM/根音读错 | 以 libsndfile 实现为准；多来源交叉校验；JSON 显式声明优先 |
| 专有格式（MPC/Ableton/Kontakt）逆向不稳定 | 导入失败或不完整 | 标记为"尽力而为"，提供转换器指引，不承诺往返 |
| 许可证污染（GPL/LGPL 依赖） | 与 Apache-2.0 分发冲突 | 在 CI 中用 `cargo-deny` 设置许可证白名单（MIT/Apache-2.0/BSD/ISC/Zlib/Unlicense/CC0/MPL-2.0） |
| 采样内容版权 | Kit 分发合规 | `manifest.license` 使用 SPDX，强制填写；代码与内容许可证分离 |
| ZIP 安全（zip-slip、zip bomb） | 安全漏洞 | 路径规范化、大小/条目限制、哈希校验 |

---

## 9. 参考链接

**SFZ**
- https://sfzformat.com/headers/
- https://sfzformat.com/opcodes/
- https://sfzformat.com/opcodes/loop_mode/
- https://sfzformat.com/opcodes/off_by/
- https://sfzformat.com/opcodes/off_mode/
- https://sfzformat.com/opcodes/trigger/
- https://sfzformat.com/opcodes/sync_beats/
- https://sfzformat.com/headers/control/
- https://sfzformat.com/tutorials/drum_basics
- https://github.com/sfztools/sfizz
- https://linuxsampler.org/sfz
- https://discourse.ardour.org/t/sfizz-no-sound-in-ardour-5-12/103902 （sfizz 未知 opcode 日志）
- https://blogs.gnome.org/stw/?p=6317 （liquidsfz）

**其他采样格式**
- https://github.com/bitwig/multisample
- https://decentsampler-developers-guide.readthedocs.io/en/latest/the-groups-element.html
- https://decentsampler-developers-guide.readthedocs.io/en/latest/topic-how-to-do-voice-muting-for-drums.html
- https://vgmpf.com/Wiki/index.php?title=SF2
- https://mail.gnu.org/archive/html/fluid-dev/2015-09/msg00008.html
- https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/merge_requests/697
- https://github.com/git-moss/ConvertWithMoss
- https://www.kvraudio.com/forum/viewtopic.php?p=9273851
- https://synthanatomy.com/2026/08/convertwithmoss.html
- https://www.mpc-forums.com/viewtopic.php?p=1736400
- https://github.com/Sample-Offline/ableton-under-the-hood
- https://pypi.org/project/daw-schemas/
- https://nationalarchives.gov.uk/PRONOM/fmt/1463
- https://www.renoise.com/tools/paketti-formats

**项目格式**
- https://github.com/bitwig/dawproject
- https://raw.githubusercontent.com/bitwig/dawproject/main/Project.xsd
- https://raw.githubusercontent.com/bitwig/dawproject/main/MetaData.xsd
- https://support.presonus.com/hc/en-us/articles/19743606863629-Introducing-DAW-Project
- https://www.steinberg.help/r/cubasis/3.8/en/cubasis/topics/dawproject_c.html
- https://helpcenter.steinberg.de/hc/en-us/articles/25142209226642-DAWproject-Exchange-Cubasis-projects-with-Cubase-and-other-DAWs
- https://www.soundonsound.com/techniques/cubase-14-using-dawproject-exchange-projects-between-cubase-cubasis
- https://forums.steinberg.net/t/daw-project-import-not-working-at-all/968702
- https://musically.com/2025/01/17/roex-adds-ableton-live-set-export-and-dawproject-support/
- https://cdm.link/dawformat-bitwig-presonus/
- https://github.com/SatyrDiamond/DawVert
- https://midi.org/midi-clip-file-specification-smf-midi-2-0-2
- https://midi.org/smf2-container-format-for-data-exchange

**Loop / WAV 元数据**
- https://git.fasttube.de/FaSTTUBe/GST-Tensordecoder-ov_ep/commit/4f37ce04f6b3957673b7bd6b4044ddb5fd87382e （acid chunk 结构）
- https://cycling74.com/forums/extracting-exif-metadata-from-wav-file
- https://www.recordingblogs.com/node/664 （smpl chunk）
- https://www.radio42.com/bass/help/html/d2889826-baf9-33e9-5cb4-8b8d2b49c847.htm
- https://forum.juce.com/t/cant-write-smpl-chunk-in-a-wav-file-if-sample-is-one-shot/21222
- https://developer.apple.com/library/mac/documentation/musicaudio/Reference/CAFSpec/CAF_overview/CAF_overview.html
- https://help.apple.com/logicpro/mac/10.1/en.lproj/lgcp32add66e.html
- EBU Tech 3285（BWF bext）：https://tech.ebu.ch/publications/tech3285

**Rust crate**
- https://crates.io/crates/zip ・ https://crates.io/crates/quick-xml ・ https://crates.io/crates/blake3
- https://crates.io/crates/hound ・ https://crates.io/crates/riff ・ https://crates.io/crates/symphonia
- https://crates.io/crates/midly ・ https://github.com/sinshu/rustysynth ・ https://github.com/PolyMeilex/OxiSynth
- https://github.com/andamira/sofiza ・ https://github.com/leichak/dawproject-rs ・ https://docs.rs/crate/nidhi/1.0.1
