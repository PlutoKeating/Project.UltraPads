import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

from upcatalog import SR, audio, licenses, rust
from upcatalog.layout import build_kit_dir, fragment_plan, item_json, n_sections
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
    def test_section_counts(self):
        self.assertEqual([n_sections(b) for b in (0, 3, 4, 7, 8, 16, 100)], [0, 0, 1, 1, 2, 4, 8])
        for _, start, n in fragment_plan():
            self.assertLessEqual(start + n, 4)

    def test_slice_is_bar_exact(self):
        x = tone_stems()["Drums"]
        seg = audio.slice_bars(x, 100.0, 2, 2)
        self.assertLessEqual(abs(len(seg) - round(2 * 4 * 60 / 100 * SR)), 1)

    def test_build_pack_verify(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            stats = build_kit_dir(song(), tone_stems(bars=16), td / "kit")
            self.assertEqual(stats["group_count"], 4)  # 16 小节 = 4 个段落
            self.assertEqual(stats["pad_count"], 8)  # 每段 2 个乐器
            doc = json.loads((td / "kit" / "kit.json").read_text())
            self.assertEqual(doc["padCount"], 48)
            pads = doc["pads"]
            self.assertEqual(pads[0]["launch"]["quantize"], "1bar")
            for bank in range(4):  # 每组都是完整一段：全部乐器各一个 pad，都是 4 小节
                group = [p for p in pads if p["addr"]["bank"] == bank]
                self.assertEqual([p["name"].split()[0] for p in group], ["Drums", "Bass"])
                self.assertEqual({p["tempo"]["beats"] for p in group}, {16})
                self.assertEqual(len({p["exclusive"] for p in group}), 2)  # 同组乐器之间不互斥
            self.assertEqual(pads[0]["exclusive"], pads[2]["exclusive"])  # 同一乐器跨段落互斥
            up = rust.pack(td / "kit", td / "x.upkit")
            info = rust.verify(up)
            self.assertEqual(info["pad_count"], 8)
            self.assertEqual(info["group_count"], 4)
            self.assertEqual(info["warnings"], 0)

    def test_mix_only_gets_fragments(self):
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            s = song()
            s.stems = s.stems[:1]
            stats = build_kit_dir(s, {"Drums": tone_stems(bars=8)["Drums"]}, td / "kit")
            self.assertEqual(stats["group_count"], 2)
            self.assertEqual(stats["pad_count"], 2 * (1 + len(fragment_plan())))

    def test_item_json_matches_contract(self):
        s = song("CC-BY-SA-4.0")
        item = item_json(s, {"group_count": 2, "pad_count": 4, "loop_secs": 9.6})
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
