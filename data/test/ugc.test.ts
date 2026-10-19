// 用户上传（UGC）与举报 / 审核：必填声明、默认私有、归属隔离、上传限制、公开 / 取消公开、配额、举报去重与自动隐藏、
// 运营下架（410）、注销级联，以及旧库补列迁移。
import { test } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";
import { openDb } from "../src/db.ts";
import { createApp } from "../src/app.ts";

const KEY = "k".repeat(48);
const ADMIN = "a".repeat(48);
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ultrapads-ugc-"));
const db = openDb(dir);
const app = createApp(db, KEY, ADMIN);

interface Opts {
  method?: string;
  json?: unknown;
  body?: Buffer | string;
  headers?: Record<string, string>;
  admin?: boolean;
}
async function call(p: string, o: Opts = {}) {
  const headers: Record<string, string> = { Authorization: `Bearer ${KEY}`, ...o.headers };
  if (o.admin) headers["X-Up-Admin"] = ADMIN;
  if (o.json !== undefined) headers["Content-Type"] = "application/json";
  const r = await app.request(`http://data${p}`, {
    method: o.method ?? "GET",
    headers,
    body: o.json !== undefined ? JSON.stringify(o.json) : (o.body as BodyInit | undefined),
  });
  const json = (r.headers.get("content-type") ?? "").includes("application/json") ? await r.json() : undefined;
  const bytes = json === undefined ? new Uint8Array(await r.arrayBuffer()) : undefined;
  return { status: r.status, json, bytes, headers: r.headers };
}

const zip = (n: number, seed = 1) => {
  const b = Buffer.alloc(n, seed);
  b.set([0x50, 0x4b, 3, 4]);
  return b;
};
const sha = (b: Buffer) => crypto.createHash("sha256").update(b).digest("hex");
const ugcMeta = (over: Record<string, unknown> = {}) => ({
  title: "My Chop",
  credit: "Alice (alice@example)",
  license: "CC-BY-SA-4.0",
  source_declaration: "own",
  source_url: "",
  group_count: 4,
  pad_count: 24,
  ...over,
});
const up = (sub: string, p = "") => `/v1/users/${sub}/uploads${p}`;
const totalUgc = async () => ((await call("/v1/catalog?origin=ugc")).json as { total: number }).total;

async function newUpload(sub: string, over: Record<string, unknown> = {}, file: Buffer | null = zip(2000, 7)) {
  const r = await call(up(sub), { method: "POST", json: ugcMeta(over) });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  const id = (r.json as { id: string }).id;
  if (file) assert.equal((await call(up(sub, `/${id}/file`), { method: "PUT", body: file })).status, 200);
  return id;
}
const makePublic = async (sub: string, id: string) =>
  assert.equal((await call(up(sub, `/${id}`), { method: "PATCH", json: { visibility: "public" } })).status, 200);

test("必须声明标题、署名、许可证与来源，缺一拒绝；默认私有，不出现在公开目录", async () => {
  for (const missing of ["title", "credit", "license", "source_declaration"]) {
    const m = ugcMeta() as Record<string, unknown>;
    delete m[missing];
    assert.equal((await call(up("alice"), { method: "POST", json: m })).status, 400, missing);
  }
  assert.equal((await call(up("alice"), { method: "POST", json: ugcMeta({ license: "GPL-3.0" }) })).status, 400);
  assert.equal((await call(up("alice"), { method: "POST", json: ugcMeta({ source_declaration: "found-online" }) })).status, 400);
  const r = await call(up("alice"), { method: "POST", json: ugcMeta({ visibility: "public", origin: "synth", status: "published" }) });
  assert.equal(r.status, 201);
  const it = r.json as Record<string, unknown>;
  assert.match(String(it.id), /^ugc-[0-9a-f]{16}$/);
  assert.equal(it.visibility, "private"); // 创建时的 visibility / origin / status 一律忽略
  assert.equal(it.origin, "ugc");
  assert.equal(it.status, "draft");
  assert.equal(it.moderation, "active");
  assert.equal(it.credit, "Alice (alice@example)");
  assert.equal(it.artist, "Alice (alice@example)");
  assert.equal(it.share_alike, true);
  assert.equal(it.commercial_ok, true);
  assert.equal("owner_sub" in it, false);
  assert.equal((await call(`/v1/catalog/${it.id}`)).status, 404);
});

test("文件上传后仍是私有；本人可下载，他人一律 404；公开前必须有文件", async () => {
  const id = await newUpload("ua", {}, null);
  assert.equal((await call(up("ua", `/${id}`), { method: "PATCH", json: { visibility: "public" } })).status, 409);
  const file = zip(3000, 9);
  const put = await call(up("ua", `/${id}/file`), { method: "PUT", body: file });
  assert.equal(put.status, 200);
  assert.equal((put.json as { sha256: string }).sha256, sha(file));
  assert.equal((put.json as { visibility: string }).visibility, "private");
  assert.equal((await call(`/v1/catalog/${id}`)).status, 404);
  assert.equal((await call(`/v1/catalog/${id}/file`)).status, 404);
  assert.equal(await totalUgc(), 0);
  const dl = await call(up("ua", `/${id}/file`));
  assert.equal(dl.status, 200);
  assert.deepEqual(Buffer.from(dl.bytes!), file);
  assert.match(dl.headers.get("cache-control") ?? "", /private/);
  assert.equal((await call(up("ub", `/${id}`))).status, 404);
  assert.equal((await call(up("ub", `/${id}/file`))).status, 404);
  assert.equal((await call(up("ub", `/${id}`), { method: "PATCH", json: { title: "x" } })).status, 404);
  assert.equal((await call(up("ub", `/${id}/file`), { method: "PUT", body: zip(100) })).status, 404);
  assert.equal((await call(up("ub", `/${id}`), { method: "DELETE" })).status, 404);
  assert.equal(((await call(up("ub"))).json as { items: unknown[] }).items.length, 0);
  assert.equal(((await call(up("ua"))).json as { items: unknown[] }).items.length, 1);
});

test("上传限制：非 ZIP 422、哈希不符 422、超过 128 MB 413", async () => {
  const id = await newUpload("ul", {}, null);
  assert.equal((await call(up("ul", `/${id}/file`), { method: "PUT", body: Buffer.from("not a zip at all") })).status, 422);
  assert.equal((await call(up("ul", `/${id}/file`), { method: "PUT", body: zip(100), headers: { "x-sha256": "0".repeat(64) } })).status, 422);
  assert.equal((await call(up("ul", `/${id}/file`), { method: "PUT", body: zip(100), headers: { "content-length": String(129 * 1024 * 1024) } })).status, 413);
  assert.equal(((await call(up("ul", `/${id}`))).json as { sha256: string | null }).sha256, null);
});

test("公开后出现在目录与 facets（origin=ugc），改回私有即消失；未提供的字段沿用，许可证链接随许可证更新", async () => {
  const id = await newUpload("up1", { title: "Public Chop", genres: ["lofi"] });
  const pub = await call(up("up1", `/${id}`), { method: "PATCH", json: { visibility: "public", license: "CC-BY-NC-4.0", description: "d" } });
  assert.equal(pub.status, 200, JSON.stringify(pub.json));
  const p = pub.json as { visibility: string; license_url: string; commercial_ok: boolean; title: string; group_count: number };
  assert.equal(p.visibility, "public");
  assert.equal(p.license_url, "https://creativecommons.org/licenses/by-nc/4.0/");
  assert.equal(p.commercial_ok, false);
  assert.equal(p.title, "Public Chop");
  assert.equal(p.group_count, 4);
  const list = (await call("/v1/catalog?origin=ugc")).json as { total: number; items: Record<string, unknown>[] };
  assert.equal(list.total, 1);
  assert.equal(list.items[0]!.id, id);
  for (const k of ["owner_sub", "visibility", "moderation", "source_declaration", "status"]) assert.equal(k in list.items[0]!, false, k);
  const facets = (await call("/v1/catalog/facets")).json as { origins: { id: string }[]; genres: { id: string }[] };
  assert.ok(facets.origins.some((o) => o.id === "ugc"));
  assert.ok(facets.genres.some((g) => g.id === "lofi"));
  assert.equal((await call(`/v1/catalog/${id}`)).status, 200);
  const dl = await call(`/v1/catalog/${id}/file`);
  assert.equal(dl.status, 200);
  assert.equal(dl.headers.get("x-digest")?.startsWith("sha256:"), true);
  assert.equal((await call(up("up1", `/${id}`), { method: "PATCH", json: { visibility: "private" } })).status, 200);
  assert.equal((await call(`/v1/catalog/${id}`)).status, 404);
  assert.equal(await totalUgc(), 0);
  assert.equal((await call(up("up1", `/${id}`), { method: "PATCH", json: { visibility: "secret" } })).status, 400);
  assert.equal((await call(up("up1", `/${id}`), { method: "PATCH", json: { source_declaration: "stolen" } })).status, 400);
});

test("官方条目的公开形态与行为不变", async () => {
  const meta = {
    title: "Dusk Run", artist: "UltraPads", origin: "synth", license: "CC0-1.0", attribution: "a", status: "draft",
  };
  assert.equal((await call("/v1/admin/catalog/official-one", { method: "PUT", json: meta, admin: true })).status, 200);
  assert.equal((await call("/v1/admin/catalog/official-one/file", { method: "PUT", body: zip(500, 2), admin: true })).status, 200);
  assert.equal((await call("/v1/admin/catalog/official-one", { method: "PUT", json: { ...meta, status: "published" }, admin: true })).status, 200);
  const detail = (await call("/v1/catalog/official-one")).json as Record<string, unknown>;
  assert.equal(detail.origin, "synth");
  for (const k of ["visibility", "moderation", "owner_sub", "source_declaration"]) assert.equal(k in detail, false, k);
  const r = await call("/v1/users/r1/reports", { method: "POST", json: { id: "official-one", reason: "other" } });
  assert.equal(r.status, 404); // 官方条目不接受举报
});

test("每个账号最多 50 个上传条目", async () => {
  for (let i = 0; i < 50; i++) assert.equal((await call(up("uq"), { method: "POST", json: ugcMeta({ title: `t${i}` }) })).status, 201);
  const r = await call(up("uq"), { method: "POST", json: ugcMeta() });
  assert.equal(r.status, 429);
  assert.equal((r.json as { error: string }).error, "quota_exceeded");
});

test("举报：同一用户只算一次，累计 3 人自动隐藏；运营恢复后旧举报不再计数", async () => {
  const id = await newUpload("ur-owner");
  const rep = (sub: string, over: Record<string, unknown> = {}) =>
    call(`/v1/users/${sub}/reports`, { method: "POST", json: { id, reason: "copyright", note: "n", ...over } });
  assert.equal((await rep("r1")).status, 404); // 私有条目
  await makePublic("ur-owner", id);
  assert.equal((await rep("ur-owner")).status, 400); // 不能举报自己的
  assert.equal((await rep("r1", { reason: "spam" })).status, 400);
  assert.equal((await rep("r1", { id: "Bad Id" })).status, 400);
  assert.equal((await rep("r1")).status, 202);
  assert.equal((await rep("r1")).status, 202); // 重复举报：不累计
  assert.equal((await rep("r2", { reason: "inappropriate" })).status, 202);
  assert.equal((await call(`/v1/catalog/${id}`)).status, 200); // 才 2 人
  const reports = (await call("/v1/admin/reports", { admin: true })).json as { items: { id: string; count: number; reports: unknown[] }[] };
  assert.equal(reports.items.find((i) => i.id === id)!.count, 2);
  assert.equal((await call("/v1/admin/reports")).status, 401);
  const third = await rep("r3", { reason: "other" });
  assert.equal(third.status, 202);
  assert.equal((third.json as { hidden: boolean }).hidden, true);
  assert.equal((await call(`/v1/catalog/${id}`)).status, 404); // hidden：不再公开
  assert.equal((await call(`/v1/catalog/${id}/file`)).status, 404);
  assert.equal(await totalUgc(), 0);
  assert.equal((await rep("r4")).status, 404);
  const mine = (await call(up("ur-owner", `/${id}`))).json as { moderation: string; visibility: string };
  assert.equal(mine.moderation, "hidden");
  assert.equal(mine.visibility, "public");
  assert.equal((await call(`/v1/admin/catalog/${id}/moderation`, { method: "PUT", json: { state: "active" } })).status, 401);
  assert.equal((await call(`/v1/admin/catalog/${id}/moderation`, { method: "PUT", json: { state: "hidden" }, admin: true })).status, 400);
  assert.equal((await call(`/v1/admin/catalog/${id}/moderation`, { method: "PUT", json: { state: "active" }, admin: true })).status, 200);
  assert.equal((await call(`/v1/catalog/${id}`)).status, 200);
  assert.equal(((await call("/v1/admin/reports", { admin: true })).json as { items: unknown[] }).items.length, 0);
  assert.equal((await rep("r4")).status, 202);
  assert.equal((await call(`/v1/catalog/${id}`)).status, 200); // 旧举报已处理，一次新举报不会立刻再隐藏
});

test("下架：公开详情与下载 410，收藏里消失，上传者不能再下载 / 公开 / 换文件，可删除；私有的仍是 404", async () => {
  const before = await totalUgc(); // 同一个库里别的用例留下的公开条目
  const id = await newUpload("ut");
  await makePublic("ut", id);
  assert.equal((await call(`/v1/users/fan/favorites/${id}`, { method: "PUT" })).status, 204);
  assert.equal((await call(`/v1/admin/catalog/${id}/moderation`, { method: "PUT", json: { state: "taken_down" }, admin: true })).status, 200);
  assert.equal((await call(`/v1/catalog/${id}/file`)).status, 410);
  assert.equal((await call(`/v1/catalog/${id}`)).status, 410);
  assert.equal(await totalUgc(), before);
  assert.deepEqual(((await call("/v1/users/fan/state")).json as { favorites: string[] }).favorites, []);
  assert.equal((await call(up("ut", `/${id}/file`))).status, 410);
  assert.equal((await call(up("ut", `/${id}/file`), { method: "PUT", body: zip(100) })).status, 403);
  assert.equal((await call(up("ut", `/${id}`), { method: "PATCH", json: { visibility: "private" } })).status, 200);
  assert.equal((await call(up("ut", `/${id}`), { method: "PATCH", json: { visibility: "public" } })).status, 403);
  assert.equal((await call(`/v1/catalog/${id}/file`)).status, 404); // 改回私有后不再暴露“曾公开”
  assert.equal((await call(up("ut", `/${id}`), { method: "DELETE" })).status, 204);
  assert.equal((await call(up("ut", `/${id}`))).status, 404);
  assert.equal((await call(`/v1/admin/catalog/${id}/moderation`, { method: "PUT", json: { state: "active" }, admin: true })).status, 404);
});

test("注销账号：连同上传的条目、独占的文件与自己提交的举报一起删除，他人的数据不动", async () => {
  const shared = zip(1500, 3);
  const keep = await newUpload("keeper", {}, shared);
  const file = zip(4321, 5);
  const a = await newUpload("leaver", {}, file);
  const b = await newUpload("leaver", { title: "second" }, shared); // 与 keeper 同内容
  await makePublic("leaver", a);
  await makePublic("keeper", keep);
  assert.equal((await call("/v1/users/leaver/reports", { method: "POST", json: { id: keep, reason: "other" } })).status, 202);
  const blob = path.join(dir, "files", sha(file).slice(0, 2), sha(file));
  assert.equal(fs.existsSync(blob), true);
  assert.equal((await call("/v1/users/leaver", { method: "DELETE" })).status, 204);
  assert.equal(fs.existsSync(blob), false);
  assert.equal((await call(`/v1/catalog/${a}`)).status, 404);
  assert.equal(((await call(up("leaver"))).json as { items: unknown[] }).items.length, 0);
  assert.equal((await call(`/v1/admin/catalog/${b}`, { admin: true })).status, 404);
  assert.equal((await call(`/v1/catalog/${keep}/file`)).status, 200); // 同内容的他人文件还在
  const rest = (await call("/v1/admin/reports", { admin: true })).json as { items: { id: string }[] };
  assert.equal(rest.items.some((i) => i.id === keep), false);
});

test("旧库升级：缺少 UGC 列的 catalog_items 打开时自动补列，已有条目保持公开，重复打开幂等", () => {
  const old = fs.mkdtempSync(path.join(os.tmpdir(), "ultrapads-old-"));
  const raw = new DatabaseSync(path.join(old, "ultrapads.sqlite"));
  raw.exec(`CREATE TABLE catalog_items (id TEXT PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '',
    origin TEXT NOT NULL, license TEXT NOT NULL, license_url TEXT NOT NULL, attribution TEXT NOT NULL, source_url TEXT NOT NULL DEFAULT '',
    commercial_ok INTEGER NOT NULL, share_alike INTEGER NOT NULL, bpm REAL, genres TEXT NOT NULL DEFAULT '[]', tags TEXT NOT NULL DEFAULT '[]',
    group_count INTEGER NOT NULL DEFAULT 1, pad_count INTEGER NOT NULL DEFAULT 0, duration_secs REAL NOT NULL DEFAULT 0, size INTEGER, sha256 TEXT,
    theme_color TEXT NOT NULL DEFAULT '#f0a35e', status TEXT NOT NULL DEFAULT 'draft', created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL);
    INSERT INTO catalog_items (id,title,origin,license,license_url,attribution,commercial_ok,share_alike,size,sha256,status,created_at_ms,updated_at_ms)
    VALUES ('synth-old-one','Old','synth','CC0-1.0','https://x','a',1,0,10,'${"c".repeat(64)}','published',1,1);`);
  raw.close();
  const odb = openDb(old);
  const it = odb.getItem("synth-old-one")!;
  assert.equal(it.visibility, "public");
  assert.equal(it.moderation, "active");
  assert.equal(it.owner_sub, null);
  assert.equal(odb.listCatalog({}).total, 1);
  odb.close();
  openDb(old).close();
});
