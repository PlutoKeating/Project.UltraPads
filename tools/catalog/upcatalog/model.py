"""管线内部的数据模型：Song（一首歌 = 对齐到小节的若干分轨 + 元数据）与目录条目。"""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path

import numpy as np

from . import SR, licenses

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{2,63}$")

# 乐器角色 → pad 颜色（up_format::kit::ColorRole）
ROLE_COLOR = {
    "drums": "orange", "perc": "yellow", "bass": "purple", "chords": "green", "keys": "green",
    "lead": "pink", "vocals": "pink", "guitar": "red", "pad": "aqua", "strings": "aqua",
    "arp": "lime", "fx": "blue", "mix": "blue",
}
THEME = {"drums": "#F49600", "bass": "#9013FE", "chords": "#0DD600", "lead": "#FA4F84", "pad": "#2AD5FA"}


def slugify(s: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return re.sub(r"-{2,}", "-", s)[:64].strip("-")


@dataclass
class StemMeta:
    name: str  # 显示名，如 "Drums"
    role: str  # ROLE_COLOR 的键
    file: str  # work/<id>/stems/ 下的 .npy


@dataclass
class Song:
    id: str
    title: str
    artist: str
    description: str
    origin: str  # album | online | synth
    license: str
    source_url: str
    bpm: float
    offset: float = 0.0  # 第 0 小节起点（秒），stems 已对齐时为 0
    genres: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    stems: list[StemMeta] = field(default_factory=list)
    theme_color: str = "#F49600"
    attribution: str = ""
    extra: dict = field(default_factory=dict)  # 来源特有信息（Zenodo 记录号、ccMixter 上传 ID 等）

    def validate(self) -> None:
        if not ID_RE.match(self.id):
            raise ValueError(f"非法 id：{self.id!r}")
        licenses.require(self.license)
        if not 20 <= self.bpm <= 400:
            raise ValueError(f"{self.id}：BPM {self.bpm} 超出范围")
        if not 1 <= len(self.stems) <= 7:
            raise ValueError(f"{self.id}：音色组数 {len(self.stems)} 不在 1..=7")
        for s in self.stems:
            if s.role not in ROLE_COLOR:
                raise ValueError(f"{self.id}：未知乐器角色 {s.role!r}")
        if not self.attribution:
            raise ValueError(f"{self.id}：缺少署名")

    # ---- 持久化
    def save(self, work: Path, stems: dict[str, np.ndarray]) -> None:
        d = work / self.id
        (d / "stems").mkdir(parents=True, exist_ok=True)
        for m in self.stems:
            np.save(d / "stems" / m.file, stems[m.name].astype(np.float32))
        (d / "song.json").write_text(json.dumps(asdict(self), ensure_ascii=False, indent=2), encoding="utf-8")

    @staticmethod
    def load(work: Path, id_: str) -> tuple["Song", dict[str, np.ndarray]]:
        d = work / id_
        raw = json.loads((d / "song.json").read_text(encoding="utf-8"))
        raw["stems"] = [StemMeta(**s) for s in raw["stems"]]
        song = Song(**raw)
        stems = {m.name: np.load(d / "stems" / m.file) for m in song.stems}
        return song, stems


def n_bars(x: np.ndarray, bpm: float, offset: float = 0.0) -> int:
    bar = 4 * 60.0 / bpm * SR
    return int((len(x) - offset * SR) // bar)
