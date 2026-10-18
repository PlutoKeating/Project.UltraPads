// /api/me*：账号数据（需要登录）。契约见 docs/API.md §7.3。数据按令牌的 sub 隔离，保存在数据服务里。

import { AuthError, requireUser } from "./auth.js";
import { json, jsonError, noContent } from "./http.js";
import { UpstreamError, dataFetch } from "./data.js";
import { isCatalogId } from "./catalog.js";

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
