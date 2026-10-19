//! 节拍分析：恒定速度的 BPM 与小节起点（downbeat）。
//!
//! 与官方曲库入库管线（`tools/catalog/upcatalog/analyze.py`）是同一套算法：谱通量 onset 包络 →
//! 自相关粗估速度 → ±1.5 BPM 内用梳状网格精扫（含相位）→ 用低频（底鼓）能量在 4 个拍位上的分布确定小节起点。
//! 结果带置信度与速度漂移；不可靠时调用方应提示用户（仍可继续，只是小节线可能偏）。

use realfft::RealFftPlanner;

pub const SR: u32 = 44_100;
const HOP: usize = 256;
const NFFT: usize = 1024;
const BEATS_PER_BAR: usize = 4;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Grid {
    pub bpm: f64,
    /// 第 0 小节起点（秒），`0 <= offset < 小节长`。
    pub offset: f64,
    /// 梳状得分相对均值的倍数；>= 2.0 视为可靠。
    pub confidence: f64,
    /// 前后半段速度估计的相对差（0.002 = 0.2%）。
    pub drift: f64,
}

impl Grid {
    pub fn reliable(&self) -> bool {
        self.confidence >= 2.0 && self.drift <= 0.004
    }

    pub fn bar_secs(&self) -> f64 {
        BEATS_PER_BAR as f64 * 60.0 / self.bpm
    }
}

/// 谱通量 onset 包络（归一到峰值 1）与帧率。
pub fn onset_envelope(mono: &[f32], sr: u32) -> (Vec<f64>, f64) {
    let fps = f64::from(sr) / HOP as f64;
    if mono.len() < NFFT + HOP * 2 {
        return (Vec::new(), fps);
    }
    let win: Vec<f64> = (0..NFFT)
        .map(|i| 0.5 - 0.5 * (std::f64::consts::TAU * i as f64 / NFFT as f64).cos())
        .collect();
    let wsum: f64 = win.iter().sum();
    let mut planner = RealFftPlanner::<f64>::new();
    let fft = planner.plan_fft_forward(NFFT);
    let mut inp = fft.make_input_vec();
    let mut spec = fft.make_output_vec();
    let frames = (mono.len() - NFFT) / HOP + 1;
    let mut prev = vec![0.0f64; NFFT / 2 + 1];
    let mut flux = vec![0.0f64; frames];
    for t in 0..frames {
        let a = t * HOP;
        for i in 0..NFFT {
            inp[i] = f64::from(mono[a + i]) * win[i];
        }
        fft.process(&mut inp, &mut spec).expect("fft size");
        let mut f = 0.0;
        for (k, c) in spec.iter().enumerate() {
            let mag = (10.0 * c.norm() / wsum).ln_1p();
            if t > 0 {
                f += (mag - prev[k]).max(0.0);
            }
            prev[k] = mag;
        }
        flux[t] = f;
    }
    // 去掉缓慢变化的基线（约 0.5 s 滑动平均，等价于 np.convolve(..., "same")）
    let k = ((0.5 * f64::from(sr) / HOP as f64) as usize).max(3);
    let mut pre = vec![0.0f64; frames + 1];
    for i in 0..frames {
        pre[i + 1] = pre[i] + flux[i];
    }
    let shift = (k - 1) / 2;
    let mut env = vec![0.0f64; frames];
    let mut peak = 0.0f64;
    for i in 0..frames {
        let hi = (i + shift + 1).min(frames);
        let lo = (i + shift + 1).saturating_sub(k).min(frames);
        let base = (pre[hi] - pre[lo]) / k as f64;
        env[i] = (flux[i] - base).max(0.0);
        peak = peak.max(env[i]);
    }
    if peak > 0.0 {
        for v in &mut env {
            *v /= peak;
        }
    }
    (env, fps)
}

fn interp(xs: &[f64], pos: f64) -> f64 {
    if pos < 0.0 {
        return xs[0];
    }
    let i = pos.floor() as usize;
    if i + 1 >= xs.len() {
        return *xs.last().unwrap_or(&0.0);
    }
    let f = pos - i as f64;
    xs[i] * (1.0 - f) + xs[i + 1] * f
}

/// 给定周期（帧）→ (最佳得分, 最佳相位帧, 平均得分)。
fn comb(env: &[f64], period: f64) -> (f64, f64, f64) {
    let n = env.len();
    let k = ((n as f64 - 1.0) / period) as usize;
    if k < 8 {
        return (0.0, 0.0, 1e-9);
    }
    let nph = period.ceil() as usize;
    let mut scores = vec![0.0f64; nph];
    for (i, s) in scores.iter_mut().enumerate() {
        let ph = i as f64;
        let mut acc = 0.0;
        for j in 0..k {
            acc += interp(env, ph + j as f64 * period);
        }
        *s = acc / k as f64;
    }
    let (j, best) = scores
        .iter()
        .copied()
        .enumerate()
        .fold((0, f64::MIN), |a, (i, v)| if v > a.1 { (i, v) } else { a });
    let mut frac = 0.0;
    if j > 0 && j + 1 < scores.len() {
        let (a, b, c) = (scores[j - 1], scores[j], scores[j + 1]);
        let d = a - 2.0 * b + c;
        if d != 0.0 {
            frac = 0.5 * (a - c) / d;
        }
    }
    let mean = (scores.iter().sum::<f64>() / scores.len() as f64).max(1e-9);
    (best, j as f64 + frac, mean)
}

fn autocorr(env: &[f64]) -> Vec<f64> {
    let n = env.len();
    let m = (2 * n).next_power_of_two();
    let mean = env.iter().sum::<f64>() / n as f64;
    let mut planner = RealFftPlanner::<f64>::new();
    let fwd = planner.plan_fft_forward(m);
    let inv = planner.plan_fft_inverse(m);
    let mut buf = fwd.make_input_vec();
    for (i, v) in env.iter().enumerate() {
        buf[i] = v - mean;
    }
    let mut spec = fwd.make_output_vec();
    fwd.process(&mut buf, &mut spec).expect("fft size");
    for c in &mut spec {
        *c = realfft::num_complex::Complex::new(c.norm_sqr(), 0.0);
    }
    let mut out = inv.make_output_vec();
    inv.process(&mut spec, &mut out).expect("fft size");
    let z = out[0];
    let scale = if z > 0.0 { z } else { 1.0 };
    out.iter().take(n).map(|v| v / scale).collect()
}

/// (bpm, 第一拍秒数, 置信度, 原始得分)
fn estimate(env: &[f64], fps: f64, lo: f64, hi: f64) -> (f64, f64, f64, f64) {
    let n = env.len();
    if n < 64 || hi <= lo {
        return (lo, 0.0, 0.0, 0.0);
    }
    let ac = autocorr(env);
    let at = |l: f64| -> f64 {
        if l < 0.0 || l >= (n - 1) as f64 {
            0.0
        } else {
            interp(&ac, l)
        }
    };
    let (mut coarse, mut best_s) = (lo, f64::MIN);
    let mut b = lo;
    while b < hi {
        let lag = fps * 60.0 / b;
        let s = at(lag) + 0.5 * at(2.0 * lag) + 0.25 * at(4.0 * lag);
        if s > best_s {
            best_s = s;
            coarse = b;
        }
        b += 0.1;
    }
    let mut best = (-1.0f64, coarse, 0.0f64, 1e-9f64);
    let mut bpm = coarse - 1.5;
    while bpm < coarse + 1.5 {
        let (s, ph, mean) = comb(env, fps * 60.0 / bpm);
        if s > best.0 {
            best = (s, bpm, ph, mean);
        }
        bpm += 0.02;
    }
    let (s, bpm, ph, mean) = best;
    (bpm, ph / fps, s / mean, s)
}

/// 4 阶巴特沃斯低通（两个二阶节），返回平方后的能量序列。
fn low_energy(mono: &[f32], sr: u32, cutoff: f64) -> Vec<f32> {
    let w0 = std::f64::consts::TAU * cutoff / f64::from(sr);
    let (sin, cos) = w0.sin_cos();
    let mut y: Vec<f64> = mono.iter().map(|v| f64::from(*v)).collect();
    for q in [0.541_196_1, 1.306_563] {
        let alpha = sin / (2.0 * q);
        let b0 = (1.0 - cos) / 2.0;
        let b1 = 1.0 - cos;
        let b2 = b0;
        let a0 = 1.0 + alpha;
        let (a1, a2) = (-2.0 * cos, 1.0 - alpha);
        let (mut x1, mut x2, mut y1, mut y2) = (0.0, 0.0, 0.0, 0.0);
        for v in &mut y {
            let x0 = *v;
            let o = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
            x2 = x1;
            x1 = x0;
            y2 = y1;
            y1 = o;
            *v = o;
        }
    }
    y.iter().map(|v| (v * v) as f32).collect()
}

/// 估计速度与小节起点。`mono` 为 44.1 kHz 单声道（采样率不同时按 `sr` 计算）。
pub fn estimate_grid(mono: &[f32], sr: u32, lo: f64, hi: f64) -> Grid {
    let (env, fps) = onset_envelope(mono, sr);
    let (mut bpm, mut first_beat, mut conf, raw) = estimate(&env, fps, lo, hi);
    if bpm > 140.0 && bpm / 2.0 >= lo - 2.0 {
        // 倍速歧义：快速度的网格在半速下平均 onset 强度也差不多时，取半速
        let (b2, fb2, c2, raw2) = estimate(&env, fps, bpm / 2.0 - 2.0, bpm / 2.0 + 2.0);
        if c2 >= 2.0 && raw2 >= 0.9 * raw {
            (bpm, first_beat, conf) = (b2, fb2, c2);
        }
    }
    let half = env.len() / 2;
    let (b1, ..) = estimate(&env[..half], fps, lo.max(bpm - 3.0), bpm + 3.0);
    let (b2, ..) = estimate(&env[half..], fps, lo.max(bpm - 3.0), bpm + 3.0);
    let drift = (b1 - b2).abs() / bpm;

    // 小节起点：底鼓（<120 Hz）在 4 个拍位上的能量分布
    let low = low_energy(mono, sr, 120.0);
    let beat = 60.0 / bpm;
    let total = mono.len() as f64 / f64::from(sr);
    let nb = ((total - first_beat) / beat).max(0.0) as usize;
    let mut energy = [0.0f64; BEATS_PER_BAR];
    let mut cnt = [0u32; BEATS_PER_BAR];
    let w = (0.06 * f64::from(sr)) as usize;
    for i in 0..nb {
        let a = (first_beat + i as f64 * beat - 0.01) * f64::from(sr);
        if a < 0.0 {
            continue;
        }
        let a = a as usize;
        if a + w > low.len() {
            continue;
        }
        let m: f64 = low[a..a + w].iter().map(|v| f64::from(*v)).sum::<f64>() / w as f64;
        energy[i % BEATS_PER_BAR] += m;
        cnt[i % BEATS_PER_BAR] += 1;
    }
    let phase = (0..BEATS_PER_BAR)
        .max_by(|a, b| {
            let ea = energy[*a] / f64::from(cnt[*a].max(1));
            let eb = energy[*b] / f64::from(cnt[*b].max(1));
            ea.partial_cmp(&eb).unwrap_or(std::cmp::Ordering::Equal)
        })
        .unwrap_or(0);
    let bar = BEATS_PER_BAR as f64 * beat;
    let offset = (first_beat + phase as f64 * beat).rem_euclid(bar);
    Grid {
        bpm: (bpm * 1000.0).round() / 1000.0,
        offset,
        confidence: conf,
        drift,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 合成鼓：每拍一个短噪声脉冲，第 1 拍有额外的低频底鼓。
    pub(crate) fn click_track(bpm: f64, bars: usize, offset: f64) -> Vec<f32> {
        let sr = f64::from(SR);
        let n = ((bars as f64 * 4.0 * 60.0 / bpm + offset) * sr) as usize;
        let mut x = vec![0.0f32; n];
        let mut seed = 12345u32;
        let beat = 60.0 / bpm;
        let mut i = 0usize;
        loop {
            let t = offset + i as f64 * beat;
            let a = (t * sr) as usize;
            if a + 3000 >= n {
                break;
            }
            for j in 0..600 {
                seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
                let noise = (seed >> 16) as f32 / 32768.0 - 1.0;
                x[a + j] += noise * 0.5 * (-(j as f32) / 150.0).exp();
            }
            if i % 4 == 0 {
                for j in 0..3000 {
                    let ph = std::f32::consts::TAU * 55.0 * j as f32 / sr as f32;
                    x[a + j] += 0.8 * ph.sin() * (-(j as f32) / 900.0).exp();
                }
            }
            i += 1;
        }
        x
    }

    #[test]
    fn recovers_tempo_and_downbeat() {
        for (bpm, off) in [(100.0, 0.30), (120.0, 0.0), (87.5, 0.55)] {
            let x = click_track(bpm, 32, off);
            let g = estimate_grid(&x, SR, 70.0, 180.0);
            assert!((g.bpm - bpm).abs() < 0.3, "bpm {} vs {}", g.bpm, bpm);
            let bar = 240.0 / bpm;
            let d = (g.offset - off).rem_euclid(bar);
            assert!(d.min(bar - d) < 0.03, "offset {} vs {}", g.offset, off);
            assert!(g.reliable(), "{g:?}");
        }
    }

    #[test]
    fn silence_is_not_reliable() {
        let g = estimate_grid(&vec![0.0f32; SR as usize * 30], SR, 70.0, 180.0);
        assert!(!g.reliable());
    }
}
