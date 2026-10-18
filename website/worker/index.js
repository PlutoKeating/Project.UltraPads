// ultrapads.plutokeating.beer 的 Worker。只接管 /api/* 与 /dl/*（wrangler.jsonc 的 run_worker_first），其余交给静态资源。
//
//   GET /api/version[?tag=vX.Y.Z][&format=sh&platform=<平台>]
//       最新正式版（或指定 tag）的版本清单：每个平台的资产名、大小、sha256、镜像地址与 GitHub 直链。
//       format=sh 时返回 UP_KEY=value 行（安装脚本用，不需要 python / jq）。契约见 docs/API.md §6。
//       上游结果在边缘缓存 5 分钟，另存 7 天的陈旧副本：GitHub 限流或连不上时顶上（X-Upstream: stale）。
//   GET /dl/<tag>/<文件名>
//       GitHub Release 资产的镜像（GitHub 在不少网络里连不上）。只镜像本仓库、符合命名的文件；
//       与 GitHub 记录的 sha256（digest）核对，通过才在边缘缓存 7 天（缓存键含 sha256，附件替换后自动失效），不符则让下载出错。
//   GET /dl/latest/<平台>
//       302 到最新正式版对应平台的 /dl/ 地址（落地页的下载按钮，页面脚本跑不起来时也能用）。
//
// 不含任何账号或令牌；GITHUB_TOKEN 是可选的 Worker Secret（提高 GitHub API 匿名 60 次 / 小时的限额）。

import { MIRRORED, PLATFORMS, REPO, TAG, manifestFromRelease, manifestToShell } from "./release.js";

const API_TTL = 300;
const STALE_TTL = 7 * 86400;
const DL_TTL = 7 * 86400;
const SMALL_MAX = 1 << 20;

const cacheOf = () => caches.default;

function cors(h) {
  h.set("Access-Control-Allow-Origin", "*");
  h.set("Access-Control-Expose-Headers", "Content-Length, X-Upstream");
  return h;
}

function text(status, body) {
  return new Response(body, {
    status,
    headers: cors(new Headers({ "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" })),
  });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const isApi = url.pathname.startsWith("/api/");
    const isDl = url.pathname.startsWith("/dl/");
    if (!isApi && !isDl) return env.ASSETS.fetch(request);
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: cors(new Headers({ "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS", "Access-Control-Allow-Headers": "Accept" })),
      });
    }
    if (request.method !== "GET" && request.method !== "HEAD") return text(405, "GET only\n");
    if (url.pathname === "/api/version") return version(url, request, env, ctx);
    if (url.pathname.startsWith("/dl/latest/")) return latest(url, env, ctx);
    if (isDl) return download(url, request, env, ctx);
    return text(404, "not found\n");
  },
};

// ---------------------------------------------------------------- GitHub

function ghHeaders(env) {
  const h = { "User-Agent": "ultrapads-site", Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" };
  if (env.GITHUB_TOKEN) h.Authorization = `Bearer ${env.GITHUB_TOKEN}`;
  return h;
}

/**
 * 取 release JSON（latest 或指定 tag），边缘缓存 + 陈旧副本。
 * 返回 { status: "ok", release, stale } | { status: "missing" } | { status: "unavailable" }。
 */
async function fetchRelease(origin, tag, env, ctx) {
  const path = tag ? `tags/${encodeURIComponent(tag)}` : "latest";
  const cache = cacheOf();
  const key = new Request(`${origin}/api/_release/${path}`);
  const staleKey = new Request(`${origin}/api/_release/${path}?stale=1`);
  const hit = await cache.match(key);
  if (hit) return { status: "ok", release: await hit.json(), stale: false };
  const fromStale = async () => {
    const s = await cache.match(staleKey);
    return s ? { status: "ok", release: await s.json(), stale: true } : { status: "unavailable" };
  };
  let res;
  try {
    res = await fetch(`https://api.github.com/repos/${REPO}/releases/${path}`, { headers: ghHeaders(env) });
  } catch {
    return fromStale();
  }
  if (res.status === 404) return { status: "missing" };
  if (!res.ok) return fromStale();
  let release;
  try {
    release = await res.json();
  } catch {
    return fromStale();
  }
  const body = JSON.stringify(release);
  ctx.waitUntil(Promise.all([
    cache.put(key, new Response(body, { headers: { "Content-Type": "application/json", "Cache-Control": `public, max-age=${API_TTL}` } })),
    cache.put(staleKey, new Response(body, { headers: { "Content-Type": "application/json", "Cache-Control": `public, max-age=${STALE_TTL}` } })),
  ]));
  return { status: "ok", release, stale: false };
}

// ---------------------------------------------------------------- /api/version

async function version(url, request, env, ctx) {
  const tag = url.searchParams.get("tag");
  if (tag !== null && !TAG.test(tag)) return text(400, "tag must look like vX.Y.Z\n");
  const r = await fetchRelease(url.origin, tag, env, ctx);
  if (r.status === "missing") return text(404, tag ? `no such release: ${tag}\n` : "no release yet\n");
  if (r.status !== "ok") return text(502, "GitHub is unreachable, try again later\n");
  const manifest = manifestFromRelease(r.release, url.origin);
  if (!manifest) return text(404, "not a stable release\n");

  const headers = cors(new Headers({ "Cache-Control": "no-cache", "X-Upstream": r.stale ? "stale" : "github" }));
  if (url.searchParams.get("format") === "sh") {
    const platform = url.searchParams.get("platform") ?? "";
    if (!PLATFORMS.includes(platform)) return text(400, `platform must be one of: ${PLATFORMS.join(", ")}\n`);
    const body = manifestToShell(manifest, platform);
    if (!body) return text(404, `${manifest.tag} has no package for ${platform}\n`);
    headers.set("Content-Type", "text/plain; charset=utf-8");
    return new Response(request.method === "HEAD" ? null : body, { status: 200, headers });
  }
  headers.set("Content-Type", "application/json; charset=utf-8");
  return new Response(request.method === "HEAD" ? null : JSON.stringify(manifest), { status: 200, headers });
}

// ---------------------------------------------------------------- /dl/latest/<平台>

async function latest(url, env, ctx) {
  const platform = url.pathname.slice("/dl/latest/".length);
  if (!PLATFORMS.includes(platform)) return text(404, `platform must be one of: ${PLATFORMS.join(", ")}\n`);
  const r = await fetchRelease(url.origin, null, env, ctx);
  if (r.status !== "ok") return text(502, "latest release is unavailable, try again later\n");
  const manifest = manifestFromRelease(r.release, url.origin);
  const a = manifest?.assets[platform];
  if (!a) return text(404, `latest release has no package for ${platform}\n`);
  return new Response(null, {
    status: 302,
    headers: cors(new Headers({ Location: a.url, "Cache-Control": "public, max-age=60" })),
  });
}

// ---------------------------------------------------------------- /dl/<tag>/<文件名>

async function download(url, request, env, ctx) {
  const [, , tag, asset, extra] = url.pathname.split("/");
  if (!tag || !asset || extra !== undefined || !TAG.test(tag) || !MIRRORED.test(asset)) {
    return text(404, "only release assets of this project are mirrored: /dl/<tag>/<file>\n");
  }
  const head = request.method === "HEAD";
  const cache = cacheOf();

  const rel = await fetchRelease(url.origin, tag, env, ctx);
  if (rel.status === "missing") return text(404, `no such release: ${tag}\n`);
  let expected = null;
  let size;
  if (rel.status === "ok") {
    const a = (rel.release.assets ?? []).find((x) => x.name === asset);
    if (!a) return text(404, `${tag} has no ${asset}\n`);
    const m = /^sha256:([0-9a-f]{64})$/.exec(String(a.digest ?? "").toLowerCase());
    if (!m) return text(502, `GitHub has no sha256 for ${asset}; not mirroring\n`);
    expected = m[1];
    if (typeof a.size === "number") size = a.size;
  }
  // 缓存键带上 GitHub 记录的 sha256：同一 tag 的附件被替换后旧副本自动失效，不会与新清单对不上
  const key = expected ? new Request(`${url.origin}/dl/${tag}/${asset}?sha256=${expected}`) : null;
  if (key) {
    const hit = await cache.match(key);
    if (hit) return withBody(hit, head);
  }

  let res;
  try {
    res = await fetch(`https://github.com/${REPO}/releases/download/${tag}/${asset}`, {
      redirect: "follow",
      headers: { "User-Agent": "ultrapads-site" },
    });
  } catch (e) {
    return text(502, `GitHub is unreachable: ${e.message}\n`);
  }
  if (!res.ok || !res.body) return text(res.status === 404 ? 404 : 502, `GitHub returned ${res.status}\n`);
  const headers = cors(new Headers());
  headers.set("Content-Type", res.headers.get("Content-Type") ?? "application/octet-stream");
  headers.set("Content-Disposition", `attachment; filename="${asset}"`);
  headers.set("X-Upstream", "github");
  const len = res.headers.get("Content-Length");

  if (!expected) {
    // 发布 JSON 取不到：照常转发，但不缓存；客户端自己还会核对 sha256
    if (len) headers.set("Content-Length", len);
    headers.set("Cache-Control", "no-store");
    headers.set("X-Digest", "unavailable");
    return new Response(head ? null : res.body, { status: 200, headers });
  }
  headers.set("Cache-Control", `public, max-age=${DL_TTL}, immutable`);
  headers.set("X-Digest", `sha256:${expected}`);
  if (size === undefined && len && /^\d+$/.test(len)) size = Number(len);

  if (size !== undefined && size <= SMALL_MAX) {
    const buf = await res.arrayBuffer();
    if (hex(await crypto.subtle.digest("SHA-256", buf)) !== expected) return text(502, `${asset} does not match GitHub's sha256\n`);
    headers.set("Content-Length", String(buf.byteLength));
    ctx.waitUntil(cache.put(key, new Response(buf, { status: 200, headers })));
    return new Response(head ? null : buf, { status: 200, headers });
  }

  // 大文件边转发边算哈希；已知大小时套 FixedLengthStream，响应带 Content-Length（进度条要用）
  let verified = verifying(res.body, expected);
  if (size !== undefined) verified = verified.pipeThrough(new FixedLengthStream(size));
  if (head) {
    ctx.waitUntil(cache.put(key, new Response(verified, { status: 200, headers })).catch(() => undefined));
    return new Response(null, { status: 200, headers });
  }
  const [client, toCache] = verified.tee();
  // 核对失败时 toCache 流出错，cache.put 随之失败，什么也不存
  ctx.waitUntil(cache.put(key, new Response(toCache, { status: 200, headers })).catch(() => undefined));
  return new Response(client, { status: 200, headers });
}

/** 边转发边算 sha256；始终扣住最后一块，核对通过才放出，不符则让流出错（客户端拿到截断的文件）。 */
function verifying(body, expected) {
  const ds = new crypto.DigestStream("SHA-256");
  const w = ds.getWriter();
  let pending;
  return body.pipeThrough(new TransformStream({
    async transform(chunk, c) {
      await w.write(chunk);
      if (pending) c.enqueue(pending);
      pending = chunk;
    },
    async flush(c) {
      await w.close();
      if (hex(await ds.digest) !== expected) throw new Error("sha256 mismatch");
      if (pending) c.enqueue(pending);
    },
  }));
}

const hex = (b) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");

function withBody(res, head) {
  const r = new Response(head ? null : res.body, res);
  cors(r.headers);
  return r;
}
