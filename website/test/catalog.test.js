import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { SignJWT, exportJWK, generateKeyPair } from "jose";
import worker from "../worker/index.js";
import { _resetJwksCache } from "../worker/auth.js";
import { normalizeListQuery } from "../worker/catalog.js";

const ORIGIN = "https://ultrapads.example";
const DATA = "https://data.example/ultrapads";
const ISSUER = "https://id.example/";
const SHA = "b".repeat(64);
const ENV = { ID_ISSUER_URL: ISSUER, ALLOWED_CLIENT_IDS: "ultrapads-app", DATA_URL: DATA, ULTRAPADS_DATA_KEY: "k-data" };
const BODY = new TextEncoder().encode("0123456789abcdef");
const ITEM = { id: "synth-dusk-run", title: "Dusk Run", license: "CC0-1.0", sha256: SHA, size: BODY.length };

/** 内存版 Cache API（含 Range 切片）。 */
class MemCache {
  store = new Map();
  async match(req) {
    const e = this.store.get(req.url);
    if (!e) return undefined;
    const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.get("Range") ?? "");
    if (range) {
      const a = Number(range[1]);
      const b = range[2] ? Number(range[2]) : e.body.length - 1;
      const h = new Headers(e.headers);
      h.set("Content-Range", `bytes ${a}-${b}/${e.body.length}`);
      return new Response(e.body.slice(a, b + 1), { status: 206, headers: h });
    }
    return new Response(e.body, { status: e.status, headers: e.headers });
  }
  async put(req, res) {
    this.store.set(req.url, { body: new Uint8Array(await res.arrayBuffer()), status: res.status, headers: [...res.headers] });
  }
}

let keys, calls, cache, upstream, jwksHits;

const ctxOf = () => {
  const pending = [];
  return { waitUntil: (p) => pending.push(Promise.resolve(p).catch(() => undefined)), flush: () => Promise.all(pending) };
};

async function token({ client = "ultrapads-app", sub = "u1", iss = ISSUER, exp = "1h", key = keys.privateKey } = {}) {
  return new SignJWT({ client_id: client, email: "a@b.c" })
    .setProtectedHeader({ alg: "RS256", kid: "k1" })
    .setIssuer(iss)
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime(exp)
    .sign(key);
}

async function call(path, { method = "GET", headers = {}, body, env = ENV } = {}) {
  const ctx = ctxOf();
  const res = await worker.fetch(new Request(ORIGIN + path, { method, headers, body }), env, ctx);
  await ctx.flush();
  return res;
}

beforeEach(async () => {
  keys = await generateKeyPair("RS256", { extractable: true });
  const jwk = { ...(await exportJWK(keys.publicKey)), kid: "k1", alg: "RS256", use: "sig" };
  _resetJwksCache();
  calls = [];
  jwksHits = 0;
  cache = new MemCache();
  globalThis.caches = { default: cache };
  upstream = () => new Response("{}", { status: 200 });
  globalThis.fetch = async (input, init) => {
    const req = new Request(input, init);
    if (req.url === `${ISSUER}.well-known/jwks.json`) {
      jwksHits++;
      return Response.json({ keys: [jwk] });
    }
    assert.ok(req.url.startsWith(DATA), `unexpected fetch ${req.url}`);
    calls.push({ url: req.url.slice(DATA.length), method: req.method, auth: req.headers.get("Authorization"), range: req.headers.get("Range"), body: await req.text() });
    return upstream(req);
  };
});

// ---------------------------------------------------------------- 目录

test("list: validates and normalizes the query before calling the data service", async () => {
  upstream = () => Response.json({ items: [ITEM], next_cursor: null, total: 1 });
  const res = await call("/api/catalog?sort=bpm&license=CC0-1.0,CC-BY-4.0&license=CC-BY-4.0&limit=500&q=dusk&bpm_min=90");
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "public, max-age=60");
  assert.equal((await res.json()).total, 1);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "/v1/catalog?bpm_min=90&license=CC-BY-4.0%2CCC0-1.0&limit=50&q=dusk&sort=bpm");
  assert.equal(calls[0].auth, "Bearer k-data");
});

test("list: bad parameters are rejected without touching upstream", async () => {
  for (const q of ["license=GPL", "origin=x", "bpm_min=5", "bpm_max=abc", "sort=random", "limit=0", "limit=x", "cursor=a%20b", `q=${"x".repeat(101)}`]) {
    const res = await call(`/api/catalog?${q}`);
    assert.equal(res.status, 400, q);
    assert.equal((await res.json()).error, "invalid_query");
  }
  assert.equal(calls.length, 0);
  assert.deepEqual(normalizeListQuery(new URLSearchParams("")), { qs: "" });
});

test("list: anonymous responses are cached for the same normalized query", async () => {
  upstream = () => Response.json({ items: [], next_cursor: null, total: 0 });
  await call("/api/catalog?license=CC0-1.0&sort=new");
  await call("/api/catalog?sort=new&license=CC0-1.0");
  assert.equal(calls.length, 1);
  await call("/api/catalog?sort=title");
  assert.equal(calls.length, 2);
});

test("facets and detail are proxied; unknown id is 404; bad id never reaches upstream", async () => {
  upstream = (req) => {
    if (req.url.endsWith("/v1/catalog/facets")) return Response.json({ licenses: [], genres: [], origins: [] });
    if (req.url.endsWith("/v1/catalog/synth-dusk-run")) return Response.json(ITEM);
    return Response.json({ error: "not_found" }, { status: 404 });
  };
  assert.equal((await call("/api/catalog/facets")).status, 200);
  assert.equal((await (await call("/api/catalog/synth-dusk-run")).json()).title, "Dusk Run");
  assert.equal((await call("/api/catalog/nope-nope")).status, 404);
  const n = calls.length;
  assert.equal((await call("/api/catalog/..%2Fetc")).status, 404);
  assert.equal((await call("/api/catalog/UPPER")).status, 404);
  assert.equal(calls.length, n);
  assert.equal((await call("/api/catalog", { method: "POST" })).status, 405);
});

test("data service failure maps to 502 upstream_unavailable", async () => {
  upstream = () => new Response("boom", { status: 500 });
  let res = await call("/api/catalog");
  assert.equal(res.status, 502);
  assert.equal((await res.json()).error, "upstream_unavailable");
  upstream = () => {
    throw new TypeError("network down");
  };
  res = await call("/api/catalog/synth-dusk-run");
  assert.equal(res.status, 502);
  assert.equal(await call("/api/me/state", { headers: { Authorization: `Bearer ${await token()}` } }).then((r) => r.status), 502);
  assert.equal((await call("/api/catalog", { env: { ...ENV, ULTRAPADS_DATA_KEY: undefined } })).status, 502);
});

// ---------------------------------------------------------------- 下载

function downloadUpstream(req) {
  if (req.url.endsWith("/v1/catalog/synth-dusk-run")) return Response.json(ITEM);
  if (req.url.endsWith("/v1/catalog/synth-dusk-run/file")) {
    const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.get("Range") ?? "");
    const h = { "Content-Type": "application/zip", ETag: `"${SHA}"` };
    if (range) {
      const a = Number(range[1]);
      const b = range[2] ? Number(range[2]) : BODY.length - 1;
      return new Response(BODY.slice(a, b + 1), { status: 206, headers: { ...h, "Content-Range": `bytes ${a}-${b}/${BODY.length}`, "Content-Length": String(b - a + 1) } });
    }
    return new Response(BODY, { status: 200, headers: { ...h, "Content-Length": String(BODY.length) } });
  }
  if (req.url.includes("/downloads")) return new Response(null, { status: 204 });
  return Response.json({ error: "not_found" }, { status: 404 });
}

test("download: anonymous stream, headers, then served from cache keyed by sha256", async () => {
  upstream = downloadUpstream;
  const res = await call("/api/catalog/synth-dusk-run/download");
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("X-Digest"), `sha256:${SHA}`);
  assert.equal(res.headers.get("Content-Disposition"), 'attachment; filename="synth-dusk-run.upkit"');
  assert.equal(res.headers.get("Content-Type"), "application/zip");
  assert.deepEqual(new Uint8Array(await res.arrayBuffer()), BODY);
  assert.ok(calls.some((c) => c.url === "/v1/catalog/synth-dusk-run/file"));
  assert.ok([...cache.store.keys()].some((k) => k.endsWith(`/api/_cache/dl/synth-dusk-run?sha256=${SHA}`)));
  assert.equal(calls.some((c) => c.url.includes("/downloads")), false);

  const before = calls.length;
  const again = await call("/api/catalog/synth-dusk-run/download");
  assert.deepEqual(new Uint8Array(await again.arrayBuffer()), BODY);
  assert.equal(calls.length, before, "second download is a cache hit");

  const part = await call("/api/catalog/synth-dusk-run/download", { headers: { Range: "bytes=4-7" } });
  assert.equal(part.status, 206);
  assert.equal(new TextDecoder().decode(await part.arrayBuffer()), "4567");
});

test("download: Range is passed through to the data service and partial responses are not cached", async () => {
  upstream = downloadUpstream;
  const res = await call("/api/catalog/synth-dusk-run/download", { headers: { Range: "bytes=10-" } });
  assert.equal(res.status, 206);
  assert.equal(res.headers.get("Content-Range"), "bytes 10-15/16");
  assert.equal(new TextDecoder().decode(await res.arrayBuffer()), "abcdef");
  assert.equal(calls.find((c) => c.url.endsWith("/file")).range, "bytes=10-");
  assert.equal([...cache.store.keys()].some((k) => k.includes("/dl/")), false);
});

test("download: a valid token records history, an invalid one still downloads anonymously", async () => {
  upstream = downloadUpstream;
  let res = await call("/api/catalog/synth-dusk-run/download", { headers: { Authorization: `Bearer ${await token({ sub: "user/1" })}` } });
  assert.equal(res.status, 200);
  await res.arrayBuffer();
  const rec = calls.find((c) => c.url.includes("/downloads"));
  assert.equal(rec.method, "POST");
  assert.equal(rec.url, "/v1/users/user%2F1/downloads");
  assert.deepEqual(JSON.parse(rec.body), { id: "synth-dusk-run" });

  cache.store.clear();
  calls.length = 0;
  res = await call("/api/catalog/synth-dusk-run/download", { headers: { Authorization: "Bearer garbage" } });
  assert.equal(res.status, 200);
  await res.arrayBuffer();
  assert.equal(calls.some((c) => c.url.includes("/downloads")), false);
});

test("download: HEAD, unknown id and ranges beyond the file", async () => {
  upstream = downloadUpstream;
  const head = await call("/api/catalog/synth-dusk-run/download", { method: "HEAD" });
  assert.equal(head.status, 200);
  assert.equal(head.headers.get("Content-Length"), String(BODY.length));
  assert.equal(calls.some((c) => c.url.endsWith("/file")), false);
  assert.equal((await call("/api/catalog/other-song/download")).status, 404);
  upstream = (req) => (req.url.endsWith("/file") ? new Response("", { status: 416 }) : downloadUpstream(req));
  assert.equal((await call("/api/catalog/synth-dusk-run/download", { headers: { Range: "bytes=99-" } })).status, 416);
});

// ---------------------------------------------------------------- 账号

const auth = async (o) => ({ Authorization: `Bearer ${await token(o)}` });

test("me: 401 for missing/invalid/expired/wrong-issuer/wrong-key tokens, 403 for foreign clients", async () => {
  const other = await generateKeyPair("RS256");
  const cases = [
    [{}, "missing_token", 401],
    [{ Authorization: "Bearer nonsense" }, "invalid_token", 401],
    [{ Authorization: `Bearer ${await token({ exp: "-1m" })}` }, "invalid_token", 401],
    [{ Authorization: `Bearer ${await token({ iss: "https://evil.example/" })}` }, "invalid_token", 401],
    [{ Authorization: `Bearer ${await token({ key: other.privateKey })}` }, "invalid_token", 401],
    [{ Authorization: `Bearer ${await token({ client: "sayit-app" })}` }, "client_not_allowed", 403],
  ];
  for (const [headers, error, status] of cases) {
    const res = await call("/api/me", { headers });
    assert.equal(res.status, status, error);
    assert.equal((await res.json()).error, error);
  }
  assert.equal(calls.length, 0);
});

test("me: identity, state and favorites are isolated by sub and never cached", async () => {
  upstream = (req) => {
    if (req.url.endsWith("/state")) return Response.json({ favorites: ["synth-dusk-run"], recent: [], downloads: [] });
    if (req.method === "PUT" && req.url.includes("/favorites/synth-dusk-run")) return new Response(null, { status: 204 });
    if (req.method === "PUT") return Response.json({ error: "not_found" }, { status: 404 });
    return new Response(null, { status: 204 });
  };
  const h = await auth({ sub: "abc-123" });
  let res = await call("/api/me", { headers: h });
  assert.deepEqual(await res.json(), { sub: "abc-123", email: "a@b.c" });
  assert.equal(res.headers.get("Cache-Control"), "no-store");
  res = await call("/api/me/state", { headers: h });
  assert.deepEqual((await res.json()).favorites, ["synth-dusk-run"]);
  assert.equal(calls.at(-1).url, "/v1/users/abc-123/state");
  assert.equal((await call("/api/me/favorites/synth-dusk-run", { method: "PUT", headers: h })).status, 204);
  assert.equal((await call("/api/me/favorites/synth-dusk-run", { method: "DELETE", headers: h })).status, 204);
  assert.equal((await call("/api/me/favorites/missing-one", { method: "PUT", headers: h })).status, 404);
  assert.equal((await call("/api/me/favorites/BAD", { method: "PUT", headers: h })).status, 404);
  assert.equal((await call("/api/me/favorites/synth-dusk-run", { method: "POST", headers: h })).status, 405);
  assert.equal(cache.store.size, 0);
});

test("me: recent validates the body; delete cascades", async () => {
  upstream = () => new Response(null, { status: 204 });
  const h = await auth();
  assert.equal((await call("/api/me/recent", { method: "POST", headers: h, body: "nope" })).status, 400);
  assert.equal((await call("/api/me/recent", { method: "POST", headers: h, body: JSON.stringify({ id: "../x" }) })).status, 400);
  assert.equal((await call("/api/me/recent", { method: "POST", headers: h, body: JSON.stringify({ id: "synth-dusk-run" }) })).status, 204);
  assert.deepEqual(JSON.parse(calls.at(-1).body), { id: "synth-dusk-run" });
  assert.equal((await call("/api/me", { method: "DELETE", headers: h })).status, 204);
  assert.deepEqual([calls.at(-1).method, calls.at(-1).url], ["DELETE", "/v1/users/u1"]);
});

test("JWKS is fetched once per issuer", async () => {
  upstream = () => new Response(null, { status: 204 });
  const h = await auth();
  await call("/api/me", { headers: h });
  await call("/api/me", { headers: h });
  assert.equal(jwksHits, 1);
});

test("CORS preflight allows Authorization and the account methods", async () => {
  const res = await call("/api/me/favorites/synth-dusk-run", { method: "OPTIONS" });
  assert.equal(res.status, 204);
  assert.match(res.headers.get("Access-Control-Allow-Methods"), /PUT.*DELETE/);
  assert.match(res.headers.get("Access-Control-Allow-Headers"), /Authorization/);
});
