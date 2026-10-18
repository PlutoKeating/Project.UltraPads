"""带重试的下载与 HTTP Range 读取（沙箱网络不稳，超时直接重试）。"""

from __future__ import annotations

import hashlib
import io
import time
import urllib.request
from pathlib import Path

UA = "upcatalog/1.0 (+https://github.com/PlutoKeating/Project.UltraPads)"


def get(url: str, timeout: int = 60, tries: int = 5, headers: dict | None = None) -> bytes:
    err = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            err = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"下载失败 {url}: {err}")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path, sha256: str | None = None, tries: int = 5, headers: dict | None = None) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and (sha256 is None or sha256_file(dest) == sha256):
        return dest
    tmp = dest.with_suffix(dest.suffix + ".part")
    for attempt in range(tries):
        try:
            have = tmp.stat().st_size if tmp.exists() else 0
            req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {}), **({"Range": f"bytes={have}-"} if have else {})})
            with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "ab" if have and r.status == 206 else "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            break
        except Exception as e:  # noqa: BLE001
            if attempt == tries - 1:
                raise RuntimeError(f"下载失败 {url}: {e}") from e
            time.sleep(2 * (attempt + 1))
    tmp.rename(dest)
    if sha256 and sha256_file(dest) != sha256:
        dest.unlink()
        raise RuntimeError(f"{dest.name} 的 sha256 与记录不符")
    return dest


class RangeFile(io.RawIOBase):
    """把 HTTP 资源当作可 seek 的文件读（zipfile 读中央目录用）。"""

    def __init__(self, url: str):
        self.url, self.pos = url, 0
        req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": UA})
        self.size = int(urllib.request.urlopen(req, timeout=60).headers["Content-Length"])

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos

    def readinto(self, b):
        n = len(b)
        if n == 0 or self.pos >= self.size:
            return 0
        data = read_range(self.url, self.pos, min(self.pos + n, self.size) - 1)
        b[: len(data)] = data
        self.pos += len(data)
        return len(data)


def read_range(url: str, start: int, end: int, tries: int = 6) -> bytes:
    err = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Range": f"bytes={start}-{end}"})
            return urllib.request.urlopen(req, timeout=90).read()
        except Exception as e:  # noqa: BLE001
            err = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"Range 读取失败 {url}: {err}")
