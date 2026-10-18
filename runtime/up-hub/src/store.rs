//! 曲库存储抽象：`LibraryStore`（由 up-library 实现）与参考实现 `FsLibraryStore`。

use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncSeekExt, AsyncWriteExt};

use crate::model::{BlobHash, LibraryManifest, MergeOutcome, merge};
use crate::util::atomic_write_sync;
use crate::{HubError, Result};

/// blob 在存储中的状态。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BlobStatus {
    /// 不存在。
    Missing,
    /// 有未完成的部分数据（字节数），可从该偏移续传。
    Partial(u64),
    /// 完整且已校验（总字节数）。
    Complete(u64),
}

/// blob 读取流。
pub type BlobReader = Pin<Box<dyn AsyncRead + Send>>;

/// 流式写入一个 blob。完成时校验 BLAKE3，失败则丢弃。
///
/// 未调用 `finish`/`abort` 就被 drop 时，已写入的部分数据**保留**，供下次续传。
#[async_trait]
pub trait BlobWriter: Send {
    /// 追加数据。
    async fn write(&mut self, chunk: &[u8]) -> Result<()>;
    /// 已写入的总字节数（含续传前已有的部分）。
    fn written(&self) -> u64;
    /// 校验并提交。哈希不符时删除部分数据并返回 [`HubError::HashMismatch`]。
    async fn finish(self: Box<Self>) -> Result<u64>;
    /// 放弃并删除部分数据。
    async fn abort(self: Box<Self>) -> Result<()>;
}

/// 曲库存储。up-library 实现它；up-hub 只通过它访问曲库。
///
/// 约定：
/// - blob 以 BLAKE3 内容寻址，写入必须校验；
/// - `merge_manifest` 必须是原子的读-合并-写（与本地其他写入串行化）；
/// - 方法会被多个任务并发调用。
#[async_trait]
pub trait LibraryStore: Send + Sync + 'static {
    /// 读取当前清单（不存在时返回空清单）。
    async fn manifest(&self) -> Result<LibraryManifest>;
    /// 覆盖写入清单。
    async fn put_manifest(&self, manifest: &LibraryManifest) -> Result<()>;
    /// 原子地把 `incoming` 合并进当前清单并保存，返回合并结果。
    ///
    /// 默认实现不是原子的；实现者应覆盖并加锁。
    async fn merge_manifest(&self, incoming: &LibraryManifest) -> Result<MergeOutcome> {
        let current = self.manifest().await?;
        let out = merge(&current, incoming);
        if out.changed > 0 {
            self.put_manifest(&out.manifest).await?;
        }
        Ok(out)
    }
    /// 列出所有完整的 blob。
    async fn list_blobs(&self) -> Result<Vec<BlobHash>>;
    /// 查询 blob 状态。
    async fn blob_status(&self, hash: &BlobHash) -> Result<BlobStatus>;
    /// 从 `offset` 开始读取完整 blob；返回 (总长度, 读取流)。不存在时返回 `None`。
    async fn open_blob(&self, hash: &BlobHash, offset: u64) -> Result<Option<(u64, BlobReader)>>;
    /// 开始写入 blob。`offset` 必须为 0（重新开始）或等于已有部分数据长度（续传），
    /// 否则返回 [`HubError::OffsetMismatch`]。
    async fn blob_writer(&self, hash: &BlobHash, offset: u64) -> Result<Box<dyn BlobWriter>>;

    /// 便捷方法：一次性写入整块数据，返回其地址。
    async fn put_blob(&self, data: &[u8]) -> Result<BlobHash> {
        let hash = BlobHash::of(data);
        if matches!(self.blob_status(&hash).await?, BlobStatus::Complete(_)) {
            return Ok(hash);
        }
        let mut w = self.blob_writer(&hash, 0).await?;
        w.write(data).await?;
        w.finish().await?;
        Ok(hash)
    }

    /// 便捷方法：读取整块数据。
    async fn read_blob(&self, hash: &BlobHash) -> Result<Vec<u8>> {
        let (len, mut r) = self
            .open_blob(hash, 0)
            .await?
            .ok_or(HubError::BlobNotFound(*hash))?;
        let mut buf = Vec::with_capacity(len as usize);
        r.read_to_end(&mut buf).await?;
        Ok(buf)
    }
}

/// 基于文件系统的参考实现。
///
/// 目录布局：
/// ```text
/// <root>/manifest.json
/// <root>/blobs/<hex[0..2]>/<hex>      完整、已校验的 blob
/// <root>/partial/<hex>.part           未完成的上传/下载（可续传）
/// ```
pub struct FsLibraryStore {
    root: PathBuf,
    manifest_lock: tokio::sync::Mutex<()>,
    writers: Arc<Mutex<HashSet<BlobHash>>>,
}

impl std::fmt::Debug for FsLibraryStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FsLibraryStore")
            .field("root", &self.root)
            .finish()
    }
}

impl FsLibraryStore {
    /// 打开（不存在时创建）存储目录。
    pub async fn open(root: impl AsRef<Path>) -> Result<Self> {
        let root = root.as_ref().to_path_buf();
        tokio::fs::create_dir_all(root.join("blobs")).await?;
        tokio::fs::create_dir_all(root.join("partial")).await?;
        Ok(Self {
            root,
            manifest_lock: tokio::sync::Mutex::new(()),
            writers: Arc::new(Mutex::new(HashSet::new())),
        })
    }

    /// 根目录。
    pub fn root(&self) -> &Path {
        &self.root
    }

    fn blob_path(&self, h: &BlobHash) -> PathBuf {
        let hex = h.to_hex();
        self.root.join("blobs").join(&hex[..2]).join(hex)
    }

    fn partial_path(&self, h: &BlobHash) -> PathBuf {
        self.root
            .join("partial")
            .join(format!("{}.part", h.to_hex()))
    }

    fn manifest_path(&self) -> PathBuf {
        self.root.join("manifest.json")
    }

    async fn read_manifest_unlocked(&self) -> Result<LibraryManifest> {
        match tokio::fs::read(self.manifest_path()).await {
            Ok(bytes) => {
                let m: LibraryManifest = serde_json::from_slice(&bytes)
                    .map_err(|e| HubError::Store(format!("manifest.json: {e}")))?;
                Ok(m)
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(LibraryManifest::default()),
            Err(e) => Err(e.into()),
        }
    }

    async fn write_manifest_unlocked(&self, m: &LibraryManifest) -> Result<()> {
        let bytes = serde_json::to_vec_pretty(m)?;
        let path = self.manifest_path();
        tokio::task::spawn_blocking(move || atomic_write_sync(&path, &bytes, false))
            .await
            .map_err(|e| HubError::Store(e.to_string()))??;
        Ok(())
    }
}

async fn file_len(p: &Path) -> Result<Option<u64>> {
    match tokio::fs::metadata(p).await {
        Ok(m) => Ok(Some(m.len())),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.into()),
    }
}

#[async_trait]
impl LibraryStore for FsLibraryStore {
    async fn manifest(&self) -> Result<LibraryManifest> {
        let _g = self.manifest_lock.lock().await;
        self.read_manifest_unlocked().await
    }

    async fn put_manifest(&self, manifest: &LibraryManifest) -> Result<()> {
        let _g = self.manifest_lock.lock().await;
        self.write_manifest_unlocked(manifest).await
    }

    async fn merge_manifest(&self, incoming: &LibraryManifest) -> Result<MergeOutcome> {
        let _g = self.manifest_lock.lock().await;
        let current = self.read_manifest_unlocked().await?;
        let out = merge(&current, incoming);
        if out.changed > 0 {
            self.write_manifest_unlocked(&out.manifest).await?;
        }
        Ok(out)
    }

    async fn list_blobs(&self) -> Result<Vec<BlobHash>> {
        let mut out = Vec::new();
        let mut shards = tokio::fs::read_dir(self.root.join("blobs")).await?;
        while let Some(shard) = shards.next_entry().await? {
            if !shard.file_type().await?.is_dir() {
                continue;
            }
            let mut files = tokio::fs::read_dir(shard.path()).await?;
            while let Some(f) = files.next_entry().await? {
                if let Some(h) = f.file_name().to_str().and_then(|n| BlobHash::parse(n).ok()) {
                    out.push(h);
                }
            }
        }
        out.sort();
        Ok(out)
    }

    async fn blob_status(&self, hash: &BlobHash) -> Result<BlobStatus> {
        if let Some(len) = file_len(&self.blob_path(hash)).await? {
            return Ok(BlobStatus::Complete(len));
        }
        Ok(match file_len(&self.partial_path(hash)).await? {
            Some(n) if n > 0 => BlobStatus::Partial(n),
            _ => BlobStatus::Missing,
        })
    }

    async fn open_blob(&self, hash: &BlobHash, offset: u64) -> Result<Option<(u64, BlobReader)>> {
        let mut f = match tokio::fs::File::open(self.blob_path(hash)).await {
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

    async fn blob_writer(&self, hash: &BlobHash, offset: u64) -> Result<Box<dyn BlobWriter>> {
        let guard = WriterGuard::acquire(&self.writers, *hash)?;
        let partial = self.partial_path(hash);
        let existing = file_len(&partial).await?.unwrap_or(0);
        if offset != 0 && offset != existing {
            return Err(HubError::OffsetMismatch { expected: existing });
        }
        let mut hasher = blake3::Hasher::new();
        let file = if offset == 0 {
            tokio::fs::File::create(&partial).await?
        } else {
            // 续传：先把已有前缀喂给哈希器。
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
        Ok(Box::new(FsBlobWriter {
            file,
            hasher,
            written: offset,
            hash: *hash,
            partial,
            final_path: self.blob_path(hash),
            _guard: guard,
        }))
    }
}

struct WriterGuard {
    set: Arc<Mutex<HashSet<BlobHash>>>,
    hash: BlobHash,
}

impl WriterGuard {
    fn acquire(set: &Arc<Mutex<HashSet<BlobHash>>>, hash: BlobHash) -> Result<Self> {
        if !set.lock().expect("writers lock").insert(hash) {
            return Err(HubError::Busy(hash));
        }
        Ok(Self {
            set: set.clone(),
            hash,
        })
    }
}

impl Drop for WriterGuard {
    fn drop(&mut self) {
        self.set.lock().expect("writers lock").remove(&self.hash);
    }
}

struct FsBlobWriter {
    file: tokio::fs::File,
    hasher: blake3::Hasher,
    written: u64,
    hash: BlobHash,
    partial: PathBuf,
    final_path: PathBuf,
    _guard: WriterGuard,
}

#[async_trait]
impl BlobWriter for FsBlobWriter {
    async fn write(&mut self, chunk: &[u8]) -> Result<()> {
        self.file.write_all(chunk).await?;
        self.hasher.update(chunk);
        self.written += chunk.len() as u64;
        Ok(())
    }

    fn written(&self) -> u64 {
        self.written
    }

    async fn finish(mut self: Box<Self>) -> Result<u64> {
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

    async fn abort(self: Box<Self>) -> Result<()> {
        match tokio::fs::remove_file(&self.partial).await {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(e.into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::identity::DeviceIdentity;
    use crate::model::{EntryKind, ManifestEntry};

    #[tokio::test]
    async fn put_read_list() {
        let dir = tempfile::tempdir().unwrap();
        let s = FsLibraryStore::open(dir.path()).await.unwrap();
        let h = s.put_blob(b"abc").await.unwrap();
        assert_eq!(h, BlobHash::of(b"abc"));
        assert_eq!(s.blob_status(&h).await.unwrap(), BlobStatus::Complete(3));
        assert_eq!(s.read_blob(&h).await.unwrap(), b"abc");
        assert_eq!(s.list_blobs().await.unwrap(), vec![h]);
        let (len, mut r) = s.open_blob(&h, 1).await.unwrap().unwrap();
        let mut rest = Vec::new();
        r.read_to_end(&mut rest).await.unwrap();
        assert_eq!((len, rest.as_slice()), (3, &b"bc"[..]));
    }

    #[tokio::test]
    async fn resume_and_verify() {
        let dir = tempfile::tempdir().unwrap();
        let s = FsLibraryStore::open(dir.path()).await.unwrap();
        let data: Vec<u8> = (0..100_000u32).map(|i| (i % 251) as u8).collect();
        let h = BlobHash::of(&data);
        {
            let mut w = s.blob_writer(&h, 0).await.unwrap();
            w.write(&data[..40_000]).await.unwrap();
            // 并发写同一 blob 被拒绝。
            assert!(matches!(s.blob_writer(&h, 0).await, Err(HubError::Busy(_))));
            // drop：保留部分数据
        }
        assert_eq!(
            s.blob_status(&h).await.unwrap(),
            BlobStatus::Partial(40_000)
        );
        assert!(matches!(
            s.blob_writer(&h, 10).await,
            Err(HubError::OffsetMismatch { expected: 40_000 })
        ));
        let mut w = s.blob_writer(&h, 40_000).await.unwrap();
        w.write(&data[40_000..]).await.unwrap();
        assert_eq!(w.written(), 100_000);
        assert_eq!(w.finish().await.unwrap(), 100_000);
        assert_eq!(s.read_blob(&h).await.unwrap(), data);
    }

    #[tokio::test]
    async fn hash_mismatch_discards() {
        let dir = tempfile::tempdir().unwrap();
        let s = FsLibraryStore::open(dir.path()).await.unwrap();
        let h = BlobHash::of(b"expected");
        let mut w = s.blob_writer(&h, 0).await.unwrap();
        w.write(b"tampered").await.unwrap();
        assert!(matches!(
            w.finish().await,
            Err(HubError::HashMismatch { .. })
        ));
        assert_eq!(s.blob_status(&h).await.unwrap(), BlobStatus::Missing);
    }

    #[tokio::test]
    async fn manifest_merge_persists() {
        let dir = tempfile::tempdir().unwrap();
        let s = FsLibraryStore::open(dir.path()).await.unwrap();
        assert!(s.manifest().await.unwrap().entries.is_empty());
        let d = DeviceIdentity::generate().id();
        let mut m = LibraryManifest::default();
        m.upsert(ManifestEntry::new("a", EntryKind::Kit, "A", d));
        let out = s.merge_manifest(&m).await.unwrap();
        assert_eq!(out.changed, 1);
        let s2 = FsLibraryStore::open(dir.path()).await.unwrap();
        assert_eq!(s2.manifest().await.unwrap(), m);
    }
}
