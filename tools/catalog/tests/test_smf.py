import tempfile
import unittest
from pathlib import Path

from upcatalog.smf import write_smf, PPQ


class SmfTest(unittest.TestCase):
    def test_header_and_tracks(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "a.mid"
            write_smf(p, 120, [{"channel": 0, "program": 4, "notes": [(0, 1, 60, 100), (1, 1, 64, 90)]}])
            b = p.read_bytes()
            self.assertTrue(b.startswith(b"MThd"))
            self.assertEqual(b.count(b"MTrk"), 2)
            self.assertEqual(int.from_bytes(b[12:14], "big"), PPQ)
            self.assertIn(bytes([0x90, 60, 100]), b)
            self.assertIn(bytes([0x80, 64, 0]), b)


if __name__ == "__main__":
    unittest.main()
