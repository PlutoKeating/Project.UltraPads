"""上传到数据服务（docs/API.md §7.4）：先写元数据（draft）→ 上传 .upkit → 只有 --publish 才改成 published。

环境变量：ULTRAPADS_DATA_URL（例如 https://data.example.com/ultrapads）、ULTRAPADS_DATA_KEY、ULTRAPADS_ADMIN_KEY。
"""

from __future__ import annotations

import hashlib
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

from .paths import Ctx


class PublishError(RuntimeError):
    pass


def _env(name: str) -> str:
    v = os.environ.get(name, "").strip()
    if not v:
        raise PublishError(f"缺少环境变量 {name}")
    return v


def _headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {_env('ULTRAPADS_DATA_KEY')}", "X-Up-Admin": _env("ULTRAPADS_ADMIN_KEY")}


def _req(method: str, url: str, headers: dict, body: bytes | None = None, length: int | None = None, stream=None):
    h = {"User-Agent": "upcatalog-publish", **headers}
    if stream is not None:
        h["Content-Length"] = str(length)
    req = urllib.request.Request(url, data=stream if stream is not None else body, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        raise PublishError(f"{method} {url} → {e.code} {e.read()[:300]!r}") from e


def publish(ctx: Ctx, ids: list[str], make_published: bool = False, dry_run: bool = False) -> list[dict]:
    base = _env("ULTRAPADS_DATA_URL").rstrip("/") if not dry_run else os.environ.get("ULTRAPADS_DATA_URL", "(未设置)")
    results = []
    for id_ in ids:
        item = json.loads((ctx.out / "items" / f"{id_}.json").read_text(encoding="utf-8"))
        upkit = ctx.out / "kits" / f"{id_}.upkit"
        if not upkit.exists():
            raise PublishError(f"{id_}：还没有打包（先运行 pack）")
        sha = hashlib.sha256(upkit.read_bytes()).hexdigest()
        size = upkit.stat().st_size
        row = {"id": id_, "size": size, "sha256": sha, "status": "published" if make_published else "draft"}
        if dry_run:
            results.append({**row, "dry_run": True})
            continue
        h = _headers()
        meta = {**item, "status": "draft"}
        _req("PUT", f"{base}/v1/admin/catalog/{id_}", {**h, "Content-Type": "application/json"}, json.dumps(meta).encode())
        with open(upkit, "rb") as f:
            _req("PUT", f"{base}/v1/admin/catalog/{id_}/file", {**h, "Content-Type": "application/zip", "x-sha256": sha}, stream=f, length=size)
        if make_published:
            meta["status"] = "published"
            _req("PUT", f"{base}/v1/admin/catalog/{id_}", {**h, "Content-Type": "application/json"}, json.dumps(meta).encode())
        results.append(row)
    return results
