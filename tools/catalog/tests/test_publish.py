import hashlib
import json
import os
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

from upcatalog import publish
from upcatalog.paths import Ctx

CALLS: list[tuple] = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_PUT(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        CALLS.append((self.path, {k.lower(): v for k, v in self.headers.items()}, body))
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"{}")


class PublishTest(unittest.TestCase):
    def setUp(self):
        CALLS.clear()
        self.srv = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()
        self.td = tempfile.TemporaryDirectory()
        self.ctx = Ctx(Path(self.td.name)).ensure()
        (self.ctx.out / "items" / "synth-x-demo.json").write_text(json.dumps({"id": "synth-x-demo", "status": "draft"}))
        (self.ctx.out / "kits" / "synth-x-demo.upkit").write_bytes(b"PK-fake-upkit-bytes")
        os.environ.update(ULTRAPADS_DATA_URL=f"http://127.0.0.1:{self.srv.server_port}/ultrapads", ULTRAPADS_DATA_KEY="dk", ULTRAPADS_ADMIN_KEY="ak")

    def tearDown(self):
        self.srv.shutdown()
        self.srv.server_close()
        self.td.cleanup()

    def test_draft_only_by_default(self):
        res = publish.publish(self.ctx, ["synth-x-demo"])
        self.assertEqual(res[0]["status"], "draft")
        self.assertEqual([c[0] for c in CALLS], ["/ultrapads/v1/admin/catalog/synth-x-demo", "/ultrapads/v1/admin/catalog/synth-x-demo/file"])
        meta_call, file_call = CALLS
        self.assertEqual(json.loads(meta_call[2])["status"], "draft")
        self.assertEqual(file_call[1]["x-sha256"], hashlib.sha256(b"PK-fake-upkit-bytes").hexdigest())
        self.assertEqual(file_call[1]["authorization"], "Bearer dk")
        self.assertEqual(file_call[1]["x-up-admin"], "ak")
        self.assertEqual(file_call[2], b"PK-fake-upkit-bytes")

    def test_publish_flag_sets_published_last(self):
        publish.publish(self.ctx, ["synth-x-demo"], make_published=True)
        self.assertEqual(len(CALLS), 3)
        self.assertEqual(json.loads(CALLS[2][2])["status"], "published")

    def test_missing_env_and_unpacked(self):
        os.environ.pop("ULTRAPADS_ADMIN_KEY")
        with self.assertRaises(publish.PublishError):
            publish.publish(self.ctx, ["synth-x-demo"])
        os.environ["ULTRAPADS_ADMIN_KEY"] = "ak"
        (self.ctx.out / "kits" / "synth-x-demo.upkit").unlink()
        with self.assertRaises(publish.PublishError):
            publish.publish(self.ctx, ["synth-x-demo"])

    def test_dry_run_makes_no_requests(self):
        res = publish.publish(self.ctx, ["synth-x-demo"], dry_run=True)
        self.assertTrue(res[0]["dry_run"])
        self.assertEqual(CALLS, [])


if __name__ == "__main__":
    unittest.main()
