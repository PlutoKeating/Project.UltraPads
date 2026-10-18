// 端到端：真实运行 public/install，对接本地假站点（/api/version?format=sh 与 /dl/），HOME 指向临时目录。
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { execFileSync, spawn } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SCRIPT = new URL("../public/install", import.meta.url).pathname;
const work = fs.mkdtempSync(path.join(os.tmpdir(), "up-install-"));
const packages = {};
let latest = "0.1.0";
let corrupt = false;
let mirrorDown = false;
let server;
let site;

function makePackage(version) {
  const name = `ultrapads-${version}-linux-x64.tar.gz`;
  const root = path.join(work, "pkg", `ultrapads-${version}-linux-x64`);
  fs.mkdirSync(path.join(root, "share/applications"), { recursive: true });
  fs.mkdirSync(path.join(root, "share/icons/hicolor/512x512/apps"), { recursive: true });
  fs.writeFileSync(path.join(root, "ultrapads"), `#!/bin/sh\necho ${version}\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(root, "share/applications/dev.ultrapads.ultrapads.desktop"), "[Desktop Entry]\nName=UltraPads\nExec=ultrapads\n");
  fs.writeFileSync(path.join(root, "share/icons/hicolor/512x512/apps/dev.ultrapads.ultrapads.png"), "png");
  const out = path.join(work, name);
  execFileSync("tar", ["-czf", out, "-C", path.join(work, "pkg"), `ultrapads-${version}-linux-x64`]);
  const bytes = fs.readFileSync(out);
  packages[version] = { name, bytes, sha: createHash("sha256").update(bytes).digest("hex") };
}

before(async () => {
  for (const v of ["0.1.0", "0.2.0", "0.3.0"]) makePackage(v);
  server = createServer((req, res) => {
    const u = new URL(req.url, "http://x");
    if (u.pathname === "/api/version") {
      const v = (u.searchParams.get("tag") ?? `v${latest}`).slice(1);
      const p = packages[v];
      if (!p || u.searchParams.get("platform") !== "linux-x64") { res.writeHead(404); return res.end("no\n"); }
      res.end([`UP_VERSION=${v}`, `UP_TAG=v${v}`, `UP_NAME=${p.name}`, `UP_SIZE=${p.bytes.length}`,
        `UP_SHA256=${p.sha}`, `UP_URL=${site}/dl/v${v}/${p.name}`, `UP_FALLBACK_URL=${site}/gh/v${v}/${p.name}`, ""].join("\n"));
      return;
    }
    const m = /^\/(dl|gh)\/v([0-9.]+)\/(.+)$/.exec(u.pathname);
    const p = m && packages[m[2]];
    if (!p) { res.writeHead(404); return res.end(); }
    if (m[1] === "dl" && mirrorDown) { res.writeHead(502); return res.end(); }
    res.end(corrupt ? Buffer.concat([p.bytes, Buffer.from("x")]) : p.bytes);
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  site = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
  fs.rmSync(work, { recursive: true, force: true });
});

const home = path.join(work, "home");
fs.mkdirSync(home, { recursive: true });
const prefix = path.join(home, ".local/opt/ultrapads");

// 必须异步：假站点和测试在同一个进程里，同步 spawn 会卡住事件循环，curl 永远等不到响应
function run(...args) {
  return new Promise((resolve) => {
    const child = spawn("bash", [SCRIPT, ...args], {
      env: { PATH: process.env.PATH, HOME: home, SHELL: "/bin/bash", UP_SITE: site, LANG: "C", NO_COLOR: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (out += d));
    child.on("close", (code) => resolve({ code, out }));
  });
}

test("fresh install lays out versions, current, bin link, desktop entry, PATH and marker", async () => {
  const r = await run();
  assert.equal(r.code, 0, r.out);
  assert.equal(fs.readlinkSync(path.join(prefix, "current")), "versions/0.1.0");
  assert.equal(execFileSync(path.join(home, ".local/bin/ultrapads"), { encoding: "utf8" }).trim(), "0.1.0");
  const desktop = fs.readFileSync(path.join(home, ".local/share/applications/dev.ultrapads.ultrapads.desktop"), "utf8");
  assert.match(desktop, new RegExp(`^Exec="${prefix}/current/ultrapads"$`, "m"));
  assert.ok(fs.existsSync(path.join(home, ".local/share/icons/hicolor/512x512/apps/dev.ultrapads.ultrapads.png")));
  const marker = JSON.parse(fs.readFileSync(path.join(prefix, "install.json"), "utf8"));
  assert.equal(marker.installer, "install.sh");
  assert.equal(marker.version, "0.1.0");
  assert.equal(marker.platform, "linux-x64");
  assert.match(fs.readFileSync(path.join(home, ".profile"), "utf8"), /# >>> ultrapads >>>/);
});

test("re-running is idempotent (no duplicate PATH block)", async () => {
  const r = await run();
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /Already on v0\.1\.0/);
  assert.doesNotMatch(r.out, /Added .* to PATH/);
  const profile = fs.readFileSync(path.join(home, ".profile"), "utf8");
  assert.equal(profile.split("# >>> ultrapads >>>").length - 1, 1);
});

test("upgrade switches current and keeps exactly one previous version", async () => {
  latest = "0.2.0";
  assert.equal((await run()).code, 0);
  latest = "0.3.0";
  const r = await run();
  assert.equal(r.code, 0, r.out);
  assert.equal(fs.readlinkSync(path.join(prefix, "current")), "versions/0.3.0");
  assert.deepEqual(fs.readdirSync(path.join(prefix, "versions")).sort(), ["0.2.0", "0.3.0"]);
});

test("--version pins an older release", async () => {
  const r = await run("--version", "0.1.0");
  assert.equal(r.code, 0, r.out);
  assert.equal(fs.readlinkSync(path.join(prefix, "current")), "versions/0.1.0");
});

test("sha256 mismatch aborts without touching the install", async () => {
  corrupt = true;
  const r = await run("--version", "0.2.0");
  corrupt = false;
  assert.notEqual(r.code, 0);
  assert.match(r.out, /SHA-256 mismatch/);
  assert.equal(fs.readlinkSync(path.join(prefix, "current")), "versions/0.1.0");
});

test("falls back to the GitHub URL when the mirror fails", async () => {
  mirrorDown = true;
  const r = await run("--version", "0.2.0");
  mirrorDown = false;
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /falling back to GitHub/);
  assert.equal(fs.readlinkSync(path.join(prefix, "current")), "versions/0.2.0");
});

test("unknown options are rejected", async () => {
  const r = await run("--bogus");
  assert.notEqual(r.code, 0);
  assert.match(r.out, /Unknown option/);
});

test("uninstall removes program, links, desktop entry and PATH block but keeps user data", async () => {
  const data = path.join(home, ".local/share/dev.ultrapads.ultrapads");
  fs.mkdirSync(data, { recursive: true });
  const r = await run("--uninstall");
  assert.equal(r.code, 0, r.out);
  assert.ok(!fs.existsSync(prefix));
  assert.ok(!fs.existsSync(path.join(home, ".local/bin/ultrapads")));
  assert.ok(!fs.existsSync(path.join(home, ".local/share/applications/dev.ultrapads.ultrapads.desktop")));
  assert.doesNotMatch(fs.readFileSync(path.join(home, ".profile"), "utf8"), /ultrapads/);
  assert.ok(fs.existsSync(data));
});
