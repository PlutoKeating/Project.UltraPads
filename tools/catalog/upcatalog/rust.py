"""调用 up-catalog-pack（Rust）：打包 .upkit、验证、SoundFont 渲染。"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # 仓库根
TARGET_BIN = ROOT / "target" / "release" / "up-catalog-pack"


def binary() -> Path:
    env = os.environ.get("UP_CATALOG_PACK")
    if env:
        return Path(env)
    if not TARGET_BIN.exists():
        subprocess.run(["cargo", "build", "-p", "up-catalog-pack", "--release"], cwd=ROOT, check=True)
    return TARGET_BIN


def _run(args: list[str]) -> str:
    p = subprocess.run([str(binary()), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"up-catalog-pack {args[0]} 失败：{p.stderr.strip()}")
    return p.stdout


def pack(kit_dir: Path, out: Path, timestamp: str = "2026-10-18T00:00:00Z") -> Path:
    _run(["pack", "--dir", str(kit_dir), "--out", str(out), "--timestamp", timestamp])
    return out


def verify(upkit: Path) -> dict:
    return json.loads(_run(["verify", str(upkit)]))


def render(sf2: Path, jobs: list[dict], threads: int | None = None, sample_rate: int = 44100) -> None:
    """jobs: [{midi, out, secs}] → out 为交错立体声 f32le 原始样本。"""
    import tempfile

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump([{**j, "midi": str(j["midi"]), "out": str(j["out"])} for j in jobs], f)
        path = f.name
    try:
        _run(["render", "--sf2", str(sf2), "--jobs", path, "--threads", str(threads or os.cpu_count() or 4),
              "--sample-rate", str(sample_rate)])
    finally:
        os.unlink(path)
