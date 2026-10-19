// 存储层：node:sqlite（内置 DatabaseSync）+ 本地内容寻址文件存储（files/<hh>/<sha256>）+ 每日 VACUUM INTO 备份。
import { DatabaseSync } from "node:sqlite";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { Transform } from "node:stream";
import { pipeline } from "node:stream/promises";
import type { Readable } from "node:stream";

const SCHEMA = fs.readFileSync(new URL("./schema.sql", import.meta.url), "utf8");

export const ID_RE = /^[a-z0-9][a-z0-9-]{2,63}$/;
export const ORIGINS = ["album", "online", "synth", "ugc"] as const;
export const STATUSES = ["draft", "published"] as const;
/** 许可证白名单：值是默认的许可证链接。 */
export const LICENSES: Record<string, string> = {
  "CC0-1.0": "https://creativecommons.org/publicdomain/zero/1.0/",
  "CC-BY-4.0": "https://creativecommons.org/licenses/by/4.0/",
  "CC-BY-3.0": "https://creativecommons.org/licenses/by/3.0/",
  "CC-BY-SA-4.0": "https://creativecommons.org/licenses/by-sa/4.0/",
  "CC-BY-SA-3.0": "https://creativecommons.org/licenses/by-sa/3.0/",
  "CC-BY-NC-4.0": "https://creativecommons.org/licenses/by-nc/4.0/",
  "CC-BY-NC-SA-4.0": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
  "CC-BY-NC-3.0": "https://creativecommons.org/licenses/by-nc/3.0/",
  "CC-BY-NC-SA-3.0": "https://creativecommons.org/licenses/by-nc-sa/3.0/",
  PD: "https://creativecommons.org/publicdomain/mark/1.0/",
};
export const VISIBILITIES = ["private", "public"] as const;
/** active 正常；hidden 被举报累计到阈值后自动隐藏、待运营审核；taken_down 运营下架（下载返回 410）。 */
export const MODERATIONS = ["active", "hidden", "taken_down"] as const;
/** own = 自己的作品 / 录音；licensed = 按所列许可证获得授权的第三方素材。 */
export const DECLARATIONS = ["own", "licensed"] as const;
export const REPORT_REASONS = ["copyright", "inappropriate", "other"] as const;
export const MAX_UGC_FILE_BYTES = 128 * 1024 * 1024;
export const MAX_UGC_PER_USER = 50;
export const HIDE_THRESHOLD = 3;
export const KEEP_RECENT = 100;
export const KEEP_DOWNLOADS = 100;
export const MAX_FILE_BYTES = 256 * 1024 * 1024;

export type Origin = (typeof ORIGINS)[number];
export type Status = (typeof STATUSES)[number];
export type Visibility = (typeof VISIBILITIES)[number];
export type Moderation = (typeof MODERATIONS)[number];
export type Declaration = (typeof DECLARATIONS)[number];
export type ReportReason = (typeof REPORT_REASONS)[number];

export interface CatalogItem {
  id: string;
  title: string;
  artist: string;
  description: string;
  origin: Origin;
  license: string;
  license_url: string;
  attribution: string;
  source_url: string;
  commercial_ok: boolean;
  share_alike: boolean;
  bpm: number | null;
  genres: string[];
  tags: string[];
  group_count: number;
  pad_count: number;
  duration_secs: number;
  size: number;
  sha256: string;
  theme_color: string;
  updated_at_ms: number;
}
export type AdminItem = Omit<CatalogItem, "size" | "sha256"> & {
  size: number | null;
  sha256: string | null;
  status: Status;
  created_at_ms: number;
  owner_sub: string | null;
  visibility: Visibility;
  moderation: Moderation;
  source_declaration: Declaration | null;
};

export interface MetaInput {
  title: string;
  artist: string;
  description: string;
  origin: Origin;
  license: string;
  license_url: string;
  attribution: string;
  source_url: string;
  bpm: number | null;
  genres: string[];
  tags: string[];
  group_count: number;
  pad_count: number;
  duration_secs: number;
  theme_color: string;
  status: Status;
}

/** 用户上传条目的元数据（credit 存入 attribution；artist 缺省 = credit）。 */
export interface UgcInput {
  title: string;
  artist: string;
  description: string;
  license: string;
  license_url: string;
  attribution: string;
  source_url: string;
  source_declaration: Declaration;
  bpm: number | null;
  genres: string[];
  tags: string[];
  group_count: number;
  pad_count: number;
  duration_secs: number;
  theme_color: string;
  visibility: Visibility;
}

export interface CatalogQuery {
  q?: string;
  licenses?: string[];
  genre?: string;
  origin?: string;
  bpmMin?: number;
  bpmMax?: number;
  sort?: "new" | "bpm" | "title";
  offset?: number;
  limit?: number;
  includeDrafts?: boolean;
}

export class HttpError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message?: string) {
    super(message ?? code);
    this.status = status;
    this.code = code;
  }
}

type Row = Record<string, unknown>;

function toItem(r: Row): AdminItem {
  return {
    id: r.id as string,
    title: r.title as string,
    artist: r.artist as string,
    description: r.description as string,
    origin: r.origin as Origin,
    license: r.license as string,
    license_url: r.license_url as string,
    attribution: r.attribution as string,
    source_url: r.source_url as string,
    commercial_ok: r.commercial_ok === 1,
    share_alike: r.share_alike === 1,
    bpm: (r.bpm as number | null) ?? null,
    genres: JSON.parse(r.genres as string) as string[],
    tags: JSON.parse(r.tags as string) as string[],
    group_count: r.group_count as number,
    pad_count: r.pad_count as number,
    duration_secs: r.duration_secs as number,
    size: (r.size as number | null) ?? null,
    sha256: (r.sha256 as string | null) ?? null,
    theme_color: r.theme_color as string,
    status: r.status as Status,
    owner_sub: (r.owner_sub as string | null) ?? null,
    visibility: r.visibility as Visibility,
    moderation: r.moderation as Moderation,
    source_declaration: (r.source_declaration as Declaration | null) ?? null,
    created_at_ms: r.created_at_ms as number,
    updated_at_ms: r.updated_at_ms as number,
  };
}

/** 对外（公开）形态：去掉 status / created_at_ms 与上传者、可见性、审核字段；公开条目一定有 size 与 sha256。 */
export function publicItem(a: AdminItem): CatalogItem {
  const { status: _s, created_at_ms: _c, owner_sub: _o, visibility: _v, moderation: _m, source_declaration: _d, ...rest } = a;
  return { ...rest, size: a.size ?? 0, sha256: a.sha256 ?? "" };
}

export function deriveFlags(license: string) {
  return { commercial_ok: !license.includes("NC"), share_alike: license.includes("SA") };
}

/** 公开可见：已有文件（published）、可见性公开、审核正常。官方条目的 visibility / moderation 恒为默认值。 */
const pubSql = (t = "") => `${t}status = 'published' AND ${t}visibility = 'public' AND ${t}moderation = 'active'`;
export const isPublic = (it: AdminItem) => it.status === "published" && it.visibility === "public" && it.moderation === "active";

/** 单调递增的毫秒时间戳：同一毫秒内的多次写入也有稳定的先后顺序（最近使用 / 下载记录按它排序）。 */
let lastMs = 0;
const nowMs = () => (lastMs = Math.max(Date.now(), lastMs + 1));

const escapeLike = (s: string) => s.replace(/[\\%_]/g, (m) => `\\${m}`);

export function openDb(rootDir: string) {
  const isMem = rootDir === ":memory:";
  const filesDir = isMem ? "" : path.join(rootDir, "files");
  if (!isMem) {
    fs.mkdirSync(path.join(filesDir, ".tmp"), { recursive: true, mode: 0o700 });
  }
  const db = new DatabaseSync(isMem ? ":memory:" : path.join(rootDir, "ultrapads.sqlite"));
  if (!isMem) db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA synchronous = NORMAL; PRAGMA busy_timeout = 5000;");
  db.exec(SCHEMA);
  // 旧库补列（CREATE TABLE IF NOT EXISTS 不会改已有的表）；新索引必须在补列之后建
  const cols = new Set((db.prepare(`PRAGMA table_info(catalog_items)`).all() as { name: string }[]).map((c) => c.name));
  for (const [name, ddl] of [
    ["owner_sub", "TEXT"],
    ["visibility", "TEXT NOT NULL DEFAULT 'public'"],
    ["moderation", "TEXT NOT NULL DEFAULT 'active'"],
    ["source_declaration", "TEXT"],
  ] as const) {
    if (!cols.has(name)) db.exec(`ALTER TABLE catalog_items ADD COLUMN ${name} ${ddl}`);
  }
  db.exec(`CREATE INDEX IF NOT EXISTS catalog_owner ON catalog_items(owner_sub) WHERE owner_sub IS NOT NULL`);

  const tx = <T>(fn: () => T): T => {
    db.exec("BEGIN IMMEDIATE");
    try {
      const r = fn();
      db.exec("COMMIT");
      return r;
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }
  };

  const filePath = (sha: string) => path.join(filesDir, sha.slice(0, 2), sha);

  // ------------------------------------------------------------ 目录

  function whereOf(q: CatalogQuery, params: (string | number)[]) {
    const w: string[] = [];
    if (!q.includeDrafts) w.push(pubSql());
    if (q.q) {
      const like = `%${escapeLike(q.q.toLowerCase())}%`;
      w.push(
        `(lower(title) LIKE ? ESCAPE '\\' OR lower(artist) LIKE ? ESCAPE '\\' OR lower(tags) LIKE ? ESCAPE '\\' OR lower(genres) LIKE ? ESCAPE '\\')`,
      );
      params.push(like, like, like, like);
    }
    if (q.licenses && q.licenses.length) {
      w.push(`license IN (${q.licenses.map(() => "?").join(",")})`);
      params.push(...q.licenses);
    }
    if (q.genre) {
      w.push(`EXISTS (SELECT 1 FROM json_each(catalog_items.genres) WHERE value = ?)`);
      params.push(q.genre);
    }
    if (q.origin) {
      w.push(`origin = ?`);
      params.push(q.origin);
    }
    if (q.bpmMin !== undefined) {
      w.push(`bpm >= ?`);
      params.push(q.bpmMin);
    }
    if (q.bpmMax !== undefined) {
      w.push(`bpm <= ?`);
      params.push(q.bpmMax);
    }
    return w.length ? `WHERE ${w.join(" AND ")}` : "";
  }

  function listCatalog(q: CatalogQuery) {
    const params: (string | number)[] = [];
    const where = whereOf(q, params);
    const limit = Math.min(Math.max(q.limit ?? 30, 1), 50);
    const offset = Math.max(q.offset ?? 0, 0);
    const order =
      q.sort === "bpm"
        ? "bpm IS NULL, bpm ASC, id ASC"
        : q.sort === "title"
          ? "title COLLATE NOCASE ASC, id ASC"
          : "updated_at_ms DESC, id ASC";
    const total = (db.prepare(`SELECT COUNT(*) AS n FROM catalog_items ${where}`).get(...params) as { n: number }).n;
    const rows = db
      .prepare(`SELECT * FROM catalog_items ${where} ORDER BY ${order} LIMIT ? OFFSET ?`)
      .all(...params, limit + 1, offset) as Row[];
    const more = rows.length > limit;
    return { items: rows.slice(0, limit).map(toItem), nextOffset: more ? offset + limit : null, total };
  }

  function facets() {
    const group = (col: string) =>
      (
        db
          .prepare(
            `SELECT ${col} AS id, COUNT(*) AS count FROM catalog_items WHERE ${pubSql()} GROUP BY ${col} ORDER BY count DESC, id ASC`,
          )
          .all() as { id: string; count: number }[]
      ).map((r) => ({ id: r.id, count: r.count }));
    const genres = (
      db
        .prepare(
          `SELECT j.value AS id, COUNT(*) AS count FROM catalog_items c, json_each(c.genres) j
           WHERE ${pubSql("c.")} GROUP BY j.value ORDER BY count DESC, id ASC`,
        )
        .all() as { id: string; count: number }[]
    ).map((r) => ({ id: r.id, count: r.count }));
    return { licenses: group("license"), genres, origins: group("origin") };
  }

  function getItem(id: string): AdminItem | null {
    const r = db.prepare(`SELECT * FROM catalog_items WHERE id = ?`).get(id) as Row | undefined;
    return r ? toItem(r) : null;
  }

  function putMeta(id: string, m: MetaInput): AdminItem {
    return tx(() => {
      const now = Date.now();
      const cur = getItem(id);
      if (m.status === "published" && !(cur && cur.sha256)) {
        throw new HttpError(409, "no_file", "上传文件之后才能发布");
      }
      const f = deriveFlags(m.license);
      const vals = [
        m.title, m.artist, m.description, m.origin, m.license, m.license_url, m.attribution, m.source_url,
        f.commercial_ok ? 1 : 0, f.share_alike ? 1 : 0, m.bpm, JSON.stringify(m.genres), JSON.stringify(m.tags),
        m.group_count, m.pad_count, m.duration_secs, m.theme_color, m.status,
      ];
      if (cur) {
        db.prepare(
          `UPDATE catalog_items SET title=?, artist=?, description=?, origin=?, license=?, license_url=?, attribution=?,
             source_url=?, commercial_ok=?, share_alike=?, bpm=?, genres=?, tags=?, group_count=?, pad_count=?,
             duration_secs=?, theme_color=?, status=?, updated_at_ms=? WHERE id=?`,
        ).run(...vals, now, id);
      } else {
        db.prepare(
          `INSERT INTO catalog_items (title, artist, description, origin, license, license_url, attribution, source_url,
             commercial_ok, share_alike, bpm, genres, tags, group_count, pad_count, duration_secs, theme_color, status,
             id, created_at_ms, updated_at_ms) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        ).run(...vals, id, now, now);
      }
      return getItem(id)!;
    });
  }

  function sharedBlobCount(sha: string, exceptId: string) {
    return (db.prepare(`SELECT COUNT(*) AS n FROM catalog_items WHERE sha256 = ? AND id <> ?`).get(sha, exceptId) as { n: number }).n;
  }

  /** 流式接收文件：写临时文件 → 算 sha256 → 核对 → 原子 rename；同内容只存一份。 */
  async function putFile(id: string, body: Readable, expectSha: string | null, maxBytes = MAX_FILE_BYTES) {
    if (isMem) throw new HttpError(500, "no_disk", "内存模式不支持文件");
    if (!getItem(id)) throw new HttpError(404, "not_found");
    const tmp = path.join(filesDir, ".tmp", crypto.randomBytes(12).toString("hex"));
    const hash = crypto.createHash("sha256");
    let size = 0;
    let magic = Buffer.alloc(0);
    try {
      await pipeline(
        body,
        new Transform({
          transform(chunk: Buffer, _enc, cb) {
            size += chunk.length;
            if (size > maxBytes) return cb(new HttpError(413, "too_large"));
            if (magic.length < 4) magic = Buffer.concat([magic, chunk.subarray(0, 4 - magic.length)]);
            hash.update(chunk);
            cb(null, chunk);
          },
        }),
        fs.createWriteStream(tmp, { mode: 0o600 }),
      );
      if (size === 0) throw new HttpError(400, "bad_request", "空文件");
      if (!(magic[0] === 0x50 && magic[1] === 0x4b && magic[2] === 3 && magic[3] === 4)) {
        throw new HttpError(422, "not_zip", ".upkit 必须是 ZIP");
      }
      const sha = hash.digest("hex");
      if (expectSha && expectSha !== sha) throw new HttpError(422, "hash_mismatch", `实际 sha256 为 ${sha}`);
      const dest = filePath(sha);
      if (fs.existsSync(dest)) {
        fs.rmSync(tmp, { force: true });
      } else {
        fs.mkdirSync(path.dirname(dest), { recursive: true, mode: 0o700 });
        fs.renameSync(tmp, dest);
      }
      const old = getItem(id)!;
      db.prepare(`UPDATE catalog_items SET size=?, sha256=?, updated_at_ms=? WHERE id=?`).run(size, sha, Date.now(), id);
      if (old.sha256 && old.sha256 !== sha && sharedBlobCount(old.sha256, id) === 0) {
        fs.rmSync(filePath(old.sha256), { force: true });
      }
      return getItem(id)!;
    } catch (e) {
      fs.rmSync(tmp, { force: true });
      throw e;
    }
  }

  function openFile(id: string, allowDraft: boolean) {
    const it = getItem(id);
    if (!it || !it.sha256 || (!allowDraft && !isPublic(it))) return null;
    const p = filePath(it.sha256);
    if (!fs.existsSync(p)) return null;
    return { path: p, size: it.size!, sha256: it.sha256 };
  }

  function deleteItem(id: string) {
    const it = getItem(id);
    if (!it) return false;
    tx(() => {
      db.prepare(`DELETE FROM catalog_items WHERE id = ?`).run(id);
      for (const t of ["favorites", "recent", "downloads", "reports"]) db.prepare(`DELETE FROM ${t} WHERE item_id = ?`).run(id);
    });
    if (it.sha256 && sharedBlobCount(it.sha256, id) === 0) fs.rmSync(filePath(it.sha256), { force: true });
    return true;
  }

  // ------------------------------------------------------------ 账号数据

  const published = (id: string) =>
    !!db.prepare(`SELECT 1 FROM catalog_items WHERE id = ? AND ${pubSql()}`).get(id);

  function prune(table: "recent" | "downloads", sub: string, keep: number) {
    db.prepare(
      `DELETE FROM ${table} WHERE user_sub = ? AND item_id NOT IN
         (SELECT item_id FROM ${table} WHERE user_sub = ? ORDER BY at_ms DESC, item_id ASC LIMIT ?)`,
    ).run(sub, sub, keep);
  }

  function userState(sub: string) {
    const rows = (table: string) =>
      db
        .prepare(
          `SELECT t.item_id AS id, t.at_ms AS at_ms FROM ${table} t JOIN catalog_items c ON c.id = t.item_id
           WHERE t.user_sub = ? AND ${pubSql("c.")} ORDER BY t.at_ms DESC, t.item_id ASC`,
        )
        .all(sub) as { id: string; at_ms: number }[];
    return {
      favorites: rows("favorites").map((r) => r.id),
      recent: rows("recent").map((r) => ({ id: r.id, at_ms: r.at_ms })),
      downloads: rows("downloads").map((r) => ({ id: r.id, at_ms: r.at_ms })),
    };
  }

  function addFavorite(sub: string, id: string) {
    if (!published(id)) throw new HttpError(404, "not_found");
    db.prepare(`INSERT INTO favorites (user_sub, item_id, at_ms) VALUES (?,?,?) ON CONFLICT DO NOTHING`).run(sub, id, nowMs());
  }
  function removeFavorite(sub: string, id: string) {
    db.prepare(`DELETE FROM favorites WHERE user_sub = ? AND item_id = ?`).run(sub, id);
  }
  function touch(table: "recent" | "downloads", sub: string, id: string, keep: number) {
    if (!published(id)) throw new HttpError(404, "not_found");
    tx(() => {
      db.prepare(
        `INSERT INTO ${table} (user_sub, item_id, at_ms) VALUES (?,?,?)
         ON CONFLICT(user_sub, item_id) DO UPDATE SET at_ms = excluded.at_ms`,
      ).run(sub, id, nowMs());
      prune(table, sub, keep);
    });
  }
  const addRecent = (sub: string, id: string) => touch("recent", sub, id, KEEP_RECENT);
  const addDownload = (sub: string, id: string) => touch("downloads", sub, id, KEEP_DOWNLOADS);

  function deleteUser(sub: string) {
    const mine = (db.prepare(`SELECT id FROM catalog_items WHERE owner_sub = ?`).all(sub) as { id: string }[]).map((r) => r.id);
    tx(() => {
      for (const t of ["favorites", "recent", "downloads"]) db.prepare(`DELETE FROM ${t} WHERE user_sub = ?`).run(sub);
      db.prepare(`DELETE FROM reports WHERE reporter_sub = ?`).run(sub);
    });
    for (const id of mine) deleteItem(id); // 注销账号 = 连同用户上传的条目与文件一并删除
  }

  // ------------------------------------------------------------ 用户上传（UGC）

  const owned = (sub: string, id: string): AdminItem => {
    const it = getItem(id);
    if (!it || it.owner_sub !== sub) throw new HttpError(404, "not_found");
    return it;
  };

  function createUpload(sub: string, m: UgcInput): AdminItem {
    return tx(() => {
      const n = (db.prepare(`SELECT COUNT(*) AS n FROM catalog_items WHERE owner_sub = ?`).get(sub) as { n: number }).n;
      if (n >= MAX_UGC_PER_USER) throw new HttpError(429, "quota_exceeded", `每个账号最多 ${MAX_UGC_PER_USER} 个上传条目`);
      const id = `ugc-${crypto.randomBytes(8).toString("hex")}`;
      const now = Date.now();
      const f = deriveFlags(m.license);
      db.prepare(
        `INSERT INTO catalog_items (id, title, artist, description, origin, license, license_url, attribution, source_url,
           commercial_ok, share_alike, bpm, genres, tags, group_count, pad_count, duration_secs, theme_color, status,
           owner_sub, visibility, moderation, source_declaration, created_at_ms, updated_at_ms)
         VALUES (?,?,?,?,'ugc',?,?,?,?,?,?,?,?,?,?,?,?,?,'draft',?,'private','active',?,?,?)`,
      ).run(
        id, m.title, m.artist, m.description, m.license, m.license_url, m.attribution, m.source_url, f.commercial_ok ? 1 : 0,
        f.share_alike ? 1 : 0, m.bpm, JSON.stringify(m.genres), JSON.stringify(m.tags), m.group_count, m.pad_count,
        m.duration_secs, m.theme_color, sub, m.source_declaration, now, now,
      );
      return getItem(id)!;
    });
  }

  const listUploads = (sub: string): AdminItem[] =>
    (db.prepare(`SELECT * FROM catalog_items WHERE owner_sub = ? ORDER BY updated_at_ms DESC, id ASC`).all(sub) as Row[]).map(toItem);

  const getUpload = (sub: string, id: string) => owned(sub, id);

  /** 改元数据 / 可见性。设为 public 前必须已有文件；被运营下架的条目不能再公开。 */
  function updateUpload(sub: string, id: string, m: UgcInput): AdminItem {
    return tx(() => {
      const cur = owned(sub, id);
      if (m.visibility === "public" && cur.visibility !== "public") {
        if (!cur.sha256) throw new HttpError(409, "no_file", "上传文件之后才能公开");
        if (cur.moderation === "taken_down") throw new HttpError(403, "taken_down", "该条目已被下架");
      }
      const f = deriveFlags(m.license);
      db.prepare(
        `UPDATE catalog_items SET title=?, artist=?, description=?, license=?, license_url=?, attribution=?, source_url=?,
           commercial_ok=?, share_alike=?, bpm=?, genres=?, tags=?, group_count=?, pad_count=?, duration_secs=?, theme_color=?,
           visibility=?, source_declaration=?, updated_at_ms=? WHERE id=?`,
      ).run(
        m.title, m.artist, m.description, m.license, m.license_url, m.attribution, m.source_url, f.commercial_ok ? 1 : 0,
        f.share_alike ? 1 : 0, m.bpm, JSON.stringify(m.genres), JSON.stringify(m.tags), m.group_count, m.pad_count,
        m.duration_secs, m.theme_color, m.visibility, m.source_declaration, Date.now(), id,
      );
      return getItem(id)!;
    });
  }

  async function putUploadFile(sub: string, id: string, body: Readable, expectSha: string | null) {
    const cur = owned(sub, id);
    if (cur.moderation === "taken_down") throw new HttpError(403, "taken_down", "该条目已被下架");
    await putFile(id, body, expectSha, MAX_UGC_FILE_BYTES);
    db.prepare(`UPDATE catalog_items SET status='published' WHERE id=?`).run(id); // 有文件 = 就绪；是否公开由 visibility 决定
    return getItem(id)!;
  }

  function openOwnedFile(sub: string, id: string) {
    const it = owned(sub, id);
    if (it.moderation === "taken_down") throw new HttpError(410, "gone", "该条目已被下架");
    return openFile(id, true);
  }

  function deleteUpload(sub: string, id: string) {
    owned(sub, id);
    deleteItem(id);
  }

  // ------------------------------------------------------------ 举报与审核

  /** 公开的用户上传条目才能被举报；同一用户只记一次；未处理的举报累计到阈值自动转 hidden。 */
  function report(sub: string, id: string, reason: ReportReason, note: string) {
    return tx(() => {
      const it = getItem(id);
      if (!it || it.origin !== "ugc" || !isPublic(it)) throw new HttpError(404, "not_found");
      if (it.owner_sub === sub) throw new HttpError(400, "bad_request", "不能举报自己的条目");
      db.prepare(`INSERT INTO reports (item_id, reporter_sub, reason, note, at_ms) VALUES (?,?,?,?,?) ON CONFLICT DO NOTHING`).run(
        id, sub, reason, note, nowMs(),
      );
      const n = (db.prepare(`SELECT COUNT(*) AS n FROM reports WHERE item_id = ? AND resolved = 0`).get(id) as { n: number }).n;
      let hidden = false;
      if (n >= HIDE_THRESHOLD) {
        db.prepare(`UPDATE catalog_items SET moderation='hidden', updated_at_ms=? WHERE id=? AND moderation='active'`).run(Date.now(), id);
        hidden = true;
      }
      return { reports: n, hidden };
    });
  }

  function setModeration(id: string, state: "active" | "taken_down"): AdminItem {
    return tx(() => {
      if (!getItem(id)) throw new HttpError(404, "not_found");
      db.prepare(`UPDATE catalog_items SET moderation=?, updated_at_ms=? WHERE id=?`).run(state, Date.now(), id);
      db.prepare(`UPDATE reports SET resolved = 1 WHERE item_id = ?`).run(id);
      return getItem(id)!;
    });
  }

  /** 未处理的举报，按条目汇总（运营接口）。 */
  function listReports() {
    const rows = db
      .prepare(
        `SELECT r.item_id AS id, c.title AS title, c.owner_sub AS owner_sub, c.moderation AS moderation, COUNT(*) AS count,
                MAX(r.at_ms) AS last_at_ms
         FROM reports r JOIN catalog_items c ON c.id = r.item_id WHERE r.resolved = 0
         GROUP BY r.item_id ORDER BY count DESC, last_at_ms DESC`,
      )
      .all() as { id: string; title: string; owner_sub: string; moderation: Moderation; count: number; last_at_ms: number }[];
    const detail = db.prepare(`SELECT reason, note, at_ms FROM reports WHERE item_id = ? AND resolved = 0 ORDER BY at_ms ASC`);
    return rows.map((r) => ({ ...r, reports: detail.all(r.id) as { reason: ReportReason; note: string; at_ms: number }[] }));
  }

  function backup(dir: string, keep = 7) {
    if (isMem) return "memory";
    fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
    const name = `ultrapads-${new Date().toISOString().slice(0, 10)}.db`;
    const target = path.join(dir, name);
    if (!fs.existsSync(target)) db.prepare("VACUUM INTO ?").run(target);
    const old = fs
      .readdirSync(dir)
      .filter((f) => /^ultrapads-\d{4}-\d{2}-\d{2}\.db$/.test(f))
      .sort()
      .slice(0, -keep);
    for (const f of old) fs.rmSync(path.join(dir, f));
    return name;
  }

  return {
    raw: db,
    listCatalog,
    facets,
    getItem,
    putMeta,
    putFile,
    openFile,
    deleteItem,
    userState,
    addFavorite,
    removeFavorite,
    addRecent,
    addDownload,
    deleteUser,
    createUpload,
    listUploads,
    getUpload,
    updateUpload,
    putUploadFile,
    openOwnedFile,
    deleteUpload,
    report,
    setModeration,
    listReports,
    backup,
    close: () => db.close(),
  };
}

export type Db = ReturnType<typeof openDb>;
