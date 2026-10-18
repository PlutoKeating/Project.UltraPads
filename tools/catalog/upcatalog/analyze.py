"""节拍分析：恒定速度的 BPM、小节起点（downbeat）估计。

素材来源已知 BPM 时（synth、ccMixter 的 bpm 字段）只做校验；否则靠音频估计。
做法：谱通量 onset 包络 → 自相关粗估速度 → 在 ±1.5 BPM 内用梳状网格精扫（含相位）→
用低频（底鼓）能量在 4 个拍位上的分布确定小节起点。分析结果带置信度与速度漂移，不可靠的素材由调用方丢弃。
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy import signal

from . import SR, BEATS_PER_BAR

HOP = 256


@dataclass
class Grid:
    bpm: float
    offset: float  # 第 0 小节起点（秒），0 <= offset < 小节长
    confidence: float  # 梳状得分相对均值的倍数；>= 2.0 视为可靠
    drift: float  # 前后半段速度估计的相对差（0.002 = 0.2%）

    @property
    def reliable(self) -> bool:
        return self.confidence >= 2.0 and self.drift <= 0.004


def onset_envelope(mono: np.ndarray, sr: int = SR) -> tuple[np.ndarray, float]:
    _, _, z = signal.stft(mono, sr, nperseg=1024, noverlap=1024 - HOP, boundary=None, padded=False)
    mag = np.log1p(10.0 * np.abs(z))
    flux = np.maximum(0.0, np.diff(mag, axis=1)).sum(axis=0)
    flux = np.concatenate([[0.0], flux])
    # 去掉缓慢变化的基线（约 0.5 s 滑动平均）
    k = max(3, int(0.5 * sr / HOP))
    base = np.convolve(flux, np.ones(k) / k, mode="same")
    env = np.maximum(0.0, flux - base)
    peak = env.max()
    return (env / peak if peak > 0 else env), sr / HOP


def _comb(env: np.ndarray, period: float) -> tuple[float, float, float]:
    """给定周期（帧）→ (最佳得分, 最佳相位帧, 平均得分)。"""
    n = len(env)
    k = int((n - 1) / period)
    if k < 8:
        return 0.0, 0.0, 1e-9
    steps = np.arange(k) * period
    phases = np.arange(0.0, period, 1.0)
    xs = np.arange(n)
    scores = np.empty(len(phases))
    for i, ph in enumerate(phases):
        scores[i] = np.interp(ph + steps, xs, env).sum() / k
    j = int(np.argmax(scores))
    frac = 0.0
    if 0 < j < len(scores) - 1:  # 抛物线插值得到亚帧相位
        a, b, c = scores[j - 1], scores[j], scores[j + 1]
        d = a - 2 * b + c
        frac = 0.5 * (a - c) / d if d != 0 else 0.0
    return float(scores[j]), float(phases[j] + frac), max(float(scores.mean()), 1e-9)


def _estimate(env: np.ndarray, fps: float, lo: float, hi: float) -> tuple[float, float, float, float]:
    n = len(env)
    f = np.fft.rfft(env - env.mean(), 2 * n)
    ac = np.fft.irfft(f * np.conj(f))[:n]
    ac /= ac[0] if ac[0] > 0 else 1.0
    bpms = np.arange(lo, hi, 0.1)
    lags = fps * 60.0 / bpms
    xs = np.arange(n)

    def at(l):
        return np.interp(l, xs, ac, right=0.0)

    score = at(lags) + 0.5 * at(2 * lags) + 0.25 * at(4 * lags)
    coarse = float(bpms[int(np.argmax(score))])
    best = (-1.0, coarse, 0.0, 1e-9)
    for bpm in np.arange(coarse - 1.5, coarse + 1.5, 0.02):
        s, ph, mean = _comb(env, fps * 60.0 / bpm)
        if s > best[0]:
            best = (s, float(bpm), ph, mean)
    s, bpm, ph, mean = best
    return bpm, ph / fps, s / mean, s


def estimate_grid(x: np.ndarray, sr: int = SR, lo: float = 70.0, hi: float = 180.0) -> Grid:
    """x：(n,2) 或 (n,) 音频。"""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    env, fps = onset_envelope(mono, sr)
    bpm, first_beat, conf, raw = _estimate(env, fps, lo, hi)
    if bpm > 140 and bpm / 2 >= lo - 2:
        # 倍速歧义：快速度的网格在半速下（落在每隔一拍的位置上）平均 onset 强度也差不多时，取半速
        b2, fb2, c2, raw2 = _estimate(env, fps, bpm / 2 - 2, bpm / 2 + 2)
        if c2 >= 2.0 and raw2 >= 0.9 * raw:
            bpm, first_beat, conf = b2, fb2, c2
    half = len(env) // 2
    b1, _, _, _ = _estimate(env[:half], fps, max(lo, bpm - 3), bpm + 3)
    b2, _, _, _ = _estimate(env[half:], fps, max(lo, bpm - 3), bpm + 3)
    drift = abs(b1 - b2) / bpm

    # 小节起点：底鼓（<120 Hz）在 4 个拍位上的能量分布
    sos = signal.butter(4, 120, "lowpass", fs=sr, output="sos")
    low = signal.sosfilt(sos, mono) ** 2
    beat = 60.0 / bpm
    nb = int((len(mono) / sr - first_beat) / beat)
    energy = np.zeros(BEATS_PER_BAR)
    cnt = np.zeros(BEATS_PER_BAR)
    w = int(0.06 * sr)
    for i in range(nb):
        a = int((first_beat + i * beat - 0.01) * sr)
        if a < 0 or a + w > len(low):
            continue
        energy[i % BEATS_PER_BAR] += low[a : a + w].mean()
        cnt[i % BEATS_PER_BAR] += 1
    phase = int(np.argmax(energy / np.maximum(cnt, 1)))
    bar = BEATS_PER_BAR * beat
    offset = (first_beat + phase * beat) % bar
    return Grid(bpm=round(bpm, 3), offset=float(offset), confidence=float(conf), drift=float(drift))
