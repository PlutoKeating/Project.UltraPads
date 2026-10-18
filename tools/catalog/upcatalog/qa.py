"""入库前自动质检（人工抽检的补充）：层数 / 响度 / 静音 / 速度与节拍网格是否对得上声明的 BPM / 循环首尾是否有跳变。"""

from __future__ import annotations

import numpy as np

from . import SR, audio
from .analyze import estimate_grid
from .model import Song, n_bars
from .paths import Ctx


def check_song(song: Song, stems: dict[str, np.ndarray]) -> list[str]:
    """返回问题列表（空 = 通过）。"""
    problems = []
    bars = {m.name: n_bars(stems[m.name], song.bpm, song.offset) for m in song.stems}
    if min(bars.values()) < 4:
        problems.append(f"不足 4 小节：{bars}")
    for m in song.stems:
        x = stems[m.name]
        if audio.peak(x) < 0.01:
            problems.append(f"{m.name} 几乎静音")
        if audio.peak(x) > 1.0:
            problems.append(f"{m.name} 削波（峰值 {audio.peak(x):.2f}）")
        # 程序化生成的素材是严格周期的：4 小节循环首尾应当连续。真实录音的切片首尾本来就不连续，由切片时的淡入淡出处理。
        if song.origin != "synth":
            continue
        bs = 4 * 60.0 / song.bpm * SR
        a, z = int(song.offset * SR), int(song.offset * SR + 4 * bs)
        if z <= len(x):
            seg = x[a:z]
            jump = float(np.abs(seg[0] - seg[-1]).max())
            if jump > 0.25:
                problems.append(f"{m.name} 循环首尾跳变 {jump:.2f}")
    mix = sum(stems[m.name][: min(len(v) for v in stems.values())] for m in song.stems)
    ref = stems.get("Drums", mix)
    if song.offset == 0 and len(ref) > 8 * SR:
        g = estimate_grid(ref[: 4 * int(4 * 60.0 / song.bpm * SR)], lo=max(60, song.bpm * 0.9), hi=song.bpm * 1.1)
        if abs(g.bpm - song.bpm) / song.bpm > 0.01 and g.confidence > 3:
            problems.append(f"鼓的节拍估计 {g.bpm:.1f} 与声明 {song.bpm:.1f} 不符")
    return problems


def run(ctx: Ctx, ids: list[str]) -> dict[str, list[str]]:
    out = {}
    for id_ in ids:
        song, stems = Song.load(ctx.work, id_)
        out[id_] = check_song(song, stems)
    return out
