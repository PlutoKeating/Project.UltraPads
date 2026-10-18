// HTTP 接口：只给 UltraPads 的 Cloudflare Worker 调用（契约见仓库 docs/API.md §7.4）。
//   GET    /health
//   GET    /v1/catalog · /v1/catalog/facets · /v1/catalog/:id · /v1/catalog/:id/file     已发布的目录与 .upkit 文件
//   GET    /v1/users/:sub/state                                                          收藏 / 最近使用 / 下载记录
//   PUT|DELETE /v1/users/:sub/favorites/:id · POST /v1/users/:sub/recent|downloads · DELETE /v1/users/:sub
//   GET|PUT|DELETE /v1/admin/catalog[/:id[/file]]                                        运营接口（草稿也可见）
// 所有路径可带 /ultrapads 前缀（共用的 Cloudflare Tunnel 按路径分流，前缀由服务剥掉）。
// 鉴权：Authorization: Bearer <ULTRAPADS_DATA_KEY>；/v1/admin/* 另需 X-Up-Admin: <ULTRAPADS_ADMIN_KEY>。
import crypto from "node:crypto";
import fs from "node:fs";
import { Readable } from "node:stream";
import { Hono, type Context } from "hono";
import {
  HttpError, ID_RE, LICENSES, ORIGINS, STATUSES, publicItem,
  type AdminItem, type Db, type MetaInput, type Origin, type Status,
} from "./db.ts";

export const VERSION = "0.1.0";
const MAX_JSON_BYTES = 64 * 1024;
const MAX_FILE_BYTES = 256 * 1024 * 1024;
const SUB_RE = /^[\x21-\x7e]{1,200}$/; // 可见 ASCII，无空白

const digest = (s: string) => crypto.createHash("sha256").update(s).digest();
const sameSecret = (got: string, want: Buffer) => crypto.timingSafeEqual(digest(got), want);

const str = (v: unknown, field: string, max: number, required = false): string => {
  if (v === undefined || v === null) {
    if (required) throw new HttpError(400, "bad_request", `${field} 必填`);
    return "";
  }
  if (typeof v !== "string") throw new HttpError(400, "bad_request", `${field} 必须是字符串`);
  const s = v.trim();
  if (required && !s) throw new HttpError(400, "bad_request", `${field} 必填`);
  if (s.length > max) throw new HttpError(400, "bad_request", `${field} 太长`);
  return s;
};
const num = (v: unknown, field: string, min: number, max: number, dflt: number | null, int = false): number | null => {
  if (v === undefined || v === null) return dflt;
  if (typeof v !== "number" || !Number.isFinite(v) || v < min || v > max || (int && !Number.isInteger(v))) {
    throw new HttpError(400, "bad_request", `${field} 必须在 ${min}..${max}${int ? "（整数）" : ""}`);
  }
  return v;
};
const strList = (v: unknown, field: string): string[] => {
  if (v === undefined || v === null) return [];
  if (!Array.isArray(v) || v.length > 16) throw new HttpError(400, "bad_request", `${field} 必须是不超过 16 项的数组`);
  return v.map((x) => str(x, field, 40, true));
};
const httpUrl = (s: string, field: string) => {
  if (s && !/^https?:\/\/[^\s]+$/i.test(s)) throw new HttpError(400, "bad_request", `${field} 必须是 http(s) 链接`);
  return s;
};

export function parseMeta(b: Record<string, unknown>): MetaInput {
  const license = str(b.license, "license", 40, true);
  if (!(license in LICENSES)) throw new HttpError(400, "bad_request", `license 必须是 ${Object.keys(LICENSES).join(" | ")}`);
  const origin = str(b.origin, "origin", 20, true);
  if (!(ORIGINS as readonly string[]).includes(origin)) throw new HttpError(400, "bad_request", `origin 必须是 ${ORIGINS.join(" | ")}`);
  const status = str(b.status ?? "draft", "status", 20, true);
  if (!(STATUSES as readonly string[]).includes(status)) throw new HttpError(400, "bad_request", `status 必须是 ${STATUSES.join(" | ")}`);
  const theme = str(b.theme_color ?? "#f0a35e", "theme_color", 9, true);
  if (!/^#[0-9a-fA-F]{6}$/.test(theme)) throw new HttpError(400, "bad_request", "theme_color 必须是 #rrggbb");
  return {
    title: str(b.title, "title", 120, true),
    artist: str(b.artist, "artist", 120),
    description: str(b.description, "description", 2000),
    origin: origin as Origin,
    license,
    license_url: httpUrl(str(b.license_url, "license_url", 300) || LICENSES[license]!, "license_url"),
    attribution: str(b.attribution, "attribution", 500, true),
    source_url: httpUrl(str(b.source_url, "source_url", 500), "source_url"),
    bpm: num(b.bpm, "bpm", 20, 400, null),
    genres: strList(b.genres, "genres"),
    tags: strList(b.tags, "tags"),
    group_count: num(b.group_count, "group_count", 1, 7, 1, true)!,
    pad_count: num(b.pad_count, "pad_count", 0, 84, 0, true)!,
    duration_secs: num(b.duration_secs, "duration_secs", 0, 3600, 0)!,
    theme_color: theme.toLowerCase(),
    status: status as Status,
  };
}

const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
function dec(cursor: string | undefined): number {
  if (!cursor) return 0;
  try {
    const o = (JSON.parse(Buffer.from(cursor, "base64url").toString("utf8")) as { o?: unknown }).o;
    if (typeof o === "number" && Number.isInteger(o) && o >= 0) return o;
  } catch {
    /* fallthrough */
  }
  throw new HttpError(400, "bad_request", "cursor 无效");
}

function parseQuery(c: Context, includeDrafts: boolean) {
  const url = new URL(c.req.url);
  const sp = url.searchParams;
  const licenses = sp.getAll("license").flatMap((v) => v.split(",")).map((v) => v.trim()).filter(Boolean);
  for (const l of licenses) if (!(l in LICENSES)) throw new HttpError(400, "bad_request", `未知 license：${l}`);
  const n = (k: string) => {
    const v = sp.get(k);
    if (v === null || v === "") return undefined;
    const x = Number(v);
    if (!Number.isFinite(x)) throw new HttpError(400, "bad_request", `${k} 必须是数字`);
    return x;
  };
  const sort = sp.get("sort") ?? "new";
  if (!["new", "bpm", "title"].includes(sort)) throw new HttpError(400, "bad_request", "sort 必须是 new | bpm | title");
  const origin = sp.get("origin") || undefined;
  if (origin && !(ORIGINS as readonly string[]).includes(origin)) throw new HttpError(400, "bad_request", "origin 无效");
  return {
    q: sp.get("q")?.trim() || undefined,
    licenses,
    genre: sp.get("genre") || undefined,
    origin,
    bpmMin: n("bpm_min"),
    bpmMax: n("bpm_max"),
    sort: sort as "new" | "bpm" | "title",
    offset: dec(sp.get("cursor") ?? undefined),
    limit: n("limit") === undefined ? undefined : Math.trunc(n("limit")!),
    includeDrafts,
  };
}

function serveFile(c: Context, f: { path: string; size: number; sha256: string }, id: string): Response {
  const etag = `"${f.sha256}"`;
  const headers: Record<string, string> = {
    "Content-Type": "application/zip",
    "Accept-Ranges": "bytes",
    ETag: etag,
    "X-Digest": `sha256:${f.sha256}`,
    "Content-Disposition": `attachment; filename="${id}.upkit"`,
    "Cache-Control": "public, max-age=31536000, immutable",
  };
  if (c.req.header("if-none-match") === etag) return new Response(null, { status: 304, headers: { ETag: etag } });
  let start = 0;
  let end = f.size - 1;
  let status = 200;
  const range = c.req.header("range")?.trim();
  if (range) {
    const m = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!m || (m[1] === "" && m[2] === "")) {
      return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${f.size}` } });
    }
    if (m[1] === "") {
      const n = Number(m[2]);
      start = Math.max(0, f.size - n);
    } else {
      start = Number(m[1]);
      if (m[2] !== "") end = Math.min(end, Number(m[2]));
    }
    if (start > end || start >= f.size) {
      return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${f.size}` } });
    }
    status = 206;
    headers["Content-Range"] = `bytes ${start}-${end}/${f.size}`;
  }
  headers["Content-Length"] = String(end - start + 1);
  const body = Readable.toWeb(fs.createReadStream(f.path, { start, end })) as ReadableStream;
  return new Response(body, { status, headers });
}

export function createApp(db: Db, key: string, adminKey: string) {
  const core = new Hono();
  const want = digest(key);
  const wantAdmin = digest(adminKey);

  core.get("/health", (c) => c.json({ ok: true, service: "ultrapads-data", version: VERSION }));

  core.use("/v1/*", async (c, next) => {
    const h = c.req.header("authorization") ?? "";
    const got = h.startsWith("Bearer ") ? h.slice(7).trim() : "";
    if (!sameSecret(got, want)) return c.json({ error: "unauthorized" }, 401);
    await next();
  });
  core.use("/v1/admin/*", async (c, next) => {
    if (!sameSecret(c.req.header("x-up-admin") ?? "", wantAdmin)) return c.json({ error: "unauthorized" }, 401);
    await next();
  });

  // ------------------------------------------------------------ 公开目录
  core.get("/v1/catalog", (c) => {
    const r = db.listCatalog(parseQuery(c, false));
    return c.json({ items: r.items.map(publicItem), next_cursor: r.nextOffset === null ? null : enc({ o: r.nextOffset }), total: r.total });
  });
  core.get("/v1/catalog/facets", (c) => c.json(db.facets()));
  core.get("/v1/catalog/:id", (c) => {
    const it = db.getItem(c.req.param("id"));
    if (!it || it.status !== "published") return c.json({ error: "not_found" }, 404);
    return c.json(publicItem(it));
  });
  core.get("/v1/catalog/:id/file", (c) => {
    const id = c.req.param("id");
    const f = db.openFile(id, false);
    if (!f) return c.json({ error: "not_found" }, 404);
    return serveFile(c, f, id);
  });

  // ------------------------------------------------------------ 账号数据
  const subOf = (c: Context) => {
    const sub = c.req.param("sub") ?? "";
    if (!SUB_RE.test(sub)) throw new HttpError(400, "bad_request", "sub 无效");
    return sub;
  };
  const jsonBody = async (c: Context): Promise<Record<string, unknown>> => {
    const raw = await c.req.arrayBuffer();
    if (raw.byteLength > MAX_JSON_BYTES) throw new HttpError(413, "too_large");
    try {
      const v = JSON.parse(new TextDecoder().decode(raw)) as unknown;
      if (v && typeof v === "object" && !Array.isArray(v)) return v as Record<string, unknown>;
    } catch {
      /* fallthrough */
    }
    throw new HttpError(400, "bad_request", "需要 JSON 对象");
  };
  const idOf = (v: unknown) => {
    if (typeof v !== "string" || !ID_RE.test(v)) throw new HttpError(400, "bad_request", "id 无效");
    return v;
  };

  core.get("/v1/users/:sub/state", (c) => c.json(db.userState(subOf(c))));
  core.put("/v1/users/:sub/favorites/:id", (c) => {
    db.addFavorite(subOf(c), c.req.param("id"));
    return c.body(null, 204);
  });
  core.delete("/v1/users/:sub/favorites/:id", (c) => {
    db.removeFavorite(subOf(c), c.req.param("id"));
    return c.body(null, 204);
  });
  core.post("/v1/users/:sub/recent", async (c) => {
    const sub = subOf(c);
    db.addRecent(sub, idOf((await jsonBody(c)).id));
    return c.body(null, 204);
  });
  core.post("/v1/users/:sub/downloads", async (c) => {
    const sub = subOf(c);
    db.addDownload(sub, idOf((await jsonBody(c)).id));
    return c.body(null, 204);
  });
  core.delete("/v1/users/:sub", (c) => {
    db.deleteUser(subOf(c));
    return c.body(null, 204);
  });

  // ------------------------------------------------------------ 运营
  core.get("/v1/admin/catalog", (c) => {
    const r = db.listCatalog(parseQuery(c, true));
    return c.json({ items: r.items, next_cursor: r.nextOffset === null ? null : enc({ o: r.nextOffset }), total: r.total });
  });
  core.get("/v1/admin/catalog/:id", (c) => {
    const it = db.getItem(c.req.param("id"));
    return it ? c.json(it) : c.json({ error: "not_found" }, 404);
  });
  core.get("/v1/admin/catalog/:id/file", (c) => {
    const id = c.req.param("id");
    const f = db.openFile(id, true);
    return f ? serveFile(c, f, id) : c.json({ error: "not_found" }, 404);
  });
  core.put("/v1/admin/catalog/:id", async (c) => {
    const id = c.req.param("id");
    if (!ID_RE.test(id)) throw new HttpError(400, "bad_request", "id 必须匹配 [a-z0-9][a-z0-9-]{2,63}");
    const item: AdminItem = db.putMeta(id, parseMeta(await jsonBody(c)));
    return c.json(item);
  });
  core.put("/v1/admin/catalog/:id/file", async (c) => {
    const id = c.req.param("id");
    const len = Number(c.req.header("content-length") ?? 0);
    if (len > MAX_FILE_BYTES) throw new HttpError(413, "too_large");
    const sha = c.req.header("x-sha256")?.toLowerCase() ?? null;
    if (sha !== null && !/^[0-9a-f]{64}$/.test(sha)) throw new HttpError(400, "bad_request", "x-sha256 必须是 64 位十六进制");
    const body = c.req.raw.body;
    if (!body) throw new HttpError(400, "bad_request", "缺少请求体");
    const item = await db.putFile(id, Readable.fromWeb(body as never), sha, MAX_FILE_BYTES);
    return c.json(item);
  });
  core.delete("/v1/admin/catalog/:id", (c) => {
    if (!db.deleteItem(c.req.param("id"))) return c.json({ error: "not_found" }, 404);
    return c.body(null, 204);
  });

  const app = new Hono();
  app.route("/ultrapads", core);
  app.route("/", core);
  app.notFound((c) => c.json({ error: "not_found" }, 404));
  app.onError((e, c) => {
    if (e instanceof HttpError) {
      return c.json({ error: e.code, ...(e.message !== e.code ? { message: e.message } : {}) }, e.status as 400);
    }
    console.error("[ultrapads-data]", (e as Error).message);
    return c.json({ error: "internal_error" }, 500);
  });
  return app;
}
