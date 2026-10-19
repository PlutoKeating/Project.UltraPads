//! 把一首歌（任意音频文件）拆成 UltraPads Kit：分析速度与小节 → 可选分轨 → 挑出若干 4 小节段落 → 每组一个段落、
//! 组内每个 pad 一个乐器（同官方曲库的排布，见 [`kit`]）。分轨在本地完成，云端不参与。

#![allow(clippy::needless_range_loop)] // DSP 代码按下标同时访问多个缓冲，下标循环更清楚

pub mod analyze;
pub mod error;
pub mod kit;
pub mod separate;

#[cfg(feature = "demucs")]
pub mod demucs;

use up_codec::AudioBuffer;

pub use analyze::{Grid, SR};
pub use error::{Result, SplitError};
pub use kit::{BuiltKit, Section};
pub use separate::{Progress, Separator, StemKind, Stereo};

/// 阶段，供界面显示。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stage {
    Decoding,
    Analyzing,
    Separating,
    Building,
}

/// 拆分的输入选项。
pub struct SplitOptions<'a> {
    pub title: &'a str,
    /// `Some` = 先分轨再拆；`None` = 只拆整曲混音。
    pub separator: Option<&'a dyn Separator>,
    /// 速度搜索范围（BPM）。
    pub bpm_range: (f64, f64),
    /// 用户已知速度时直接给定，跳过估计（仍会估计小节起点）。
    pub known_bpm: Option<f64>,
}

impl Default for SplitOptions<'_> {
    fn default() -> Self {
        Self {
            title: "Imported song",
            separator: None,
            bpm_range: (70.0, 180.0),
            known_bpm: None,
        }
    }
}

/// 拆分结果与分析信息。
pub struct SplitOutcome {
    pub kit: BuiltKit,
    pub grid: Grid,
    pub sections: Vec<Section>,
    pub separated: bool,
}

/// 把解码后的音频统一成 44.1 kHz 立体声。
pub fn to_stereo_44k(buf: &AudioBuffer) -> Result<Stereo> {
    if buf.channels == 0 || buf.sample_rate == 0 || buf.data.is_empty() {
        return Err(SplitError::Decode("音频为空".into()));
    }
    let buf = if buf.sample_rate == SR {
        buf.clone()
    } else {
        up_codec::resample(buf, SR).map_err(|e| SplitError::Decode(e.to_string()))?
    };
    let (l, r) = buf.to_stereo_planar();
    Ok(Stereo { l, r })
}

/// 核心入口：`progress(阶段, 0..=1)` 返回 `false` 取消。
pub fn split_song(
    audio: &AudioBuffer,
    opts: &SplitOptions<'_>,
    progress: &mut dyn FnMut(Stage, f32) -> bool,
) -> Result<SplitOutcome> {
    if !progress(Stage::Decoding, 0.0) {
        return Err(SplitError::Cancelled);
    }
    let stereo = to_stereo_44k(audio)?;
    let mono = stereo.mono();
    let secs = mono.len() as f64 / f64::from(SR);

    if !progress(Stage::Analyzing, 0.0) {
        return Err(SplitError::Cancelled);
    }
    let (lo, hi) = match opts.known_bpm {
        Some(b) => (b - 0.5, b + 0.5),
        None => opts.bpm_range,
    };
    let grid = analyze::estimate_grid(&mono, SR, lo, hi);
    if grid.confidence < 1.2 {
        return Err(SplitError::NoGrid {
            confidence: grid.confidence,
        });
    }
    let need = 4.0 * grid.bar_secs() + grid.offset;
    if secs < need {
        return Err(SplitError::TooShort {
            need_secs: need,
            got_secs: secs,
        });
    }
    let sections = kit::pick_sections(&mono, &grid);
    if sections.is_empty() {
        return Err(SplitError::TooShort {
            need_secs: need,
            got_secs: secs,
        });
    }

    let (stems, separated): (Vec<(StemKind, Stereo)>, bool) = match opts.separator {
        Some(sep) => {
            let need_mb = sep.memory_mb(stereo.frames());
            if let Some(have) = separate::available_memory_mb()
                && have < need_mb
            {
                return Err(SplitError::InsufficientMemory {
                    need_mb,
                    have_mb: have,
                });
            }
            let out = sep.separate(&stereo, &mut |p| progress(Stage::Separating, p))?;
            (sep.stems().iter().copied().zip(out).collect(), true)
        }
        None => (vec![(StemKind::Mix, stereo)], false),
    };

    if !progress(Stage::Building, 0.0) {
        return Err(SplitError::Cancelled);
    }
    let description = if separated {
        format!(
            "Imported song split into {} sections of 4 bars at {:.0} BPM; each section is played by its stem pads.",
            sections.len(),
            grid.bpm
        )
    } else {
        format!(
            "Imported song split into {} sections of 4 bars at {:.0} BPM (whole mix with 2-bar and 1-bar fragments).",
            sections.len(),
            grid.bpm
        )
    };
    let id = format!("urn:uuid:{}", new_uuid());
    let kit = kit::build_kit(&kit::KitSource {
        title: opts.title,
        grid,
        stems: &stems,
        sections: &sections,
        description,
        id,
    })?;
    progress(Stage::Building, 1.0);
    Ok(SplitOutcome {
        kit,
        grid,
        sections,
        separated,
    })
}

/// 随机 UUID v4 字符串（不引入 uuid 依赖：用时间 + 地址熵即可，Kit ID 只需唯一）。
fn new_uuid() -> String {
    use std::hash::{BuildHasher, Hasher};
    let mut h = std::collections::hash_map::RandomState::new().build_hasher();
    h.write_u128(
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0),
    );
    let a = h.finish();
    let mut h2 = std::collections::hash_map::RandomState::new().build_hasher();
    h2.write_u64(a);
    let b = h2.finish();
    let mut x = [0u8; 16];
    x[..8].copy_from_slice(&a.to_le_bytes());
    x[8..].copy_from_slice(&b.to_le_bytes());
    x[6] = (x[6] & 0x0f) | 0x40;
    x[8] = (x[8] & 0x3f) | 0x80;
    let h: String = x.iter().map(|b| format!("{b:02x}")).collect();
    format!(
        "{}-{}-{}-{}-{}",
        &h[..8],
        &h[8..12],
        &h[12..16],
        &h[16..20],
        &h[20..]
    )
}
