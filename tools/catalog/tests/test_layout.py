import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

from upcatalog import SR, audio, licenses, rust
from upcatalog.layout import build_kit_dir, item_json, pad_plan
from upcatalog.model import Song, StemMeta


def tone_stems(bpm=100.0, bars=8):
    n = int(bars * 4 * 60 / bpm * SR)
    t = np.arange(n) / SR
    out = {}
    for name, hz in (("Drums", 80.0), ("Bass", 55.0)):
        s = (np.sin(2 * np.pi * hz * t) * 0.4).astype(np.float32)
        out[name] = np.stack([s, s], axis=1)
    return out


def song(license="CC0-1.0"):
    return Song(
        id="test-song", title="Test Song", artist="Tester", description="d", origin="synth", license=license,
        source_url="https://example.com", bpm=100.0, genres=["house"], tags=["t"],
        stems=[StemMeta("Drums", "drums", "drums.npy"), StemMeta("Bass", "bass", "bass.npy")],
        attribution=licenses.attribution("Test Song", "Tester", license),
    )


class LayoutTest(unittest.TestCase):
    def test_plan_sizes(self):
        self.assertEqual(len(pad_plan(8)), 12)
        self.assertEqual(sum(n for _, _, n in pad_plan(8)), 4 + 4 + 8 + 6)
        self.assertEqual(len(pad_plan(4)), 7)
        self.assertEqual(len(pad_plan(2)), 2)
        self.assertEqual(pad_plan(0), [])
        for bars in (2, 4, 8, 16):
            for _, start, n in pad_plan(bars):
                self.assertLessEqual(start + n, bars)

    def test_slice_is_bar_exact(self):
        x = tone_stems()["Drums"]
        seg = audio.slice_bars(x, 100.0, 2, 2)
        self.assertLessEqual(abs(len(seg) - round(2 * 4 * 60 / 100 * SR)), 1)

    def test_build_pack_verify(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            stats = build_kit_dir(song(), tone_stems(), td / "kit")
            self.assertEqual(stats["group_count"], 2)
            self.assertEqual(stats["pad_count"], 24)
            doc = json.loads((td / "kit" / "kit.json").read_text())
            self.assertEqual(doc["padCount"], 24)
            self.assertEqual(doc["pads"][0]["launch"]["quantize"], "1bar")
            up = rust.pack(td / "kit", td / "x.upkit")
            info = rust.verify(up)
            self.assertEqual(info["pad_count"], 24)
            self.assertEqual(info["group_count"], 2)
            self.assertEqual(info["warnings"], 0)

    def test_item_json_matches_contract(self):
        s = song("CC-BY-SA-4.0")
        item = item_json(s, {"group_count": 2, "pad_count": 24, "loop_secs": 9.6})
        self.assertEqual(item["license_url"], "https://creativecommons.org/licenses/by-sa/4.0/")
        self.assertEqual(item["status"], "draft")
        self.assertIn("CC BY-SA 4.0", item["attribution"])

    def test_bad_song_rejected(self):
        s = song()
        s.attribution = ""
        with self.assertRaises(ValueError):
            s.validate()
        s = song()
        s.license = "GPL-3.0"
        with self.assertRaises(licenses.LicenseError):
            s.validate()


if __name__ == "__main__":
    unittest.main()
