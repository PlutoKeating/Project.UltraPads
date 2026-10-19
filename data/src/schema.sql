-- ultrapads-data 的表结构。所有 CREATE 都是幂等的。
CREATE TABLE IF NOT EXISTS catalog_items (
  id            TEXT PRIMARY KEY,
  title         TEXT NOT NULL,
  artist        TEXT NOT NULL DEFAULT '',
  description   TEXT NOT NULL DEFAULT '',
  origin        TEXT NOT NULL,
  license       TEXT NOT NULL,
  license_url   TEXT NOT NULL,
  attribution   TEXT NOT NULL,
  source_url    TEXT NOT NULL DEFAULT '',
  commercial_ok INTEGER NOT NULL,
  share_alike   INTEGER NOT NULL,
  bpm           REAL,
  genres        TEXT NOT NULL DEFAULT '[]',
  tags          TEXT NOT NULL DEFAULT '[]',
  group_count   INTEGER NOT NULL DEFAULT 1,
  pad_count     INTEGER NOT NULL DEFAULT 0,
  duration_secs REAL NOT NULL DEFAULT 0,
  size          INTEGER,
  sha256        TEXT,
  theme_color   TEXT NOT NULL DEFAULT '#f0a35e',
  status        TEXT NOT NULL DEFAULT 'draft',
  -- 用户上传（origin='ugc'）：官方条目这几列保持默认值（public / active / NULL）。旧库由 db.ts 的 migrate() 补列
  owner_sub     TEXT,
  visibility    TEXT NOT NULL DEFAULT 'public',
  moderation    TEXT NOT NULL DEFAULT 'active',
  source_declaration TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS catalog_status_updated ON catalog_items(status, updated_at_ms DESC, id);
CREATE INDEX IF NOT EXISTS catalog_sha ON catalog_items(sha256);

CREATE TABLE IF NOT EXISTS favorites (
  user_sub TEXT NOT NULL,
  item_id  TEXT NOT NULL,
  at_ms    INTEGER NOT NULL,
  PRIMARY KEY (user_sub, item_id)
);
CREATE TABLE IF NOT EXISTS recent (
  user_sub TEXT NOT NULL,
  item_id  TEXT NOT NULL,
  at_ms    INTEGER NOT NULL,
  PRIMARY KEY (user_sub, item_id)
);
CREATE INDEX IF NOT EXISTS recent_user_at ON recent(user_sub, at_ms DESC);
CREATE TABLE IF NOT EXISTS downloads (
  user_sub TEXT NOT NULL,
  item_id  TEXT NOT NULL,
  at_ms    INTEGER NOT NULL,
  PRIMARY KEY (user_sub, item_id)
);
CREATE INDEX IF NOT EXISTS downloads_user_at ON downloads(user_sub, at_ms DESC);

-- 对用户上传条目的举报：同一用户对同一条目只记一次；运营处理（改 moderation）后该条目的举报标为已处理
CREATE TABLE IF NOT EXISTS reports (
  item_id      TEXT NOT NULL,
  reporter_sub TEXT NOT NULL,
  reason       TEXT NOT NULL,
  note         TEXT NOT NULL DEFAULT '',
  at_ms        INTEGER NOT NULL,
  resolved     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id, reporter_sub)
);
CREATE INDEX IF NOT EXISTS reports_item ON reports(item_id, resolved);
