import unittest

import numpy as np

from upcatalog import SR
from upcatalog.analyze import estimate_grid


def click_track(bpm, offset, secs=40.0, seed=0):
    rng = np.random.default_rng(seed)
    n = int(secs * SR)
    x = np.zeros(n, dtype=np.float32)
    beat = 60 / bpm
    i = 0
    while True:
        t = offset + i * beat
        a = int(t * SR)
        if a + SR // 4 >= n:
            break
        k = np.arange(int(0.12 * SR))
        if i % 4 == 0:  # 小节第 1 拍：底鼓
            x[a : a + len(k)] += (np.sin(2 * np.pi * 55 * k / SR) * np.exp(-k / (0.04 * SR))).astype(np.float32)
        else:  # 其余拍：军鼓 / 踩镲噪声
            m = int(0.04 * SR)
            x[a : a + m] += (rng.standard_normal(m) * np.exp(-np.arange(m) / (0.01 * SR)) * 0.4).astype(np.float32)
        i += 1
    return np.stack([x, x], axis=1)


class AnalyzeTest(unittest.TestCase):
    def check(self, bpm, offset):
        g = estimate_grid(click_track(bpm, offset))
        self.assertAlmostEqual(g.bpm, bpm, delta=0.3)
        bar = 4 * 60 / bpm
        d = abs(((g.offset - offset) + bar / 2) % bar - bar / 2)
        self.assertLess(d, 0.02, f"offset {g.offset} vs {offset}")
        self.assertTrue(g.reliable, g)

    def test_100(self):
        self.check(100.0, 0.37)

    def test_128(self):
        self.check(128.0, 0.9)

    def test_87(self):
        self.check(87.5, 0.12)

    def test_fast_ambiguity_prefers_half(self):
        # 每拍一模一样的点击在 160 与 80 之间本来就分不出；> 140 时取半速（一小节更接近人对小节的感觉）
        g = estimate_grid(click_track(160.0, 0.2))
        self.assertAlmostEqual(g.bpm, 80.0, delta=0.3)

    def test_noise_is_unreliable(self):
        rng = np.random.default_rng(1)
        x = rng.standard_normal((SR * 30, 2)).astype(np.float32) * 0.1
        self.assertFalse(estimate_grid(x).reliable)


if __name__ == "__main__":
    unittest.main()
