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
