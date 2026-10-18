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
  PD: "https://creativecommons.org/publicdomain/mark/1.0/",
};
export const KEEP_RECENT = 100;
export const KEEP_DOWNLOADS = 100;
export const MAX_FILE_BYTES = 256 * 1024 * 1024;

export type Origin = (typeof ORIGINS)[number];
export type Status = (typeof STATUSES)[number];

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
    created_at_ms: r.created_at_ms as number,
    updated_at_ms: r.updated_at_ms as number,
  };
}

/** 对外（公开）形态：去掉 status / created_at_ms；只发布的条目一定有 size 与 sha256。 */
export function publicItem(a: AdminItem): CatalogItem {
  const { status: _s, created_at_ms: _c, ...rest } = a;
  return { ...rest, size: a.size ?? 0, sha256: a.sha256 ?? "" };
}

export function deriveFlags(license: string) {
  return { commercial_ok: !license.includes("NC"), share_alike: license.includes("SA") };
}

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
    if (!q.includeDrafts) w.push("status = 'published'");
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
            `SELECT ${col} AS id, COUNT(*) AS count FROM catalog_items WHERE status='published' GROUP BY ${col} ORDER BY count DESC, id ASC`,
          )
          .all() as { id: string; count: number }[]
      ).map((r) => ({ id: r.id, count: r.count }));
    const genres = (
      db
        .prepare(
          `SELECT j.value AS id, COUNT(*) AS count FROM catalog_items c, json_each(c.genres) j
           WHERE c.status='published' GROUP BY j.value ORDER BY count DESC, id ASC`,
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
    if (!it || !it.sha256 || (!allowDraft && it.status !== "published")) return null;
    const p = filePath(it.sha256);
    if (!fs.existsSync(p)) return null;
    return { path: p, size: it.size!, sha256: it.sha256 };
  }

  function deleteItem(id: string) {
    const it = getItem(id);
    if (!it) return false;
    tx(() => {
      db.prepare(`DELETE FROM catalog_items WHERE id = ?`).run(id);
      for (const t of ["favorites", "recent", "downloads"]) db.prepare(`DELETE FROM ${t} WHERE item_id = ?`).run(id);
    });
    if (it.sha256 && sharedBlobCount(it.sha256, id) === 0) fs.rmSync(filePath(it.sha256), { force: true });
    return true;
  }

  // ------------------------------------------------------------ 账号数据

  const published = (id: string) =>
    !!db.prepare(`SELECT 1 FROM catalog_items WHERE id = ? AND status='published'`).get(id);

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
           WHERE t.user_sub = ? AND c.status='published' ORDER BY t.at_ms DESC, t.item_id ASC`,
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
    tx(() => {
      for (const t of ["favorites", "recent", "downloads"]) db.prepare(`DELETE FROM ${t} WHERE user_sub = ?`).run(sub);
    });
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
    backup,
    close: () => db.close(),
  };
}

export type Db = ReturnType<typeof openDb>;
