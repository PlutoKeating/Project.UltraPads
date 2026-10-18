import { test } from "node:test";
import assert from "node:assert/strict";
import { manifestFromRelease, manifestToShell, parseAssetName, sha256Of } from "../worker/release.js";

const SHA = "a".repeat(64);
const release = (over = {}) => ({
  tag_name: "v0.1.0",
  draft: false,
  prerelease: false,
  published_at: "2026-10-18T00:00:00Z",
  assets: [
    { name: "ultrapads-0.1.0-linux-x64.tar.gz", size: 10, digest: `sha256:${SHA}` },
    { name: "ultrapads-0.1.0-android-arm64-v8a.apk", size: 20, digest: `sha256:${SHA.toUpperCase()}` },
    { name: "ultrapads-0.1.0-linux-arm64.tar.gz", size: 30, digest: null },
    { name: "ultrapads-0.0.9-linux-x64.tar.gz", size: 1, digest: `sha256:${SHA}` },
    { name: "SHA256SUMS.txt", size: 1, digest: `sha256:${SHA}` },
  ],
  ...over,
});

test("asset names map to platforms", () => {
  assert.deepEqual(parseAssetName("ultrapads-0.1.0-linux-arm64.tar.gz"), { version: "0.1.0", platform: "linux-arm64" });
  assert.deepEqual(parseAssetName("ultrapads-1.2.3-android-x86_64.apk"), { version: "1.2.3", platform: "android-x86_64" });
  assert.equal(parseAssetName("ultrapads-0.1.0-linux-x64.apk"), null);
  assert.equal(parseAssetName("ultrapads-0.1.0-android-x86_64.tar.gz"), null);
  assert.equal(parseAssetName("evil-0.1.0-linux-x64.tar.gz"), null);
});

test("digest parsing", () => {
  assert.equal(sha256Of(`sha256:${SHA}`), SHA);
  assert.equal(sha256Of(`sha256:${SHA.toUpperCase()}`), SHA);
  assert.equal(sha256Of("sha512:abc"), null);
  assert.equal(sha256Of(undefined), null);
});

test("manifest keeps only verifiable assets of the tagged version", () => {
  const m = manifestFromRelease(release(), "https://ultrapads.example");
  assert.equal(m.version, "0.1.0");
  assert.deepEqual(Object.keys(m.assets).sort(), ["android-arm64-v8a", "linux-x64"]);
  assert.equal(m.assets["linux-x64"].url, "https://ultrapads.example/dl/v0.1.0/ultrapads-0.1.0-linux-x64.tar.gz");
  assert.equal(m.assets["linux-x64"].fallback_url, "https://github.com/PlutoKeating/Project.UltraPads/releases/download/v0.1.0/ultrapads-0.1.0-linux-x64.tar.gz");
  assert.equal(m.assets["android-arm64-v8a"].sha256, SHA);
  assert.equal(m.notes_url, "https://github.com/PlutoKeating/Project.UltraPads/releases/tag/v0.1.0");
});

test("prereleases, drafts and odd tags are not stable", () => {
  assert.equal(manifestFromRelease(release({ prerelease: true }), "x"), null);
  assert.equal(manifestFromRelease(release({ draft: true }), "x"), null);
  assert.equal(manifestFromRelease(release({ tag_name: "v0.1.0-rc1" }), "x"), null);
});

test("shell format is line based and whitelisted", () => {
  const m = manifestFromRelease(release(), "https://ultrapads.example");
  const sh = manifestToShell(m, "linux-x64");
  assert.match(sh, /^UP_VERSION=0\.1\.0$/m);
  assert.match(sh, new RegExp(`^UP_SHA256=${SHA}$`, "m"));
  assert.equal(manifestToShell(m, "linux-arm64"), null);
  m.assets["linux-x64"].url = "https://x/$(rm -rf ~)";
  assert.equal(manifestToShell(m, "linux-x64"), null);
});
