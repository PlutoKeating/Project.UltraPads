//! 分轨：可插拔的 `Separator` 接口。
//!
//! 后端只需要实现 [`Separator::separate`]：输入 44.1 kHz 立体声，输出每个分轨同长度的立体声。
//! 目前自带 Demucs（htdemucs，ONNX，纯 Rust 推理），见 [`crate::demucs`]；以后可以接别的模型（如 `ort`）而不动拆分逻辑。

use crate::error::Result;

/// 分轨的乐器类别（决定 pad 名称、颜色）。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum StemKind {
    Drums,
    Bass,
    Other,
    Vocals,
    /// 没有分轨时的整曲混音。
    Mix,
}

impl StemKind {
    pub fn name(self) -> &'static str {
        match self {
            Self::Drums => "Drums",
            Self::Bass => "Bass",
            Self::Other => "Other",
            Self::Vocals => "Vocals",
            Self::Mix => "Mix",
        }
    }

    /// `up_format::kit::ColorRole` 的小写名字。
    pub fn color(self) -> &'static str {
        match self {
            Self::Drums => "orange",
            Self::Bass => "purple",
            Self::Other => "green",
            Self::Vocals => "pink",
            Self::Mix => "blue",
        }
    }
}

/// 一条立体声（左右各一个缓冲）。
#[derive(Debug, Clone, Default)]
pub struct Stereo {
    pub l: Vec<f32>,
    pub r: Vec<f32>,
}

impl Stereo {
    pub fn silent(frames: usize) -> Self {
        Self {
            l: vec![0.0; frames],
            r: vec![0.0; frames],
        }
    }

    pub fn frames(&self) -> usize {
        self.l.len()
    }

    pub fn mono(&self) -> Vec<f32> {
        self.l
            .iter()
            .zip(&self.r)
            .map(|(a, b)| 0.5 * (a + b))
            .collect()
    }
}

/// 进度回调：参数是 0..=1 的完成比例；返回 `false` 表示用户取消。
pub type Progress<'a> = &'a mut dyn FnMut(f32) -> bool;

pub trait Separator {
    /// 后端名称（日志与界面用）。
    fn name(&self) -> &str;

    /// 输出的分轨类别与顺序。
    fn stems(&self) -> &[StemKind];

    /// 估算峰值内存（MB），用于开始前检查。
    fn memory_mb(&self, frames: usize) -> u64;

    /// 输入必须是 44.1 kHz 立体声。返回的分轨顺序与 [`Separator::stems`] 一致、长度与输入相同。
    fn separate(&self, input: &Stereo, progress: Progress<'_>) -> Result<Vec<Stereo>>;
}

/// 当前可用内存（MB）；读不到时返回 `None`（不阻止运行）。
pub fn available_memory_mb() -> Option<u64> {
    let s = std::fs::read_to_string("/proc/meminfo").ok()?;
    let line = s.lines().find(|l| l.starts_with("MemAvailable:"))?;
    let kb: u64 = line.split_whitespace().nth(1)?.parse().ok()?;
    Some(kb / 1024)
}
