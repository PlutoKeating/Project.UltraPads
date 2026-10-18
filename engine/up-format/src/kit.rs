//! Kit 的逻辑文档 [`KitDoc`]。
//!
//! `engine/up-model` 目前还没有 Kit/Pad 类型。在它就绪前，本模块作为适配层：
//! `.upkit`（SFZ + JSON + manifest）与 `KitDoc` 互转，`up-library` 和 FFI 只面对 `KitDoc`。
//! 等 `up-model` 提供 `Kit` 后，在这里补 `From<KitDoc> for up_model::Kit`（及反向）即可，
//! 字段需求见 `docs/research/kit-and-project-formats.md` 与 up-format 的 README 说明。

use serde::{Deserialize, Serialize};

/// 每组（bank）的 pad 数。
pub const PADS_PER_BANK: u8 = 12;
/// 最大 pad 数（引擎上限：`up_core::BANK_COUNT` 组 × 12，即 A–G 七组 84 个）。
pub const MAX_PADS: u8 = up_core::PAD_COUNT as u8;
/// 音色组字母（`layout.banks` 与 pad 的 `bank` 字段）。
pub const BANK_LETTERS: [&str; up_core::BANK_COUNT] = ["A", "B", "C", "D", "E", "F", "G"];
/// pad 0（A1）对应的 MIDI 音符。
pub const BASE_NOTE: u8 = 36;

/// pad 编址（与 `docs/API.md` 的 `PadId` 一致）。
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct PadAddr {
    /// 0 = A，1 = B
    pub bank: u8,
    /// 0..=11
    pub index: u8,
}

impl PadAddr {
    pub fn from_flat(flat: u8) -> Self {
        Self {
            bank: flat / PADS_PER_BANK,
            index: flat % PADS_PER_BANK,
        }
    }
    pub fn flat(self) -> u8 {
        self.bank * PADS_PER_BANK + self.index
    }
    /// 默认音符映射：`36 + flat`。
    pub fn default_note(self) -> u8 {
        BASE_NOTE + self.flat()
    }
    /// 由音符反推 pad（仅限默认映射范围 36..=59）。
    pub fn from_default_note(note: u8) -> Option<Self> {
        note.checked_sub(BASE_NOTE)
            .filter(|f| *f < MAX_PADS)
            .map(Self::from_flat)
    }
    pub fn bank_letter(self) -> &'static str {
        BANK_LETTERS
            .get(usize::from(self.bank))
            .copied()
            .unwrap_or("?")
    }
}

/// pad 的颜色：调色板角色或自定义十六进制色。
///
/// 序列化为字符串：角色名（`blue`）或 `#RRGGBB`。角色与 `design/tokens` 的 pad 调色板对应，
/// 引擎/UI 只引用角色，皮肤决定具体渐变。
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum PadColor {
    Role(ColorRole),
    Hex(String),
}

/// pad 调色板角色。前四个与参考设计的四种 pad 色一致（blue/green/orange/pink），
/// 后面的取自参考设计编辑器 8 色色板。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ColorRole {
    Blue,
    Green,
    Orange,
    Pink,
    Aqua,
    Lime,
    Red,
    Purple,
    Yellow,
    Grey,
}

impl ColorRole {
    pub const ALL: [ColorRole; 10] = [
        Self::Blue,
        Self::Green,
        Self::Orange,
        Self::Pink,
        Self::Aqua,
        Self::Lime,
        Self::Red,
        Self::Purple,
        Self::Yellow,
        Self::Grey,
    ];
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Blue => "blue",
            Self::Green => "green",
            Self::Orange => "orange",
            Self::Pink => "pink",
            Self::Aqua => "aqua",
            Self::Lime => "lime",
            Self::Red => "red",
            Self::Purple => "purple",
            Self::Yellow => "yellow",
            Self::Grey => "grey",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|r| r.as_str() == s)
    }
    /// 用于 DAWproject 等需要具体颜色的导出（取 NORMAL 皮肤渐变中间色）。
    pub fn reference_hex(self) -> &'static str {
        match self {
            Self::Blue => "#2AD5FA",
            Self::Green => "#0DD600",
            Self::Orange => "#F49600",
            Self::Pink => "#FA4F84",
            Self::Aqua => "#50E3C2",
            Self::Lime => "#BBD809",
            Self::Red => "#D0021B",
            Self::Purple => "#9013FE",
            Self::Yellow => "#FFEC00",
            Self::Grey => "#939BA3",
        }
    }
}

impl Default for PadColor {
    fn default() -> Self {
        Self::Role(ColorRole::Orange)
    }
}

impl PadColor {
    pub fn parse(s: &str) -> Self {
        let s = s.trim();
        if let Some(role) = ColorRole::parse(&s.to_ascii_lowercase()) {
            return Self::Role(role);
        }
        if s.starts_with('#')
            && (s.len() == 7 || s.len() == 9)
            && s[1..].chars().all(|c| c.is_ascii_hexdigit())
        {
            return Self::Hex(s.to_ascii_uppercase());
        }
        Self::default()
    }
    pub fn as_string(&self) -> String {
        match self {
            Self::Role(r) => r.as_str().to_string(),
            Self::Hex(h) => h.clone(),
        }
    }
    pub fn to_hex(&self) -> String {
        match self {
            Self::Role(r) => r.reference_hex().to_string(),
            Self::Hex(h) => h[..7].to_string(),
        }
    }
}

impl Serialize for PadColor {
    fn serialize<S: serde::Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&self.as_string())
    }
}

impl<'de> Deserialize<'de> for PadColor {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        let s = String::deserialize(d)?;
        Ok(Self::parse(&s))
    }
}

/// 声音类型。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PadKind {
    #[default]
    OneShot,
    Loop,
}

/// 启动模式（对应 API 的 `PadMode` 加上 toggle）。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LaunchMode {
    /// 按下从头播一次，松手不停（one-shot）。
    #[default]
    Trigger,
    /// 按住播放，松手停止。
    Gate,
    /// 按一下开，再按一下关（loop）。
    Toggle,
}

/// 量化启动（与项目 Clip Launcher 全局量化共用）。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Quantize {
    #[default]
    #[serde(rename = "none")]
    None,
    #[serde(rename = "1/16")]
    Sixteenth,
    #[serde(rename = "1/8")]
    Eighth,
    #[serde(rename = "1/4")]
    Quarter,
    #[serde(rename = "1beat")]
    Beat,
    #[serde(rename = "1bar")]
    Bar,
    #[serde(rename = "2bar")]
    TwoBars,
    #[serde(rename = "4bar")]
    FourBars,
    #[serde(rename = "global")]
    Global,
}

impl Quantize {
    /// 以拍为单位的长度（拍号分子为 `beats_per_bar`）；`None`/`Global` 返回 `None`。
    pub fn beats(self, beats_per_bar: u8) -> Option<f64> {
        let bar = f64::from(beats_per_bar.max(1));
        match self {
            Self::None | Self::Global => None,
            Self::Sixteenth => Some(0.25),
            Self::Eighth => Some(0.5),
            Self::Quarter | Self::Beat => Some(1.0),
            Self::Bar => Some(bar),
            Self::TwoBars => Some(2.0 * bar),
            Self::FourBars => Some(4.0 * bar),
        }
    }
    /// 从 SFZ `sync_beats` 反推。
    pub fn from_beats(beats: f64, beats_per_bar: u8) -> Self {
        let bar = f64::from(beats_per_bar.max(1));
        let eq = |a: f64, b: f64| (a - b).abs() < 1e-6;
        if beats <= 0.0 {
            Self::None
        } else if eq(beats, 0.25) {
            Self::Sixteenth
        } else if eq(beats, 0.5) {
            Self::Eighth
        } else if eq(beats, 1.0) {
            Self::Beat
        } else if eq(beats, bar) {
            Self::Bar
        } else if eq(beats, 2.0 * bar) {
            Self::TwoBars
        } else if eq(beats, 4.0 * bar) {
            Self::FourBars
        } else {
            Self::Bar
        }
    }
}

/// 重触发行为。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Retrigger {
    #[default]
    Restart,
    Continue,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Launch {
    #[serde(default)]
    pub mode: LaunchMode,
    #[serde(default)]
    pub quantize: Quantize,
    #[serde(default)]
    pub retrigger: Retrigger,
}

/// 时间拉伸策略。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Stretch {
    #[default]
    None,
    Beats,
    Repitch,
}

/// loop 的速度信息。
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoopTempo {
    pub bpm: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub beats: Option<f64>,
    #[serde(default = "default_ts")]
    pub time_signature: [u8; 2],
    #[serde(default)]
    pub stretch: Stretch,
}

fn default_ts() -> [u8; 2] {
    [4, 4]
}

/// 一个采样层（对应 SFZ 的一个 `<region>`）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SampleLayer {
    /// 包内路径，如 `samples/kick.wav`。
    pub sample: String,
    /// 内容哈希（BLAKE3）。曲库内的 Kit 总是有；新分配的采样（麦克风录音）只需填它，
    /// 保存时由曲库分配包内路径。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub sample_id: Option<String>,
    #[serde(default)]
    pub lovel: u8,
    #[serde(default = "max_vel")]
    pub hivel: u8,
    /// 轮替序号（1 起），配合 [`PadDoc::seq_length`]。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub seq_position: Option<u32>,
    /// 随机选择区间 `[lorand, hirand)`。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rand_range: Option<[f32; 2]>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub root_key: Option<u8>,
    /// 起始帧（SFZ `offset`）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub start_frame: Option<u64>,
    /// 结束帧（SFZ `end`，包含）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub end_frame: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub loop_start: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub loop_end: Option<u64>,
    #[serde(default, skip_serializing_if = "is_zero_i32")]
    pub tune_cents: i32,
    #[serde(default, skip_serializing_if = "is_zero_i32")]
    pub transpose: i32,
    #[serde(default, skip_serializing_if = "is_zero_f32")]
    pub volume_db: f32,
}

fn max_vel() -> u8 {
    127
}
fn is_zero_i32(v: &i32) -> bool {
    *v == 0
}
fn is_zero_f32(v: &f32) -> bool {
    *v == 0.0
}

impl SampleLayer {
    pub fn new(sample: impl Into<String>) -> Self {
        Self {
            sample: sample.into(),
            sample_id: None,
            lovel: 0,
            hivel: 127,
            seq_position: None,
            rand_range: None,
            root_key: None,
            start_frame: None,
            end_frame: None,
            loop_start: None,
            loop_end: None,
            tune_cents: 0,
            transpose: 0,
            volume_db: 0.0,
        }
    }
}

/// choke 停止方式。
#[derive(Debug, Clone, Copy, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ChokeMode {
    /// 快速淡出（SFZ `off_mode=fast`）。
    #[default]
    Fast,
    /// 进入 release（`off_mode=normal`）。
    Normal,
    /// 指定时长淡出（`off_mode=time` + `off_time`）。
    Time(f32),
}

/// 一个 pad。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PadDoc {
    pub addr: PadAddr,
    /// 该 pad 在 SFZ 中的 MIDI 音符（默认 `36 + flat`）。
    pub note: u8,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default)]
    pub color: PadColor,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    #[serde(default)]
    pub kind: PadKind,
    #[serde(default)]
    pub launch: Launch,
    /// pad 级增益（dB，SFZ `<group> volume`）。
    #[serde(default)]
    pub gain_db: f32,
    /// -1..=1（SFZ `pan` / 100）。
    #[serde(default)]
    pub pan: f32,
    /// SFZ `group`：该 pad 所属的 choke 组。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub choke_group: Option<u32>,
    /// SFZ `off_by`：被哪个组截断。互斥组 = `choke_group == choked_by`。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub choked_by: Option<u32>,
    #[serde(default)]
    pub choke_mode: ChokeMode,
    /// 同 pad 重触发时截断自身（SFZ `note_polyphony=1` / `note_selfmask`）。
    #[serde(default)]
    pub self_choke: bool,
    /// JSON `exclusive`：同名的 loop 互斥（Clip Launcher 语义）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exclusive: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tempo: Option<LoopTempo>,
    /// 轮替长度（SFZ `seq_length`）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub seq_length: Option<u32>,
    #[serde(default)]
    pub layers: Vec<SampleLayer>,
    /// 其它 UltraPads 扩展参数（如编辑器的 `timeRatio`、`fadeInMs`），原样存进 `ultrapads-kit.json` 的 pad 条目。
    #[serde(default, skip_serializing_if = "serde_json::Map::is_empty")]
    pub extra: serde_json::Map<String, serde_json::Value>,
}

impl PadDoc {
    pub fn new(addr: PadAddr) -> Self {
        Self {
            addr,
            note: addr.default_note(),
            name: None,
            color: PadColor::default(),
            icon: None,
            kind: PadKind::OneShot,
            launch: Launch::default(),
            gain_db: 0.0,
            pan: 0.0,
            choke_group: None,
            choked_by: None,
            choke_mode: ChokeMode::Fast,
            self_choke: false,
            exclusive: None,
            tempo: None,
            seq_length: None,
            layers: Vec::new(),
            extra: serde_json::Map::new(),
        }
    }
}

/// Kit 级速度（整套 Kit 的参考 BPM）。
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KitTempo {
    pub bpm: f64,
    #[serde(default = "default_ts")]
    pub time_signature: [u8; 2],
}

/// 教程引用。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TutorialRef {
    pub id: String,
    /// 包内 `tutorial.json` 路径。
    pub path: String,
}

/// 来源信息（导入器写入，便于追溯与去重）。
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KitSource {
    /// `upkit` | `sfz` | `wav-folder` | `compat-android` | `compat-ios` | `generated` | `user`
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub original_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub original_name: Option<String>,
    /// 灵感来源（私有素材包的 authorName / musicName）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub inspired_by: Option<String>,
}

/// Kit 文档。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KitDoc {
    /// 资源 ID（UUIDv7 字符串或 `urn:uuid:…`）。
    pub id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(default)]
    pub authors: Vec<String>,
    /// 内容许可证（SPDX）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub license: Option<String>,
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tempo: Option<KitTempo>,
    /// 12 或 24。
    pub pad_count: u8,
    pub pads: Vec<PadDoc>,
    #[serde(default)]
    pub tutorials: Vec<TutorialRef>,
    /// 包内封面路径。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cover: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub skin: Option<String>,
    /// Kit 主题色（列表/预览配色）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub theme_color: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source: Option<KitSource>,
}

impl KitDoc {
    pub fn new(id: impl Into<String>, name: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            description: None,
            authors: Vec::new(),
            license: None,
            genres: Vec::new(),
            tags: Vec::new(),
            tempo: None,
            pad_count: PADS_PER_BANK,
            pads: Vec::new(),
            tutorials: Vec::new(),
            cover: None,
            skin: None,
            theme_color: None,
            source: None,
        }
    }

    pub fn pad(&self, addr: PadAddr) -> Option<&PadDoc> {
        self.pads.iter().find(|p| p.addr == addr)
    }

    pub fn pad_by_note(&self, note: u8) -> Option<&PadDoc> {
        self.pads.iter().find(|p| p.note == note)
    }

    /// 每小节拍数（默认 4）。
    pub fn beats_per_bar(&self) -> u8 {
        self.tempo.map(|t| t.time_signature[0]).unwrap_or(4)
    }

    /// 结构校验：pad 地址/音符唯一、在范围内，pad_count 合法。
    pub fn validate(&self) -> crate::Result<()> {
        use crate::FormatError::InvalidKit;
        if self.name.trim().is_empty() {
            return Err(InvalidKit("Kit 名称为空".into()));
        }
        if self.pad_count == 0 || self.pad_count % PADS_PER_BANK != 0 || self.pad_count > MAX_PADS {
            return Err(InvalidKit(format!(
                "padCount 必须是 12 的倍数（12–{MAX_PADS}），得到 {}",
                self.pad_count
            )));
        }
        let mut seen_addr = std::collections::BTreeSet::new();
        let mut seen_note = std::collections::BTreeSet::new();
        for p in &self.pads {
            if p.addr.index >= PADS_PER_BANK || p.addr.flat() >= self.pad_count {
                return Err(InvalidKit(format!(
                    "pad {}{} 超出 padCount {}",
                    p.addr.bank_letter(),
                    p.addr.index + 1,
                    self.pad_count
                )));
            }
            if p.note > 127 {
                return Err(InvalidKit(format!("pad 音符 {} 越界", p.note)));
            }
            if !seen_addr.insert(p.addr) {
                return Err(InvalidKit(format!(
                    "pad {}{} 重复",
                    p.addr.bank_letter(),
                    p.addr.index + 1
                )));
            }
            if !seen_note.insert(p.note) {
                return Err(InvalidKit(format!("音符 {} 被多个 pad 使用", p.note)));
            }
            for l in &p.layers {
                crate::path::normalize(&l.sample)?;
                if l.lovel > l.hivel {
                    return Err(InvalidKit(format!("{}: lovel > hivel", l.sample)));
                }
            }
        }
        Ok(())
    }

    /// 所有被引用的包内采样路径（去重、排序）。
    pub fn sample_paths(&self) -> Vec<String> {
        let mut v: Vec<String> = self
            .pads
            .iter()
            .flat_map(|p| p.layers.iter().map(|l| l.sample.clone()))
            .collect();
        v.sort();
        v.dedup();
        v
    }

    /// 按 (bank, index) 排序 pad。
    pub fn sort_pads(&mut self) {
        self.pads.sort_by_key(|p| p.addr);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn addressing() {
        let a = PadAddr::from_flat(13);
        assert_eq!(a, PadAddr { bank: 1, index: 1 });
        assert_eq!(a.default_note(), 49);
        assert_eq!(PadAddr::from_default_note(36), Some(PadAddr::from_flat(0)));
        assert_eq!(
            PadAddr::from_default_note(60),
            Some(PadAddr { bank: 2, index: 0 })
        );
        assert_eq!(
            PadAddr::from_default_note(119),
            Some(PadAddr { bank: 6, index: 11 })
        );
        assert_eq!(PadAddr::from_default_note(120), None);
    }

    #[test]
    fn colors() {
        assert_eq!(PadColor::parse("Blue"), PadColor::Role(ColorRole::Blue));
        assert_eq!(PadColor::parse("#ff5a36"), PadColor::Hex("#FF5A36".into()));
        let json = serde_json::to_string(&PadColor::Role(ColorRole::Pink)).unwrap();
        assert_eq!(json, "\"pink\"");
    }

    #[test]
    fn quantize_beats() {
        assert_eq!(Quantize::Bar.beats(4), Some(4.0));
        assert_eq!(Quantize::from_beats(8.0, 4), Quantize::TwoBars);
        assert_eq!(Quantize::from_beats(3.0, 3), Quantize::Bar);
        assert_eq!(
            serde_json::to_string(&Quantize::Sixteenth).unwrap(),
            "\"1/16\""
        );
    }

    #[test]
    fn validation() {
        let mut k = KitDoc::new("x", "Kit");
        k.pads.push(PadDoc::new(PadAddr::from_flat(0)));
        assert!(k.validate().is_ok());
        k.pads.push(PadDoc::new(PadAddr::from_flat(12)));
        assert!(k.validate().is_err());
        k.pad_count = 24;
        assert!(k.validate().is_ok());
        let mut dup = PadDoc::new(PadAddr::from_flat(1));
        dup.note = 36;
        k.pads.push(dup);
        assert!(k.validate().is_err());
    }
}
