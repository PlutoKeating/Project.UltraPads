"""分轨 → 段落组 / pad 布局，并生成 .upkit 目录（kit.json + samples/*.flac + 许可证文件）。

**一个音色组（A/B/C…）= 歌曲的一个完整段落（4 小节），组内一个 pad = 该段落的一个乐器分轨**：
同时打开同一组的全部 pad 就是完整的一段歌；换到另一组的同一乐器 pad 即换段落（同一乐器跨组互斥，`exclusive`）。
所有 pad 都是 Loop + Toggle + 按小节量化（`1bar`）。只有一条分轨的素材（整曲混音）在该组的空 pad 上补 2 小节 / 1 小节的片段。
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from . import SR, audio, licenses
from .model import ROLE_COLOR, Song, n_bars

LICENSE_FILE = "LICENSE.txt"
ATTRIBUTION_FILE = "ATTRIBUTION.txt"
SECTION_BARS = 4
MAX_SECTIONS = 8


def n_sections(bars: int) -> int:
    """素材共 `bars` 个小节 → 段落数（每段 4 小节，不足一段的尾巴丢弃）。"""
    return min(bars // SECTION_BARS, MAX_SECTIONS)


def fragment_plan() -> list[tuple[str, int, int]]:
    """整曲混音（只有一条分轨）时，段落内补充的片段 [(标签, 段内起始小节, 小节数)]。"""
    return [("2bar 1", 0, 2), ("2bar 2", 2, 2), ("1bar 1", 0, 1), ("1bar 2", 1, 1), ("1bar 3", 2, 1), ("1bar 4", 3, 1)]


def kit_uuid(song_id: str) -> str:
    """由条目 id 确定性派生的 Kit ID（UUIDv8 形态，同一条目每次打包得到同一个 ID，客户端重复下载自动去重）。"""
    import hashlib

    h = bytearray(hashlib.blake2b(f"ultrapads-catalog:{song_id}".encode(), digest_size=16).digest())
    h[6] = (h[6] & 0x0F) | 0x80
    h[8] = (h[8] & 0x3F) | 0x80
    x = h.hex()
    return f"urn:uuid:{x[:8]}-{x[8:12]}-{x[12:16]}-{x[16:20]}-{x[20:]}"


def license_text(song: Song) -> str:
    lic = song.license
    return (
        f"{song.title} — {song.artist}\n"
        f"License: {licenses.label_of(lic)} ({lic})\n{licenses.url_of(lic)}\n\n"
        f"{song.attribution}\n"
        + ("\nThis kit is a derivative arrangement; adaptations must be shared under the same license (ShareAlike).\n"
           if licenses.share_alike(lic) else "")
        + ("\nNon-commercial use only.\n" if not licenses.commercial_ok(lic) else "")
        + (f"\n{song.extra['notice']}\n" if song.extra.get("notice") else "")
    )


def build_kit_dir(song: Song, stems: dict[str, np.ndarray], out: Path) -> dict:
    """写 `out/kit.json`、`out/samples/*.flac`、许可证文件；返回条目统计。"""
    song.validate()
    if out.exists():
        for p in sorted(out.rglob("*"), reverse=True):
            p.unlink() if p.is_file() else p.rmdir()
    (out / "samples").mkdir(parents=True)
    pads, total_pad = [], 0
    first_loop_secs = None
    sections = n_sections(min(n_bars(stems[m.name], song.bpm, song.offset) for m in song.stems))
    if sections < 1:
        raise ValueError(f"{song.id}：不足 {SECTION_BARS} 小节")
    single = len(song.stems) == 1

    def add_pad(bank: int, index: int, meta, label: str, start: int, nb: int, excl: str) -> None:
        nonlocal total_pad, first_loop_secs
        seg = audio.slice_bars(stems[meta.name], song.bpm, start, nb, song.offset * SR)
        rel = f"samples/{'abcdefgh'[bank]}_{meta.role}{index + 1}_{label.replace(' ', '_').lower()}.flac"
        audio.encode_flac(seg, out / rel)
        pads.append({
            "addr": {"bank": bank, "index": index},
            "note": 36 + bank * 12 + index,
            "name": f"{meta.name} {label}",
            "color": ROLE_COLOR[meta.role],
            "kind": "loop",
            "launch": {"mode": "toggle", "quantize": "1bar", "retrigger": "restart"},
            "exclusive": excl,
            "tempo": {"bpm": song.bpm, "beats": nb * 4, "timeSignature": [4, 4], "stretch": "beats"},
            "layers": [{"sample": rel}],
        })
        total_pad += 1
        if first_loop_secs is None and nb == SECTION_BARS:
            first_loop_secs = len(seg) / SR

    for bank in range(sections):
        sec = "ABCDEFGH"[bank]
        for index, meta in enumerate(song.stems):  # pad 序号 = 乐器序号，各组一致
            add_pad(bank, index, meta, f"{sec}", bank * SECTION_BARS, SECTION_BARS, f"inst{index + 1}")
        if single:  # 整曲混音：补段内片段，供切分即兴
            for k, (label, start, nb) in enumerate(fragment_plan()):
                add_pad(bank, 1 + k, song.stems[0], f"{sec} {label}", bank * SECTION_BARS + start, nb, f"frag{bank}")
    doc = {
        "id": kit_uuid(song.id),
        "name": song.title,
        "description": song.description,
        "authors": [song.artist],
        "license": song.license,
        "genres": song.genres,
        "tags": song.tags,
        "tempo": {"bpm": song.bpm, "timeSignature": [4, 4]},
        "padCount": sections * 12,
        "pads": pads,
        "themeColor": song.theme_color,
        "source": {"kind": "catalog", "originalId": song.id, "originalName": song.source_url, "inspiredBy": song.attribution},
    }
    (out / "kit.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / LICENSE_FILE).write_text(license_text(song), encoding="utf-8")
    (out / ATTRIBUTION_FILE).write_text(song.attribution + "\n", encoding="utf-8")
    if song.extra.get("notice_file"):  # 第三方素材（如 SoundFont）要求随附的版权与许可声明原文
        (out / "NOTICE.txt").write_text(Path(song.extra["notice_file"]).read_text(encoding="utf-8"), encoding="utf-8")
    return {"pad_count": total_pad, "group_count": sections, "loop_secs": first_loop_secs or 4 * 4 * 60.0 / song.bpm}


def item_json(song: Song, stats: dict) -> dict:
    """data 服务 admin 接口用的元数据（docs/API.md §7.4；size / sha256 由服务端计算）。"""
    lic = song.license
    return {
        "id": song.id,
        "title": song.title,
        "artist": song.artist,
        "description": song.description,
        "origin": song.origin,
        "license": lic,
        "license_url": licenses.url_of(lic),
        "attribution": song.attribution,
        "source_url": song.source_url,
        "bpm": round(song.bpm),
        "genres": song.genres,
        "tags": song.tags,
        "group_count": stats["group_count"],
        "pad_count": stats["pad_count"],
        "duration_secs": round(stats["loop_secs"], 2),
        "theme_color": song.theme_color,
        "status": "draft",
    }
