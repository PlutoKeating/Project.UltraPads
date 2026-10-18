"""程序化作曲：风格模板 + 种子 → 一首 8 小节歌曲（A、B 两个 4 小节乐句）的各乐器音符。

产出的是**原创**音符（每首歌由种子确定性生成），再由 SoundFont（MuseScore_General，MIT）渲染成音频。
每个乐句独立循环（A 渲染两遍取第二遍），所以 1 / 2 / 4 小节的切片都能无缝循环。
"""

from __future__ import annotations

import random
import zlib
from dataclasses import dataclass, field

SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}
# 每小节一个和弦（0 起的音级），按调式给几套进行
PROGRESSIONS = {
    "minor": [[0, 5, 2, 6], [0, 6, 5, 6], [0, 3, 5, 6], [0, 5, 3, 6], [0, 2, 6, 5], [5, 6, 0, 0], [0, 3, 6, 2], [0, 6, 3, 4]],
    "dorian": [[0, 3, 0, 3], [0, 6, 3, 0], [0, 3, 6, 3], [1, 3, 0, 0], [0, 4, 3, 6]],
    "major": [[0, 4, 5, 3], [0, 5, 3, 4], [0, 3, 4, 3], [5, 3, 0, 4], [0, 2, 3, 4], [3, 4, 2, 5]],
    "mixolydian": [[0, 6, 3, 0], [0, 3, 6, 0], [0, 6, 0, 3]],
    "phrygian": [[0, 1, 0, 6], [0, 6, 1, 0]],
}
# GM 鼓
DRUM = dict(kick=36, rim=37, snare=38, clap=39, chat=42, phat=44, ohat=46, tl=45, tm=47, th=50, crash=49, ride=51,
            tamb=54, cow=56, shaker=70, conga_h=63, conga_l=64, clave=75)
VEL = {"X": 112, "x": 92, "o": 58, "g": 40}  # 重音 / 普通 / 轻 / 幽灵音
STEP = 0.25  # 一个 16 分音符 = 0.25 拍
BAR = 4.0


@dataclass
class Part:
    name: str  # 显示名
    role: str  # model.ROLE_COLOR 的键
    kind: str  # drums | bass | chords | lead | pad | arp | perc
    program: int
    gain_db: float = 0.0
    octave: int = 0  # 相对默认音域的八度偏移
    pattern: int | None = None  # 固定使用第几套节奏；None = 随种子选


@dataclass
class Style:
    id: str
    genre: str
    bpm: tuple[int, int]
    modes: list[str]
    parts: list[Part]
    swing: float = 0.0
    kit: int = 0
    drums: dict[str, list[str]] = field(default_factory=dict)
    bass: list[str] = field(default_factory=list)
    chords: list[str] = field(default_factory=list)
    lead_density: float = 0.5  # 0..1，旋律音符密度
    seventh: bool = False
    keys: list[int] = field(default_factory=lambda: [0, 2, 3, 5, 7, 9, 10])  # 主音候选（相对 C）
    tags: list[str] = field(default_factory=list)


def pitch(root: int, scale: list[int], degree: int) -> int:
    octv, i = divmod(degree, 7)
    return root + 12 * octv + scale[i]


def chord_tones(root: int, scale: list[int], degree: int, seventh: bool) -> list[int]:
    t = [pitch(root, scale, degree + k) for k in (0, 2, 4)]
    if seventh:
        t.append(pitch(root, scale, degree + 6))
    return t


def swing_offset(step: int, swing: float) -> float:
    """奇数个 16 分音符向后推 swing*STEP。"""
    return swing * STEP if step % 2 == 1 else 0.0


# ---------------------------------------------------------------- 各乐器

def drums_phrase(st: Style, rng: random.Random, phrase: int, variant: int) -> list[tuple]:
    notes = []
    for bar in range(4):
        base = bar * BAR
        for name, pats in st.drums.items():
            pat = pats[(variant + (bar % 2)) % len(pats)] if len(pats) > 1 else pats[0]
            for s, ch in enumerate(pat):
                if ch in VEL:
                    notes.append((base + s * STEP + swing_offset(s, st.swing), 0.2, DRUM[name], VEL[ch] + rng.randint(-4, 4)))
        last = bar == 3
        if last and phrase == 1:  # B 乐句最后一小节：军鼓过门 + 下一遍开头的镲
            for k, s in enumerate(range(12, 16)):
                notes.append((base + s * STEP, 0.2, DRUM["snare"], 70 + k * 12))
        elif last:  # A 乐句最后一小节：小鼓点
            notes.append((base + 14 * STEP, 0.2, DRUM["snare"], 80))
            notes.append((base + 15 * STEP, 0.2, DRUM["snare"], 96))
        if bar == 0 and phrase == 1:
            notes.append((base, 1.0, DRUM["crash"], 96))
    return notes


def _parse_bass(pat: str) -> list[tuple[int, int, str]]:
    ev = [(i, c) for i, c in enumerate(pat) if c not in ".-"]
    out = []
    for n, (i, c) in enumerate(ev):
        end = ev[n + 1][0] if n + 1 < len(ev) else 16
        j = i + 1
        while j < end and pat[j] == "-":
            j += 1
        out.append((i, j - i, c))
    return out


def bass_phrase(st: Style, rng: random.Random, prog: list[int], root: int, scale: list[int], pat_idx: int, octave: int) -> list[tuple]:
    notes = []
    base_pitch = root + 24 + 12 * octave  # C1 起（MIDI 24~35）
    for bar, deg in enumerate(prog):
        pat = st.bass[(pat_idx + (bar % 2 if len(st.bass) > 1 else 0)) % len(st.bass)]
        tones = chord_tones(base_pitch, scale, deg, False)
        pick = {"r": tones[0], "3": tones[1], "5": tones[2], "o": tones[0] + 12, "7": pitch(base_pitch, scale, deg + 6)}
        for s, length, c in _parse_bass(pat):
            notes.append((bar * BAR + s * STEP + swing_offset(s, st.swing), max(0.2, length * STEP * 0.92), pick[c], 100 if s % 4 == 0 else 86))
    return notes


def chords_phrase(st: Style, rng: random.Random, prog: list[int], root: int, scale: list[int], pat_idx: int, octave: int, arp: bool = False) -> list[tuple]:
    notes = []
    base = root + 48 + 12 * octave  # 约 C3~B3 起
    for bar, deg in enumerate(prog):
        tones = chord_tones(base, scale, deg, st.seventh)
        if arp:
            order = [0, 1, 2, 3, 2, 1] if len(tones) > 3 else [0, 1, 2, 1]
            for s in range(16):
                t = tones[order[s % len(order)] % len(tones)] + (12 if (s // len(order)) % 2 else 0)
                notes.append((bar * BAR + s * STEP + swing_offset(s, st.swing), STEP * 0.9, t + 12, 78 + (10 if s % 4 == 0 else 0)))
            continue
        pat = st.chords[(pat_idx + bar // 2) % len(st.chords)]
        ev = [(i, c) for i, c in enumerate(pat) if c not in ".-"]
        for n, (i, c) in enumerate(ev):
            end = ev[n + 1][0] if n + 1 < len(ev) else 16
            j = i + 1
            while j < end and pat[j] == "-":
                j += 1
            dur = max(0.2, (j - i) * STEP * 0.95)
            t0 = bar * BAR + i * STEP + swing_offset(i, st.swing)
            if c == "x":
                for k, p in enumerate(tones):
                    notes.append((t0 + k * 0.012, dur, p, 80))
            else:  # a b c d：单个和弦音
                idx = "abcd".index(c)
                notes.append((t0, dur, tones[idx % len(tones)], 84))
    return notes


def pad_phrase(root: int, scale: list[int], prog: list[int], octave: int, seventh: bool) -> list[tuple]:
    notes = []
    base = root + 48 + 12 * octave
    for bar, deg in enumerate(prog):
        for p in chord_tones(base, scale, deg, seventh):
            notes.append((bar * BAR, BAR * 0.99, p, 62))
    return notes


def lead_phrase(st: Style, rng: random.Random, prog: list[int], root: int, scale: list[int], octave: int, motif_seed: int, phrase: int) -> list[tuple]:
    """两小节动机 + 变化重复。强拍落在和弦音上，其余按音阶级进 / 跳进。"""
    mr = random.Random(motif_seed)
    # 动机节奏：(步位, 时值步数)
    rhythms = []
    for _ in range(2):
        s, bar = 0, []
        while s < 16:
            if mr.random() < st.lead_density or s % 4 == 0 and mr.random() < 0.7:
                ln = mr.choice([1, 2, 2, 3, 4]) if s % 4 == 0 else mr.choice([1, 1, 2])
                ln = min(ln, 16 - s)
                bar.append((s, ln))
                s += ln
            else:
                s += mr.choice([1, 2])
        if not bar:
            bar = [(0, 4), (8, 4)]
        rhythms.append(bar)
    base = root + 60 + 12 * octave
    cur = 2 + mr.randint(0, 2)  # 音阶级（相对 base，0 = 主音，7 = 高八度）
    notes = []
    for bar in range(4):
        deg = prog[bar]
        tones = [(deg + k) for k in (0, 2, 4)]
        rhythm = rhythms[bar % 2]
        for n, (s, ln) in enumerate(rhythm):
            strong = s % 4 == 0
            if strong:  # 靠近当前位置的和弦音
                cand = [t + 7 * o for t in tones for o in (0, 1)]
                cur = min(cand, key=lambda c: abs(c - cur) + mr.random())
            else:
                cur += mr.choice([-2, -1, -1, 1, 1, 2])
            if bar == 3 and n == len(rhythm) - 1:  # 乐句末尾落回主音 / 五度
                cur = prog[0] + (0 if phrase == 0 else 4)
            cur = max(0, min(cur, 9))
            notes.append((bar * BAR + s * STEP + swing_offset(s, st.swing), max(0.2, ln * STEP * 0.9), pitch(base, scale, cur), 88 if strong else 76))
    return notes


def perc_phrase(st: Style, rng: random.Random, phrase: int, variant: int) -> list[tuple]:
    notes = []
    pats = [
        {"shaker": "xoxoxoxoxoxoxoxo", "tamb": "....x.......x..."},
        {"conga_h": "..x..x..x..x..x.", "conga_l": "x..x..x...x..x..", "cow": "........x......."},
        {"shaker": "x.o.x.o.x.o.x.o.", "clave": "x..x..x...x.x..."},
    ]
    pat = pats[variant % len(pats)]
    for bar in range(4):
        for name, p in pat.items():
            for s, ch in enumerate(p):
                if ch in VEL:
                    notes.append((bar * BAR + s * STEP + swing_offset(s, st.swing), 0.2, DRUM[name], VEL[ch] - (10 if name == "shaker" else 0)))
    return notes


# ---------------------------------------------------------------- 整首歌

@dataclass
class SongPlan:
    style: Style
    seed: int
    bpm: int
    root: int  # 0..11
    mode: str
    prog: list[list[int]]  # [A, B]
    variant: int
    motif: int


def plan(style: Style, seed: int) -> SongPlan:
    rng = random.Random(seed)
    mode = rng.choice(style.modes)
    progs = PROGRESSIONS[mode]
    a = rng.choice(progs)
    b = rng.choice([p for p in progs if p != a] or progs)
    return SongPlan(style, seed, rng.randint(*style.bpm), rng.choice(style.keys), mode, [a, b], rng.randint(0, 5), rng.randint(0, 10**6))


def phrase_notes(p: SongPlan, part: Part, phrase: int) -> list[tuple]:
    """某个乐器在 A(0) / B(1) 乐句里的音符 [(起拍, 时长拍, 音高, 力度)]。"""
    st = p.style
    scale = SCALES[p.mode]
    rng = random.Random(p.seed * 31 + phrase * 7 + zlib.crc32(part.name.encode()) % 997)
    prog = p.prog[phrase]
    pat = p.variant if part.pattern is None else part.pattern
    if part.kind == "drums":
        return drums_phrase(st, rng, phrase, pat)
    if part.kind == "perc":
        return perc_phrase(st, rng, phrase, pat)
    if part.kind == "bass":
        return bass_phrase(st, rng, prog, p.root, scale, pat, part.octave)
    if part.kind == "chords":
        return chords_phrase(st, rng, prog, p.root, scale, pat, part.octave)
    if part.kind == "arp":
        return chords_phrase(st, rng, prog, p.root, scale, pat, part.octave, arp=True)
    if part.kind == "pad":
        return pad_phrase(p.root, scale, prog, part.octave, st.seventh)
    if part.kind == "lead":
        return lead_phrase(st, rng, prog, p.root, scale, part.octave, p.motif + phrase * 17, phrase)
    raise ValueError(part.kind)
