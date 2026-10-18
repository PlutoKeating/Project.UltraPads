from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]  # tools/catalog


@dataclass
class Ctx:
    root: Path = HERE

    @property
    def cache(self) -> Path:
        return self.root / ".cache"

    @property
    def work(self) -> Path:
        return self.root / "out" / "work"

    @property
    def out(self) -> Path:
        return self.root / "out"

    @property
    def sources(self) -> dict:
        return json.loads((self.root / "data" / "sources.json").read_text(encoding="utf-8"))

    def ensure(self) -> "Ctx":
        for p in (self.cache, self.work, self.out / "kits", self.out / "items", self.out / "preview"):
            p.mkdir(parents=True, exist_ok=True)
        return self
