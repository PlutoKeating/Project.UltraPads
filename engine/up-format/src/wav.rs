//! WAV/RIFF：格式信息、元数据 chunk（`smpl`/`acid`/`inst`/`cue `+`LIST/adtl`/`bext`）读写、PCM 编解码。
//!
//! 字段布局：`smpl`/`inst`/`cue ` 依据 Microsoft/IBM RIFF 规范；`acid` 以 libsndfile 的实现为准；
//! `bext` 依据 EBU Tech 3285（v2）。只处理小端 `RIFF`/`WAVE`。

use crate::{FormatError, Result};

fn err(msg: impl Into<String>) -> FormatError {
    FormatError::Wav(msg.into())
}

fn u16_at(b: &[u8], o: usize) -> u16 {
    u16::from_le_bytes([b[o], b[o + 1]])
}
fn u32_at(b: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([b[o], b[o + 1], b[o + 2], b[o + 3]])
}
fn f32_at(b: &[u8], o: usize) -> f32 {
    f32::from_le_bytes([b[o], b[o + 1], b[o + 2], b[o + 3]])
}

/// RIFF 子 chunk 的位置。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChunkRef {
    pub id: [u8; 4],
    /// chunk 数据（不含 8 字节头）的起始偏移。
    pub offset: usize,
    pub len: usize,
}

impl ChunkRef {
    pub fn id_str(&self) -> String {
        String::from_utf8_lossy(&self.id).into_owned()
    }
    pub fn data<'a>(&self, bytes: &'a [u8]) -> &'a [u8] {
        &bytes[self.offset..self.offset + self.len]
    }
}

/// 列出 WAVE 文件中的所有顶层 chunk。截断的最后一个 chunk 会被裁到文件末尾。
pub fn chunks(bytes: &[u8]) -> Result<Vec<ChunkRef>> {
    if bytes.len() < 12 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return Err(err("不是 RIFF/WAVE 文件"));
    }
    let mut out = Vec::new();
    let mut pos = 12usize;
    while pos + 8 <= bytes.len() {
        let id = [bytes[pos], bytes[pos + 1], bytes[pos + 2], bytes[pos + 3]];
        let declared = u32_at(bytes, pos + 4) as usize;
        let offset = pos + 8;
        let len = declared.min(bytes.len() - offset);
        out.push(ChunkRef { id, offset, len });
        if out.len() > 4096 {
            return Err(err("chunk 数量过多"));
        }
        pos = offset.saturating_add(declared).saturating_add(declared & 1);
    }
    Ok(out)
}

/// 采样格式。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SampleFormat {
    Int,
    Float,
}

/// `fmt ` + `data` 信息。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WavInfo {
    pub format: SampleFormat,
    pub channels: u16,
    pub sample_rate: u32,
    pub bits_per_sample: u16,
    pub block_align: u16,
    pub data_offset: usize,
    pub data_len: usize,
    pub frames: u64,
}

impl WavInfo {
    pub fn duration_secs(&self) -> f64 {
        if self.sample_rate == 0 {
            0.0
        } else {
            self.frames as f64 / f64::from(self.sample_rate)
        }
    }
}

/// 解析 `fmt ` 和 `data`。
pub fn info(bytes: &[u8]) -> Result<WavInfo> {
    let list = chunks(bytes)?;
    let fmt = list
        .iter()
        .find(|c| &c.id == b"fmt ")
        .ok_or_else(|| err("缺少 fmt chunk"))?;
    let data = list
        .iter()
        .find(|c| &c.id == b"data")
        .ok_or_else(|| err("缺少 data chunk"))?;
    let f = fmt.data(bytes);
    if f.len() < 16 {
        return Err(err("fmt chunk 过短"));
    }
    let mut tag = u16_at(f, 0);
    if tag == 0xFFFE && f.len() >= 40 {
        tag = u16_at(f, 24);
    }
    let format = match tag {
        1 => SampleFormat::Int,
        3 => SampleFormat::Float,
        other => {
            return Err(err(format!(
                "不支持的编码 0x{other:04X}（只支持 PCM/IEEE float）"
            )));
        }
    };
    let channels = u16_at(f, 2);
    let sample_rate = u32_at(f, 4);
    let block_align = u16_at(f, 12);
    let bits = u16_at(f, 14);
    if channels == 0 || sample_rate == 0 || block_align == 0 {
        return Err(err("fmt 字段为 0"));
    }
    let valid_bits = matches!(
        (format, bits),
        (SampleFormat::Int, 8 | 16 | 24 | 32) | (SampleFormat::Float, 32 | 64)
    );
    if !valid_bits {
        return Err(err(format!("不支持的位深 {bits}")));
    }
    if usize::from(block_align) != usize::from(channels) * usize::from(bits / 8) {
        return Err(err("block_align 与声道/位深不一致"));
    }
    Ok(WavInfo {
        format,
        channels,
        sample_rate,
        bits_per_sample: bits,
        block_align,
        data_offset: data.offset,
        data_len: data.len,
        frames: (data.len / usize::from(block_align)) as u64,
    })
}

/// 解码后的交错 PCM（f32，-1..1）。
#[derive(Debug, Clone, PartialEq)]
pub struct DecodedPcm {
    pub channels: u16,
    pub sample_rate: u32,
    pub samples: Vec<f32>,
}

impl DecodedPcm {
    pub fn frames(&self) -> usize {
        if self.channels == 0 {
            0
        } else {
            self.samples.len() / usize::from(self.channels)
        }
    }
}

/// 把 WAV 解码为交错 f32。
pub fn decode(bytes: &[u8]) -> Result<DecodedPcm> {
    let i = info(bytes)?;
    let data = &bytes[i.data_offset..i.data_offset + i.data_len];
    let n = (i.frames as usize) * usize::from(i.channels);
    let mut samples = Vec::with_capacity(n);
    let width = usize::from(i.bits_per_sample / 8);
    for k in 0..n {
        let o = k * width;
        let s = match (i.format, i.bits_per_sample) {
            (SampleFormat::Int, 8) => (f32::from(data[o]) - 128.0) / 128.0,
            (SampleFormat::Int, 16) => {
                f32::from(i16::from_le_bytes([data[o], data[o + 1]])) / 32768.0
            }
            (SampleFormat::Int, 24) => {
                let v = i32::from_le_bytes([0, data[o], data[o + 1], data[o + 2]]) >> 8;
                v as f32 / 8_388_608.0
            }
            (SampleFormat::Int, 32) => {
                i32::from_le_bytes([data[o], data[o + 1], data[o + 2], data[o + 3]]) as f32
                    / 2_147_483_648.0
            }
            (SampleFormat::Float, 32) => f32_at(data, o),
            (SampleFormat::Float, 64) => f64::from_le_bytes([
                data[o],
                data[o + 1],
                data[o + 2],
                data[o + 3],
                data[o + 4],
                data[o + 5],
                data[o + 6],
                data[o + 7],
            ]) as f32,
            _ => unreachable!("info() 已校验位深"),
        };
        samples.push(s);
    }
    Ok(DecodedPcm {
        channels: i.channels,
        sample_rate: i.sample_rate,
        samples,
    })
}

/// 把交错 f32 编码为 16-bit PCM WAV（带 TPDF 以外的简单舍入，供生成器/录音使用）。
pub fn encode_pcm16(channels: u16, sample_rate: u32, samples: &[f32]) -> Vec<u8> {
    let data_len = samples.len() * 2;
    let mut out = Vec::with_capacity(44 + data_len);
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&((36 + data_len) as u32).to_le_bytes());
    out.extend_from_slice(b"WAVE");
    out.extend_from_slice(b"fmt ");
    out.extend_from_slice(&16u32.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&channels.to_le_bytes());
    out.extend_from_slice(&sample_rate.to_le_bytes());
    out.extend_from_slice(&(sample_rate * u32::from(channels) * 2).to_le_bytes());
    out.extend_from_slice(&(channels * 2).to_le_bytes());
    out.extend_from_slice(&16u16.to_le_bytes());
    out.extend_from_slice(b"data");
    out.extend_from_slice(&(data_len as u32).to_le_bytes());
    for s in samples {
        let v = (s.clamp(-1.0, 1.0) * 32767.0).round() as i16;
        out.extend_from_slice(&v.to_le_bytes());
    }
    out
}

/// `smpl` 中的 loop 类型。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LoopType {
    Forward,
    PingPong,
    Backward,
    Other(u32),
}

impl LoopType {
    fn from_u32(v: u32) -> Self {
        match v {
            0 => Self::Forward,
            1 => Self::PingPong,
            2 => Self::Backward,
            o => Self::Other(o),
        }
    }
    fn to_u32(self) -> u32 {
        match self {
            Self::Forward => 0,
            Self::PingPong => 1,
            Self::Backward => 2,
            Self::Other(o) => o,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SampleLoop {
    pub cue_id: u32,
    pub kind: LoopType,
    /// 起始帧（包含）。
    pub start: u32,
    /// 结束帧（包含）。
    pub end: u32,
    pub fraction: u32,
    /// 0 = 无限。
    pub play_count: u32,
}

/// `smpl` chunk。
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct SmplChunk {
    pub manufacturer: u32,
    pub product: u32,
    /// 采样周期（纳秒）。
    pub sample_period: u32,
    pub midi_unity_note: u32,
    pub midi_pitch_fraction: u32,
    pub smpte_format: u32,
    pub smpte_offset: u32,
    pub loops: Vec<SampleLoop>,
    pub sampler_data: Vec<u8>,
}

impl SmplChunk {
    pub fn parse(d: &[u8]) -> Result<Self> {
        if d.len() < 36 {
            return Err(err("smpl chunk 过短"));
        }
        let n = u32_at(d, 28) as usize;
        let sd_len = u32_at(d, 32) as usize;
        let mut loops = Vec::new();
        for k in 0..n {
            let o = 36 + k * 24;
            if o + 24 > d.len() {
                break;
            }
            loops.push(SampleLoop {
                cue_id: u32_at(d, o),
                kind: LoopType::from_u32(u32_at(d, o + 4)),
                start: u32_at(d, o + 8),
                end: u32_at(d, o + 12),
                fraction: u32_at(d, o + 16),
                play_count: u32_at(d, o + 20),
            });
        }
        let sd_off = 36 + loops.len() * 24;
        let sampler_data = d
            .get(sd_off..(sd_off + sd_len).min(d.len()))
            .unwrap_or_default()
            .to_vec();
        Ok(Self {
            manufacturer: u32_at(d, 0),
            product: u32_at(d, 4),
            sample_period: u32_at(d, 8),
            midi_unity_note: u32_at(d, 12),
            midi_pitch_fraction: u32_at(d, 16),
            smpte_format: u32_at(d, 20),
            smpte_offset: u32_at(d, 24),
            loops,
            sampler_data,
        })
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        let mut o = Vec::with_capacity(36 + self.loops.len() * 24 + self.sampler_data.len());
        for v in [
            self.manufacturer,
            self.product,
            self.sample_period,
            self.midi_unity_note,
            self.midi_pitch_fraction,
            self.smpte_format,
            self.smpte_offset,
            self.loops.len() as u32,
            self.sampler_data.len() as u32,
        ] {
            o.extend_from_slice(&v.to_le_bytes());
        }
        for l in &self.loops {
            for v in [
                l.cue_id,
                l.kind.to_u32(),
                l.start,
                l.end,
                l.fraction,
                l.play_count,
            ] {
                o.extend_from_slice(&v.to_le_bytes());
            }
        }
        o.extend_from_slice(&self.sampler_data);
        o
    }

    /// 由采样率构造带根音的 smpl。
    pub fn new(sample_rate: u32, unity_note: u8) -> Self {
        Self {
            sample_period: if sample_rate == 0 {
                0
            } else {
                (1_000_000_000u64 / u64::from(sample_rate)) as u32
            },
            midi_unity_note: u32::from(unity_note),
            ..Self::default()
        }
    }
}

/// ACID chunk flags。
pub mod acid_flags {
    pub const ONE_SHOT: u32 = 0x01;
    pub const ROOT_NOTE_SET: u32 = 0x02;
    pub const STRETCH: u32 = 0x04;
    pub const DISK_BASED: u32 = 0x08;
    pub const HIGH_OCTAVE: u32 = 0x10;
}

/// `acid` chunk（24 字节）。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AcidChunk {
    pub flags: u32,
    pub root_note: u16,
    pub unknown1: u16,
    pub unknown2: f32,
    pub beats: u32,
    pub meter_denominator: u16,
    pub meter_numerator: u16,
    pub tempo: f32,
}

impl AcidChunk {
    pub fn parse(d: &[u8]) -> Result<Self> {
        if d.len() < 24 {
            return Err(err("acid chunk 过短"));
        }
        Ok(Self {
            flags: u32_at(d, 0),
            root_note: u16_at(d, 4),
            unknown1: u16_at(d, 6),
            unknown2: f32_at(d, 8),
            beats: u32_at(d, 12),
            meter_denominator: u16_at(d, 16),
            meter_numerator: u16_at(d, 18),
            tempo: f32_at(d, 20),
        })
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        let mut o = Vec::with_capacity(24);
        o.extend_from_slice(&self.flags.to_le_bytes());
        o.extend_from_slice(&self.root_note.to_le_bytes());
        o.extend_from_slice(&self.unknown1.to_le_bytes());
        o.extend_from_slice(&self.unknown2.to_le_bytes());
        o.extend_from_slice(&self.beats.to_le_bytes());
        o.extend_from_slice(&self.meter_denominator.to_le_bytes());
        o.extend_from_slice(&self.meter_numerator.to_le_bytes());
        o.extend_from_slice(&self.tempo.to_le_bytes());
        o
    }

    /// loop：可拉伸、带根音。
    pub fn looped(tempo: f32, beats: u32, root_note: u8, ts: [u8; 2]) -> Self {
        Self {
            flags: acid_flags::STRETCH | acid_flags::ROOT_NOTE_SET,
            root_note: u16::from(root_note),
            unknown1: 0x8000,
            unknown2: 0.0,
            beats,
            meter_denominator: u16::from(ts[1]),
            meter_numerator: u16::from(ts[0]),
            tempo,
        }
    }

    pub fn is_one_shot(&self) -> bool {
        self.flags & acid_flags::ONE_SHOT != 0
    }
}

/// `inst` chunk（7 字节）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct InstChunk {
    pub unshifted_note: u8,
    pub fine_tune: i8,
    pub gain: i8,
    pub low_note: u8,
    pub high_note: u8,
    pub low_velocity: u8,
    pub high_velocity: u8,
}

impl InstChunk {
    pub fn parse(d: &[u8]) -> Result<Self> {
        if d.len() < 7 {
            return Err(err("inst chunk 过短"));
        }
        Ok(Self {
            unshifted_note: d[0],
            fine_tune: d[1] as i8,
            gain: d[2] as i8,
            low_note: d[3],
            high_note: d[4],
            low_velocity: d[5],
            high_velocity: d[6],
        })
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        vec![
            self.unshifted_note,
            self.fine_tune as u8,
            self.gain as u8,
            self.low_note,
            self.high_note,
            self.low_velocity,
            self.high_velocity,
        ]
    }
}

/// 一个 cue 点（`cue ` + 可选的 `LIST/adtl/labl` 标签）。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CuePoint {
    pub id: u32,
    /// 帧位置（取 `sample_offset`）。
    pub position: u32,
    pub label: Option<String>,
}

/// BWF `bext` chunk（EBU Tech 3285 v2）。
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct BextChunk {
    pub description: String,
    pub originator: String,
    pub originator_reference: String,
    /// `yyyy-mm-dd`
    pub origination_date: String,
    /// `hh:mm:ss`
    pub origination_time: String,
    pub time_reference: u64,
    pub version: u16,
    pub umid: Vec<u8>,
    pub loudness_value: i16,
    pub loudness_range: i16,
    pub max_true_peak_level: i16,
    pub max_momentary_loudness: i16,
    pub max_short_term_loudness: i16,
    pub coding_history: String,
}

fn fixed_str(d: &[u8]) -> String {
    let end = d.iter().position(|b| *b == 0).unwrap_or(d.len());
    String::from_utf8_lossy(&d[..end]).trim_end().to_string()
}

fn put_fixed(o: &mut Vec<u8>, s: &str, n: usize) {
    let b = s.as_bytes();
    let take = b.len().min(n);
    o.extend_from_slice(&b[..take]);
    o.extend(std::iter::repeat_n(0u8, n - take));
}

impl BextChunk {
    pub const FIXED_LEN: usize = 602;

    pub fn parse(d: &[u8]) -> Result<Self> {
        if d.len() < 348 {
            return Err(err("bext chunk 过短"));
        }
        let i16_at = |o: usize| -> i16 {
            if o + 2 <= d.len() {
                i16::from_le_bytes([d[o], d[o + 1]])
            } else {
                0
            }
        };
        Ok(Self {
            description: fixed_str(&d[0..256]),
            originator: fixed_str(&d[256..288]),
            originator_reference: fixed_str(&d[288..320]),
            origination_date: fixed_str(&d[320..330]),
            origination_time: fixed_str(&d[330..338]),
            time_reference: u64::from(u32_at(d, 338)) | (u64::from(u32_at(d, 342)) << 32),
            version: u16_at(d, 346),
            umid: d
                .get(348..412)
                .filter(|u| u.iter().any(|b| *b != 0))
                .map(<[u8]>::to_vec)
                .unwrap_or_default(),
            loudness_value: i16_at(412),
            loudness_range: i16_at(414),
            max_true_peak_level: i16_at(416),
            max_momentary_loudness: i16_at(418),
            max_short_term_loudness: i16_at(420),
            coding_history: d.get(Self::FIXED_LEN..).map(fixed_str).unwrap_or_default(),
        })
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        let mut o = Vec::with_capacity(Self::FIXED_LEN + self.coding_history.len());
        put_fixed(&mut o, &self.description, 256);
        put_fixed(&mut o, &self.originator, 32);
        put_fixed(&mut o, &self.originator_reference, 32);
        put_fixed(&mut o, &self.origination_date, 10);
        put_fixed(&mut o, &self.origination_time, 8);
        o.extend_from_slice(&(self.time_reference as u32).to_le_bytes());
        o.extend_from_slice(&((self.time_reference >> 32) as u32).to_le_bytes());
        o.extend_from_slice(&self.version.to_le_bytes());
        let mut umid = self.umid.clone();
        umid.resize(64, 0);
        o.extend_from_slice(&umid);
        for v in [
            self.loudness_value,
            self.loudness_range,
            self.max_true_peak_level,
            self.max_momentary_loudness,
            self.max_short_term_loudness,
        ] {
            o.extend_from_slice(&v.to_le_bytes());
        }
        o.extend(std::iter::repeat_n(0u8, 180));
        o.extend_from_slice(self.coding_history.as_bytes());
        o
    }
}

/// 一个 WAV 中 UltraPads 关心的全部元数据。
#[derive(Debug, Clone, PartialEq, Default)]
pub struct WavMetadata {
    pub smpl: Option<SmplChunk>,
    pub acid: Option<AcidChunk>,
    pub inst: Option<InstChunk>,
    pub cues: Vec<CuePoint>,
    pub bext: Option<BextChunk>,
}

fn parse_cues(d: &[u8]) -> Vec<CuePoint> {
    if d.len() < 4 {
        return Vec::new();
    }
    let n = u32_at(d, 0) as usize;
    let mut out = Vec::new();
    for k in 0..n {
        let o = 4 + k * 24;
        if o + 24 > d.len() {
            break;
        }
        out.push(CuePoint {
            id: u32_at(d, o),
            position: u32_at(d, o + 20),
            label: None,
        });
    }
    out
}

fn parse_adtl_labels(d: &[u8]) -> Vec<(u32, String)> {
    let mut out = Vec::new();
    if d.len() < 4 || &d[0..4] != b"adtl" {
        return out;
    }
    let mut pos = 4;
    while pos + 8 <= d.len() {
        let id = &d[pos..pos + 4];
        let len = u32_at(d, pos + 4) as usize;
        let start = pos + 8;
        let end = (start + len).min(d.len());
        if id == b"labl" && end >= start + 4 {
            out.push((u32_at(d, start), fixed_str(&d[start + 4..end])));
        }
        pos = start + len + (len & 1);
    }
    out
}

/// 读取元数据 chunk。损坏的 chunk 被忽略（尽力而为）。
pub fn read_metadata(bytes: &[u8]) -> Result<WavMetadata> {
    let list = chunks(bytes)?;
    let mut m = WavMetadata::default();
    let mut labels = Vec::new();
    for c in &list {
        let d = c.data(bytes);
        match &c.id {
            b"smpl" => m.smpl = SmplChunk::parse(d).ok(),
            b"acid" => m.acid = AcidChunk::parse(d).ok(),
            b"inst" => m.inst = InstChunk::parse(d).ok(),
            b"bext" => m.bext = BextChunk::parse(d).ok(),
            b"cue " => m.cues = parse_cues(d),
            b"LIST" => labels.extend(parse_adtl_labels(d)),
            _ => {}
        }
    }
    for (id, label) in labels {
        if let Some(c) = m.cues.iter_mut().find(|c| c.id == id) {
            c.label = Some(label);
        }
    }
    Ok(m)
}

fn push_chunk(out: &mut Vec<u8>, id: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(id);
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
    if data.len() & 1 == 1 {
        out.push(0);
    }
}

/// 用 `meta` 重写元数据 chunk：移除旧的 `smpl`/`acid`/`inst`/`cue `/`bext`/`LIST-adtl`，
/// 其余 chunk（`fmt `、`data`、`LIST-INFO` 等）原样保留；`bext` 写在 `fmt ` 之前，其余写在 `data` 之后。
pub fn write_metadata(bytes: &[u8], meta: &WavMetadata) -> Result<Vec<u8>> {
    let list = chunks(bytes)?;
    info(bytes)?;
    let mut body = Vec::with_capacity(bytes.len() + 1024);
    body.extend_from_slice(b"WAVE");
    if let Some(b) = &meta.bext {
        push_chunk(&mut body, b"bext", &b.to_bytes());
    }
    for c in &list {
        let d = c.data(bytes);
        let drop = match &c.id {
            b"smpl" | b"acid" | b"inst" | b"cue " | b"bext" => true,
            b"LIST" => d.len() >= 4 && &d[0..4] == b"adtl",
            _ => false,
        };
        if !drop {
            push_chunk(&mut body, &c.id, d);
        }
    }
    if let Some(s) = &meta.smpl {
        push_chunk(&mut body, b"smpl", &s.to_bytes());
    }
    if let Some(a) = &meta.acid {
        push_chunk(&mut body, b"acid", &a.to_bytes());
    }
    if let Some(i) = &meta.inst {
        push_chunk(&mut body, b"inst", &i.to_bytes());
    }
    if !meta.cues.is_empty() {
        let mut cue = Vec::new();
        cue.extend_from_slice(&(meta.cues.len() as u32).to_le_bytes());
        for c in &meta.cues {
            cue.extend_from_slice(&c.id.to_le_bytes());
            cue.extend_from_slice(&c.position.to_le_bytes());
            cue.extend_from_slice(b"data");
            cue.extend_from_slice(&0u32.to_le_bytes());
            cue.extend_from_slice(&0u32.to_le_bytes());
            cue.extend_from_slice(&c.position.to_le_bytes());
        }
        push_chunk(&mut body, b"cue ", &cue);
        if meta.cues.iter().any(|c| c.label.is_some()) {
            let mut adtl = b"adtl".to_vec();
            for c in &meta.cues {
                if let Some(l) = &c.label {
                    let mut d = c.id.to_le_bytes().to_vec();
                    d.extend_from_slice(l.as_bytes());
                    d.push(0);
                    push_chunk(&mut adtl, b"labl", &d);
                }
            }
            push_chunk(&mut body, b"LIST", &adtl);
        }
    }
    let mut out = Vec::with_capacity(body.len() + 8);
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    Ok(out)
}

/// loop/BPM 推断结果的来源。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HintSource {
    Acid,
    Smpl,
    FileName,
    Duration,
}

/// 从元数据/文件名/时长推断出的 loop 信息。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LoopHint {
    pub is_loop: bool,
    pub bpm: Option<f64>,
    pub beats: Option<f64>,
    pub root_note: Option<u8>,
    pub loop_points: Option<(u64, u64)>,
    pub source: Option<HintSource>,
}

/// 从文件名解析 BPM，如 `loop_92bpm_4bar.wav`、`Beat 120 BPM.wav`。
pub fn bpm_from_name(name: &str) -> Option<f64> {
    let lower = name.to_ascii_lowercase();
    let idx = lower.find("bpm")?;
    let before = lower[..idx].trim_end_matches([' ', '_', '-']);
    let digits: String = before
        .chars()
        .rev()
        .take_while(|c| c.is_ascii_digit() || *c == '.')
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();
    let v: f64 = digits.parse().ok()?;
    (20.0..=999.0).contains(&v).then_some(v)
}

/// 从文件名解析小节数，如 `4bar`、`2 bars`。
pub fn bars_from_name(name: &str) -> Option<u32> {
    let lower = name.to_ascii_lowercase();
    let idx = lower.find("bar")?;
    let before = lower[..idx].trim_end_matches([' ', '_', '-']);
    let digits: String = before
        .chars()
        .rev()
        .take_while(|c| c.is_ascii_digit())
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();
    digits.parse().ok().filter(|v| (1..=64).contains(v))
}

/// 按规格 §4 的优先级推断 loop 信息：`acid` > `smpl`/`inst` > 文件名 > 时长推算。
/// `fallback_bpm` 用于“只知道是 loop、不知道 BPM”时由时长推算拍数（取 2 的幂）。
pub fn loop_hint(bytes: &[u8], file_name: &str, fallback_bpm: Option<f64>) -> Result<LoopHint> {
    let i = info(bytes)?;
    let m = read_metadata(bytes)?;
    let dur = i.duration_secs();
    let lower = file_name.to_ascii_lowercase();
    let name_loop = lower.contains("loop");
    let mut h = LoopHint {
        is_loop: false,
        bpm: None,
        beats: None,
        root_note: None,
        loop_points: None,
        source: None,
    };
    if let Some(s) = &m.smpl {
        h.root_note = u8::try_from(s.midi_unity_note).ok().filter(|n| *n <= 127);
        if let Some(l) = s.loops.first() {
            h.is_loop = true;
            h.loop_points = Some((u64::from(l.start), u64::from(l.end)));
            h.source = Some(HintSource::Smpl);
        }
    } else if let Some(inst) = &m.inst {
        h.root_note = Some(inst.unshifted_note).filter(|n| *n <= 127);
    }
    if let Some(a) = &m.acid {
        if a.flags & acid_flags::ROOT_NOTE_SET != 0 && h.root_note.is_none() {
            h.root_note = u8::try_from(a.root_note).ok().filter(|n| *n <= 127);
        }
        if !a.is_one_shot() && a.tempo.is_finite() && a.tempo > 0.0 {
            h.is_loop = true;
            h.bpm = Some(f64::from(a.tempo));
            h.beats = (a.beats > 0).then_some(f64::from(a.beats));
            h.source = Some(HintSource::Acid);
            return Ok(h);
        }
        if a.is_one_shot() && h.loop_points.is_none() {
            return Ok(h);
        }
    }
    if let Some(bpm) = bpm_from_name(file_name) {
        h.is_loop = true;
        h.bpm = Some(bpm);
        h.beats = bars_from_name(file_name)
            .map(|b| f64::from(b) * 4.0)
            .or_else(|| Some(beats_for(dur, bpm)));
        h.source.get_or_insert(HintSource::FileName);
        return Ok(h);
    }
    if name_loop {
        h.is_loop = true;
        h.source.get_or_insert(HintSource::FileName);
    }
    if h.is_loop && h.bpm.is_none() {
        if let Some(bpm) = fallback_bpm {
            h.bpm = Some(bpm);
            h.beats = Some(beats_for(dur, bpm));
            h.source.get_or_insert(HintSource::Duration);
        }
    }
    Ok(h)
}

/// 由时长和 BPM 推算拍数，取最接近的 2 的幂（至少 1）。
pub fn beats_for(duration_secs: f64, bpm: f64) -> f64 {
    let raw = duration_secs * bpm / 60.0;
    if raw <= 1.0 {
        return 1.0;
    }
    let exp = raw.log2().round();
    2f64.powf(exp)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tone(frames: usize) -> Vec<u8> {
        let s: Vec<f32> = (0..frames).map(|i| (i as f32 * 0.05).sin() * 0.5).collect();
        encode_pcm16(1, 44_100, &s)
    }

    #[test]
    fn encode_decode_roundtrip() {
        let wav = tone(1000);
        let i = info(&wav).unwrap();
        assert_eq!(i.frames, 1000);
        assert_eq!(i.channels, 1);
        let pcm = decode(&wav).unwrap();
        assert_eq!(pcm.frames(), 1000);
        assert!((pcm.samples[10] - (10f32 * 0.05).sin() * 0.5).abs() < 1e-3);
    }

    #[test]
    fn metadata_roundtrip() {
        let wav = tone(44_100);
        let mut smpl = SmplChunk::new(44_100, 60);
        smpl.loops.push(SampleLoop {
            cue_id: 0,
            kind: LoopType::Forward,
            start: 0,
            end: 44_099,
            fraction: 0,
            play_count: 0,
        });
        let meta = WavMetadata {
            smpl: Some(smpl),
            acid: Some(AcidChunk::looped(120.0, 2, 60, [4, 4])),
            inst: Some(InstChunk {
                unshifted_note: 60,
                fine_tune: -3,
                gain: 0,
                low_note: 0,
                high_note: 127,
                low_velocity: 1,
                high_velocity: 127,
            }),
            cues: vec![
                CuePoint {
                    id: 1,
                    position: 0,
                    label: Some("start".into()),
                },
                CuePoint {
                    id: 2,
                    position: 22_050,
                    label: None,
                },
            ],
            bext: Some(BextChunk {
                description: "UltraPads test".into(),
                originator: "up-format".into(),
                origination_date: "2026-10-18".into(),
                origination_time: "12:00:00".into(),
                time_reference: 1 << 33,
                version: 2,
                coding_history: "A=PCM,F=44100,W=16,M=mono".into(),
                ..BextChunk::default()
            }),
        };
        let out = write_metadata(&wav, &meta).unwrap();
        let back = read_metadata(&out).unwrap();
        assert_eq!(back.smpl, meta.smpl);
        assert_eq!(back.acid, meta.acid);
        assert_eq!(back.inst, meta.inst);
        assert_eq!(back.cues, meta.cues);
        assert_eq!(back.bext.as_ref().unwrap().description, "UltraPads test");
        assert_eq!(back.bext.as_ref().unwrap().time_reference, 1 << 33);
        assert_eq!(back.bext, meta.bext);
        // 音频数据保持不变
        assert_eq!(decode(&out).unwrap(), decode(&wav).unwrap());
        // 再写一次是幂等的
        assert_eq!(write_metadata(&out, &meta).unwrap(), out);
        let h = loop_hint(&out, "x.wav", None).unwrap();
        assert!(h.is_loop);
        assert_eq!(h.bpm, Some(120.0));
        assert_eq!(h.beats, Some(2.0));
        assert_eq!(h.root_note, Some(60));
        assert_eq!(h.source, Some(HintSource::Acid));
    }

    #[test]
    fn hints_from_name_and_duration() {
        let wav = tone(88_200); // 2 秒
        let h = loop_hint(&wav, "Groove_92bpm_4bar.wav", None).unwrap();
        assert!(h.is_loop);
        assert_eq!(h.bpm, Some(92.0));
        assert_eq!(h.beats, Some(16.0));
        let h = loop_hint(&wav, "drum loop.wav", Some(120.0)).unwrap();
        assert!(h.is_loop);
        assert_eq!(h.beats, Some(4.0));
        assert_eq!(h.source, Some(HintSource::FileName));
        let h = loop_hint(&wav, "kick.wav", Some(120.0)).unwrap();
        assert!(!h.is_loop);
        assert_eq!(bpm_from_name("Beat 128 BPM.wav"), Some(128.0));
        assert_eq!(bpm_from_name("nobpm.wav"), None);
    }

    #[test]
    fn rejects_garbage() {
        assert!(info(b"not a wav").is_err());
        let mut wav = tone(10);
        wav[20] = 0x55; // 编码改成未知
        assert!(info(&wav).is_err());
    }

    #[test]
    fn decodes_24bit_and_float() {
        // 手工构造 24-bit 单声道 2 帧
        let mut w = encode_pcm16(1, 48_000, &[0.0, 0.0]);
        // 改写 fmt：bits=24, block_align=3, byte_rate
        w[32] = 3;
        w[34] = 24;
        let rate = 48_000u32 * 3;
        w[28..32].copy_from_slice(&rate.to_le_bytes());
        let data = [0x00, 0x00, 0x40, 0x00, 0x00, 0xC0];
        w.truncate(40);
        w.extend_from_slice(&(data.len() as u32).to_le_bytes());
        w.extend_from_slice(&data);
        let len = (w.len() - 8) as u32;
        w[4..8].copy_from_slice(&len.to_le_bytes());
        let pcm = decode(&w).unwrap();
        assert!((pcm.samples[0] - 0.5).abs() < 1e-6);
        assert!((pcm.samples[1] + 0.5).abs() < 1e-6);
    }
}
