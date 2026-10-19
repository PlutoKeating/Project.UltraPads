// /api/me*：账号数据与用户上传（需要登录）。契约见 docs/API.md §7.3、§7.5。数据按令牌的 sub 隔离，保存在数据服务里。
// 上传文件是纯透传的流（Worker 不读字节、不算哈希）：大小限制与 ZIP / 哈希校验都在数据服务。

import { AuthError, requireUser } from "./auth.js";
import { cors, json, jsonError, noContent } from "./http.js";
import { UpstreamError, dataFetch } from "./data.js";
import { isCatalogId } from "./catalog.js";

const MAX_UPLOAD_BYTES = 128 * 1024 * 1024;
const MAX_JSON_BYTES = 64 * 1024;

export async function handleMe(request, url, env) {
  let user;
  try {
    user = await requireUser(request, env);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.code === "client_not_allowed" ? 403 : 401, e.code);
    throw e;
  }
  const base = `/v1/users/${encodeURIComponent(user.sub)}`;
  const path = url.pathname;
  const method = request.method;
  try {
    if (path === "/api/me") {
      if (method === "GET") return json(200, { sub: user.sub, ...(user.email ? { email: user.email } : {}), ...(user.name ? { name: user.name } : {}) });
      if (method === "DELETE") return upstreamNoContent(await dataFetch(env, base, { method: "DELETE" }));
      return jsonError(405, "method_not_allowed");
    }
    if (path === "/api/me/state") {
      if (method !== "GET") return jsonError(405, "method_not_allowed");
      const res = await dataFetch(env, `${base}/state`);
      if (!res.ok) throw new UpstreamError(`data service ${res.status}`);
      return json(200, await res.json());
    }
    const fav = /^\/api\/me\/favorites\/([^/]+)$/.exec(path);
    if (fav) {
      if (method !== "PUT" && method !== "DELETE") return jsonError(405, "method_not_allowed");
      if (!isCatalogId(fav[1])) return jsonError(404, "not_found");
      return upstreamNoContent(await dataFetch(env, `${base}/favorites/${fav[1]}`, { method }));
    }
    if (path === "/api/me/recent") {
      if (method !== "POST") return jsonError(405, "method_not_allowed");
      let body;
      try {
        body = await request.json();
      } catch {
        return jsonError(400, "invalid_body", "JSON body { id } required");
      }
      if (!body || typeof body.id !== "string" || !isCatalogId(body.id)) return jsonError(400, "invalid_body", "id must be a catalog id");
      return upstreamNoContent(
        await dataFetch(env, `${base}/recent`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: body.id }) }),
      );
    }
    const up = /^\/api\/me\/uploads(?:\/([^/]+)(\/file|\/download)?)?$/.exec(path);
    if (up) return await uploads(request, env, base, up[1], up[2]);
    return jsonError(404, "not_found");
  } catch (e) {
    if (e instanceof UpstreamError) return jsonError(502, "upstream_unavailable");
    throw e;
  }
}

function upstreamNoContent(res) {
  if (res.status === 404) return jsonError(404, "not_found");
  if (!res.ok) throw new UpstreamError(`data service ${res.status}`);
  return noContent();
}

/** 数据服务的 JSON 响应原样转出（4xx 带错误码）；5xx 当作上游不可用。 */
async function relay(res, okStatus) {
  if (res.status >= 500) throw new UpstreamError(`data service ${res.status}`);
  if (res.status === 204) return noContent();
  const body = await res.json().catch(() => ({ error: res.ok ? "ok" : "error" }));
  return json(res.ok && okStatus ? okStatus : res.status, body);
}

/** 读 JSON 请求体（≤ 64 KB），原样转给数据服务校验；不是 JSON 对象返回 null。 */
async function readJson(request) {
  const text = await request.text();
  if (text.length > MAX_JSON_BYTES) return { tooLarge: true };
  try {
    const v = JSON.parse(text);
    return v && typeof v === "object" && !Array.isArray(v) ? { text } : null;
  } catch {
    return null;
  }
}

async function uploads(request, env, base, id, sub) {
  const method = request.method;
  const jsonInit = (m, text) => ({ method: m, headers: { "Content-Type": "application/json" }, body: text });
  if (id === undefined) {
    if (method === "GET") return relay(await dataFetch(env, `${base}/uploads`));
    if (method !== "POST") return jsonError(405, "method_not_allowed");
    const b = await readJson(request);
    if (!b) return jsonError(400, "invalid_body", "JSON object required");
    if (b.tooLarge) return jsonError(413, "too_large");
    return relay(await dataFetch(env, `${base}/uploads`, jsonInit("POST", b.text)), 201);
  }
  if (!isCatalogId(id)) return jsonError(404, "not_found");
  if (sub === undefined) {
    if (method === "GET") return relay(await dataFetch(env, `${base}/uploads/${id}`));
    if (method === "DELETE") return relay(await dataFetch(env, `${base}/uploads/${id}`, { method: "DELETE" }));
    if (method !== "PATCH") return jsonError(405, "method_not_allowed");
    const b = await readJson(request);
    if (!b) return jsonError(400, "invalid_body", "JSON object required");
    if (b.tooLarge) return jsonError(413, "too_large");
    return relay(await dataFetch(env, `${base}/uploads/${id}`, jsonInit("PATCH", b.text)));
  }
  if (sub === "/file") {
    if (method !== "PUT") return jsonError(405, "method_not_allowed");
    const len = request.headers.get("Content-Length");
    if (!len || !/^\d+$/.test(len)) return jsonError(411, "length_required", "Content-Length is required");
    if (Number(len) > MAX_UPLOAD_BYTES) return jsonError(413, "too_large", "uploads are limited to 128 MB");
    if (Number(len) === 0 || !request.body) return jsonError(400, "invalid_body", "empty body");
    const headers = { "Content-Length": len, "Content-Type": "application/zip" };
    const sha = request.headers.get("X-Sha256");
    if (sha) headers["X-Sha256"] = sha;
    return relay(await dataFetch(env, `${base}/uploads/${id}/file`, { method: "PUT", headers, body: request.body, duplex: "half" }));
  }
  // /download：本人下载，含私有条目；不进共享缓存
  if (method !== "GET") return jsonError(405, "method_not_allowed");
  const range = request.headers.get("Range");
  const res = await dataFetch(env, `${base}/uploads/${id}/file`, range ? { headers: { Range: range } } : {});
  if (res.status === 416) return jsonError(416, "range_not_satisfiable");
  if (!res.ok || !res.body) return relay(res);
  const headers = cors(new Headers());
  headers.set("Content-Type", "application/zip");
  headers.set("Content-Disposition", `attachment; filename="${id}.upkit"`);
  headers.set("Accept-Ranges", "bytes");
  headers.set("Cache-Control", "private, no-store");
  for (const h of ["Content-Length", "Content-Range", "ETag", "X-Digest"]) {
    const v = res.headers.get(h);
    if (v) headers.set(h, v);
  }
  return new Response(res.body, { status: res.status, headers });
}
