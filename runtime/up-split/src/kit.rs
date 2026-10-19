//! 拆分结果 → Kit：**一个音色组（A/B/C…）= 歌曲的一个完整段落（4 小节），组内一个 pad = 一个乐器分轨**。
//!
//! 与官方曲库同一排布（`docs/adr/0005-catalog-and-accounts.md` 第 3 条）：同组 pad 全开即完整放出这一段；
//! pad 序号 = 乐器序号，各组一致；同一乐器跨组互斥（`exclusive = instN`）。只有整曲混音（没有分轨）时，
//! 每段 pad 1 = 整段，其余 pad 补 2 小节 / 1 小节片段。

use std::collections::BTreeMap;

use realfft::RealFftPlanner;
use up_format::kit::KitDoc;

use crate::analyze::{Grid, SR};
use crate::error::{Result, SplitError};
use crate::separate::{StemKind, Stereo};

pub const SECTION_BARS: usize = 4;
pub const MAX_SECTIONS: usize = 8;
const FADE_FRAMES: usize = (SR as usize * 3) / 2000; // 1.5 ms

/// 一个候选/入选的段落：从第几小节开始（相对小节网格）。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Section {
    pub start_bar: usize,
    /// 平均电平（dBFS）。
    pub level_db: f32,
}

fn bar_frames(grid: &Grid) -> f64 {
    grid.bar_secs() * f64::from(SR)
}

fn frame_at(grid: &Grid, bar: f64) -> usize {
    ((grid.offset * f64::from(SR)) + bar * bar_frames(grid))
        .round()
        .max(0.0) as usize
}

/// 整首歌能切出多少个完整小节。
pub fn total_bars(grid: &Grid, frames: usize) -> usize {
    let avail = frames as f64 - grid.offset * f64::from(SR);
    if avail <= 0.0 {
        0
    } else {
        (avail / bar_frames(grid)).floor() as usize
    }
}

fn rms_db(x: &[f32]) -> f32 {
    if x.is_empty() {
        return -120.0;
    }
    let e = x.iter().map(|v| v * v).sum::<f32>() / x.len() as f32;
    10.0 * e.max(1e-12).log10()
}

/// 8 个对数频带的能量（dB），去掉整体电平，用来比较两个段落“听起来像不像”。
fn spectral_signature(x: &[f32]) -> [f32; 8] {
    const N: usize = 2048;
    let mut planner = RealFftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(N);
    let mut inp = fft.make_input_vec();
    let mut spec = fft.make_output_vec();
    let edges = [0usize, 4, 8, 16, 32, 64, 128, 256, 1025]; // bin 0.. 约 0 / 86 / 170 / 340 / 690 / 1.4k / 2.7k / 5.5k / 22k Hz
    let mut acc = [0.0f32; 8];
    let mut n = 0;
    let hop = N * 2;
    let mut a = 0;
    while a + N <= x.len() {
        for i in 0..N {
            let w = 0.5 - 0.5 * (std::f32::consts::TAU * i as f32 / N as f32).cos();
            inp[i] = x[a + i] * w;
        }
        if fft.process(&mut inp, &mut spec).is_ok() {
            for b in 0..8 {
                acc[b] += spec[edges[b]..edges[b + 1]]
                    .iter()
                    .map(|c| c.norm_sqr())
                    .sum::<f32>();
            }
            n += 1;
        }
        a += hop;
    }
    let mut sig = [0.0f32; 8];
    for b in 0..8 {
        sig[b] = 10.0 * (acc[b] / n.max(1) as f32 + 1e-9).log10();
    }
    let mean = sig.iter().sum::<f32>() / 8.0;
    for v in &mut sig {
        *v -= mean;
    }
    sig
}

/// 在整首歌里挑出最多 [`MAX_SECTIONS`] 个互相差别最大的 4 小节段落，按时间顺序返回（A、B、C…）。
///
/// 候选是以第 0 小节为起点、每 4 小节一段；电平比最响的段落低 30 dB 以上的（前奏静音、结尾淡出）丢掉；
/// 再用最远点优先挑选，使入选的段落音色 / 密度尽量不同。
pub fn pick_sections(mono: &[f32], grid: &Grid) -> Vec<Section> {
    let bars = total_bars(grid, mono.len());
    let mut cands = Vec::new();
    let mut b = 0;
    while b + SECTION_BARS <= bars {
        let a = frame_at(grid, b as f64);
        let z = frame_at(grid, (b + SECTION_BARS) as f64).min(mono.len());
        if z > a {
            let seg = &mono[a..z];
            cands.push((b, rms_db(seg), spectral_signature(seg)));
        }
        b += SECTION_BARS;
    }
    let loudest = cands.iter().map(|c| c.1).fold(-120.0f32, f32::max);
    cands.retain(|c| c.1 > loudest - 30.0);
    if cands.len() <= MAX_SECTIONS {
        return cands
            .iter()
            .map(|c| Section {
                start_bar: c.0,
                level_db: c.1,
            })
            .collect();
    }
    let feat = |c: &(usize, f32, [f32; 8])| -> [f32; 9] {
        let mut f = [0.0; 9];
        f[..8].copy_from_slice(&c.2);
        f[8] = (c.1 - loudest) * 0.5;
        f
    };
    let dist = |a: &[f32; 9], b: &[f32; 9]| -> f32 {
        a.iter().zip(b).map(|(x, y)| (x - y) * (x - y)).sum::<f32>()
    };
    let feats: Vec<[f32; 9]> = cands.iter().map(feat).collect();
    // 从最响的段落开始，最远点优先
    let first = cands
        .iter()
        .enumerate()
        .max_by(|a, b| {
            a.1.1
                .partial_cmp(&b.1.1)
                .unwrap_or(std::cmp::Ordering::Equal)
        })
        .map(|(i, _)| i)
        .unwrap_or(0);
    let mut chosen = vec![first];
    let mut mind: Vec<f32> = feats.iter().map(|f| dist(f, &feats[first])).collect();
    while chosen.len() < MAX_SECTIONS {
        let next = (0..cands.len())
            .filter(|i| !chosen.contains(i))
            .max_by(|a, b| {
                mind[*a]
                    .partial_cmp(&mind[*b])
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
        let Some(next) = next else { break };
        chosen.push(next);
        for i in 0..cands.len() {
            mind[i] = mind[i].min(dist(&feats[i], &feats[next]));
        }
    }
    chosen.sort_unstable();
    chosen
        .iter()
        .map(|i| Section {
            start_bar: cands[*i].0,
            level_db: cands[*i].1,
        })
        .collect()
}

fn slice(x: &[f32], a: usize, z: usize) -> Vec<f32> {
    let mut seg = x[a.min(x.len())..z.min(x.len())].to_vec();
    let f = FADE_FRAMES.min(seg.len() / 2);
    for i in 0..f {
        let g = i as f32 / f as f32;
        let n = seg.len();
        seg[i] *= g;
        seg[n - 1 - i] *= g;
    }
    seg
}

/// 左右声道几乎一致时存成单声道，体积减半（引擎播放时单声道原样复制到两侧）。
fn encode(seg_l: &[f32], seg_r: &[f32]) -> Vec<u8> {
    let diff = seg_l
        .iter()
        .zip(seg_r)
        .map(|(a, b)| (a - b).abs())
        .fold(0.0f32, f32::max);
    if diff < 1.0 / 32768.0 {
        up_format::wav::encode_pcm16(1, SR, seg_l)
    } else {
        let mut inter = Vec::with_capacity(seg_l.len() * 2);
        for (a, b) in seg_l.iter().zip(seg_r) {
            inter.push(*a);
            inter.push(*b);
        }
        up_format::wav::encode_pcm16(2, SR, &inter)
    }
}

pub struct KitSource<'a> {
    pub title: &'a str,
    pub grid: Grid,
    /// 分轨（Mix 时只有一条）。每条与整首歌等长。
    pub stems: &'a [(StemKind, Stereo)],
    pub sections: &'a [Section],
    pub description: String,
    pub id: String,
}

pub struct BuiltKit {
    pub doc: KitDoc,
    /// 包内路径 → 文件字节（`samples/*.wav`）。
    pub assets: BTreeMap<String, Vec<u8>>,
}

const LABELS: &str = "ABCDEFGH";

pub fn build_kit(src: &KitSource<'_>) -> Result<BuiltKit> {
    if src.sections.is_empty() {
        return Err(SplitError::Kit("没有可用的段落".into()));
    }
    let g = &src.grid;
    let len = (SECTION_BARS as f64 * bar_frames(g)).round() as usize;
    // 全局增益：所有入选段落里“全部分轨相加”的峰值不超过 0.95
    let mut peak = 0.0f32;
    for sec in src.sections {
        let a = frame_at(g, sec.start_bar as f64);
        for i in (0..len).step_by(1) {
            let mut sl = 0.0;
            let mut sr = 0.0;
            for (_, s) in src.stems {
                if a + i < s.l.len() {
                    sl += s.l[a + i];
                    sr += s.r[a + i];
                }
            }
            peak = peak.max(sl.abs()).max(sr.abs());
        }
    }
    let gain = if peak > 0.95 { 0.95 / peak } else { 1.0 };

    let single = src.stems.len() == 1;
    let mut pads = Vec::new();
    let mut assets = BTreeMap::new();
    let mut add = |bank: usize,
                   index: usize,
                   kind: StemKind,
                   label: String,
                   a: usize,
                   z: usize,
                   excl: String,
                   stem: &Stereo| {
        let l: Vec<f32> = slice(&stem.l, a, z).iter().map(|v| v * gain).collect();
        let r: Vec<f32> = slice(&stem.r, a, z).iter().map(|v| v * gain).collect();
        let beats = ((z - a) as f64 / (bar_frames(g) / 4.0)).round() as u32;
        let rel = format!(
            "samples/{}_{}{}_{}.wav",
            LABELS[bank..=bank].to_lowercase(),
            kind.name().to_lowercase(),
            index + 1,
            label.replace(' ', "_").to_lowercase()
        );
        assets.insert(rel.clone(), encode(&l, &r));
        pads.push(serde_json::json!({
            "addr": {"bank": bank, "index": index},
            "note": 36 + bank * 12 + index,
            "name": format!("{} {}", kind.name(), label),
            "color": kind.color(),
            "kind": "loop",
            "launch": {"mode": "toggle", "quantize": "1bar", "retrigger": "restart"},
            "exclusive": excl,
            "tempo": {"bpm": g.bpm, "beats": beats, "timeSignature": [4, 4], "stretch": "beats"},
            "layers": [{"sample": rel}],
        }));
    };
    // 各组都保持同样的乐器序号；整段静音的分轨在所有段落都静音时才整体去掉
    let keep: Vec<usize> = (0..src.stems.len())
        .filter(|i| {
            src.sections.iter().any(|sec| {
                let a = frame_at(g, sec.start_bar as f64);
                let z = (a + len).min(src.stems[*i].1.l.len());
                a < z && rms_db(&src.stems[*i].1.l[a..z]) > -60.0
            })
        })
        .collect();
    if keep.is_empty() {
        return Err(SplitError::Kit("所有分轨都是静音".into()));
    }
    for (bank, sec) in src.sections.iter().enumerate() {
        let a = frame_at(g, sec.start_bar as f64);
        let z = a + len;
        let name = &LABELS[bank..=bank];
        for (index, si) in keep.iter().enumerate() {
            let (kind, stem) = &src.stems[*si];
            add(
                bank,
                index,
                *kind,
                name.to_owned(),
                a,
                z,
                format!("inst{}", index + 1),
                stem,
            );
        }
        if single {
            let (kind, stem) = &src.stems[0];
            let q = bar_frames(g).round() as usize;
            let frags: [(&str, usize, usize); 6] = [
                ("2bar 1", 0, 2),
                ("2bar 2", 2, 2),
                ("1bar 1", 0, 1),
                ("1bar 2", 1, 1),
                ("1bar 3", 2, 1),
                ("1bar 4", 3, 1),
            ];
            for (k, (label, start, nb)) in frags.iter().enumerate() {
                let fa = a + start * q;
                add(
                    bank,
                    1 + k,
                    *kind,
                    format!("{name} {label}"),
                    fa,
                    fa + nb * q,
                    format!("frag{bank}"),
                    stem,
                );
            }
        }
    }
    let count = src.sections.len();
    let doc = serde_json::json!({
        "id": src.id,
        "name": src.title,
        "description": src.description,
        "authors": [],
        "genres": [],
        "tags": ["imported", if single { "mix" } else { "stems" }],
        "tempo": {"bpm": g.bpm, "timeSignature": [4, 4]},
        "padCount": count * 12,
        "pads": pads,
        "themeColor": "#2AD5FA",
        "source": {"kind": "import", "originalName": src.title},
    });
    let doc: KitDoc = serde_json::from_value(doc).map_err(|e| SplitError::Kit(e.to_string()))?;
    Ok(BuiltKit { doc, assets })
}
