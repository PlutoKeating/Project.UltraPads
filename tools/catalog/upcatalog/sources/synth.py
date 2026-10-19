"""来源 ①：synth —— 原创 MIDI（程序化作曲）+ MuseScore_General SoundFont（MIT）渲染。许可证 CC0-1.0，作者 UltraPads。"""

from __future__ import annotations

import random
import shutil
from pathlib import Path

import numpy as np

from .. import SR, audio, licenses, rust
from ..compose import Part, SongPlan, phrase_notes, plan
from ..http import download
from ..model import ROLE_COLOR, THEME, Song, StemMeta, slugify
from ..paths import Ctx
from ..smf import write_smf
from ..styles import STYLES

PER_STYLE = 4
ADJ = ["Neon", "Velvet", "Midnight", "Golden", "Hollow", "Electric", "Quiet", "Crimson", "Lunar", "Paper", "Glass",
       "Amber", "Silver", "Distant", "Wild", "Soft", "Rusty", "Cosmic", "Faded", "Bright", "Salt", "Idle", "Northern"]
NOUN = ["Skyline", "Garden", "Signal", "Harbor", "Echo", "Orbit", "Parade", "Drift", "Mirage", "Circuit", "Tide",
        "Lantern", "Meadow", "Engine", "Static", "Compass", "Canyon", "Carousel", "Horizon", "Pulse", "Bridge", "Arcade", "Station"]
KEYS = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
# 各类乐器的目标活动 RMS（dBFS）：鼓与贝斯在前，和弦 / 旋律居中，铺底在后
LEVEL_DB = {"drums": -20.0, "bass": -21.0, "chords": -25.0, "lead": -24.0, "pad": -28.0, "arp": -28.0, "perc": -27.0}


def fetch(ctx: Ctx) -> dict:
    """下载并校验 SoundFont 与其许可证原文；许可证不含 MIT 声明直接失败。"""
    sf = ctx.sources["soundfont"]
    sf2 = download(sf["url"], ctx.cache / sf["name"], sf["sha256"])
    lic = download(sf["license_url"], ctx.cache / "MuseScore_General_License.md", sf["license_sha256"])
    text = lic.read_text(encoding="utf-8", errors="replace")
    if sf["license_must_contain"] not in text:
        raise licenses.LicenseError("MuseScore_General 的许可证原文中没有 MIT 声明，拒绝使用")
    return {"sf2": str(sf2), "license": str(lic)}


def song_specs(per_style: int = PER_STYLE) -> list[dict]:
    """确定性的曲目清单（风格 × 序号 → 种子、标题、id）。"""
    specs, used = [], set()
    for si, (sid, st) in enumerate(STYLES.items()):
        for k in range(per_style):
            seed = 10_000 * (si + 1) + 97 * k + 13
            rng = random.Random(seed)
            while True:
                title = f"{rng.choice(ADJ)} {rng.choice(NOUN)}"
                if title not in used:
                    used.add(title)
                    break
            specs.append({"style": sid, "seed": seed, "title": title, "id": f"synth-{sid}-{slugify(title)}"})
    return specs


def _key_name(p: SongPlan) -> str:
    return f"{KEYS[p.root]} {p.mode}"


def _midi_channels(part: Part, notes: list[tuple], rep: int) -> list[dict]:
    drum = part.kind in ("drums", "perc")
    allnotes = [(s + r * 16.0, d, p, v) for r in range(rep) for (s, d, p, v) in notes]
    return [{"channel": 9 if drum else 0, "program": part.program, "notes": allnotes}]


def build(ctx: Ctx, only: set[str] | None = None, per_style: int = PER_STYLE) -> list[str]:
    """作曲 → 写 MIDI → 批量渲染 → 取每个乐句第二遍（自带前一遍的混响尾巴，可无缝循环）→ 存 Song。"""
    res = fetch(ctx)
    specs = [s for s in song_specs(per_style) if not only or s["id"] in only]
    jobs, plans = [], {}
    midi_root = ctx.work.parent / "midi"
    for sp in specs:
        st = STYLES[sp["style"]]
        p = plan(st, sp["seed"])
        plans[sp["id"]] = p
        beat = 60.0 / p.bpm
        for part in st.parts:
            for ph, name in enumerate("ABCD"):
                notes = phrase_notes(p, part, ph)
                f = midi_root / sp["id"] / f"{part.name.lower().replace(' ', '_')}_{name}.mid"
                write_smf(f, p.bpm, _midi_channels(part, notes, 2), title=f"{sp['title']} / {part.name} / {name}")
                jobs.append({"midi": f, "out": f.with_suffix(".f32"), "secs": 32 * beat})
    rust.render(Path(res["sf2"]), jobs)

    built = []
    for sp in specs:
        st, p = STYLES[sp["style"]], plans[sp["id"]]
        bs = 4 * 60.0 / p.bpm * SR
        L = int(round(4 * bs))  # 一个 4 小节乐句的样本数
        stems: dict[str, np.ndarray] = {}
        for part in st.parts:
            halves = []
            for name in "ABCD":
                f = midi_root / sp["id"] / f"{part.name.lower().replace(' ', '_')}_{name}.f32"
                raw = np.fromfile(f, dtype="<f4").reshape(-1, 2)
                halves.append(raw[L : 2 * L])  # 第二遍
            x = np.concatenate(halves)
            if audio.peak(x) < 1e-5:
                raise audio.AudioError(f"{sp['id']}/{part.name} 渲染为静音")
            # SoundFont 各乐器本身电平差很大：先按乐器类型把分轨调到统一的目标电平，再用 gain_db 微调
            stems[part.name] = audio.match_level(x, LEVEL_DB[part.kind] + 0.3 * part.gain_db)
        stems, _ = audio.normalize_mix(stems)
        title = sp["title"]
        song = Song(
            id=sp["id"], title=title, artist="UltraPads",
            description=f"Original {st.genre} loop kit at {p.bpm} BPM in {_key_name(p)}. "
                        f"4 sections (A–D) of 4 bars; each section is played in full by its {len(st.parts)} instrument pads.",
            origin="synth", license="CC0-1.0", source_url="https://github.com/PlutoKeating/Project.UltraPads/tree/main/tools/catalog",
            bpm=float(p.bpm), offset=0.0, genres=[st.genre], tags=sorted({*st.tags, _key_name(p).lower(), "original"}),
            stems=[StemMeta(pt.name, pt.role, f"{i + 1}_{pt.name.lower().replace(' ', '_')}.npy") for i, pt in enumerate(st.parts)],
            theme_color=THEME.get(st.parts[0].role, "#F49600"),
            attribution=licenses.attribution(title, "UltraPads", "CC0-1.0")
            + " — composition CC0; sounds rendered with the MuseScore_General SoundFont (MIT License).",
            extra={"seed": sp["seed"], "style": sp["style"], "key": _key_name(p), "notice_file": res["license"],
                   "soundfont": ctx.sources["soundfont"]["credits"]},
        )
        song.save(ctx.work, stems)
        built.append(song.id)
    return built
