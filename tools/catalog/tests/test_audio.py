import unittest

import numpy as np

from upcatalog import SR, audio


def sine(secs=2.0, hz=220.0, amp=0.5):
    t = np.arange(int(secs * SR)) / SR
    s = (np.sin(2 * np.pi * hz * t) * amp).astype(np.float32)
    return np.stack([s, s], axis=1)


class AudioTest(unittest.TestCase):
    def test_soft_limit_bounds(self):
        x = np.linspace(-3, 3, 1000, dtype=np.float32)[:, None].repeat(2, axis=1)
        y = audio.soft_limit(x, 0.7)
        self.assertLessEqual(float(np.abs(y).max()), 0.7 + 1e-6)
        small = x[np.abs(x[:, 0]) < 0.5]
        np.testing.assert_allclose(audio.soft_limit(small), small)

    def test_match_level(self):
        y = audio.match_level(sine(amp=0.1), -20.0)
        self.assertAlmostEqual(audio.rms_db_active(y), -20.0, delta=0.1)

    def test_normalize_mix_shared_gain(self):
        a, b = sine(amp=0.1), sine(hz=330.0, amp=0.05)
        out, g = audio.normalize_mix({"a": a, "b": b})
        self.assertAlmostEqual(audio.peak(out["a"]) / audio.peak(out["b"]), 2.0, delta=0.05)  # 保持相对平衡
        self.assertGreater(g, 1.0)

    def test_silence_rejected(self):
        with self.assertRaises(audio.AudioError):
            audio.normalize_mix({"a": np.zeros((100, 2), dtype=np.float32)})

    def test_flac_roundtrip_and_mono(self):
        import tempfile, pathlib

        with tempfile.TemporaryDirectory() as td:
            p = audio.encode_flac(sine(0.5), pathlib.Path(td) / "a.flac")
            back = audio.decode(p)
            self.assertEqual(back.shape[1], 2)
            self.assertAlmostEqual(len(back) / SR, 0.5, delta=0.01)
            self.assertLess(float(np.abs(back - sine(0.5)).max()), 2e-3)

    def test_slice_fade_no_click(self):
        seg = audio.slice_bars(sine(10.0, amp=0.9), 120.0, 1, 2)
        self.assertLess(abs(float(seg[0, 0])), 1e-3)
        self.assertLess(abs(float(seg[-1, 0])), 0.05)
        with self.assertRaises(audio.AudioError):
            audio.slice_bars(sine(1.0), 120.0, 0, 4)


if __name__ == "__main__":
    unittest.main()
