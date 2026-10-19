"""来源 ③：online —— ccMixter（https://ccmixter.org/api/query，无需 key）。

只收白名单内的 CC 许可证（每条上传以自己的 license_url 为准；Sampling Plus、ND 等一律丢弃），且必须带 `bpm_xxx_yyy` 速度标签。
两种形态：
  stems  上传里有 3 个以上等长的独立分轨（bass / piano / drums …）→ 按乐器分组的多组 Kit；
  mix    只有一条完整混音 → 估计速度与小节起点，取 8 小节窗口做成单组 Kit。
Jamendo、Freesound 需要申请 API key，本期不做（见 README）。
"""

from __future__ import annotations

import json
import re
import subprocess
import urllib.parse
from pathlib import Path

import numpy as np

from .. import SR, audio, licenses
from ..analyze import estimate_grid
from ..http import download
from ..model import Song, StemMeta, slugify
from ..paths import Ctx
from .album import pick_window

API = "https://ccmixter.org/api/query"
QUERIES = [("stems", 10), ("multitrack", 6), ("loops", 14), ("instrumental", 14), ("acapella", 4)]  # (标签, 页数)；每页 15 条（更大的 limit 会让响应被截断）
PAGE = 15

# 文件名 → 乐器组（按顺序匹配，先到先得）
ROLE_RX = [
    ("Drums", "drums", r"drum|beat|kick|snare|hat|perc|cymbal|break"),
    ("Bass", "bass", r"\bbass|sub\b"),
    ("Vocals", "vocals", r"vox|vocal|voice|choir|sing|acap|lead v|back v"),
    ("Guitar", "guitar", r"guitar|gtr|uke|banjo"),
    ("Keys", "keys", r"piano|keys|rhodes|organ|epiano|wurli|clav"),
    ("Strings", "strings", r"string|violin|cello|viola|orchestra"),
    ("Lead", "lead", r"lead|melod|solo|brass|horn|flute|sax|trumpet"),
    ("Pad", "pad", r"pad|atmos|ambien|drone|texture|noise|fx|synth|arp|chord|sequence"),
]


def _query(**kw) -> list[dict]:
    url = f"{API}?" + urllib.parse.urlencode({"f": "json", **kw})
    for _ in range(4):
        p = subprocess.run(["curl", "-sS", "-m", "60", url], capture_output=True)
        if p.returncode == 0 and p.stdout.strip():
            try:
                return json.loads(p.stdout.decode("utf-8", errors="replace"))
            except ValueError:
                pass
    return []


def _secs(ps: str | None) -> float:
    if not ps:
        return 0.0
    parts = [int(x) for x in ps.split(":")]
    return float(sum(v * 60 ** i for i, v in enumerate(reversed(parts))))


def classify(role_name: str) -> tuple[str, str] | None:
    for name, role, rx in ROLE_RX:
        if re.search(rx, role_name, re.I):
            return name, role
    return None


def _artist(u: dict) -> str:
    real, handle = str(u.get("user_real_name") or "").strip(), str(u["user_name"]).strip()
    return handle if not real or real.lower() == handle.lower() else f"{real} ({handle})"


def candidate(u: dict) -> dict | None:
    """一条 ccMixter 上传 → 候选（许可证 / 速度 / 文件不满足条件返回 None）。"""
    try:
        lic = licenses.from_url(u["license_url"])
    except licenses.LicenseError:
        return None
    m = re.search(r"bpm_(\d+)_(\d+)", u["upload_extra"].get("ccud", "") + "," + u["upload_extra"].get("usertags", ""))
    if not m:
        return None
    lo, hi = int(m.group(1)), int(m.group(2))
    files = []
    for f in u.get("files", []):
        fmt = f.get("file_format_info", {})
        if fmt.get("media-type") != "audio" or fmt.get("default-ext") not in ("mp3", "flac", "wav", "ogg"):
            continue
        files.append({"name": f["file_nicname"], "url": f["download_url"], "ext": fmt["default-ext"], "secs": _secs(fmt.get("ps")), "id": f["file_id"]})
    if not files:
        return None
    main = max(files, key=lambda f: f["secs"])
    stems = [f for f in files if f is not main and abs(f["secs"] - main["secs"]) <= 2.0 and f["secs"] >= 10
             and not re.search(r"remix|mix$|full|master|instrumental|^mp3$", f["name"], re.I)]
    kind = "stems" if len(stems) >= 3 else "mix"
    return {"id": u["upload_id"], "title": str(u["upload_name"]).strip(), "artist": _artist(u),
            "user": str(u["user_name"]), "license": lic, "license_url": licenses.url_of(lic), "page": u["file_page_url"],
            "bpm_lo": lo, "bpm_hi": hi, "main": main, "stems": stems, "kind": kind, "tags": u["upload_extra"].get("usertags", "")}


def fetch(ctx: Ctx) -> dict:
    out: dict[int, dict] = {}
    skipped = {"license": 0, "other": 0}
    for tag, pages in QUERIES:
        for pg in range(pages):
            rows = _query(limit=PAGE, offset=pg * PAGE, tags=tag, sort="rank", dir="desc")
            if not rows:
                break
            for u in rows:
                c = candidate(u)
                if c is None:
                    skipped["other"] += 1
                elif c["id"] not in out:
                    out[c["id"]] = c
    path = ctx.cache / "ccmixter_candidates.json"
    path.write_text(json.dumps(sorted(out.values(), key=lambda c: (c["kind"] != "stems", -len(c["stems"]))), ensure_ascii=False, indent=1), encoding="utf-8")
    kinds = {k: sum(1 for c in out.values() if c["kind"] == k) for k in ("stems", "mix")}
    lic = {}
    for c in out.values():
        lic[c["license"]] = lic.get(c["license"], 0) + 1
    return {"candidates": len(out), **kinds, "licenses": lic, "rejected": skipped["other"]}


def _fetch_audio(ctx: Ctx, f: dict, uid: int, page: str) -> np.ndarray:
    # ccMixter 的下载地址有防盗链：必须带上该上传的页面作为 Referer，否则 403
    p = download(f["url"], ctx.cache / "ccmixter" / f"{uid}_{f['id']}.{f['ext']}", headers={"Referer": page})
    return audio.decode(p)


def _in_range(bpm: float, lo: int, hi: int) -> bool:
    return lo - 2.5 <= bpm <= hi + 2.5


def _attr(c: dict, lic: str, changes: str) -> str:
    return (f"“{c['title']}” by {c['artist']} (ccMixter: {c['page']}), {licenses.label_of(lic)}. {changes}")


GENRE_TAGS = [("hip_hop", "hip-hop"), ("hiphop", "hip-hop"), ("trip_hop", "trip-hop"), ("ambient", "ambient"), ("chill", "chill"), ("downtempo", "downtempo"),
              ("house", "house"), ("trance", "trance"), ("dance", "dance"), ("disco", "disco"), ("funk", "funk"), ("jazz", "jazz"), ("blues", "blues"),
              ("rock", "rock"), ("folk", "folk"), ("classical", "classical"), ("pop", "pop"), ("reggae", "reggae"), ("electronic", "electronic")]


def genres_of(tags: str) -> list[str]:
    """ccMixter 用户标签 → 曲风（取前两个匹配）；没有任何曲风标签的归为 other。"""
    ts = [t.strip().lower() for t in tags.split(",") if t.strip()]
    out = [g for key, g in GENRE_TAGS if any(key == t or key in t for t in ts)]
    return list(dict.fromkeys(out))[:2] or ["other"]


def _song(c: dict, groups: dict[str, np.ndarray], roles: dict[str, str], bpm: float, window_bar: int, kind: str, win: int = 8) -> Song:
    lic = c["license"]
    names = list(groups)
    return Song(
        id=f"online-{slugify(c['title'])[:40].strip('-')}-{c['id']}", title=c["title"], artist=c["artist"],
        description=f"{'Multitrack stems' if kind == 'stems' else 'Full mix'} from ccMixter at {round(bpm)} BPM, "
                    f"{win} bars from bar {window_bar + 1}: {win // 4} sections of 4 bars, each played in full by {len(names)} pad{'s' if len(names) > 1 else ''}.",
        origin="online", license=lic, source_url=c["page"], bpm=bpm, offset=0.0, genres=genres_of(c["tags"]),
        tags=sorted({"ccmixter", kind, *[t for t in c["tags"].split(",") if t and not t.startswith("bpm_")][:4]}),
        stems=[StemMeta(n, roles[n], f"{i + 1}_{slugify(n)}.npy") for i, n in enumerate(names)],
        theme_color="#2AD5FA",
        attribution=_attr(c, lic, "Changes: trimmed, cut into loops, loudness-normalized."),
        extra={"ccmixter_id": c["id"], "kind": kind, "notice": f"Source: {c['page']} — licensed {licenses.label_of(lic)} ({c['license_url']}). Modified from the original upload."},
    )


def build(ctx: Ctx, only: set[str] | None = None, limit: int = 24) -> list[str]:
    cand_path = ctx.cache / "ccmixter_candidates.json"
    if not cand_path.exists():
        fetch(ctx)
    cands = json.loads(cand_path.read_text(encoding="utf-8"))
    built: list[str] = []
    for c in cands:
        if len(built) >= limit:
            break
        try:
            lic = licenses.require(c["license"])  # 入库前再核对一遍
            if c["kind"] == "stems":
                groups_raw: dict[str, list[np.ndarray]] = {}
                roles: dict[str, str] = {}
                for f in c["stems"]:
                    cl = classify(f["name"])
                    if cl is None:
                        continue
                    groups_raw.setdefault(cl[0], []).append(_fetch_audio(ctx, f, c["id"], c["page"]))
                    roles[cl[0]] = cl[1]
                if len(groups_raw) < 3:
                    continue
                groups = {}
                for k, parts in groups_raw.items():
                    n = min(len(p) for p in parts)
                    groups[k] = np.sum([p[:n] for p in parts], axis=0).astype(np.float32)
                n = min(len(g) for g in groups.values())
                groups = {k: g[:n] for k, g in groups.items()}
                ref = groups.get("Drums") if "Drums" in groups else sum(groups.values())
            else:
                mix = _fetch_audio(ctx, c["main"], c["id"], c["page"])
                groups, roles, ref = {"Mix": mix}, {"Mix": "mix"}, mix
            grid = estimate_grid(ref, lo=max(60, c["bpm_lo"] - 3), hi=c["bpm_hi"] + 3)
            if not grid.reliable or not _in_range(grid.bpm, c["bpm_lo"], c["bpm_hi"]):
                print(f"[online] {c['title']} ({c['id']}): 速度不可靠 {grid}，丢弃")
                continue
            win = 16  # 4 个 4 小节段落；找不到时退到 8 小节
            picked = pick_window(groups, grid.bpm, grid.offset, bars=win, min_start_s=4.0, min_groups=min(3, len(groups)))
            if picked is None:
                win = 8
                picked = pick_window(groups, grid.bpm, grid.offset, bars=win, min_start_s=4.0, min_groups=min(3, len(groups)))
            if picked is None:
                print(f"[online] {c['title']} ({c['id']}): 没有合适的 8 小节窗口，丢弃")
                continue
            bar, active = picked
            groups = {k: groups[k] for k in active}
            bs = 4 * 60.0 / grid.bpm
            a = int(round((grid.offset + bar * bs) * SR))
            z = a + int(round(win * bs * SR))
            stems = {k: v[a:z] for k, v in groups.items()}
            stems, _ = audio.normalize_mix(stems)
            song = _song(c, groups, roles, grid.bpm, bar, c["kind"], win)
            if only and song.id not in only:
                continue
            song.save(ctx.work, stems)
            built.append(song.id)
            print(f"[online] {song.id}: {c['kind']} {lic} {grid.bpm:.1f} BPM 第 {bar + 1} 小节起 {len(stems)} 组")
        except (licenses.LicenseError, audio.AudioError, RuntimeError) as e:
            print(f"[online] {c.get('title')} ({c.get('id')}): {e}，丢弃")
    return built
