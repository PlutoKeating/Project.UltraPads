"""来源 ②：album —— AlbumDB（Zenodo 19683001，CC BY 4.0，Tom McKenzie）的真实多轨。

stems_mixed.zip 有 5 GB，里面每个分轨是 deflate 压缩的 WAV。这里用 HTTP Range 读 zip 中央目录，
再对每个需要的分轨只取压缩流的**开头一段**（deflate 可以顺序解压到任意位置），不下载整个包。
流程：下载每首歌各乐器组的前 N 秒 → 用鼓组估计恒定速度与小节起点 → 选出各组都有声音且能量最高的 8 小节 → 存为 Song。
"""

from __future__ import annotations

import io
import json
import re
import struct
import zipfile
import zlib
from pathlib import Path

import numpy as np

from .. import SR, audio, licenses
from ..analyze import estimate_grid
from ..http import RangeFile, read_range
from ..model import Song, StemMeta, slugify
from ..paths import Ctx

PREFIX_SECS = 130  # 每个分轨取开头多少秒
WINDOW_BARS = 16  # 4 个 4 小节段落；找不到时退到 8 小节（2 个段落）

# 乐器组 → 文件名正则（在歌曲目录内匹配）。顺序 = 音色组顺序。
GROUPS = [
    ("Drums", "drums", r"^drums_(kick|snare\w*|overheads|toms)\.wav$"),
    ("Bass", "bass", r"^bass\.wav$"),
    ("Guitar", "guitar", r"^guitar_(electric_(rhythm\w*|smooth\w*|strum\w*|heavy\w*)|acoustic\w*)\.wav$"),
    ("Keys", "keys", r"^(keys_\w+|ukelele)\.wav$"),
    ("Vocals", "vocals", r"^vox_lead\.wav$"),
    ("Backing", "vocals", r"^vox_(backing|back)_\w+\.wav$|^vox_backing\.wav$"),
    ("Perc", "perc", r"^perc_(shaker|tapping|tambourine|triangle|glockenspiel|claps)\.wav$"),
]
SONGS = ["02 No More Mr Nice Guy", "03 Karma", "05 Diva", "04 Magistrates"]


def _zip(ctx: Ctx) -> tuple[str, zipfile.ZipFile]:
    url = ctx.sources["album"]["zip_url"]
    return url, zipfile.ZipFile(io.BufferedReader(RangeFile(url), buffer_size=1 << 20))


def fetch(ctx: Ctx) -> dict:
    """读 zip 中央目录并核对许可证（Zenodo 记录必须是 cc-by-4.0）。"""
    from ..http import get

    meta = json.loads(get(f"https://zenodo.org/api/records/{ctx.sources['album']['zenodo_record']}"))
    lic = meta["metadata"]["license"]["id"]
    if lic != "cc-by-4.0":
        raise licenses.LicenseError(f"AlbumDB 的许可证现在是 {lic!r}，与管线记录的 cc-by-4.0 不符，拒绝入库")
    idx = ctx.cache / "album_index.json"
    if not idx.exists():
        _, z = _zip(ctx)
        idx.write_text(json.dumps([{"name": i.filename, "off": i.header_offset, "csize": i.compress_size, "size": i.file_size, "ctype": i.compress_type}
                                   for i in z.infolist() if not i.is_dir()]), encoding="utf-8")
    entries = json.loads(idx.read_text(encoding="utf-8"))
    return {"license": lic, "entries": len(entries), "doi": meta["metadata"]["doi"]}


def read_prefix(url: str, e: dict, max_out: int) -> bytes:
    """读 zip 条目解压后的开头 max_out 字节。"""
    hdr = read_range(url, e["off"], e["off"] + 29)
    nlen, elen = struct.unpack("<HH", hdr[26:30])
    pos = e["off"] + 30 + nlen + elen
    end = pos + e["csize"]
    if e["ctype"] == 0:
        return read_range(url, pos, min(pos + max_out, end) - 1)
    d = zlib.decompressobj(-15)
    out = bytearray()
    while len(out) < max_out and pos < end:
        step = min(4 << 20, end - pos)
        out += d.decompress(read_range(url, pos, pos + step - 1))
        pos += step
    return bytes(out[:max_out])


def parse_wav(raw: bytes) -> np.ndarray:
    """16 位 PCM WAV（可能被截断）→ (n,2) float32。"""
    if raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        raise ValueError("不是 WAV")
    pos, fmt = 12, None
    while pos + 8 <= len(raw):
        cid, size = raw[pos : pos + 4], struct.unpack("<I", raw[pos + 4 : pos + 8])[0]
        if cid == b"fmt ":
            tag, ch, sr, _, _, bits = struct.unpack("<HHIIHH", raw[pos + 8 : pos + 24])
            fmt = (tag, ch, sr, bits)
        elif cid == b"data":
            if not fmt or fmt[3] != 16 or fmt[2] != SR:
                raise ValueError(f"只支持 16 位 44.1 kHz WAV，实际 {fmt}")
            body = raw[pos + 8 : pos + 8 + size]
            ch = fmt[1]
            body = body[: len(body) // (2 * ch) * (2 * ch)]
            x = np.frombuffer(body, dtype="<i2").astype(np.float32) / 32768.0
            x = x.reshape(-1, ch)
            return np.repeat(x, 2, axis=1) if ch == 1 else x[:, :2].copy()
        pos += 8 + size + (size & 1)
    raise ValueError("WAV 没有 data 块")


def _load_stem(ctx: Ctx, url: str, entry: dict, secs: int) -> np.ndarray:
    cache = ctx.cache / "album" / (re.sub(r"[^A-Za-z0-9._-]+", "_", entry["name"]) + f".{secs}s.npy")
    if cache.exists():
        return np.load(cache)
    x = parse_wav(read_prefix(url, entry, secs * SR * 4 + 4096))
    x = x[: secs * SR]
    cache.parent.mkdir(parents=True, exist_ok=True)
    np.save(cache, x)
    return x


def _sum(parts: list[np.ndarray]) -> np.ndarray:
    n = min(len(p) for p in parts)
    out = np.zeros((n, 2), dtype=np.float32)
    for p in parts:
        out += p[:n]
    return out


def pick_window(groups: dict[str, np.ndarray], bpm: float, offset: float, bars: int = WINDOW_BARS, min_start_s: float = 12.0,
                min_groups: int | None = None) -> tuple[int, list[str]] | None:
    """选从第几小节开始的 `bars` 小节窗口，返回 (起始小节, 有声音的乐器组)。

    窗口内静音（< -50 dBFS）的乐器组会被丢掉，活跃组数要 >= min_groups（缺省 = 全部）；
    组数多的窗口优先，其次看最安静的组与平均能量；起点按 4 小节对齐。
    """
    bs = 4 * 60.0 / bpm
    need = min_groups or len(groups)
    n = min(len(g) for g in groups.values())
    total = int((n / SR - offset) // bs)
    best, best_key = None, None
    for b in range(int(np.ceil(min_start_s / bs)), total - bars + 1):
        if b % 4:
            continue
        a, z = int((offset + b * bs) * SR), int((offset + (b + bars) * bs) * SR)
        if z > n:
            break
        levels = {k: audio.rms_db(g[a:z]) for k, g in groups.items()}
        active = [k for k, v in levels.items() if v >= -50]
        if len(active) < need:
            continue
        vals = [levels[k] for k in active]
        key = (len(active), min(vals) * 0.5 + float(np.mean(vals)))
        if best is None or key > best:
            best, best_key = key, (b, active)
    return best_key


def build(ctx: Ctx, only: set[str] | None = None, limit: int | None = None) -> list[str]:
    info = fetch(ctx)
    entries = json.loads((ctx.cache / "album_index.json").read_text(encoding="utf-8"))
    url = ctx.sources["album"]["zip_url"]
    A = ctx.sources["album"]
    built = []
    for folder in SONGS[: limit or len(SONGS)]:
        title = folder.split(" ", 1)[1]
        id_ = f"album-{slugify(title)}"
        if only and id_ not in only:
            continue
        files = [e for e in entries if e["name"].startswith(f"stems_mixed/{folder}/") and Path(e["name"]).name[0] != "."]
        groups: dict[str, np.ndarray] = {}
        meta: dict[str, str] = {}
        for gname, role, rx in GROUPS:
            sel = [e for e in files if re.match(rx, Path(e["name"]).name)]
            if not sel:
                continue
            groups[gname] = _sum([_load_stem(ctx, url, e, PREFIX_SECS) for e in sel])
            meta[gname] = role
        if len(groups) < 4:
            print(f"[album] {folder}：可用乐器组不足（{list(groups)}），跳过")
            continue
        grid = estimate_grid(groups["Drums"] if "Drums" in groups else _sum(list(groups.values())), lo=75, hi=170)
        if not grid.reliable:
            print(f"[album] {folder}：速度不稳定 {grid}，跳过")
            continue
        win = WINDOW_BARS
        picked = pick_window(groups, grid.bpm, grid.offset, bars=win, min_groups=4)
        if picked is None:
            win = WINDOW_BARS // 2
            picked = pick_window(groups, grid.bpm, grid.offset, bars=win, min_groups=4)
        if picked is None:
            print(f"[album] {folder}：找不到至少 4 个乐器组有声音的 {win} 小节，跳过")
            continue
        bar, active = picked
        groups = {k: groups[k] for k in active}
        bs = 4 * 60.0 / grid.bpm
        a = int(round((grid.offset + bar * bs) * SR))
        z = a + int(round(win * bs * SR))
        stems = {k: v[a:z] for k, v in groups.items()}
        stems, _ = audio.normalize_mix(stems)
        names = list(groups)
        meta = {k: meta[k] for k in names}
        attribution = (f"“{title}” by {A['artist']} from the album “Extraordinary” (AlbumDB multitrack dataset, {A['authors']}, "
                       f"DOI {A['doi']}), CC BY 4.0. Changes: stems summed per instrument group, cut into loops, loudness-normalized.")
        song = Song(
            id=id_, title=title, artist=A["artist"],
            description=f"Real multitrack recording of “{title}” (indie rock/folk) at {round(grid.bpm)} BPM, "
                        f"bars {bar + 1}–{bar + win}: {win // 4} sections of 4 bars, each played in full by {len(names)} instrument pads.",
            origin="album", license="CC-BY-4.0", source_url=A["record_url"], bpm=grid.bpm, offset=0.0,
            genres=["indie rock", "folk"], tags=["album", "live-band", "multitrack"],
            stems=[StemMeta(n, meta[n], f"{i + 1}_{n.lower()}.npy") for i, n in enumerate(names)],
            theme_color="#FA4F84", attribution=attribution,
            extra={"zenodo_record": A["zenodo_record"], "folder": folder, "window_bar": bar, "grid_confidence": grid.confidence,
                   "notice": f"Source: {A['record_url']} — {A['name']}. Licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). "
                             "Modified from the original stems (summed, trimmed, normalized)."},
        )
        song.save(ctx.work, stems)
        built.append(id_)
        print(f"[album] {id_}: {grid.bpm} BPM (置信 {grid.confidence:.1f}, 漂移 {grid.drift:.4f})，第 {bar + 1} 小节起，{len(names)} 组")
    return built
