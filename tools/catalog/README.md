# tools/catalog — 官方曲库入库管线

把开放许可的音乐素材批处理成 UltraPads 的 `.upkit` Kit，并上传到数据服务（`docs/API.md` §7.4）。决策见 `docs/adr/0005-catalog-and-accounts.md`。

**素材永远不进 Git**：下载缓存在 `.cache/`，产物在 `out/`，二者都被 `.gitignore` 忽略。

## 环境

- Python 3.11+，`pip install -r requirements.txt`（numpy、scipy）
- 系统 `ffmpeg` / `ffprobe`（解码、FLAC / mp3 编码）
- Rust 工具 `up-catalog-pack`（打包、验证、SoundFont 渲染）：`cargo build -p up-catalog-pack --release`，缺失时管线会自动构建

## 用法

在 `tools/catalog/` 下运行：

```bash
python3 -m upcatalog build --source synth          # fetch → analyze → slice → pack → preview 一条龙
python3 -m upcatalog build --source album
python3 -m upcatalog build --source online --limit 22

# 也可以分步（--id 可重复，只处理指定条目；--source 缺省为 all）
python3 -m upcatalog fetch    --source online      # 拉取并校验来源、核对许可证原文
python3 -m upcatalog analyze  --source album       # synth: 作曲 + 渲染；album/online: 节拍分析 + 选段
python3 -m upcatalog slice                          # 切片，生成 out/kitdirs/<id>/ 与 out/items/<id>.json
python3 -m upcatalog pack                           # 打成 out/kits/<id>.upkit，并导入一遍、逐个解码全部样本
python3 -m upcatalog qa --strict                    # 自动质检：静音 / 削波 / 节拍对齐 / 循环首尾跳变
python3 -m upcatalog preview                        # out/preview/index.html（人工抽检）
python3 -m upcatalog publish --dry-run              # 上传前预览
python3 -m upcatalog publish                        # 上传为 draft
python3 -m upcatalog publish --publish              # 上传并发布（必须先人工抽检）
python3 -m unittest discover -s tests -t .          # 管线自身的测试
```

`just catalog-test` 运行管线测试（Python + Rust）。

### 上传

`publish` 读取环境变量（不要写进仓库）：

| 变量 | 含义 |
|---|---|
| `ULTRAPADS_DATA_URL` | 数据服务地址（含路径前缀），如 `https://data.example.com/ultrapads` |
| `ULTRAPADS_DATA_KEY` | 数据服务密钥（`Authorization: Bearer`） |
| `ULTRAPADS_ADMIN_KEY` | 管理密钥（`X-Up-Admin`） |

顺序：`PUT /v1/admin/catalog/<id>`（draft）→ `PUT …/file`（带 `x-sha256`，服务端核对）→ 只有 `--publish` 才再 PUT 一次 `status: published`。

## 目录结构

```
tools/catalog/
├── upcatalog/               Python 管线
│   ├── cli.py               命令行入口（python3 -m upcatalog）
│   ├── licenses.py          许可证白名单与校验（未知许可证直接拒绝）
│   ├── audio.py             ffmpeg 读写、响度、软限幅、按小节切片
│   ├── analyze.py           BPM / 小节起点估计（谱通量 + 自相关 + 梳状网格）
│   ├── layout.py            分轨 → 音色组 / pad 布局，生成 kit.json 与 .upkit 目录
│   ├── compose.py styles.py smf.py   synth 来源：程序化作曲、风格模板、MIDI 写入
│   ├── sources/{synth,album,online}.py   三类来源
│   ├── qa.py preview.py publish.py rust.py http.py model.py paths.py
├── pack/                    Rust 工具 up-catalog-pack（pack / verify / render / presets）
├── data/sources.json        外部资源的地址、sha256 与许可证核对记录
├── tests/                   Python 单元测试
├── .cache/                  下载缓存（不入库）
└── out/                     work/ kitdirs/ kits/ items/ preview/（不入库）
```

## Kit 形态

每首歌一个 Kit，**一个音色组（A/B/C…）= 歌曲的一个完整段落（4 小节），组内一个 pad = 该段落的一个乐器分轨**。把同一组的全部 pad 都打开，就是完整的一段歌；pad 序号 = 乐器序号，各组一致（如 pad 1 永远是鼓）。全部 Loop + Toggle + 按小节量化（`1bar`），颜色按乐器区分。`exclusive` 按乐器编号（`inst1`…）跨组互斥：切到另一段的鼓会自动停掉上一段的鼓，其余乐器不受影响，可以逐个乐器换段落即兴。

| 素材 | 段落数 |
|---|---|
| synth | 4（A–D，和弦进行与节奏各不相同） |
| album / online | 优先取 16 小节 = 4 段，找不到时退到 8 小节 = 2 段；最多 8 段，不足 4 小节的尾巴丢弃 |
| 只有整曲混音（一条分轨） | 每段 pad 1 = 整段，pad 2–7 补 2 小节 / 1 小节片段（`frag` 组互斥） |

**任何把整首歌自动拆成 Kit 的功能（包括后续的用户导入拆分）都必须遵守这个排布。**每个 pad 是独立的 FLAC 文件（引擎的 `start_frame` 用引擎采样率计数，设备采样率不同会错位，所以不用同一文件的偏移）。左右声道一致的分轨存成单声道，体积减半，引擎播放时单声道原样复制到两侧，听感不变。

`.upkit` 内含：`kit.json`（`ultrapads-kit.json` 的来源）、`samples/*.flac`、`LICENSE.txt`（许可证与署名）、`ATTRIBUTION.txt`、`NOTICE.txt`（第三方素材要求随附的版权声明，如 SoundFont）。`manifest.json` 的 `license` 与 `source.inspiredBy`（署名行）由 `up-format` 写入。Kit ID 由条目 id 确定性派生，重复下载自动去重。

## 许可证策略

白名单（`licenses.py`）：`CC0-1.0`、`PD`、`CC-BY-3.0/4.0`、`CC-BY-SA-3.0/4.0`、`CC-BY-NC-3.0/4.0`、`CC-BY-NC-SA-3.0/4.0`。**不在白名单就拒绝入库**，包括 ND、Sampling Plus、自定义「免费但不可再分发」之类。

- `commercial_ok` = 不含 NC，`share_alike` = 含 SA，由许可证 ID 推出。
- 每个条目带 `license`、`license_url`、`attribution`（署名行，应用内与 Kit 元数据原样展示）、`source_url`。
- 来源检查写在代码里：`synth` 校验 SoundFont 的 sha256 与许可证原文含 MIT 声明；`album` 校验 Zenodo 记录的许可证仍是 `cc-by-4.0`；`online` 对每条上传按它自己的 `license_url` 过滤。
- 修改过原素材（求和、裁剪、响度）的条目，署名行里写明 `Changes: …`（CC BY 要求标注修改）。
- CC BY-SA 素材的衍生 Kit 沿用同样许可证；CC BY-NC 素材使整个目录保持非商用定位。

## 三类来源

### synth（原创，CC0-1.0）

`compose.py` + `styles.py` 用种子确定性地生成 10 种风格（house、hip-hop、lo-fi、trap、drum-and-bass、funk、ambient、chiptune、synthwave、disco）各 4 首原创歌曲：和弦进行、鼓谱、贝斯、和弦伴奏、旋律（动机 + 变化重复）、铺底、琶音 / 打击乐。每首 8 小节 = A、B 两个 4 小节乐句。写出标准 MIDI，再用 `up-catalog-pack render` 以 MuseScore_General SoundFont（MIT，sha256 在 `data/sources.json` 里钉死）渲染；每个乐句渲染两遍取第二遍，这样混响尾巴是循环的，切片首尾无缝。各乐器按类型调到统一目标电平后整首共用一个增益，软限幅防削波。

注意：要在 CC0 的作品里分发 SoundFont 渲染出的音频，MIT 许可要求随附版权与许可声明，管线已把许可证原文写进每个 Kit 的 `NOTICE.txt`。

### album（真实多轨，CC BY 4.0）

[AlbumDB](https://zenodo.org/records/19683001)（Tom McKenzie，Zenodo 19683001）。`stems_mixed.zip` 有 5 GB，管线用 HTTP Range 读 zip 中央目录，再对每个分轨只读压缩流的开头（deflate 可顺序解压到任意位置），每个文件只取前 130 秒。按文件名把几十个分轨归并为 ≤7 个乐器组，用鼓组估计恒定速度与小节起点，选所有乐器组都有声音、能量最高的 8 小节。速度不稳定（置信度 < 2 或前后半段漂移 > 0.4%）的歌曲直接丢弃。

### online（ccMixter）

`https://ccmixter.org/api/query`（无需 key；单次 `limit` 超过 15 响应会被截断，所以分页取）。只要许可证在白名单且带 `bpm_xxx_yyy` 标签的上传，形态分两种：

- **stems**：上传里有 ≥3 个等长的独立分轨 → 按文件名归并成乐器组的多组 Kit；
- **mix**：只有一条完整混音 → 估计速度与小节起点，取 8 小节窗口做成单组 Kit。

速度估计必须落在标签范围内（±2.5 BPM），否则丢弃。**Jamendo 和 Freesound 本期不做**：二者都要申请 API key（Jamendo 还有逐曲的下载开关与非商用限额，Freesound 的原文件下载要 OAuth），拿到 key 之后可以仿照 `sources/online.py` 加来源。

## 人工抽检流程

1. `python3 -m upcatalog qa --strict` 先过自动质检。
2. 打开 `out/preview/index.html`：每条有 16 小节逐层加乐器的试听、各乐器 4 小节循环（循环播放，听首尾有没有爆音或错拍）。
3. 对照检查：许可证与署名是否和来源页一致；`NC` 条目标橙色、`SA` 条目标青色；乐器分组是否合理；BPM 是否像样（大约 ±1 BPM 之内能跟着节拍拍手）。
4. 有问题的条目删掉 `out/work/<id>` 重新 `analyze`，或从目录里剔除（不要上传）。
5. `publish` 默认只写 draft；抽检通过后用 `publish --publish` 发布。

## 已知限制

- `analyze` 只估计**恒定速度**；变速或手弹的素材会因漂移被丢弃。
- 小节起点靠底鼓能量分布判断，没有底鼓的素材可能差一拍，预览里要听一下。
- 体积：一个 6 组 Kit 约 7–28 MB（FLAC，铺底类乐器压缩率低）；如果觉得太大，可以在 `layout.pad_plan` 里去掉 1 小节的 pad。
- 沙箱访问外网不稳定，下载都做了重试与断点续传；大文件在 `.cache/` 里，重复运行不会重新下载。
