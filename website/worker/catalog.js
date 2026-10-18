// /api/catalog*：官方曲库目录（匿名可读）与 .upkit 下载。契约见 docs/API.md §7.2。
// 不处理字节：下载是纯透传（Worker 每请求只有 10 ms CPU，不在这里哈希或切分）。

import { optionalUser } from "./auth.js";
import { cors, json, jsonError } from "./http.js";
import { UpstreamError, dataFetch } from "./data.js";

const ID = /^[a-z0-9][a-z0-9-]{2,63}$/;
const LICENSES = new Set(["CC0-1.0", "CC-BY-4.0", "CC-BY-3.0", "CC-BY-SA-4.0", "CC-BY-SA-3.0", "CC-BY-NC-4.0", "CC-BY-NC-SA-4.0", "PD"]);
const ORIGINS = new Set(["album", "online", "synth", "ugc"]);
const SORTS = new Set(["new", "bpm", "title"]);
const LIST_TTL = 60;
const DL_TTL = 7 * 86400;
const MAX_LIMIT = 50;

const cacheOf = () => caches.default;

export const isCatalogId = (id) => ID.test(id);

/** 校验并规范化列表查询串（键排序、值去重排序），非法返回 { error }。 */
export function normalizeListQuery(params) {
  const out = new Map();
  const bad = (m) => ({ error: m });
  const q = params.get("q");
  if (q) {
    if (q.length > 100) return bad("q too long");
    out.set("q", q);
  }
  const genre = params.get("genre");
  if (genre) {
    if (genre.length > 40) return bad("genre too long");
    out.set("genre", genre);
  }
  const set = (name, allowed) => {
    const values = [...new Set(params.getAll(name).flatMap((v) => v.split(",")).map((s) => s.trim()).filter(Boolean))].sort();
    if (values.some((v) => !allowed.has(v))) return false;
    if (values.length) out.set(name, values.join(","));
    return true;
  };
  if (!set("license", LICENSES)) return bad("unknown license");
  if (!set("origin", ORIGINS)) return bad("unknown origin");
  for (const k of ["bpm_min", "bpm_max"]) {
    const v = params.get(k);
    if (v === null || v === "") continue;
    if (!/^\d{1,3}$/.test(v) || Number(v) < 20 || Number(v) > 400) return bad(`${k} must be 20..400`);
    out.set(k, v);
  }
  const sort = params.get("sort");
  if (sort) {
    if (!SORTS.has(sort)) return bad("sort must be new, bpm or title");
    out.set("sort", sort);
  }
  const cursor = params.get("cursor");
  if (cursor) {
    if (cursor.length > 200 || !/^[A-Za-z0-9_=.-]+$/.test(cursor)) return bad("bad cursor");
    out.set("cursor", cursor);
  }
  const limit = params.get("limit");
  if (limit !== null && limit !== "") {
    if (!/^\d{1,4}$/.test(limit) || Number(limit) < 1) return bad("limit must be a positive integer");
    out.set("limit", String(Math.min(Number(limit), MAX_LIMIT)));
  }
  const qs = new URLSearchParams([...out.entries()].sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
  return { qs: qs.toString() };
}

/** GET 上游 JSON，边缘缓存 60 秒；返回 { status, body(text) }。上游不可达抛 UpstreamError。 */
async function cachedGet(origin, cacheKey, env, ctx, path) {
  const cache = cacheOf();
  const key = new Request(`${origin}/api/_cache/${cacheKey}`);
  const hit = await cache.match(key);
  if (hit) return { status: hit.status, body: await hit.text() };
  const res = await dataFetch(env, path);
  if (res.status === 404) return { status: 404, body: null };
  if (!res.ok) throw new UpstreamError(`data service ${res.status}`);
  const body = await res.text();
  ctx.waitUntil(cache.put(key, new Response(body, { headers: { "Content-Type": "application/json", "Cache-Control": `public, max-age=${LIST_TTL}` } })));
  return { status: 200, body };
}

function jsonText(body) {
  return new Response(body, {
    status: 200,
    headers: cors(new Headers({ "Content-Type": "application/json; charset=utf-8", "Cache-Control": `public, max-age=${LIST_TTL}` })),
  });
}

export async function handleCatalog(request, url, env, ctx) {
  const path = url.pathname;
  try {
    if (path === "/api/catalog") {
      const n = normalizeListQuery(url.searchParams);
      if (n.error) return jsonError(400, "invalid_query", n.error);
      const r = await cachedGet(url.origin, `catalog?${n.qs}`, env, ctx, `/v1/catalog${n.qs ? `?${n.qs}` : ""}`);
      return jsonText(r.body);
    }
    if (path === "/api/catalog/facets") {
      const r = await cachedGet(url.origin, "facets", env, ctx, "/v1/catalog/facets");
      return jsonText(r.body);
    }
    const m = /^\/api\/catalog\/([^/]+)(\/download)?$/.exec(path);
    if (!m) return jsonError(404, "not_found");
    const id = m[1];
    if (!ID.test(id)) return jsonError(404, "not_found");
    if (m[2]) return download(request, url, env, ctx, id);
    const r = await cachedGet(url.origin, `item/${id}`, env, ctx, `/v1/catalog/${id}`);
    if (r.status === 404) return jsonError(404, "not_found");
    return jsonText(r.body);
  } catch (e) {
    if (e instanceof UpstreamError) return jsonError(502, "upstream_unavailable");
    throw e;
  }
}

// ---------------------------------------------------------------- 下载

function startsAtZero(range) {
  if (!range) return true;
  const m = /^bytes=(\d*)-/.exec(range);
  return !!m && (m[1] === "" ? false : Number(m[1]) === 0);
}

async function download(request, url, env, ctx, id) {
  const meta = await cachedGet(url.origin, `item/${id}`, env, ctx, `/v1/catalog/${id}`);
  if (meta.status === 404) return jsonError(404, "not_found");
  const item = JSON.parse(meta.body);
  const sha = String(item.sha256 ?? "");
  if (!/^[0-9a-f]{64}$/.test(sha)) return jsonError(502, "upstream_unavailable");
  const head = request.method === "HEAD";
  const range = request.headers.get("Range");

  const headers = cors(new Headers());
  headers.set("Content-Type", "application/zip");
  headers.set("Content-Disposition", `attachment; filename="${id}.upkit"`);
  headers.set("Accept-Ranges", "bytes");
  headers.set("X-Digest", `sha256:${sha}`);
  headers.set("ETag", `"${sha}"`);
  headers.set("Cache-Control", `public, max-age=${DL_TTL}, immutable`);

  const user = await optionalUser(request, env);
  const record = () => {
    if (user && startsAtZero(range)) {
      ctx.waitUntil(
        dataFetch(env, `/v1/users/${encodeURIComponent(user.sub)}/downloads`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id }),
        }).catch(() => undefined),
      );
    }
  };

  if (head) {
    if (typeof item.size === "number") headers.set("Content-Length", String(item.size));
    return new Response(null, { status: 200, headers });
  }

  // 缓存键含 sha256：条目文件被替换后旧副本自动失效；Range 由 Cache API 原生切片
  const cache = cacheOf();
  const key = new Request(`${url.origin}/api/_cache/dl/${id}?sha256=${sha}`, range ? { headers: { Range: range } } : undefined);
  const hit = await cache.match(key);
  if (hit) {
    record();
    const r = new Response(hit.body, hit);
    cors(r.headers);
    r.headers.set("X-Digest", `sha256:${sha}`);
    return r;
  }

  const up = await dataFetch(env, `/v1/catalog/${id}/file`, range ? { headers: { Range: range } } : {});
  if (up.status === 404) return jsonError(404, "not_found");
  if (up.status === 416) return jsonError(416, "range_not_satisfiable");
  if (!up.ok || !up.body) throw new UpstreamError(`data service ${up.status}`);
  for (const h of ["Content-Length", "Content-Range"]) {
    const v = up.headers.get(h);
    if (v) headers.set(h, v);
  }
  record();
  const out = new Response(up.body, { status: up.status, headers });
  const etag = up.headers.get("ETag");
  if (up.status === 200 && !range && (!etag || etag === `"${sha}"`)) {
    ctx.waitUntil(cache.put(new Request(`${url.origin}/api/_cache/dl/${id}?sha256=${sha}`), out.clone()).catch(() => undefined));
  }
  return out;
}
