//! Demucs（htdemucs，4 轨：鼓 / 贝斯 / 其他 / 人声）的 ONNX 后端，用纯 Rust 的 tract 推理。
//!
//! 模型是单文件 ONNX（STFT 已在图里），输入 `mix` `(1, 2, 343980)`，输出 `stems` `(1, 4, 2, 343980)`，
//! 44.1 kHz。长音频按 7.8 秒分段、25% 重叠、线性淡入淡出加权拼接。
//! 模型文件不随应用分发，由应用在用户同意后下载并校验 sha256，这里只负责按路径加载。

use std::path::Path;

use tract_onnx::prelude::*;

use crate::error::{Result, SplitError};
use crate::separate::{Progress, Separator, StemKind, Stereo};

pub const SEGMENT: usize = 343_980;
const OVERLAP: usize = SEGMENT / 4;
const STEMS: [StemKind; 4] = [
    StemKind::Drums,
    StemKind::Bass,
    StemKind::Other,
    StemKind::Vocals,
];
/// 一个分段推理的峰值内存（实测约 4.4 GB，含权重）。
pub const PEAK_MB: u64 = 4_600;

type Plan = std::sync::Arc<TypedRunnableModel>;

pub struct Demucs {
    plan: Plan,
}

impl Demucs {
    /// 加载 ONNX（fp32 或 fp16 权重均可）。耗时约十几秒。
    pub fn load(path: &Path) -> Result<Self> {
        let plan = tract_onnx::onnx()
            .model_for_path(path)
            .and_then(|m| m.with_input_fact(0, f32::fact([1, 2, SEGMENT]).into()))
            .and_then(|m| m.into_optimized())
            .and_then(|m| m.into_runnable())
            .map_err(|e| SplitError::Model(format!("{e:#}")))?;
        Ok(Self { plan })
    }
}

/// 第 `c` 段（共 `chunks` 段）的加权窗：首段没有淡入，末段没有淡出，保证首尾样本权重不为 0。
fn window(c: usize, chunks: usize) -> Vec<f32> {
    let mut w = vec![1.0f32; SEGMENT];
    for i in 0..OVERLAP {
        let f = (i as f32 + 0.5) / OVERLAP as f32;
        if c > 0 {
            w[i] = f;
        }
        if c + 1 < chunks {
            w[SEGMENT - 1 - i] = f;
        }
    }
    w
}

impl Separator for Demucs {
    fn name(&self) -> &str {
        "Demucs htdemucs (tract)"
    }

    fn stems(&self) -> &[StemKind] {
        &STEMS
    }

    fn memory_mb(&self, frames: usize) -> u64 {
        // 模型 + 输入 + 4 条输出 + 权重和（每帧 4 字节 × (2 声道 × (1 + 4 + 4 + 1)) 的余量）
        PEAK_MB + (frames as u64 * 4 * 2 * 10) / (1024 * 1024)
    }

    fn separate(&self, input: &Stereo, progress: Progress<'_>) -> Result<Vec<Stereo>> {
        let total = input.frames();
        let stride = SEGMENT - OVERLAP;
        let chunks = total.div_ceil(stride).max(1);
        let mut out: Vec<Stereo> = (0..STEMS.len()).map(|_| Stereo::silent(total)).collect();
        let mut weight = vec![0.0f32; total];
        if !progress(0.0) {
            return Err(SplitError::Cancelled);
        }
        for c in 0..chunks {
            let start = c * stride;
            let end = (start + SEGMENT).min(total);
            let len = end - start;
            let w = window(c, chunks);
            let mut x = tract_ndarray::Array3::<f32>::zeros((1, 2, SEGMENT));
            for i in 0..len {
                x[[0, 0, i]] = input.l[start + i];
                x[[0, 1, i]] = input.r[start + i];
            }
            let res = self
                .plan
                .run(tvec!(x.into_tensor().into()))
                .map_err(|e| SplitError::Separate(format!("{e:#}")))?;
            let y = res[0]
                .to_plain_array_view::<f32>()
                .map_err(|e| SplitError::Separate(format!("{e:#}")))?;
            if y.shape() != [1, 4, 2, SEGMENT] {
                return Err(SplitError::Separate(format!(
                    "意外的输出形状 {:?}",
                    y.shape()
                )));
            }
            for (s, stem) in out.iter_mut().enumerate() {
                for i in 0..len {
                    stem.l[start + i] += y[[0, s, 0, i]] * w[i];
                    stem.r[start + i] += y[[0, s, 1, i]] * w[i];
                }
            }
            for i in 0..len {
                weight[start + i] += w[i];
            }
            if !progress((c + 1) as f32 / chunks as f32) {
                return Err(SplitError::Cancelled);
            }
        }
        for stem in &mut out {
            for i in 0..total {
                let k = 1.0 / weight[i].max(1e-8);
                stem.l[i] *= k;
                stem.r[i] *= k;
            }
        }
        Ok(out)
    }
}
