// Worker 内共用的响应小工具（CORS、JSON、纯文本）。

export function cors(h) {
  h.set("Access-Control-Allow-Origin", "*");
  h.set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges, ETag, X-Digest, X-Upstream");
  return h;
}

/** JSON 响应；错误体统一 { error, message? }（docs/API.md §7）。 */
export function json(status, body, cache = "no-store") {
  return new Response(JSON.stringify(body), {
    status,
    headers: cors(new Headers({ "Content-Type": "application/json; charset=utf-8", "Cache-Control": cache })),
  });
}

export const jsonError = (status, error, message) => json(status, message ? { error, message } : { error });

export function noContent() {
  return new Response(null, { status: 204, headers: cors(new Headers({ "Cache-Control": "no-store" })) });
}
