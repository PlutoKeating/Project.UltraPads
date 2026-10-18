//! `up_hub::LibraryStore` 的曲库实现（feature `hub`，默认开启）。
//!
//! 映射：
//! | 曲库对象 | 清单条目 ID | kind | blobs（role） | meta |
//! |---|---|---|---|---|
//! | Kit | Kit ID | `kit` | `kits/<id>/manifest.json`（`manifest`）+ 包内每个文件（role = 包内路径） | `{favorite}` |
//! | 独立样本 | `sample:<blake3>` | `sample` | 音频（`audio`） | `{name, origin, …}` |
//! | 录音作品 | Track ID | `track` | 音频（`audio`） | `TrackInfo` |
//!
//! 同步清单保存在 `<root>/sync-manifest.json`。每次 `manifest()`/`merge_manifest()` 前先把本地变化
//! （新增/修改/删除墓碑）写进清单并 `touch(device)`；合并后把远端的新条目落地到曲库（blob 已由
//! Hub 客户端在合并前下载完毕）。blob 就是曲库的内容寻址存储 `samples/<hh>/<hash>`；
//! 录音作品的 blob 落地后移动到 `tracks/<id>.wav`。

use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use serde_json::{Value, json};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};
use up_hub::{
    BlobHash, BlobReader, BlobRef, BlobStatus, BlobWriter, DeviceId, EntryKind, HubError,
    LibraryManifest, LibraryStore, ManifestEntry, MergeOutcome, merge,
};

use crate::index::{SampleRecord, TrackInfo};
use crate::{Library, fsutil};

pub const SYNC_MANIFEST_FILE: &str = "sync-manifest.json";

fn store_err(e: impl std::fmt::Display) -> HubError {
    HubError::Store(e.to_string())
}

struct Inner {
    lib: Arc<Library>,
    device: DeviceId,
    writers: Mutex<HashSet<BlobHash>>,
    manifest_lock: tokio::sync::Mutex<()>,
}

/// 曲库的 Hub 存储适配器。
#[derive(Clone)]
pub struct LibraryHubStore {
    inner: Arc<Inner>,
}

impl std::fmt::Debug for LibraryHubStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LibraryHubStore")
            .field("root", &self.inner.lib.root())
            .finish()
    }
}

/// 一个本地对象期望在清单中呈现的内容。
struct Desired {
    id: String,
    kind: EntryKind,
    name: String,
    blobs: Vec<BlobRef>,
    meta: Value,
}

fn hash(s: &str) -> Option<BlobHash> {
    BlobHash::parse(s).ok()
}

impl Inner {
    fn manifest_path(&self) -> PathBuf {
        self.lib.root().join(SYNC_MANIFEST_FILE)
    }

    fn load(&self) -> up_hub::Result<LibraryManifest> {
        match std::fs::read(self.manifest_path()) {
            Ok(b) => serde_json::from_slice(&b).map_err(store_err),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(LibraryManifest::default()),
            Err(e) => Err(e.into()),
        }
    }

    fn save(&self, m: &LibraryManifest) -> up_hub::Result<()> {
        let bytes = serde_json::to_vec_pretty(m)?;
        fsutil::atomic_write(&self.manifest_path(), &bytes, false).map_err(store_err)
    }

    fn desired(&self) -> up_hub::Result<Vec<Desired>> {
        let idx = self.lib.index_snapshot();
        let mut out = Vec::new();
        for (id, k) in &idx.kits {
            let m = self.lib.kit_manifest(id).map_err(store_err)?;
            let mbytes = self.lib.kit_manifest_bytes(id).map_err(store_err)?;
            let mut blobs = vec![BlobRef {
                hash: BlobHash::of(&mbytes),
                size: mbytes.len() as u64,
                role: "manifest".into(),
            }];
            for f in &m.files {
                if let Some(h) = hash(&f.blake3) {
                    blobs.push(BlobRef {
                        hash: h,
                        size: f.size,
                        role: f.path.clone(),
                    });
                }
            }
            out.push(Desired {
                id: id.clone(),
                kind: EntryKind::Kit,
                name: k.name.clone(),
                blobs,
                meta: json!({ "favorite": k.favorite }),
            });
        }
        for (h, s) in &idx.samples {
            let Some(bh) = hash(h) else { continue };
            out.push(Desired {
                id: format!("sample:{h}"),
                kind: EntryKind::Sample,
                name: s.name.clone(),
                blobs: vec![BlobRef {
                    hash: bh,
                    size: s.size,
                    role: "audio".into(),
                }],
                meta: serde_json::to_value(s)?,
            });
        }
        for (id, t) in &idx.tracks {
            let Some(bh) = hash(&t.blob) else { continue };
            out.push(Desired {
                id: id.clone(),
                kind: EntryKind::Track,
                name: t.name.clone(),
                blobs: vec![BlobRef {
                    hash: bh,
                    size: t.size,
                    role: "audio".into(),
                }],
                meta: serde_json::to_value(t)?,
            });
        }
        Ok(out)
    }

    /// 把本地状态写进清单。返回是否有变化。
    fn reconcile(&self, m: &mut LibraryManifest) -> up_hub::Result<bool> {
        let mut changed = false;
        for d in self.desired()? {
            match m.entries.get_mut(&d.id) {
                Some(e)
                    if !e.deleted
                        && e.kind == d.kind
                        && e.name == d.name
                        && e.blobs == d.blobs
                        && e.meta == d.meta => {}
                Some(e) => {
                    e.kind = d.kind;
                    e.name = d.name;
                    e.blobs = d.blobs;
                    e.meta = d.meta;
                    e.deleted = false;
                    e.touch(self.device);
                    changed = true;
                }
                None => {
                    let mut e = ManifestEntry::new(d.id.clone(), d.kind, d.name, self.device);
                    e.blobs = d.blobs;
                    e.meta = d.meta;
                    m.upsert(e);
                    changed = true;
                }
            }
        }
        let tombstones = self.lib.index_snapshot().tombstones;
        for id in tombstones.keys() {
            if let Some(e) = m.entries.get_mut(id) {
                if !e.deleted {
                    e.mark_deleted(self.device);
                    changed = true;
                }
            }
        }
        Ok(changed)
    }

    /// 把清单中的远端变化落地到曲库。
    fn apply(&self, m: &LibraryManifest) -> up_hub::Result<()> {
        let idx = self.lib.index_snapshot();
        for e in m.entries.values() {
            let safe = fsutil::is_safe_id(&e.id);
            match (e.kind, e.deleted) {
                (EntryKind::Kit, false) if safe => {
                    let Some(mref) = e.blobs.iter().find(|b| b.role == "manifest") else {
                        continue;
                    };
                    let mhex = mref.hash.to_hex();
                    let favorite = e
                        .meta
                        .get("favorite")
                        .and_then(Value::as_bool)
                        .unwrap_or(false);
                    let same = idx
                        .kits
                        .get(&e.id)
                        .is_some_and(|k| k.manifest_blake3 == mhex);
                    if !same {
                        if !e.blobs.iter().all(|b| self.lib.has_blob(&b.hash.to_hex())) {
                            continue;
                        }
                        let mbytes = self.lib.read_blob(&mhex).map_err(store_err)?;
                        self.lib
                            .install_stored_manifest(&e.id, &mbytes)
                            .map_err(store_err)?;
                    }
                    let fav_now = idx.kits.get(&e.id).is_some_and(|k| k.favorite);
                    if !same || fav_now != favorite {
                        self.lib.set_favorite(&e.id, favorite).map_err(store_err)?;
                    }
                }
                (EntryKind::Kit, true) if idx.kits.contains_key(&e.id) => {
                    self.lib.delete_kit(&e.id).map_err(store_err)?;
                }
                (EntryKind::Sample, false) => {
                    let Ok(rec) = serde_json::from_value::<SampleRecord>(e.meta.clone()) else {
                        continue;
                    };
                    if idx.samples.get(&rec.id) != Some(&rec) && self.lib.has_blob(&rec.id) {
                        self.lib
                            .update_index(|i| {
                                i.samples.insert(rec.id.clone(), rec.clone());
                                i.tombstones.remove(&e.id);
                                Ok(())
                            })
                            .map_err(store_err)?;
                    }
                }
                (EntryKind::Sample, true) => {
                    if let Some(h) = e.id.strip_prefix("sample:") {
                        if idx.samples.contains_key(h) {
                            self.lib.delete_sample(h).map_err(store_err)?;
                        }
                    }
                }
                (EntryKind::Track, false) if safe => {
                    let Ok(info) = serde_json::from_value::<TrackInfo>(e.meta.clone()) else {
                        continue;
                    };
                    if idx.tracks.get(&e.id) == Some(&info) {
                        continue;
                    }
                    let dest = self.lib.track_file(&e.id);
                    let local_blob = idx.tracks.get(&e.id).map(|t| t.blob.clone());
                    if local_blob.as_deref() != Some(info.blob.as_str()) {
                        let cas = self.lib.cas_path(&info.blob);
                        if !cas.is_file() {
                            continue;
                        }
                        if let Some(dir) = dest.parent() {
                            std::fs::create_dir_all(dir)?;
                        }
                        std::fs::rename(&cas, &dest)?;
                    }
                    let id = e.id.clone();
                    self.lib
                        .update_index(|i| {
                            i.tracks.insert(
                                id.clone(),
                                TrackInfo {
                                    id: id.clone(),
                                    ..info.clone()
                                },
                            );
                            i.tombstones.remove(&id);
                            Ok(())
                        })
                        .map_err(store_err)?;
                }
                (EntryKind::Track, true) if idx.tracks.contains_key(&e.id) => {
                    self.lib.track_delete(&e.id).map_err(store_err)?;
                }
                _ => {}
            }
        }
        Ok(())
    }

    fn partial_path(&self, h: &BlobHash) -> PathBuf {
        self.lib.partial_dir().join(format!("{}.part", h.to_hex()))
    }

    fn list_blobs(&self) -> up_hub::Result<Vec<BlobHash>> {
        let mut out = Vec::new();
        let samples = self.lib.root().join(crate::SAMPLES_DIR);
        for shard in std::fs::read_dir(&samples)? {
            let shard = shard?;
            let name = shard.file_name().to_string_lossy().into_owned();
            if name.len() != 2 || !shard.file_type()?.is_dir() {
                continue;
            }
            for f in std::fs::read_dir(shard.path())? {
                if let Some(h) = f?
                    .file_name()
                    .to_str()
                    .and_then(|n| BlobHash::parse(n).ok())
                {
                    out.push(h);
                }
            }
        }
        for t in self.lib.index_snapshot().tracks.values() {
            if let Some(h) = hash(&t.blob) {
                if self.lib.track_file(&t.id).is_file() {
                    out.push(h);
                }
            }
        }
        out.sort();
        out.dedup();
        Ok(out)
    }
}

impl LibraryHubStore {
    /// `device` 是本机在 Hub 中的设备 ID（用于版本向量）。
    pub fn new(lib: Arc<Library>, device: DeviceId) -> Self {
        Self {
            inner: Arc::new(Inner {
                lib,
                device,
                writers: Mutex::new(HashSet::new()),
                manifest_lock: tokio::sync::Mutex::new(()),
            }),
        }
    }

    pub fn library(&self) -> &Arc<Library> {
        &self.inner.lib
    }

    async fn blocking<T: Send + 'static>(
        &self,
        f: impl FnOnce(&Inner) -> up_hub::Result<T> + Send + 'static,
    ) -> up_hub::Result<T> {
        let inner = self.inner.clone();
        tokio::task::spawn_blocking(move || f(&inner))
            .await
            .map_err(store_err)?
    }
}

#[async_trait]
impl LibraryStore for LibraryHubStore {
    async fn manifest(&self) -> up_hub::Result<LibraryManifest> {
        let _g = self.inner.manifest_lock.lock().await;
        self.blocking(|i| {
            let mut m = i.load()?;
            if i.reconcile(&mut m)? {
                i.save(&m)?;
            }
            Ok(m)
        })
        .await
    }

    async fn put_manifest(&self, manifest: &LibraryManifest) -> up_hub::Result<()> {
        let _g = self.inner.manifest_lock.lock().await;
        let m = manifest.clone();
        self.blocking(move |i| {
            i.save(&m)?;
            i.apply(&m)
        })
        .await
    }

    async fn merge_manifest(&self, incoming: &LibraryManifest) -> up_hub::Result<MergeOutcome> {
        let _g = self.inner.manifest_lock.lock().await;
        let incoming = incoming.clone();
        self.blocking(move |i| {
            let mut current = i.load()?;
            if i.reconcile(&mut current)? {
                i.save(&current)?;
            }
            let out = merge(&current, &incoming);
            if out.changed > 0 {
                i.save(&out.manifest)?;
            }
            i.apply(&out.manifest)?;
            Ok(out)
        })
        .await
    }

    async fn list_blobs(&self) -> up_hub::Result<Vec<BlobHash>> {
        self.blocking(|i| i.list_blobs()).await
    }

    async fn blob_status(&self, hash: &BlobHash) -> up_hub::Result<BlobStatus> {
        let path = self.inner.lib.blob_path(&hash.to_hex());
        if let Ok(m) = tokio::fs::metadata(&path).await {
            return Ok(BlobStatus::Complete(m.len()));
        }
        Ok(
            match tokio::fs::metadata(self.inner.partial_path(hash)).await {
                Ok(m) if m.len() > 0 => BlobStatus::Partial(m.len()),
                _ => BlobStatus::Missing,
            },
        )
    }

    async fn open_blob(
        &self,
        hash: &BlobHash,
        offset: u64,
    ) -> up_hub::Result<Option<(u64, BlobReader)>> {
        let path = self.inner.lib.blob_path(&hash.to_hex());
        let mut f = match tokio::fs::File::open(&path).await {
            Ok(f) => f,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
            Err(e) => return Err(e.into()),
        };
        let len = f.metadata().await?.len();
        if offset > len {
            return Err(HubError::InvalidInput(format!(
                "offset {offset} > blob length {len}"
            )));
        }
        if offset > 0 {
            f.seek(std::io::SeekFrom::Start(offset)).await?;
        }
        Ok(Some((len, Box::pin(f))))
    }

    async fn blob_writer(
        &self,
        hash: &BlobHash,
        offset: u64,
    ) -> up_hub::Result<Box<dyn BlobWriter>> {
        {
            let mut w = self.inner.writers.lock().unwrap_or_else(|p| p.into_inner());
            if !w.insert(*hash) {
                return Err(HubError::Busy(*hash));
            }
        }
        let guard = WriterGuard {
            inner: self.inner.clone(),
            hash: *hash,
        };
        let partial = self.inner.partial_path(hash);
        tokio::fs::create_dir_all(self.inner.lib.partial_dir()).await?;
        let existing = tokio::fs::metadata(&partial)
            .await
            .map(|m| m.len())
            .unwrap_or(0);
        if offset != 0 && offset != existing {
            return Err(HubError::OffsetMismatch { expected: existing });
        }
        let mut hasher = blake3::Hasher::new();
        let file = if offset == 0 {
            tokio::fs::File::create(&partial).await?
        } else {
            let mut f = tokio::fs::OpenOptions::new()
                .read(true)
                .append(true)
                .open(&partial)
                .await?;
            let mut buf = vec![0u8; 256 * 1024];
            loop {
                let n = f.read(&mut buf).await?;
                if n == 0 {
                    break;
                }
                hasher.update(&buf[..n]);
            }
            f
        };
        Ok(Box::new(CasWriter {
            file,
            hasher,
            written: offset,
            hash: *hash,
            partial,
            final_path: self.inner.lib.cas_path(&hash.to_hex()),
            _guard: guard,
        }))
    }
}

struct WriterGuard {
    inner: Arc<Inner>,
    hash: BlobHash,
}

impl Drop for WriterGuard {
    fn drop(&mut self) {
        self.inner
            .writers
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .remove(&self.hash);
    }
}

struct CasWriter {
    file: tokio::fs::File,
    hasher: blake3::Hasher,
    written: u64,
    hash: BlobHash,
    partial: PathBuf,
    final_path: PathBuf,
    _guard: WriterGuard,
}

#[async_trait]
impl BlobWriter for CasWriter {
    async fn write(&mut self, chunk: &[u8]) -> up_hub::Result<()> {
        self.file.write_all(chunk).await?;
        self.hasher.update(chunk);
        self.written += chunk.len() as u64;
        Ok(())
    }

    fn written(&self) -> u64 {
        self.written
    }

    async fn finish(mut self: Box<Self>) -> up_hub::Result<u64> {
        self.file.flush().await?;
        self.file.sync_all().await?;
        let actual = BlobHash::from(self.hasher.finalize());
        if actual != self.hash {
            let _ = tokio::fs::remove_file(&self.partial).await;
            return Err(HubError::HashMismatch {
                expected: self.hash,
                actual,
            });
        }
        if let Some(dir) = self.final_path.parent() {
            tokio::fs::create_dir_all(dir).await?;
        }
        tokio::fs::rename(&self.partial, &self.final_path).await?;
        Ok(self.written)
    }

    async fn abort(self: Box<Self>) -> up_hub::Result<()> {
        match tokio::fs::remove_file(&self.partial).await {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(e.into()),
        }
    }
}
