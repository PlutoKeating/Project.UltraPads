"""人工抽检：每首歌一段试听 mp3（依次播放各段落，每段全部乐器同时）+ 每个乐器的 4 小节循环 + HTML 清单。"""

from __future__ import annotations

import html
import json
from pathlib import Path

import numpy as np

from . import SR, audio, layout, licenses
from .model import Song, n_bars
from .paths import Ctx


def arrangement(song: Song, stems: dict[str, np.ndarray]) -> np.ndarray:
    """按 A、B、C… 顺序依次播放每个段落（段落内全部乐器同时），与 App 里每组全开 pad 的效果一致。"""
    bs = int(round(4 * 60.0 / song.bpm * SR))
    names = [m.name for m in song.stems]
    sections = layout.n_sections(min(n_bars(stems[n], song.bpm, song.offset) for n in names))
    out = []
    for i in range(sections):
        seg = np.zeros((4 * bs, 2), dtype=np.float32)
        for n in names:
            x = stems[n][int(song.offset * SR) + i * 4 * bs : int(song.offset * SR) + (i + 1) * 4 * bs]
            seg[: len(x)] += x
        out.append(seg)
    mix = np.concatenate(out)
    p = audio.peak(mix)
    return mix * (0.9 / p) if p > 0.9 else mix


def build(ctx: Ctx, ids: list[str]) -> Path:
    rows = []
    for id_ in ids:
        song, stems = Song.load(ctx.work, id_)
        pdir = ctx.out / "preview" / id_
        audio.encode_mp3(arrangement(song, stems), pdir / "mix.mp3", "128k")
        layers = []
        bs = int(round(4 * 60.0 / song.bpm * SR))
        for m in song.stems:
            x = stems[m.name][int(song.offset * SR) : int(song.offset * SR) + 4 * bs]
            fn = f"{m.role}_{len(layers) + 1}.mp3"
            audio.encode_mp3(x, pdir / fn, "96k")
            layers.append((m.name, fn))
        item = json.loads((ctx.out / "items" / f"{id_}.json").read_text(encoding="utf-8"))
        ver_f = ctx.out / "items" / f"{id_}.verify.json"
        ver = json.loads(ver_f.read_text(encoding="utf-8")) if ver_f.exists() else {}
        rows.append((song, item, ver, layers))
    esc = html.escape
    parts = ["""<!doctype html><meta charset="utf-8"><title>UltraPads catalog preview</title>
<style>body{font:14px system-ui;margin:24px;background:#0e0f11;color:#eee}table{border-collapse:collapse;width:100%}
td,th{padding:6px 8px;border-bottom:1px solid #333;vertical-align:top}.nc{color:#f0a35e}.sa{color:#7fd}
details summary{cursor:pointer;color:#9ab}audio{height:28px;width:260px}</style><h1>UltraPads 目录预览（人工抽检）</h1>
<p>逐条确认：许可证与署名正确、节拍对齐（试听循环无爆音）、乐器分组合理。</p>
<table><tr><th>条目</th><th>来源 / 许可证</th><th>BPM</th><th>组/pad</th><th>试听</th></tr>"""]
    for song, item, ver, layers in rows:
        lic = item["license"]
        cls = "nc" if not licenses.commercial_ok(lic) else ("sa" if licenses.share_alike(lic) else "")
        size = f"{ver.get('bytes', 0) / 1e6:.1f} MB" if ver else "未打包"
        parts.append(
            f"<tr><td><b>{esc(item['title'])}</b><br><small>{esc(item['id'])} · {esc(item['artist'])}</small></td>"
            f"<td>{esc(item['origin'])}<br><span class='{cls}'>{esc(lic)}</span><br><small>{esc(item['attribution'])}</small>"
            f"<br><a href='{esc(item['source_url'])}' style='color:#9ab'>来源</a></td>"
            f"<td>{item['bpm']}</td><td>{item['group_count']} / {item['pad_count']}<br><small>{size}</small></td>"
            f"<td><audio controls preload='none' src='{esc(song.id)}/mix.mp3'></audio>"
            f"<details><summary>各乐器第一段（A）4 小节循环</summary>"
            + "".join(f"<div>{esc(n)} <audio controls loop preload='none' src='{esc(song.id)}/{esc(fn)}'></audio></div>" for n, fn in layers)
            + "</details></td></tr>"
        )
    parts.append("</table>")
    path = ctx.out / "preview" / "index.html"
    path.write_text("".join(parts), encoding="utf-8")
    return path
