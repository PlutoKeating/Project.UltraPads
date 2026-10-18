"""最小的标准 MIDI 文件（SMF format 1）写入器：纯标准库，供 synth 来源输出原创 MIDI。"""

from __future__ import annotations

import struct
from pathlib import Path

PPQ = 480


def _vlq(n: int) -> bytes:
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


def _track(events: list[tuple[int, int, bytes]]) -> bytes:
    """events: (tick, order, 原始事件字节)；同 tick 按 order 排序（先 note-off 再 note-on）。"""
    events = sorted(events, key=lambda e: (e[0], e[1]))
    body, last = bytearray(), 0
    for tick, _, data in events:
        body += _vlq(tick - last) + data
        last = tick
    body += _vlq(0) + b"\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(body)) + bytes(body)


def write_smf(path: Path, bpm: float, channels: list[dict], title: str = "") -> None:
    """channels: [{channel, program, notes: [(start_beat, dur_beat, pitch, velocity)]}]。"""
    tempo = int(round(60_000_000 / bpm))
    meta = [(0, 0, b"\xff\x51\x03" + tempo.to_bytes(3, "big")), (0, 0, b"\xff\x58\x04\x04\x02\x18\x08")]
    if title:
        meta.append((0, 0, b"\xff\x03" + _vlq(len(title.encode())) + title.encode()))
    tracks = [_track(meta)]
    for ch in channels:
        c = ch["channel"] & 0x0F
        ev: list[tuple[int, int, bytes]] = [(0, 0, bytes([0xC0 | c, ch["program"] & 0x7F]))]
        for start, dur, pitch, vel in ch["notes"]:
            on = int(round(start * PPQ))
            off = max(on + 1, int(round((start + dur) * PPQ)))
            ev.append((on, 1, bytes([0x90 | c, pitch & 0x7F, max(1, min(127, int(vel)))])))
            ev.append((off, 0, bytes([0x80 | c, pitch & 0x7F, 0])))
        tracks.append(_track(ev))
    head = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), PPQ)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(head + b"".join(tracks))
