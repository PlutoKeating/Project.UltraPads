"""许可证白名单与校验。未知许可证一律拒绝入库。

ID 与 docs/API.md §7.2 的 `license` 枚举一致，另加 ccMixter 大量使用的 CC-BY-NC-3.0 / CC-BY-NC-SA-3.0（API 枚举需同步）。派生字段：
  commercial_ok = 不含 NC；share_alike = 含 SA。
"""

from __future__ import annotations

import re

# id -> (显示名, 许可证原文 URL)
LICENSES: dict[str, tuple[str, str]] = {
    "CC0-1.0": ("CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/"),
    "PD": ("Public Domain", "https://creativecommons.org/publicdomain/mark/1.0/"),
    "CC-BY-3.0": ("CC BY 3.0", "https://creativecommons.org/licenses/by/3.0/"),
    "CC-BY-4.0": ("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
    "CC-BY-SA-3.0": ("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0/"),
    "CC-BY-SA-4.0": ("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
    "CC-BY-NC-3.0": ("CC BY-NC 3.0", "https://creativecommons.org/licenses/by-nc/3.0/"),
    "CC-BY-NC-SA-3.0": ("CC BY-NC-SA 3.0", "https://creativecommons.org/licenses/by-nc-sa/3.0/"),
    "CC-BY-NC-4.0": ("CC BY-NC 4.0", "https://creativecommons.org/licenses/by-nc/4.0/"),
    "CC-BY-NC-SA-4.0": ("CC BY-NC-SA 4.0", "https://creativecommons.org/licenses/by-nc-sa/4.0/"),
}

_URL_RE = re.compile(
    r"creativecommons\.org/(?:licenses/(?P<kind>by(?:-nc)?(?:-sa)?(?:-nd)?)/(?P<ver>\d\.\d)"
    r"|publicdomain/(?P<pd>zero|mark)/1\.0)",
    re.I,
)


class LicenseError(ValueError):
    """许可证不在白名单（或无法识别）。"""


def from_url(url: str) -> str:
    """CC 许可证 URL → 白名单 ID；不认识或不在白名单（含 ND）抛 LicenseError。"""
    m = _URL_RE.search(url or "")
    if not m:
        raise LicenseError(f"无法识别的许可证 URL：{url!r}")
    if m.group("pd"):
        lic = "CC0-1.0" if m.group("pd").lower() == "zero" else "PD"
    else:
        lic = f"CC-{m.group('kind').upper()}-{m.group('ver')}"
    return require(lic)


def require(lic: str) -> str:
    if lic not in LICENSES:
        raise LicenseError(f"许可证 {lic!r} 不在白名单（{', '.join(LICENSES)}）")
    return lic


def commercial_ok(lic: str) -> bool:
    return "-NC-" not in require(lic)


def share_alike(lic: str) -> bool:
    return "-SA-" in require(lic)


def url_of(lic: str) -> str:
    return LICENSES[require(lic)][1]


def label_of(lic: str) -> str:
    return LICENSES[require(lic)][0]


def attribution(title: str, artist: str, lic: str, source_url: str | None = None) -> str:
    """应用内与 Kit 元数据里原样展示的署名行。"""
    s = f"“{title}” by {artist}, {label_of(lic)}"
    return f"{s} ({source_url})" if source_url else s
