// 数据服务（data/，docs/API.md §7.4）的 HTTP 客户端。密钥 ULTRAPADS_DATA_KEY 只在 Worker Secret 里。

export const DEFAULT_DATA_URL = "https://data.jnify.plutokeating.beer/ultrapads";

export class UpstreamError extends Error {}

/** 请求数据服务；网络错误或没配置密钥抛 UpstreamError。 */
export async function dataFetch(env, path, init = {}) {
  if (!env.ULTRAPADS_DATA_KEY) throw new UpstreamError("ULTRAPADS_DATA_KEY missing");
  const base = String(env.DATA_URL || DEFAULT_DATA_URL).replace(/\/+$/, "");
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${env.ULTRAPADS_DATA_KEY}`);
  headers.set("User-Agent", "ultrapads-site");
  try {
    return await fetch(base + path, { ...init, headers });
  } catch (e) {
    throw new UpstreamError(e?.message ?? "fetch failed");
  }
}
