// PlutoKeating 账号（id.plutokeating.beer，Ory Hydra）的访问令牌验签。契约见 docs/API.md §7.1。
// 用 jose 对 <issuer>/.well-known/jwks.json 本地验签；校验 iss 与 client_id 白名单，不校验 aud（Hydra 的 aud 不可靠）。

import { createRemoteJWKSet, jwtVerify } from "jose";

export const DEFAULT_ISSUER = "https://id.plutokeating.beer/";
export const DEFAULT_CLIENT_IDS = "ultrapads-app";

export class AuthError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

/** Hydra 的 issuer 带尾部斜杠。 */
export function normalizeIssuer(raw) {
  const s = String(raw || DEFAULT_ISSUER).trim();
  return s.endsWith("/") ? s : `${s}/`;
}

export function allowedClientIds(env) {
  return String(env.ALLOWED_CLIENT_IDS ?? DEFAULT_CLIENT_IDS)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

const jwksCache = new Map();

function getJwks(issuer) {
  let jwks = jwksCache.get(issuer);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(".well-known/jwks.json", issuer), { cooldownDuration: 30_000, cacheMaxAge: 600_000 });
    jwksCache.set(issuer, jwks);
  }
  return jwks;
}

/** 测试用：清空 JWKS 缓存。 */
export function _resetJwksCache() {
  jwksCache.clear();
}

export function bearerFrom(request) {
  const m = /^Bearer\s+(\S+)$/i.exec(request.headers.get("Authorization") ?? "");
  return m ? m[1] : null;
}

/** 验签并返回 { sub, email?, name?, clientId, scopes }；失败抛 AuthError。 */
export async function verifyAccessToken(token, env) {
  const issuer = normalizeIssuer(env.ID_ISSUER_URL);
  let payload;
  try {
    ({ payload } = await jwtVerify(token, getJwks(issuer), {
      issuer: [issuer, issuer.slice(0, -1)],
      algorithms: ["RS256", "ES256"],
    }));
  } catch {
    throw new AuthError("invalid_token");
  }
  if (typeof payload.sub !== "string" || !payload.sub) throw new AuthError("invalid_token");
  if (!allowedClientIds(env).includes(String(payload.client_id ?? ""))) throw new AuthError("client_not_allowed");
  const scopes = Array.isArray(payload.scp) ? payload.scp : typeof payload.scope === "string" ? payload.scope.split(" ") : [];
  return {
    sub: payload.sub,
    email: payload.email ?? payload.ext?.email,
    name: payload.name ?? payload.ext?.name,
    clientId: payload.client_id,
    scopes,
  };
}

/** 需要登录：无令牌/坏令牌/客户端不在名单时抛 AuthError。 */
export async function requireUser(request, env) {
  const token = bearerFrom(request);
  if (!token) throw new AuthError("missing_token");
  return verifyAccessToken(token, env);
}

/** 可选登录：没有或无效的令牌一律当匿名（下载等匿名接口用）。 */
export async function optionalUser(request, env) {
  const token = bearerFrom(request);
  if (!token) return null;
  try {
    return await verifyAccessToken(token, env);
  } catch {
    return null;
  }
}
