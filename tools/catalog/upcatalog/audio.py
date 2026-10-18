"""音频读写与切片。解码 / 编码走系统 ffmpeg，其余用 numpy。内部一律 44.1 kHz 立体声 float32，形状 (n, 2)。"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np

from . import SR, BEATS_PER_BAR


class AudioError(RuntimeError):
    pass


def _run(cmd: list[str], data: bytes | None = None) -> bytes:
    p = subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        raise AudioError(f"{cmd[0]} 失败：{p.stderr.decode(errors='replace')[-400:]}")
    return p.stdout


def channels_of(path: str | Path) -> int:
    try:
        out = _run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels", "-of", "csv=p=0", str(path)])
        return int(out.decode().strip().split(",")[0])
    except Exception:  # noqa: BLE001
        return 2


def decode(src: str | Path | bytes, start: float | None = None, dur: float | None = None) -> np.ndarray:
    """任意格式 → (n, 2) float32 @ 44.1 kHz。"""
    cmd = ["ffmpeg", "-v", "error", "-nostdin"]
    if start:
        cmd += ["-ss", f"{start}"]
    if dur:
        cmd += ["-t", f"{dur}"]
    cmd += ["-i", "pipe:0" if isinstance(src, bytes) else str(src)]
    # 单声道要原样复制到左右（ffmpeg 默认的 -ac 2 升混会衰减 3 dB）
    mono = not isinstance(src, bytes) and channels_of(src) == 1
    cmd += (["-af", "pan=stereo|c0=c0|c1=c0"] if mono else ["-ac", "2"]) + ["-f", "f32le", "-ar", str(SR), "pipe:1"]
    raw = _run(cmd, src if isinstance(src, bytes) else None)
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()


def to_int16(x: np.ndarray, dither: bool = True, seed: int = 1) -> np.ndarray:
    y = x * 32767.0
    if dither:  # TPDF 抖动，避免 16 位量化失真
        rng = np.random.default_rng(seed)
        y = y + rng.random(x.shape, dtype=np.float32) - rng.random(x.shape, dtype=np.float32)
    return np.clip(np.rint(y), -32768, 32767).astype("<i2")


def is_dual_mono(x: np.ndarray, tol: float = 1e-3) -> bool:
    return bool(np.max(np.abs(x[:, 0] - x[:, 1])) <= tol)


def encode_flac(x: np.ndarray, path: str | Path, allow_mono: bool = True) -> Path:
    """float (n,2) → 16-bit FLAC。左右声道基本一致时存成单声道（体积减半）。"""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    mono = allow_mono and is_dual_mono(x)
    pcm = to_int16(x[:, :1] if mono else x)
    cmd = [
        "ffmpeg", "-v", "error", "-nostdin", "-y", "-f", "s16le", "-ac", "1" if mono else "2",
        "-ar", str(SR), "-i", "pipe:0", "-c:a", "flac", "-compression_level", "8", "-map_metadata", "-1",
        "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path),
    ]
    _run(cmd, pcm.tobytes())
    return path


def encode_mp3(x: np.ndarray, path: str | Path, bitrate: str = "128k") -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-v", "error", "-nostdin", "-y", "-f", "s16le", "-ac", "2", "-ar", str(SR), "-i", "pipe:0",
           "-c:a", "libmp3lame", "-b:a", bitrate, str(path)]
    _run(cmd, to_int16(x).tobytes())
    return path


def peak(x: np.ndarray) -> float:
    return float(np.max(np.abs(x))) if x.size else 0.0


def rms_db(x: np.ndarray) -> float:
    r = float(np.sqrt(np.mean(np.square(x, dtype=np.float64)))) if x.size else 0.0
    return -120.0 if r <= 1e-9 else 20.0 * np.log10(r)


def rms_db_active(x: np.ndarray, thresh: float = 1e-3) -> float:
    """只在非静音处求 RMS（鼓、稀疏旋律等有大量空隙的分轨用它定电平）。"""
    m = np.abs(x).max(axis=1) > thresh
    return rms_db(x[m]) if m.any() else -120.0


def match_level(x: np.ndarray, target_db: float, max_gain_db: float = 40.0) -> np.ndarray:
    """把分轨的活动 RMS 调到 target_db（增益不超过 max_gain_db，避免放大噪声）。"""
    g = min(target_db - rms_db_active(x), max_gain_db)
    return (x * 10 ** (g / 20.0)).astype(np.float32)


def soft_limit(x: np.ndarray, ceiling: float = 0.7, knee: float = 0.5) -> np.ndarray:
    """软限幅：|x| 低于 knee 原样通过，超出部分用 tanh 压向 ceiling（避免硬削波的刺耳失真）。"""
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((a[over] - knee) / (ceiling - knee)))
    return y


def normalize_mix(stems: dict[str, np.ndarray], target_rms_db: float = -17.0, ceiling: float = 0.7) -> tuple[dict[str, np.ndarray], float]:
    """整首歌用同一个增益：让各分轨叠加后的响度接近 target_rms_db，保持歌曲内部的混音平衡；
    每个分轨再做软限幅（单轨峰值 <= ceiling），叠加峰值由引擎主输出的限幅器兜底。返回 (新分轨, 线性增益)。"""
    n = max(len(a) for a in stems.values())
    mix = np.zeros((n, 2), dtype=np.float64)
    for a in stems.values():
        mix[: len(a)] += a
    if float(np.max(np.abs(mix))) <= 1e-9:
        raise AudioError("整首歌是静音")
    gain = 10 ** ((target_rms_db - rms_db(mix)) / 20.0)
    return {k: soft_limit((v * gain).astype(np.float32), ceiling) for k, v in stems.items()}, gain


def bar_samples(bpm: float) -> float:
    return BEATS_PER_BAR * 60.0 / bpm * SR


def slice_bars(x: np.ndarray, bpm: float, start_bar: float, n_bars: float, offset: float = 0.0, fade_ms: float = 1.5) -> np.ndarray:
    """按小节切片；start/length 取最近的整数样本，首尾各做 fade_ms 的线性淡化避免爆音。"""
    bs = bar_samples(bpm)
    a = int(round(offset + start_bar * bs))
    b = int(round(offset + (start_bar + n_bars) * bs))
    if a < 0 or b > len(x) or b <= a:
        raise AudioError(f"切片越界：{a}..{b}（长度 {len(x)}）")
    seg = x[a:b].copy()
    f = min(int(fade_ms * SR / 1000), len(seg) // 2)
    if f > 1:
        ramp = np.linspace(0.0, 1.0, f, dtype=np.float32)[:, None]
        seg[:f] *= ramp
        seg[-f:] *= ramp[::-1]
    return seg
