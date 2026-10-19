// 用户上传与举报：/api/me/uploads*（需登录、按 sub 隔离、文件纯透传）与 POST /api/catalog/<id>/report，
// 以及目录对下架（410）的处理。数据服务用 mock，不碰真实网络。
import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { SignJWT, exportJWK, generateKeyPair } from "jose";
import worker from "../worker/index.js";
import { _resetJwksCache } from "../worker/auth.js";

const ORIGIN = "https://ultrapads.example";
const DATA = "https://data.example/ultrapads";
const ISSUER = "https://id.example/";
const SHA = "b".repeat(64);
const ENV = { ID_ISSUER_URL: ISSUER, ALLOWED_CLIENT_IDS: "ultrapads-app", DATA_URL: DATA, ULTRAPADS_DATA_KEY: "k-data" };
const BODY = new TextEncoder().encode("0123456789abcdef");
const UP = { id: "ugc-0123456789abcdef", title: "My Chop", visibility: "private", moderation: "active", status: "draft" };

class MemCache {
  store = new Map();
  async match(req) {
    const e = this.store.get(req.url);
    return e ? new Response(e.body, { status: e.status, headers: e.headers }) : undefined;
  }
  async put(req, res) {
    this.store.set(req.url, { body: new Uint8Array(await res.arrayBuffer()), status: res.status, headers: [...res.headers] });
  }
}

let keys, calls, cache, upstream;

const ctxOf = () => {
  const pending = [];
  return { waitUntil: (p) => pending.push(Promise.resolve(p).catch(() => undefined)), flush: () => Promise.all(pending) };
};

async function token({ client = "ultrapads-app", sub = "u1" } = {}) {
  return new SignJWT({ client_id: client })
    .setProtectedHeader({ alg: "RS256", kid: "k1" })
    .setIssuer(ISSUER)
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(keys.privateKey);
}
const auth = async (o) => ({ Authorization: `Bearer ${await token(o)}` });
const jsonHeaders = async (o) => ({ ...(await auth(o)), "Content-Type": "application/json" });

async function call(path, { method = "GET", headers = {}, body } = {}) {
  const ctx = ctxOf();
  const res = await worker.fetch(new Request(ORIGIN + path, { method, headers, body }), ENV, ctx);
  await ctx.flush();
  return res;
}

beforeEach(async () => {
  keys = await generateKeyPair("RS256", { extractable: true });
  const jwk = { ...(await exportJWK(keys.publicKey)), kid: "k1", alg: "RS256", use: "sig" };
  _resetJwksCache();
  calls = [];
  cache = new MemCache();
  globalThis.caches = { default: cache };
  upstream = () => new Response("{}", { status: 200 });
  globalThis.fetch = async (input, init) => {
    const req = new Request(input, init);
    if (req.url === `${ISSUER}.well-known/jwks.json`) return Response.json({ keys: [jwk] });
    assert.ok(req.url.startsWith(DATA), `unexpected fetch ${req.url}`);
    calls.push({ url: req.url.slice(DATA.length), method: req.method, auth: req.headers.get("Authorization"), range: req.headers.get("Range"), body: await req.text() });
    return upstream(req);
  };
});

test("uploads: every route needs a valid token and never reaches the data service without one", async () => {
  for (const [method, path] of [
    ["GET", "/api/me/uploads"],
    ["POST", "/api/me/uploads"],
    ["GET", `/api/me/uploads/${UP.id}`],
    ["PATCH", `/api/me/uploads/${UP.id}`],
    ["DELETE", `/api/me/uploads/${UP.id}`],
    ["PUT", `/api/me/uploads/${UP.id}/file`],
    ["GET", `/api/me/uploads/${UP.id}/download`],
    ["POST", `/api/catalog/${UP.id}/report`],
  ]) {
    const res = await call(path, { method, body: method === "GET" || method === "DELETE" ? undefined : "{}" });
    assert.equal(res.status, 401, `${method} ${path}`);
  }
  assert.equal((await call("/api/me/uploads", { headers: await auth({ client: "sayit-app" }) })).status, 403);
  assert.equal(calls.length, 0);
});

test("uploads: create/list/get/patch/delete are scoped to the token's sub and relay data-service answers", async () => {
  upstream = (req) => {
    if (req.method === "POST") return Response.json({ ...UP, credit: "A" }, { status: 201 });
    if (req.method === "PATCH") return Response.json({ ...UP, visibility: "public", status: "published" });
    if (req.method === "DELETE") return new Response(null, { status: 204 });
    if (req.url.endsWith("/uploads")) return Response.json({ items: [UP] });
    return Response.json({ error: "not_found" }, { status: 404 });
  };
  const h = await jsonHeaders({ sub: "user/9" });
  const create = await call("/api/me/uploads", { method: "POST", headers: h, body: JSON.stringify({ title: "My Chop", credit: "A", license: "CC0-1.0", source_declaration: "own" }) });
  assert.equal(create.status, 201);
  assert.equal((await create.json()).id, UP.id);
  assert.equal(create.headers.get("Cache-Control"), "no-store");
  assert.deepEqual([calls.at(-1).method, calls.at(-1).url], ["POST", "/v1/users/user%2F9/uploads"]);
  assert.equal(JSON.parse(calls.at(-1).body).source_declaration, "own");
  assert.equal((await (await call("/api/me/uploads", { headers: h })).json()).items.length, 1);
  assert.equal((await call(`/api/me/uploads/${UP.id}`, { headers: h })).status, 404); // 数据服务说不是本人的 → 原样 404
  const patch = await call(`/api/me/uploads/${UP.id}`, { method: "PATCH", headers: h, body: JSON.stringify({ visibility: "public" }) });
  assert.equal((await patch.json()).visibility, "public");
  assert.equal(calls.at(-1).url, `/v1/users/user%2F9/uploads/${UP.id}`);
  assert.equal((await call(`/api/me/uploads/${UP.id}`, { method: "DELETE", headers: h })).status, 204);
  assert.equal(cache.store.size, 0);
});

test("uploads: bodies are validated before forwarding; upstream 4xx codes and 5xx are mapped", async () => {
  const h = await jsonHeaders();
  assert.equal((await call("/api/me/uploads", { method: "POST", headers: h, body: "nope" })).status, 400);
  assert.equal((await call("/api/me/uploads", { method: "POST", headers: h, body: "[1]" })).status, 400);
  assert.equal((await call("/api/me/uploads", { method: "POST", headers: h, body: JSON.stringify({ pad: "x".repeat(70_000) }) })).status, 413);
  assert.equal((await call("/api/me/uploads/BAD_ID", { headers: h })).status, 404);
  assert.equal((await call("/api/me/uploads", { method: "PUT", headers: h, body: "{}" })).status, 405);
  assert.equal(calls.length, 0);
  upstream = () => Response.json({ error: "bad_request", message: "credit 必填" }, { status: 400 });
  const bad = await call("/api/me/uploads", { method: "POST", headers: h, body: "{}" });
  assert.equal(bad.status, 400);
  assert.equal((await bad.json()).error, "bad_request");
  upstream = () => Response.json({ error: "quota_exceeded" }, { status: 429 });
  assert.equal((await call("/api/me/uploads", { method: "POST", headers: h, body: "{}" })).status, 429);
  upstream = () => new Response("boom", { status: 500 });
  const down = await call("/api/me/uploads", { headers: h });
  assert.equal(down.status, 502);
  assert.equal((await down.json()).error, "upstream_unavailable");
});

test("uploads: the file is streamed through with its length; missing length and >128 MB are refused locally", async () => {
  const h = await auth({ sub: "u7" });
  upstream = () => Response.json({ ...UP, status: "published", sha256: SHA });
  const res = await call(`/api/me/uploads/${UP.id}/file`, { method: "PUT", headers: { ...h, "X-Sha256": SHA, "Content-Length": "16" }, body: BODY });
  assert.equal(res.status, 200);
  assert.equal((await res.json()).sha256, SHA);
  const sent = calls.at(-1);
  assert.equal(sent.url, `/v1/users/u7/uploads/${UP.id}/file`);
  assert.equal(sent.body, "0123456789abcdef");
  assert.equal(sent.auth, "Bearer k-data");
  const before = calls.length;
  const big = await call(`/api/me/uploads/${UP.id}/file`, { method: "PUT", headers: { ...h, "Content-Length": String(129 * 1024 * 1024) }, body: BODY });
  assert.equal(big.status, 413);
  const noLen = await worker.fetch(
    new Request(ORIGIN + `/api/me/uploads/${UP.id}/file`, { method: "PUT", headers: h, body: new ReadableStream({ start: (c) => (c.enqueue(BODY), c.close()) }), duplex: "half" }),
    ENV,
    ctxOf(),
  );
  assert.equal(noLen.status, 411);
  assert.equal(calls.length, before);
  upstream = () => Response.json({ error: "not_zip" }, { status: 422 });
  assert.equal((await call(`/api/me/uploads/${UP.id}/file`, { method: "PUT", headers: { ...h, "Content-Length": "16" }, body: BODY })).status, 422);
});

test("uploads: own download streams privately with Range and is never cached", async () => {
  const h = await auth({ sub: "u7" });
  upstream = (req) => {
    const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.get("Range") ?? "");
    const base = { "Content-Type": "application/zip", ETag: `"${SHA}"`, "X-Digest": `sha256:${SHA}` };
    if (range) return new Response(BODY.slice(Number(range[1])), { status: 206, headers: { ...base, "Content-Range": "bytes 10-15/16", "Content-Length": "6" } });
    return new Response(BODY, { status: 200, headers: { ...base, "Content-Length": "16" } });
  };
  const res = await call(`/api/me/uploads/${UP.id}/download`, { headers: h });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "private, no-store");
  assert.equal(res.headers.get("X-Digest"), `sha256:${SHA}`);
  assert.equal(res.headers.get("Content-Disposition"), `attachment; filename="${UP.id}.upkit"`);
  assert.deepEqual(new Uint8Array(await res.arrayBuffer()), BODY);
  assert.equal(calls.at(-1).url, `/v1/users/u7/uploads/${UP.id}/file`);
  const part = await call(`/api/me/uploads/${UP.id}/download`, { headers: { ...h, Range: "bytes=10-" } });
  assert.equal(part.status, 206);
  assert.equal(calls.at(-1).range, "bytes=10-");
  assert.equal(cache.store.size, 0);
  upstream = () => Response.json({ error: "gone" }, { status: 410 });
  assert.equal((await call(`/api/me/uploads/${UP.id}/download`, { headers: h })).status, 410);
  upstream = () => Response.json({ error: "not_found" }, { status: 404 });
  assert.equal((await call(`/api/me/uploads/${UP.id}/download`, { headers: h })).status, 404);
  assert.equal((await call(`/api/me/uploads/${UP.id}/download`, { method: "POST", headers: h })).status, 405);
});

test("report: needs a token and a valid reason, forwards under the reporter's sub, relays 404/400", async () => {
  const h = await jsonHeaders({ sub: "rep-1" });
  const post = (body, headers = h) => call(`/api/catalog/${UP.id}/report`, { method: "POST", headers, body: JSON.stringify(body) });
  assert.equal((await post({ reason: "copyright" }, { "Content-Type": "application/json" })).status, 401);
  assert.equal((await post({ reason: "spam" })).status, 400);
  assert.equal((await post({})).status, 400);
  assert.equal((await post({ reason: "other", note: 5 })).status, 400);
  assert.equal((await call(`/api/catalog/${UP.id}/report`, { method: "POST", headers: h, body: "nope" })).status, 400);
  assert.equal((await call("/api/catalog/BAD_ID/report", { method: "POST", headers: h, body: "{}" })).status, 404);
  assert.equal(calls.length, 0);
  upstream = () => Response.json({ ok: true, hidden: false }, { status: 202 });
  const ok = await post({ reason: "copyright", note: "this is mine" });
  assert.equal(ok.status, 202);
  assert.deepEqual(await ok.json(), { ok: true });
  assert.deepEqual([calls.at(-1).method, calls.at(-1).url], ["POST", "/v1/users/rep-1/reports"]);
  assert.deepEqual(JSON.parse(calls.at(-1).body), { id: UP.id, reason: "copyright", note: "this is mine" });
  upstream = () => Response.json({ error: "not_found" }, { status: 404 });
  assert.equal((await post({ reason: "other" })).status, 404);
  upstream = () => Response.json({ error: "bad_request" }, { status: 400 });
  assert.equal((await post({ reason: "other" })).status, 400);
  upstream = () => new Response("x", { status: 503 });
  assert.equal((await post({ reason: "other" })).status, 502);
  assert.equal(cache.store.size, 0);
});

test("catalog stays read-only: writes on list, facets, detail and download are 405", async () => {
  for (const p of ["/api/catalog", "/api/catalog/facets", "/api/catalog/synth-dusk-run", "/api/catalog/synth-dusk-run/download"]) {
    assert.equal((await call(p, { method: "POST", body: "{}" })).status, 405, p);
    assert.equal((await call(p, { method: "DELETE" })).status, 405, p);
  }
  assert.equal(calls.length, 0);
});

test("a taken-down upload answers 410 on detail and download, and 410 is never cached", async () => {
  upstream = () => Response.json({ error: "gone" }, { status: 410 });
  const detail = await call(`/api/catalog/${UP.id}`);
  assert.equal(detail.status, 410);
  assert.equal((await detail.json()).error, "gone");
  assert.equal((await call(`/api/catalog/${UP.id}/download`)).status, 410);
  assert.equal(cache.store.size, 0);
  // 元数据还在缓存、文件接口已在下架后返回 410：同样 410，也不缓存文件
  upstream = (req) => (req.url.endsWith("/file") ? Response.json({ error: "gone" }, { status: 410 }) : Response.json({ id: UP.id, sha256: SHA, size: BODY.length }));
  assert.equal((await call(`/api/catalog/${UP.id}/download`)).status, 410);
  assert.equal([...cache.store.keys()].some((k) => k.includes("/dl/")), false);
});

test("CORS preflight also allows PATCH and X-Sha256 for uploads", async () => {
  const res = await call(`/api/me/uploads/${UP.id}`, { method: "OPTIONS" });
  assert.equal(res.status, 204);
  assert.match(res.headers.get("Access-Control-Allow-Methods"), /PATCH/);
  assert.match(res.headers.get("Access-Control-Allow-Headers"), /X-Sha256/);
});
