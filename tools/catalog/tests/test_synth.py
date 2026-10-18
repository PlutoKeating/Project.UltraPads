import unittest

from upcatalog import compose
from upcatalog.sources import synth
from upcatalog.styles import STYLES


class SynthTest(unittest.TestCase):
    def test_specs_unique_and_deterministic(self):
        a, b = synth.song_specs(), synth.song_specs()
        self.assertEqual(a, b)
        self.assertEqual(len({s["id"] for s in a}), len(a))
        self.assertGreaterEqual(len(a), 40)

    def test_notes_deterministic_and_in_range(self):
        for sid, st in STYLES.items():
            p1, p2 = compose.plan(st, 123), compose.plan(st, 123)
            self.assertEqual(p1, p2)
            self.assertGreaterEqual(p1.bpm, st.bpm[0])
            self.assertLessEqual(p1.bpm, st.bpm[1])
            for part in st.parts:
                for ph in (0, 1):
                    n1, n2 = compose.phrase_notes(p1, part, ph), compose.phrase_notes(p1, part, ph)
                    self.assertEqual(n1, n2, f"{sid}/{part.name}")
                    self.assertTrue(n1, f"{sid}/{part.name} 没有音符")
                    for start, dur, pitch, vel in n1:
                        self.assertTrue(0 <= start < 16.0 and dur > 0, (sid, part.name, start, dur))
                        self.assertTrue(0 <= pitch <= 127 and 1 <= vel <= 127)

    def test_every_style_has_distinct_groups(self):
        for sid, st in STYLES.items():
            self.assertTrue(5 <= len(st.parts) <= 7)
            self.assertEqual(len({p.name for p in st.parts}), len(st.parts))


if __name__ == "__main__":
    unittest.main()
