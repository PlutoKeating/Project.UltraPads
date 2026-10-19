import io
import struct
import threading
import unittest
import zipfile
from http.server import BaseHTTPRequestHandler, HTTPServer

import numpy as np

from upcatalog import SR, licenses
from upcatalog.sources import album, online


def wav_bytes(x: np.ndarray) -> bytes:
    pcm = (x * 32767).astype("<i2")
    return (b"RIFF" + struct.pack("<I", 36 + pcm.nbytes) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 2, SR, SR * 4, 4, 16)
            + b"data" + struct.pack("<I", pcm.nbytes) + pcm.tobytes())


class RangeHandler(BaseHTTPRequestHandler):
    data = b""

    def log_message(self, *a):
        pass

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Length", str(len(self.data)))
        self.end_headers()

    def do_GET(self):
        rng = self.headers.get("Range")
        a, b = 0, len(self.data) - 1
        if rng:
            a, b = (int(v) for v in rng.split("=")[1].split("-"))
            b = min(b, len(self.data) - 1)
        self.send_response(206 if rng else 200)
        self.send_header("Content-Length", str(b - a + 1))
        self.end_headers()
        self.wfile.write(self.data[a : b + 1])


class AlbumTest(unittest.TestCase):
    def test_partial_deflate_prefix_over_http(self):
        t = np.arange(SR * 20) / SR
        x = np.stack([np.sin(2 * np.pi * 220 * t), np.sin(2 * np.pi * 330 * t)], 1).astype(np.float32) * 0.5
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("stems_mixed/s/a.wav", wav_bytes(x))
        RangeHandler.data = buf.getvalue()
        srv = HTTPServer(("127.0.0.1", 0), RangeHandler)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            url = f"http://127.0.0.1:{srv.server_port}/x.zip"
            z = zipfile.ZipFile(io.BufferedReader(album.RangeFile(url)))
            info = z.infolist()[0]
            entry = {"name": info.filename, "off": info.header_offset, "csize": info.compress_size, "size": info.file_size, "ctype": info.compress_type}
            raw = album.read_prefix(url, entry, SR * 4 * 5 + 2000)  # 只要前 5 秒
            self.assertLess(len(raw), info.file_size)
            y = album.parse_wav(raw)
            self.assertGreaterEqual(len(y), SR * 5 - 10)
            np.testing.assert_allclose(y[: SR], x[: SR], atol=2e-4)
        finally:
            srv.shutdown()
            srv.server_close()

    def test_parse_wav_rejects_other_formats(self):
        raw = b"RIFF" + struct.pack("<I", 36) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 2, 48000, 192000, 4, 16) + b"data" + struct.pack("<I", 0)
        with self.assertRaises(ValueError):
            album.parse_wav(raw)

    def test_pick_window_requires_all_groups_active(self):
        bpm = 120.0
        n = SR * 40
        loud = (np.random.default_rng(0).standard_normal((n, 2)) * 0.1).astype(np.float32)
        quiet = np.zeros((n, 2), dtype=np.float32)
        quiet[SR * 24 :] = loud[SR * 24 :]  # 第二个组从 24 s 才有声音
        bar, active = album.pick_window({"a": loud, "b": quiet}, bpm, 0.0, bars=8, min_start_s=2.0)
        self.assertGreaterEqual(bar * 2.0, 24.0)  # 120 BPM 一小节 2 s
        self.assertEqual(bar % 4, 0)
        self.assertEqual(sorted(active), ["a", "b"])

    def test_pick_window_drops_silent_group_when_allowed(self):
        n = SR * 40
        loud = (np.random.default_rng(0).standard_normal((n, 2)) * 0.1).astype(np.float32)
        silent = np.zeros((n, 2), dtype=np.float32)
        self.assertIsNone(album.pick_window({"a": loud, "b": silent}, 120.0, 0.0, bars=8, min_start_s=2.0))
        bar, active = album.pick_window({"a": loud, "b": silent}, 120.0, 0.0, bars=8, min_start_s=2.0, min_groups=1)
        self.assertEqual(active, ["a"])


def upload(license_url, bpm_tag="bpm_100_105", files=None):
    files = files or [
        ("mp3", 200.0), ("drums", 200.0), ("bass", 200.0), ("piano", 200.0), ("lead vox", 200.0), ("Instrumental", 200.0),
    ]
    return {
        "upload_id": 1, "upload_name": "Song", "user_name": "tester", "user_real_name": "Test Er", "license_url": license_url,
        "file_page_url": "https://ccmixter.org/files/tester/1", "upload_extra": {"ccud": f"media,{bpm_tag}", "usertags": "pop"},
        "files": [{"file_id": i, "file_nicname": n, "download_url": f"https://ccmixter.org/content/{n}.mp3",
                   "file_format_info": {"media-type": "audio", "default-ext": "mp3", "ps": f"{int(s // 60)}:{int(s % 60):02d}"}}
                  for i, (n, s) in enumerate(files)],
    }


class OnlineTest(unittest.TestCase):
    def test_license_gate(self):
        self.assertIsNone(online.candidate(upload("http://creativecommons.org/licenses/sampling+/1.0/")))
        self.assertIsNone(online.candidate(upload("http://creativecommons.org/licenses/by-nd/3.0/")))
        c = online.candidate(upload("http://creativecommons.org/licenses/by-nc/3.0/"))
        self.assertEqual(c["license"], "CC-BY-NC-3.0")
        self.assertEqual(c["artist"], "Test Er (tester)")

    def test_requires_bpm_tag(self):
        self.assertIsNone(online.candidate(upload("http://creativecommons.org/licenses/by/3.0/", bpm_tag="remix")))

    def test_stems_vs_mix(self):
        c = online.candidate(upload("http://creativecommons.org/licenses/by/3.0/"))
        self.assertEqual(c["kind"], "stems")
        self.assertEqual({s["name"] for s in c["stems"]}, {"drums", "bass", "piano", "lead vox"})  # mp3 / Instrumental 不是分轨
        mix = online.candidate(upload("http://creativecommons.org/licenses/by/3.0/", files=[("mp3", 180.0)]))
        self.assertEqual(mix["kind"], "mix")

    def test_genres(self):
        self.assertEqual(online.genres_of("ambient,chill,instrumental"), ["ambient", "chill"])
        self.assertEqual(online.genres_of("hip_hop,electronic,downtempo"), ["hip-hop", "downtempo"])
        self.assertEqual(online.genres_of("windfall"), ["other"])

    def test_classify(self):
        self.assertEqual(online.classify("Lead Vox")[1], "vocals")
        self.assertEqual(online.classify("percussion all")[1], "drums")
        self.assertEqual(online.classify("pad1")[1], "pad")
        self.assertIsNone(online.classify("Loop"))


if __name__ == "__main__":
    unittest.main()
