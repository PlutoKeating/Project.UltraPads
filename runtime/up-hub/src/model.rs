//! 曲库清单（LibraryManifest）、内容寻址 blob 与合并算法。
//!
//! # 合并语义
//! 每个条目带一个版本向量（`version`：设备 ID → 计数器）。合并两个同 ID 条目时：
//! - 一方版本向量支配另一方 → 取支配方，**不算冲突**（普通的单边修改）；
//! - 并发（互不支配）且内容相同 → 取 LWW 胜者，版本向量取逐点最大值，不算冲突；
//! - 并发且内容不同 → **最后写入者胜**（按 `modified_at_ms`、`origin`、内容摘要排序，
//!   全序且确定），败者以确定性的 ID（`<id>~conflict~<摘要前 12 位>`）保留为冲突副本，
//!   并设置 `conflict_of = Some(<id>)`。败者若是删除墓碑则不保留副本。
//!
//! 该合并满足交换律、幂等，因此任意两端各自合并后结果一致。

use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::str::FromStr;

use serde::{Deserialize, Serialize};

use crate::identity::DeviceId;
use crate::util::now_ms;
use crate::{HubError, Result};

/// 当前清单 schema 版本。
pub const MANIFEST_SCHEMA: u32 = 1;

/// BLAKE3-256 内容地址。文本形式为 64 位小写十六进制。
#[derive(Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct BlobHash([u8; 32]);

impl BlobHash {
    /// 计算数据的地址。
    pub fn of(data: &[u8]) -> Self {
        Self(*blake3::hash(data).as_bytes())
    }
    /// 由原始字节构造。
    pub const fn from_bytes(b: [u8; 32]) -> Self {
        Self(b)
    }
    /// 原始字节。
    pub const fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
    /// 十六进制文本。
    pub fn to_hex(&self) -> String {
        data_encoding::HEXLOWER.encode(&self.0)
    }
    /// 解析十六进制（大小写不敏感）。
    pub fn parse(s: &str) -> Result<Self> {
        let raw = data_encoding::HEXLOWER_PERMISSIVE
            .decode(s.as_bytes())
            .map_err(|e| HubError::InvalidInput(format!("blob hash: {e}")))?;
        let arr: [u8; 32] = raw
            .try_into()
            .map_err(|_| HubError::InvalidInput("blob hash must be 32 bytes".into()))?;
        Ok(Self(arr))
    }
}

impl From<blake3::Hash> for BlobHash {
    fn from(h: blake3::Hash) -> Self {
        Self(*h.as_bytes())
    }
}

impl fmt::Display for BlobHash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_hex())
    }
}

impl fmt::Debug for BlobHash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "BlobHash({})", &self.to_hex()[..12])
    }
}

impl FromStr for BlobHash {
    type Err = HubError;
    fn from_str(s: &str) -> Result<Self> {
        Self::parse(s)
    }
}

impl Serialize for BlobHash {
    fn serialize<S: serde::Serializer>(&self, s: S) -> std::result::Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_hex())
    }
}

impl<'de> Deserialize<'de> for BlobHash {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> std::result::Result<Self, D::Error> {
        let s = String::deserialize(d)?;
        BlobHash::parse(&s).map_err(serde::de::Error::custom)
    }
}

/// 条目类型。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EntryKind {
    /// 打击垫套件。
    Kit,
    /// 采样。
    Sample,
    /// 录音作品。
    Track,
    /// 编曲工程。
    Project,
}

/// 条目引用的 blob。
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct BlobRef {
    /// 内容地址。
    pub hash: BlobHash,
    /// 字节数。
    pub size: u64,
    /// 用途（如 `audio`、`doc`、`cover`），由曲库定义。
    #[serde(default)]
    pub role: String,
}

/// 版本向量：设备 → 该设备对此条目的写入次数。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct VersionVector(pub BTreeMap<DeviceId, u64>);

/// 两个版本向量的因果关系。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Causality {
    /// 相同。
    Equal,
    /// 左边严格新于右边。
    Dominates,
    /// 右边严格新于左边。
    DominatedBy,
    /// 并发（互不支配）。
    Concurrent,
}

impl VersionVector {
    /// 本设备计数器加一。
    pub fn bump(&mut self, device: DeviceId) {
        *self.0.entry(device).or_insert(0) += 1;
    }

    /// 比较因果关系。
    pub fn compare(&self, other: &Self) -> Causality {
        let mut greater = false;
        let mut less = false;
        let keys: BTreeSet<&DeviceId> = self.0.keys().chain(other.0.keys()).collect();
        for k in keys {
            let a = self.0.get(k).copied().unwrap_or(0);
            let b = other.0.get(k).copied().unwrap_or(0);
            match a.cmp(&b) {
                Ordering::Greater => greater = true,
                Ordering::Less => less = true,
                Ordering::Equal => {}
            }
        }
        match (greater, less) {
            (false, false) => Causality::Equal,
            (true, false) => Causality::Dominates,
            (false, true) => Causality::DominatedBy,
            (true, true) => Causality::Concurrent,
        }
    }

    /// 逐点最大值。
    pub fn merged(&self, other: &Self) -> Self {
        let mut out = self.0.clone();
        for (k, v) in &other.0 {
            let e = out.entry(*k).or_insert(0);
            *e = (*e).max(*v);
        }
        Self(out)
    }
}

/// 清单条目（kit / sample / track / project 的元数据）。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ManifestEntry {
    /// 条目 ID（曲库内唯一，建议 UUID）。
    pub id: String,
    /// 类型。
    pub kind: EntryKind,
    /// 显示名。
    pub name: String,
    /// 引用的 blob。
    #[serde(default)]
    pub blobs: Vec<BlobRef>,
    /// 最后修改时间（Unix 毫秒，写入设备的墙钟）。
    pub modified_at_ms: i64,
    /// 最后写入它的设备（来源设备）。
    pub origin: DeviceId,
    /// 版本向量。
    #[serde(default)]
    pub version: VersionVector,
    /// 删除墓碑：为 true 时条目已删除，仅用于传播删除。
    #[serde(default)]
    pub deleted: bool,
    /// 冲突副本标记：指向原条目 ID。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub conflict_of: Option<String>,
    /// 曲库自定义的元数据（不透明，参与内容比较）。
    #[serde(default)]
    pub meta: serde_json::Value,
}

#[derive(Serialize)]
struct ContentView<'a> {
    kind: EntryKind,
    name: &'a str,
    blobs: &'a [BlobRef],
    deleted: bool,
    conflict_of: &'a Option<String>,
    meta: &'a serde_json::Value,
}

impl ManifestEntry {
    /// 新建条目（版本向量从 `{device: 1}` 开始）。
    pub fn new(
        id: impl Into<String>,
        kind: EntryKind,
        name: impl Into<String>,
        device: DeviceId,
    ) -> Self {
        let mut version = VersionVector::default();
        version.bump(device);
        Self {
            id: id.into(),
            kind,
            name: name.into(),
            blobs: Vec::new(),
            modified_at_ms: now_ms(),
            origin: device,
            version,
            deleted: false,
            conflict_of: None,
            meta: serde_json::Value::Null,
        }
    }

    /// 记录一次本地修改：更新时间、来源设备，并递增版本向量。
    /// 曲库每次修改条目后都必须调用。
    pub fn touch(&mut self, device: DeviceId) {
        self.modified_at_ms = now_ms().max(self.modified_at_ms + 1);
        self.origin = device;
        self.version.bump(device);
    }

    /// 标记删除（墓碑）。
    pub fn mark_deleted(&mut self, device: DeviceId) {
        self.deleted = true;
        self.blobs.clear();
        self.touch(device);
    }

    fn content_digest(&self) -> [u8; 32] {
        let view = ContentView {
            kind: self.kind,
            name: &self.name,
            blobs: &self.blobs,
            deleted: self.deleted,
            conflict_of: &self.conflict_of,
            meta: &self.meta,
        };
        let bytes = serde_json::to_vec(&view).expect("serializable");
        *blake3::hash(&bytes).as_bytes()
    }

    fn content_eq(&self, other: &Self) -> bool {
        self.kind == other.kind
            && self.name == other.name
            && self.blobs == other.blobs
            && self.deleted == other.deleted
            && self.conflict_of == other.conflict_of
            && self.meta == other.meta
    }

    fn lww_key(&self) -> (i64, DeviceId, [u8; 32]) {
        (self.modified_at_ms, self.origin, self.content_digest())
    }

    fn validate(&self) -> Result<()> {
        if self.id.is_empty() || self.id.len() > 256 || self.id.chars().any(char::is_control) {
            return Err(HubError::InvalidInput(format!(
                "bad entry id {:?}",
                self.id
            )));
        }
        if self.name.len() > 1024 {
            return Err(HubError::InvalidInput(format!(
                "entry {} name too long",
                self.id
            )));
        }
        if self.blobs.len() > 100_000 {
            return Err(HubError::InvalidInput(format!(
                "entry {} has too many blobs",
                self.id
            )));
        }
        Ok(())
    }
}

/// 曲库清单。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LibraryManifest {
    /// schema 版本，当前为 1。
    pub schema: u32,
    /// 条目，按 ID 排序。线上格式为数组。
    #[serde(with = "entries_as_vec")]
    pub entries: BTreeMap<String, ManifestEntry>,
}

impl Default for LibraryManifest {
    fn default() -> Self {
        Self {
            schema: MANIFEST_SCHEMA,
            entries: BTreeMap::new(),
        }
    }
}

mod entries_as_vec {
    use super::ManifestEntry;
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    use std::collections::BTreeMap;

    pub fn serialize<S: Serializer>(
        m: &BTreeMap<String, ManifestEntry>,
        s: S,
    ) -> Result<S::Ok, S::Error> {
        let v: Vec<&ManifestEntry> = m.values().collect();
        v.serialize(s)
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(
        d: D,
    ) -> Result<BTreeMap<String, ManifestEntry>, D::Error> {
        let v = Vec::<ManifestEntry>::deserialize(d)?;
        let mut m = BTreeMap::new();
        for e in v {
            if m.contains_key(&e.id) {
                return Err(serde::de::Error::custom(format!(
                    "duplicate entry id {}",
                    e.id
                )));
            }
            m.insert(e.id.clone(), e);
        }
        Ok(m)
    }
}

impl LibraryManifest {
    /// 插入或替换条目。
    pub fn upsert(&mut self, entry: ManifestEntry) {
        self.entries.insert(entry.id.clone(), entry);
    }

    /// 未删除的条目。
    pub fn live_entries(&self) -> impl Iterator<Item = &ManifestEntry> {
        self.entries.values().filter(|e| !e.deleted)
    }

    /// 未删除条目引用的全部 blob（去重）。
    pub fn referenced_blobs(&self) -> BTreeMap<BlobHash, u64> {
        let mut out = BTreeMap::new();
        for e in self.live_entries() {
            for b in &e.blobs {
                out.insert(b.hash, b.size);
            }
        }
        out
    }

    /// 校验 schema 与条目字段。
    pub fn validate(&self) -> Result<()> {
        if self.schema != MANIFEST_SCHEMA {
            return Err(HubError::Protocol(format!(
                "unsupported manifest schema {} (expected {MANIFEST_SCHEMA})",
                self.schema
            )));
        }
        for (k, e) in &self.entries {
            if k != &e.id {
                return Err(HubError::InvalidInput(format!(
                    "entry key {k} != id {}",
                    e.id
                )));
            }
            e.validate()?;
        }
        Ok(())
    }
}

/// 合并结果。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MergeOutcome {
    /// 合并后的清单。
    pub manifest: LibraryManifest,
    /// 本次合并新产生的冲突副本 ID。
    pub conflicts: Vec<String>,
    /// 相对于左侧（本地）清单新增或改变的条目数。
    pub changed: u32,
}

enum Resolution {
    KeepLocal,
    Take(ManifestEntry),
    Conflict {
        winner: ManifestEntry,
        copy: Option<ManifestEntry>,
    },
}

fn conflict_copy(loser: &ManifestEntry, base_id: &str) -> ManifestEntry {
    let digest = data_encoding::HEXLOWER.encode(&loser.content_digest());
    let mut c = loser.clone();
    c.id = format!("{base_id}~conflict~{}", &digest[..12]);
    c.conflict_of = Some(base_id.to_string());
    c
}

fn resolve(local: &ManifestEntry, remote: &ManifestEntry) -> Resolution {
    let causality = local.version.compare(&remote.version);
    match causality {
        Causality::Dominates => return Resolution::KeepLocal,
        Causality::DominatedBy => return Resolution::Take(remote.clone()),
        Causality::Equal if local == remote => return Resolution::KeepLocal,
        Causality::Equal | Causality::Concurrent => {}
    }
    let version = local.version.merged(&remote.version);
    let (winner, loser) = if local.lww_key() >= remote.lww_key() {
        (local, remote)
    } else {
        (remote, local)
    };
    let mut merged = winner.clone();
    merged.version = version;
    if local.content_eq(remote) {
        return if &merged == local {
            Resolution::KeepLocal
        } else {
            Resolution::Take(merged)
        };
    }
    let copy = (!loser.deleted).then(|| conflict_copy(loser, &local.id));
    Resolution::Conflict {
        winner: merged,
        copy,
    }
}

/// 合并两个清单（`local` 为基准，结果相对 `local` 统计变化）。
pub fn merge(local: &LibraryManifest, remote: &LibraryManifest) -> MergeOutcome {
    let mut out = local.clone();
    let mut conflicts = Vec::new();
    let mut changed = 0u32;
    for (id, r) in &remote.entries {
        let Some(l) = out.entries.get(id) else {
            out.entries.insert(id.clone(), r.clone());
            changed += 1;
            continue;
        };
        match resolve(l, r) {
            Resolution::KeepLocal => {}
            Resolution::Take(e) => {
                out.entries.insert(id.clone(), e);
                changed += 1;
            }
            Resolution::Conflict { winner, copy } => {
                if out.entries.get(id) != Some(&winner) {
                    changed += 1;
                }
                out.entries.insert(id.clone(), winner);
                if let Some(c) = copy
                    && !out.entries.contains_key(&c.id)
                {
                    conflicts.push(c.id.clone());
                    out.entries.insert(c.id.clone(), c);
                    changed += 1;
                }
            }
        }
    }
    MergeOutcome {
        manifest: out,
        conflicts,
        changed,
    }
}

/// 一次同步的统计。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyncReport {
    /// 上传到对端的 blob 数。
    pub uploaded_blobs: u32,
    /// 实际上传的字节数（续传时只计本次发送的部分）。
    pub uploaded_bytes: u64,
    /// 从对端下载的 blob 数。
    pub downloaded_blobs: u32,
    /// 实际下载的字节数（续传时只计本次接收的部分）。
    pub downloaded_bytes: u64,
    /// 从断点续传的 blob 数（上传 + 下载）。
    pub resumed_blobs: u32,
    /// 本次新产生的冲突副本数。
    pub conflicts: u32,
    /// 冲突副本 ID。
    pub conflict_ids: Vec<String>,
    /// 本地清单新增/改变的条目数。
    pub local_changed: u32,
    /// 对端清单新增/改变的条目数。
    pub remote_changed: u32,
    /// 耗时（毫秒）。
    pub duration_ms: u64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::identity::DeviceIdentity;

    fn dev() -> DeviceId {
        DeviceIdentity::generate().id()
    }

    fn blob(n: u8) -> BlobRef {
        BlobRef {
            hash: BlobHash::of(&[n]),
            size: 1,
            role: "audio".into(),
        }
    }

    #[test]
    fn hash_roundtrip() {
        let h = BlobHash::of(b"hello");
        assert_eq!(BlobHash::parse(&h.to_hex()).unwrap(), h);
        assert_eq!(BlobHash::parse(&h.to_hex().to_uppercase()).unwrap(), h);
        assert!(BlobHash::parse("zz").is_err());
    }

    #[test]
    fn manifest_json_roundtrip_and_validate() {
        let d = dev();
        let mut m = LibraryManifest::default();
        let mut e = ManifestEntry::new("k1", EntryKind::Kit, "Kit", d);
        e.blobs.push(blob(1));
        e.meta = serde_json::json!({"bpm": 120});
        m.upsert(e);
        let s = serde_json::to_string(&m).unwrap();
        let back: LibraryManifest = serde_json::from_str(&s).unwrap();
        assert_eq!(back, m);
        back.validate().unwrap();
        let dup = s.replace(
            "]}",
            &format!(",{}]}}", serde_json::to_string(&m.entries["k1"]).unwrap()),
        );
        assert!(serde_json::from_str::<LibraryManifest>(&dup).is_err());
    }

    #[test]
    fn one_sided_edit_is_not_conflict() {
        let (a, b) = (dev(), dev());
        let mut base = LibraryManifest::default();
        base.upsert(ManifestEntry::new("s", EntryKind::Sample, "v1", a));
        let mut edited = base.clone();
        let e = edited.entries.get_mut("s").unwrap();
        e.name = "v2".into();
        e.touch(b);
        let out = merge(&base, &edited);
        assert!(out.conflicts.is_empty());
        assert_eq!(out.changed, 1);
        assert_eq!(out.manifest.entries["s"].name, "v2");
        let out2 = merge(&edited, &base);
        assert_eq!(out2.changed, 0);
        assert_eq!(out2.manifest, edited);
    }

    #[test]
    fn concurrent_edit_lww_with_conflict_copy_and_commutative() {
        let (a, b) = (dev(), dev());
        let mut base = LibraryManifest::default();
        base.upsert(ManifestEntry::new("t", EntryKind::Track, "v1", a));
        let mut ma = base.clone();
        let mut mb = base.clone();
        {
            let e = ma.entries.get_mut("t").unwrap();
            e.name = "from-a".into();
            e.touch(a);
            e.modified_at_ms = 1_000;
        }
        {
            let e = mb.entries.get_mut("t").unwrap();
            e.name = "from-b".into();
            e.touch(b);
            e.modified_at_ms = 2_000;
        }
        let ab = merge(&ma, &mb);
        let ba = merge(&mb, &ma);
        assert_eq!(ab.manifest, ba.manifest, "merge must be commutative");
        assert_eq!(ab.conflicts.len(), 1);
        assert_eq!(ba.conflicts.len(), 1);
        let m = &ab.manifest;
        assert_eq!(m.entries["t"].name, "from-b", "later write wins");
        let copy = &m.entries[&ab.conflicts[0]];
        assert_eq!(copy.name, "from-a");
        assert_eq!(copy.conflict_of.as_deref(), Some("t"));
        // 幂等：再次合并不再产生冲突。
        let again = merge(&ab.manifest, &ma);
        assert!(again.conflicts.is_empty());
        assert_eq!(again.changed, 0);
        let again = merge(&ma, &ab.manifest);
        assert!(again.conflicts.is_empty());
        assert_eq!(again.manifest, ab.manifest);
    }

    #[test]
    fn concurrent_identical_content_is_not_conflict() {
        let (a, b) = (dev(), dev());
        let mut ma = LibraryManifest::default();
        let mut e = ManifestEntry::new("x", EntryKind::Kit, "same", a);
        ma.upsert(e.clone());
        e.version = VersionVector::default();
        e.version.bump(b);
        e.origin = b;
        let mut mb = LibraryManifest::default();
        mb.upsert(e);
        let out = merge(&ma, &mb);
        assert!(out.conflicts.is_empty());
        assert_eq!(merge(&mb, &ma).manifest, out.manifest);
    }

    #[test]
    fn delete_vs_edit_keeps_edit_as_copy() {
        let (a, b) = (dev(), dev());
        let mut base = LibraryManifest::default();
        let mut e = ManifestEntry::new("p", EntryKind::Project, "song", a);
        e.blobs.push(blob(7));
        base.upsert(e);
        let mut ma = base.clone();
        let mut mb = base.clone();
        ma.entries.get_mut("p").unwrap().mark_deleted(a);
        ma.entries.get_mut("p").unwrap().modified_at_ms = 5_000;
        let eb = mb.entries.get_mut("p").unwrap();
        eb.name = "song v2".into();
        eb.touch(b);
        eb.modified_at_ms = 4_000;
        let out = merge(&ma, &mb);
        assert!(out.manifest.entries["p"].deleted);
        assert_eq!(out.conflicts.len(), 1);
        assert_eq!(out.manifest.entries[&out.conflicts[0]].name, "song v2");
        assert!(out.manifest.referenced_blobs().contains_key(&blob(7).hash));
        // 反过来：编辑胜、删除败 → 不保留墓碑副本。
        ma.entries.get_mut("p").unwrap().modified_at_ms = 1_000;
        let out = merge(&ma, &mb);
        assert!(!out.manifest.entries["p"].deleted);
        assert!(out.conflicts.is_empty());
    }
}
