// ultrapads-data 单测：鉴权（含常量时间比较的两把密钥）、目录查询与分页、元数据校验、文件上传（sha256 / ZIP 魔数 / 复用）、
// Range 与 ETag、发布规则、账号数据（收藏 / 最近 / 下载 / 级联删除）与 /ultrapads 路径前缀。
import { test } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { openDb } from "../src/db.ts";
import { createApp } from "../src/app.ts";

const KEY = "k".repeat(48);
const ADMIN = "a".repeat(48);
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ultrapads-data-"));
const db = openDb(dir);
const app = createApp(db, KEY, ADMIN);

interface Opts {
  method?: string;
  json?: unknown;
  body?: Buffer | string;
  headers?: Record<string, string>;
  key?: string | null;
  admin?: boolean | string;
}
let target = app;
async function call(p: string, o: Opts = {}) {
  const headers: Record<string, string> = { ...o.headers };
  if (o.key !== null) headers.Authorization = `Bearer ${o.key ?? KEY}`;
  if (o.admin) headers["X-Up-Admin"] = typeof o.admin === "string" ? o.admin : ADMIN;
  if (o.json !== undefined) headers["Content-Type"] = "application/json";
  const r = await target.request(`http://data${p}`, {
    method: o.method ?? "GET",
    headers,
    body: o.json !== undefined ? JSON.stringify(o.json) : (o.body as BodyInit | undefined),
  });
  const ct = r.headers.get("content-type") ?? "";
  const json = ct.includes("application/json") ? await r.json() : undefined;
  const bytes = json === undefined ? new Uint8Array(await r.arrayBuffer()) : undefined;
  return { status: r.status, json, bytes, headers: r.headers };
}

const meta = (over: Record<string, unknown> = {}) => ({
  title: "Dusk Run",
  artist: "UltraPads",
  description: "测试",
  origin: "synth",
  license: "CC0-1.0",
  attribution: "“Dusk Run” by UltraPads, CC0 1.0",
  source_url: "https://example.org/dusk",
  bpm: 112,
  genres: ["house"],
  tags: ["drums", "bass"],
  group_count: 4,
  pad_count: 44,
  duration_secs: 17.1,
  theme_color: "#F0A35E",
  ...over,
});
const zip = (n: number, seed = 1) => {
  const b = Buffer.alloc(n, seed);
  b.set([0x50, 0x4b, 3, 4]);
  return b;
};
const sha = (b: Buffer) => crypto.createHash("sha256").update(b).digest("hex");

async function publish(id: string, over: Record<string, unknown> = {}, file = zip(1000, id.length)) {
  assert.equal((await call(`/v1/admin/catalog/${id}`, { method: "PUT", json: meta(over), admin: true })).status, 200);
  const up = await call(`/v1/admin/catalog/${id}/file`, { method: "PUT", body: file, admin: true });
  assert.equal(up.status, 200, JSON.stringify(up.json));
  const pub = await call(`/v1/admin/catalog/${id}`, { method: "PUT", json: meta({ ...over, status: "published" }), admin: true });
  assert.equal(pub.status, 200, JSON.stringify(pub.json));
  return file;
}

test("健康检查无需密钥；/v1/* 缺少或错误密钥返回 401；admin 需要两把密钥", async () => {
  assert.equal((await call("/health", { key: null })).status, 200);
  assert.equal((await call("/v1/catalog", { key: null })).status, 401);
  assert.equal((await call("/v1/catalog", { key: "wrong" })).status, 401);
  assert.equal((await call("/v1/admin/catalog", { key: KEY })).status, 401);
  assert.equal((await call("/v1/admin/catalog", { admin: "wrong" })).status, 401);
  assert.equal((await call("/v1/admin/catalog", { admin: ADMIN, key: "wrong" })).status, 401);
  assert.equal((await call("/v1/admin/catalog", { admin: true })).status, 200);
  assert.equal((await call("/v1/catalog", { admin: true })).status, 200);
});

test("路径前缀 /ultrapads 与无前缀等价", async () => {
  assert.equal((await call("/ultrapads/health", { key: null })).status, 200);
  assert.equal((await call("/ultrapads/v1/catalog")).status, 200);
  assert.equal((await call("/ultrapads/v1/catalog", { key: "x" })).status, 401);
  assert.equal((await call("/nope")).status, 404);
});

test("元数据校验：id、license 白名单、数值范围、派生字段", async () => {
  const put = (id: string, j: unknown) => call(`/v1/admin/catalog/${id}`, { method: "PUT", json: j, admin: true });
  assert.equal((await put("Bad_ID", meta())).status, 400);
  assert.equal((await put("ab", meta())).status, 400);
  assert.equal((await put("bad-license", meta({ license: "MIT" }))).status, 400);
  assert.equal((await put("bad-origin", meta({ origin: "x" }))).status, 400);
  assert.equal((await put("bad-bpm", meta({ bpm: 5 }))).status, 400);
  assert.equal((await put("bad-groups", meta({ group_count: 8 }))).status, 400);
  assert.equal((await put("bad-pads", meta({ pad_count: 1.5 }))).status, 400);
  assert.equal((await put("bad-color", meta({ theme_color: "red" }))).status, 400);
  assert.equal((await put("bad-url", meta({ source_url: "javascript:alert(1)" }))).status, 400);
  assert.equal((await put("no-title", meta({ title: " " }))).status, 400);
  assert.equal((await put("no-attr", { ...meta(), attribution: undefined })).status, 400);

  const ok = await put("flags-nc-sa", meta({ license: "CC-BY-NC-SA-4.0", commercial_ok: true, share_alike: false }));
  assert.equal(ok.status, 200);
  assert.equal(ok.json.commercial_ok, false); // 由服务计算，忽略客户端传入
  assert.equal(ok.json.share_alike, true);
  assert.equal(ok.json.license_url, "https://creativecommons.org/licenses/by-nc-sa/4.0/");
  assert.equal(ok.json.theme_color, "#f0a35e");
  assert.equal(ok.json.status, "draft");
  assert.equal(ok.json.sha256, null);

  const by = (await put("flags-by", meta({ license: "CC-BY-4.0" }))).json;
  assert.equal(by.commercial_ok, true);
  assert.equal(by.share_alike, false);
});

test("无文件不允许发布；草稿对公开接口不可见", async () => {
  const r = await call("/v1/admin/catalog/draft-only", { method: "PUT", json: meta({ status: "published" }), admin: true });
  assert.equal(r.status, 409); // no_file：条目还没有文件
  assert.equal(r.json.error, "no_file");
  await call("/v1/admin/catalog/draft-only", { method: "PUT", json: meta(), admin: true });
  assert.equal((await call("/v1/catalog/draft-only")).status, 404);
  assert.equal((await call("/v1/catalog/draft-only/file")).status, 404);
  const list = await call("/v1/catalog?q=draft-only");
  assert.equal(list.json.total, 0);
  const adminList = await call("/v1/admin/catalog", { admin: true });
  assert.ok(adminList.json.items.some((i: { id: string }) => i.id === "draft-only"));
});

test("上传：sha256 核对、ZIP 魔数、空文件、条目不存在、同内容复用", async () => {
  await call("/v1/admin/catalog/up-one", { method: "PUT", json: meta(), admin: true });
  const f = zip(5000, 7);
  const put = (id: string, body: Buffer, headers: Record<string, string> = {}) =>
    call(`/v1/admin/catalog/${id}/file`, { method: "PUT", body, headers, admin: true });

  assert.equal((await put("up-one", f, { "x-sha256": "0".repeat(64) })).status, 422);
  assert.equal((await put("up-one", f, { "x-sha256": "xyz" })).status, 400);
  assert.equal((await put("up-one", Buffer.from("not a zip at all"))).status, 422);
  assert.equal((await put("up-one", Buffer.alloc(0))).status, 400);
  assert.equal((await put("nope-nope", f)).status, 404);
  assert.deepEqual(fs.readdirSync(path.join(dir, "files", ".tmp")), []); // 失败不留临时文件

  const ok = await put("up-one", f, { "x-sha256": sha(f) });
  assert.equal(ok.status, 200);
  assert.equal(ok.json.sha256, sha(f));
  assert.equal(ok.json.size, 5000);
  assert.ok(fs.existsSync(path.join(dir, "files", sha(f).slice(0, 2), sha(f))));

  await call("/v1/admin/catalog/up-two", { method: "PUT", json: meta(), admin: true });
  assert.equal((await put("up-two", f)).status, 200);
  // 删除其中一个，另一个仍可用（共享文件不被误删）
  assert.equal((await call("/v1/admin/catalog/up-one", { method: "DELETE", admin: true })).status, 204);
  assert.ok(fs.existsSync(path.join(dir, "files", sha(f).slice(0, 2), sha(f))));
  assert.equal((await call("/v1/admin/catalog/up-two", { method: "DELETE", admin: true })).status, 204);
  assert.ok(!fs.existsSync(path.join(dir, "files", sha(f).slice(0, 2), sha(f))));
  assert.equal((await call("/v1/admin/catalog/up-two", { method: "DELETE", admin: true })).status, 404);
});

test("替换文件：旧文件无人引用时清理", async () => {
  const a = zip(300, 1);
  const b = zip(400, 2);
  await publish("replace-me", {}, a);
  const old = path.join(dir, "files", sha(a).slice(0, 2), sha(a));
  assert.ok(fs.existsSync(old));
  const r = await call("/v1/admin/catalog/replace-me/file", { method: "PUT", body: b, admin: true });
  assert.equal(r.json.sha256, sha(b));
  assert.ok(!fs.existsSync(old));
  assert.equal((await call("/v1/catalog/replace-me")).json.size, 400);
});

test("文件下载：整文件、Range、ETag/304、HEAD", async () => {
  const f = await publish("dl-test", {}, zip(1000, 9));
  const full = await call("/v1/catalog/dl-test/file");
  assert.equal(full.status, 200);
  assert.equal(full.headers.get("content-type"), "application/zip");
  assert.equal(full.headers.get("content-length"), "1000");
  assert.equal(full.headers.get("etag"), `"${sha(f)}"`);
  assert.equal(full.headers.get("x-digest"), `sha256:${sha(f)}`);
  assert.equal(full.headers.get("accept-ranges"), "bytes");
  assert.deepEqual(Buffer.from(full.bytes!), f);

  const part = await call("/v1/catalog/dl-test/file", { headers: { Range: "bytes=10-19" } });
  assert.equal(part.status, 206);
  assert.equal(part.headers.get("content-range"), "bytes 10-19/1000");
  assert.deepEqual(Buffer.from(part.bytes!), f.subarray(10, 20));

  const tail = await call("/v1/catalog/dl-test/file", { headers: { Range: "bytes=990-" } });
  assert.equal(tail.status, 206);
  assert.equal(tail.bytes!.length, 10);
  const suffix = await call("/v1/catalog/dl-test/file", { headers: { Range: "bytes=-5" } });
  assert.equal(suffix.headers.get("content-range"), "bytes 995-999/1000");
  assert.equal((await call("/v1/catalog/dl-test/file", { headers: { Range: "bytes=2000-" } })).status, 416);
  assert.equal((await call("/v1/catalog/dl-test/file", { headers: { Range: "bytes=5-2" } })).status, 416);
  assert.equal((await call("/v1/catalog/dl-test/file", { headers: { Range: "items=1-2" } })).status, 416);

  assert.equal((await call("/v1/catalog/dl-test/file", { headers: { "If-None-Match": `"${sha(f)}"` } })).status, 304);
  const head = await call("/v1/catalog/dl-test/file", { method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(head.headers.get("content-length"), "1000");
});

test("目录查询：过滤、排序、分页、facets", async () => {
  // 用一个全新的库，避免前面用例留下的条目干扰计数
  const dir2 = fs.mkdtempSync(path.join(os.tmpdir(), "ultrapads-data-q-"));
  const db2 = openDb(dir2);
  target = createApp(db2, KEY, ADMIN);
  try {
    await queryTest();
  } finally {
    target = app;
    db2.close();
  }
});

async function queryTest() {
  await publish("q-house-a", { title: "Alpha House", bpm: 120, genres: ["house", "dance"], license: "CC0-1.0", origin: "synth" });
  await publish("q-house-b", { title: "beta house", bpm: 100, genres: ["house"], license: "CC-BY-4.0", origin: "online", tags: ["vocal"] });
  await publish("q-lofi-c", { title: "Gamma Lofi", bpm: 80, genres: ["lofi"], license: "CC-BY-NC-4.0", origin: "album", artist: "Some 50%_Artist" });
  await publish("q-nobpm-d", { title: "Delta", bpm: null, genres: [], license: "CC-BY-SA-4.0", origin: "synth" });

  const ids = (r: { json: { items: { id: string }[] } }) => r.json.items.map((i) => i.id);
  const only = "/v1/catalog?limit=50";
  assert.deepEqual(ids(await call(`${only}&q=house&sort=bpm`)), ["q-house-b", "q-house-a"]);
  assert.deepEqual(ids(await call(`${only}&q=VOCAL`)), ["q-house-b"]); // 大小写不敏感，匹配标签
  assert.deepEqual(ids(await call(`${only}&q=${encodeURIComponent("50%_")}`)), ["q-lofi-c"]); // LIKE 通配符被转义
  assert.equal((await call(`${only}&q=${encodeURIComponent("5%")}`)).json.total, 0); // 未转义时 5% 会匹配 50%_
  assert.deepEqual(ids(await call(`${only}&genre=lofi`)), ["q-lofi-c"]);
  assert.deepEqual(ids(await call(`${only}&origin=online`)), ["q-house-b"]);
  assert.deepEqual(ids(await call(`${only}&license=CC0-1.0&license=CC-BY-4.0&sort=title`)), ["q-house-a", "q-house-b"]);
  assert.deepEqual(ids(await call(`${only}&license=CC0-1.0,CC-BY-SA-4.0&sort=title`)), ["q-house-a", "q-nobpm-d"]);
  assert.deepEqual(ids(await call(`${only}&bpm_min=90&bpm_max=110`)), ["q-house-b"]);
  assert.deepEqual(ids(await call(`${only}&sort=bpm`)), ["q-lofi-c", "q-house-b", "q-house-a", "q-nobpm-d"]); // 无 BPM 排最后
  assert.deepEqual(ids(await call(`${only}&q=house&sort=title`)), ["q-house-a", "q-house-b"]); // NOCASE
  assert.equal((await call(`${only}&license=MIT`)).status, 400);
  assert.equal((await call(`${only}&sort=random`)).status, 400);
  assert.equal((await call(`${only}&bpm_min=abc`)).status, 400);
  assert.equal((await call(`${only}&cursor=%%%`)).status, 400);

  // 分页：游标走完全部，不重复不遗漏
  const seen: string[] = [];
  let cursor: string | null = null;
  for (let i = 0; i < 10; i++) {
    const r = await call(`/v1/catalog?limit=2&sort=title${cursor ? `&cursor=${cursor}` : ""}`);
    assert.equal(r.json.total, 4);
    seen.push(...ids(r));
    cursor = r.json.next_cursor;
    if (!cursor) break;
  }
  assert.deepEqual(seen, ["q-house-a", "q-house-b", "q-nobpm-d", "q-lofi-c"]);
  assert.equal((await call("/v1/catalog?limit=999")).json.items.length <= 50, true);

  const f = (await call("/v1/catalog/facets")).json;
  const count = (arr: { id: string; count: number }[], id: string) => arr.find((x) => x.id === id)?.count;
  assert.equal(count(f.licenses, "CC0-1.0"), 1);
  assert.equal(count(f.licenses, "CC-BY-NC-4.0"), 1);
  assert.equal(count(f.genres, "house"), 2);
  assert.equal(count(f.origins, "synth"), 2);
  assert.equal(f.genres.length, 3); // house / dance / lofi

  // 公开形态：不含 status / created_at_ms，字段齐全
  const one = (await call("/v1/catalog/q-house-a")).json;
  assert.equal(one.status, undefined);
  assert.equal(one.created_at_ms, undefined);
  for (const k of ["id","title","artist","description","origin","license","license_url","attribution","source_url","commercial_ok","share_alike","bpm","genres","tags","group_count","pad_count","duration_secs","size","sha256","theme_color","updated_at_ms"]) {
    assert.ok(k in one, `缺少字段 ${k}`);
  }
  assert.match(one.sha256, /^[0-9a-f]{64}$/);
}

test("下架（改回 draft）后公开接口不可见，账号数据里也不再出现", async () => {
  await publish("unpub-me");
  await call("/v1/users/u-unpub/favorites/unpub-me", { method: "PUT" });
  assert.deepEqual((await call("/v1/users/u-unpub/state")).json.favorites, ["unpub-me"]);
  await call("/v1/admin/catalog/unpub-me", { method: "PUT", json: meta({ status: "draft" }), admin: true });
  assert.equal((await call("/v1/catalog/unpub-me")).status, 404);
  assert.deepEqual((await call("/v1/users/u-unpub/state")).json.favorites, []);
  assert.equal((await call("/v1/users/u-unpub/favorites/unpub-me", { method: "PUT" })).status, 404);
});

test("账号数据：收藏、最近（去重+上限）、下载、隔离与级联删除", async () => {
  await publish("acct-a");
  await publish("acct-b");
  const U1 = "b3028fde-35f9-4678-91cc-9501c089610e";
  const U2 = "22222222-3333-4444-8555-666666666666";
  const put = (u: string, id: string) => call(`/v1/users/${u}/favorites/${id}`, { method: "PUT" });

  assert.equal((await put(U1, "acct-a")).status, 204);
  assert.equal((await put(U1, "acct-a")).status, 204); // 幂等
  assert.equal((await put(U1, "does-not-exist")).status, 404);
  assert.equal((await put(U2, "acct-b")).status, 204);
  assert.deepEqual((await call(`/v1/users/${U1}/state`)).json.favorites, ["acct-a"]);
  assert.deepEqual((await call(`/v1/users/${U2}/state`)).json.favorites, ["acct-b"]);
  assert.equal((await call(`/v1/users/${U1}/favorites/acct-b`, { method: "DELETE" })).status, 204); // 删除不存在的也幂等
  assert.equal((await call(`/v1/users/${U1}/favorites/acct-a`, { method: "DELETE" })).status, 204);
  assert.deepEqual((await call(`/v1/users/${U1}/state`)).json.favorites, []);

  const post = (kind: string, u: string, j: unknown) => call(`/v1/users/${u}/${kind}`, { method: "POST", json: j });
  assert.equal((await post("recent", U1, { id: "acct-a" })).status, 204);
  await new Promise((r) => setTimeout(r, 5));
  assert.equal((await post("recent", U1, { id: "acct-b" })).status, 204);
  await new Promise((r) => setTimeout(r, 5));
  assert.equal((await post("recent", U1, { id: "acct-a" })).status, 204); // 去重并置顶
  const st = (await call(`/v1/users/${U1}/state`)).json;
  assert.deepEqual(st.recent.map((r: { id: string }) => r.id), ["acct-a", "acct-b"]);
  assert.equal(typeof st.recent[0].at_ms, "number");
  assert.equal((await post("recent", U1, { id: "nope-nope" })).status, 404);
  assert.equal((await post("recent", U1, { id: "Bad ID" })).status, 400);
  assert.equal((await post("recent", U1, {})).status, 400);
  assert.equal((await call(`/v1/users/${U1}/recent`, { method: "POST", body: "[1]", headers: { "Content-Type": "application/json" } })).status, 400);

  assert.equal((await post("downloads", U1, { id: "acct-b" })).status, 204);
  assert.deepEqual((await call(`/v1/users/${U1}/state`)).json.downloads.map((r: { id: string }) => r.id), ["acct-b"]);

  assert.equal((await call(`/v1/users/${"x".repeat(201)}/state`)).status, 400);

  // 级联删除只影响本人
  await put(U1, "acct-a");
  assert.equal((await call(`/v1/users/${U1}`, { method: "DELETE" })).status, 204);
  assert.deepEqual((await call(`/v1/users/${U1}/state`)).json, { favorites: [], recent: [], downloads: [] });
  assert.deepEqual((await call(`/v1/users/${U2}/state`)).json.favorites, ["acct-b"]);

  // 删除目录条目时，所有人的相关记录一并清掉
  await call("/v1/admin/catalog/acct-b", { method: "DELETE", admin: true });
  assert.deepEqual((await call(`/v1/users/${U2}/state`)).json.favorites, []);
  assert.equal(db.raw.prepare("SELECT COUNT(*) AS n FROM favorites WHERE item_id='acct-b'").get()!.n, 0);
});

test("最近使用与下载记录各保留最近 100 条", async () => {
  await publish("cap-base");
  const U = "cap-user";
  for (let i = 0; i < 105; i++) {
    const id = `cap-${String(i).padStart(3, "0")}`;
    db.raw
      .prepare(
        `INSERT INTO catalog_items (id,title,origin,license,license_url,attribution,commercial_ok,share_alike,status,sha256,size,created_at_ms,updated_at_ms)
         VALUES (?,?,?,?,?,?,1,0,'published','x',1,1,1)`,
      )
      .run(id, id, "synth", "CC0-1.0", "https://x.example", "a");
  }
  for (let i = 0; i < 105; i++) {
    const id = `cap-${String(i).padStart(3, "0")}`;
    assert.equal((await call(`/v1/users/${U}/recent`, { method: "POST", json: { id } })).status, 204);
    assert.equal((await call(`/v1/users/${U}/downloads`, { method: "POST", json: { id } })).status, 204);
  }
  const st = (await call(`/v1/users/${U}/state`)).json;
  assert.equal(st.recent.length, 100);
  assert.equal(st.downloads.length, 100);
  assert.equal(st.recent[0].id, "cap-104"); // 最新在前
  assert.ok(!st.recent.some((r: { id: string }) => r.id === "cap-000")); // 最旧的被挤掉
});

test("备份：VACUUM INTO 一天一份，只留最近 7 份", () => {
  const b = path.join(dir, "backups");
  assert.match(db.backup(b), /^ultrapads-\d{4}-\d{2}-\d{2}\.db$/);
  for (let d = 1; d <= 9; d++) fs.writeFileSync(path.join(b, `ultrapads-2020-01-0${d}.db`), "x");
  db.backup(b);
  const left = fs.readdirSync(b);
  assert.equal(left.length, 7);
  assert.ok(left.some((f) => f.startsWith(`ultrapads-${new Date().toISOString().slice(0, 10)}`)));
});
