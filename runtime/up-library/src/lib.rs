//! UltraPads 曲库：Kit/样本/录音作品的存储与服务。
//!
//! # 数据根目录布局
//! ```text
//! <root>/
//! ├── library.json                 索引：Kit/样本/作品摘要、收藏、最近使用、外部目录、删除墓碑
//! ├── kits/<kit-id>/manifest.json  每个 Kit 的包清单（.upkit 的 manifest.json，文件内容在 samples/）
//! ├── samples/<hh>/<blake3>        内容寻址存储（BLAKE3）：采样音频以及 Kit 包内的所有文件
//! ├── samples/.partial/            同步中未完成的 blob
//! ├── tracks/<track-id>.wav        录音作品
//! └── projects/                    编曲工程（预留）
//! ```
//! Kit 在库内以“manifest + 内容寻址 blob”的形式保存：同一采样被多个 Kit 引用只存一份；
//! 导出时重新组装成 `.upkit`（ZIP 或文件夹）。
//!
//! # 线程安全
//! [`Library`] 内部加锁，所有方法都取 `&self`，可放进 `Arc` 在控制线程与 Hub 之间共享。
//! 不要在音频线程调用。

pub mod archive;
pub mod error;
pub mod fsutil;
pub mod import;
pub mod index;
pub mod kitgen;
mod kits;
mod media;
pub mod transcode;

#[cfg(feature = "hub")]
pub mod hub_store;

use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard};

pub use archive::{ImportLimits, SourceFs};
pub use error::{LibraryError, Result};
pub use import::compat::{CompatKit, CompatScan, CompatSource};
pub use import::{ImportKind, ImportReport, ImportedKit};
pub use index::{
    CatalogCategory, CatalogEntry, CatalogStatus, KitQuery, KitSort, KitSummary, LibraryIndex,
    SampleOrigin, SampleRecord, TrackInfo,
};
pub use kits::{ExportFormat, LoadOptions, LoadedKit, LoadedSample};
pub use media::TrackExportFormat;
pub use up_format;
pub use up_format::Warning;
pub use up_format::kit::KitDoc;

use error::IoContext;

pub const KITS_DIR: &str = "kits";
pub const SAMPLES_DIR: &str = "samples";
pub const TRACKS_DIR: &str = "tracks";
pub const PROJECTS_DIR: &str = "projects";
#[cfg(feature = "hub")]
const PARTIAL_DIR: &str = ".partial";

/// 打开曲库的选项。
pub struct LibraryOptions {
    pub limits: ImportLimits,
    /// 私有素材包导入器（可插拔，多来源）。默认包含所有内置来源。
    pub compat_sources: Vec<Box<dyn CompatSource>>,
}

impl Default for LibraryOptions {
    fn default() -> Self {
        Self {
            limits: ImportLimits::default(),
            compat_sources: import::compat::builtin_sources(),
        }
    }
}

/// 曲库。
pub struct Library {
    root: PathBuf,
    index: Mutex<LibraryIndex>,
    limits: ImportLimits,
    compat: Vec<Box<dyn CompatSource>>,
}

impl std::fmt::Debug for Library {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Library").field("root", &self.root).finish()
    }
}

impl Library {
    /// 打开（不存在时创建）数据根目录下的曲库。
    pub fn open(root: impl AsRef<Path>) -> Result<Self> {
        Self::open_with(root, LibraryOptions::default())
    }

    pub fn open_with(root: impl AsRef<Path>, options: LibraryOptions) -> Result<Self> {
        let root = root.as_ref().to_path_buf();
        for d in [KITS_DIR, SAMPLES_DIR, TRACKS_DIR, PROJECTS_DIR] {
            let p = root.join(d);
            std::fs::create_dir_all(&p).ctx(|| format!("创建 {}", p.display()))?;
        }
        let index_path = root.join(index::INDEX_FILE);
        let lib = Self {
            root,
            index: Mutex::new(LibraryIndex::default()),
            limits: options.limits,
            compat: options.compat_sources,
        };
        let loaded = match std::fs::read(&index_path) {
            Ok(bytes) => match serde_json::from_slice::<LibraryIndex>(&bytes) {
                Ok(idx) => {
                    up_format::check_format_version(&idx.format_version)?;
                    Some(idx)
                }
                Err(_) => None,
            },
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
            Err(e) => return Err(LibraryError::io("读取 library.json", e)),
        };
        match loaded {
            Some(idx) => *lib.lock() = idx,
            None => {
                // 索引缺失或损坏：从 kits/ 与 tracks/ 重建（用户状态丢失，但内容不丢）
                lib.rebuild_index()?;
            }
        }
        Ok(lib)
    }

    /// 数据根目录。
    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn limits(&self) -> ImportLimits {
        self.limits
    }

    pub(crate) fn lock(&self) -> MutexGuard<'_, LibraryIndex> {
        self.index.lock().unwrap_or_else(|p| p.into_inner())
    }

    pub(crate) fn save_index(&self, idx: &LibraryIndex) -> Result<()> {
        let mut bytes = serde_json::to_vec_pretty(idx)
            .map_err(|e| LibraryError::CorruptIndex(e.to_string()))?;
        bytes.push(b'\n');
        fsutil::atomic_write(&self.root.join(index::INDEX_FILE), &bytes, true)
    }

    /// 修改索引并持久化。
    pub(crate) fn update_index<T>(
        &self,
        f: impl FnOnce(&mut LibraryIndex) -> Result<T>,
    ) -> Result<T> {
        let mut idx = self.lock();
        let out = f(&mut idx)?;
        self.save_index(&idx)?;
        Ok(out)
    }

    /// 当前索引的快照。
    pub fn index_snapshot(&self) -> LibraryIndex {
        self.lock().clone()
    }

    // ------------------------------------------------------------------
    // 内容寻址存储
    // ------------------------------------------------------------------

    /// blob 的磁盘路径（不保证存在）。录音作品的音频在 `tracks/` 下。
    pub fn blob_path(&self, hash: &str) -> PathBuf {
        let hash = hash.to_ascii_lowercase();
        if let Some(t) = self.lock().tracks.values().find(|t| t.blob == hash) {
            return self.track_file(&t.id);
        }
        self.cas_path(&hash)
    }

    pub(crate) fn cas_path(&self, hash: &str) -> PathBuf {
        let shard = hash.get(..2).unwrap_or("00");
        self.root.join(SAMPLES_DIR).join(shard).join(hash)
    }

    #[cfg(feature = "hub")]
    pub(crate) fn partial_dir(&self) -> PathBuf {
        self.root.join(SAMPLES_DIR).join(PARTIAL_DIR)
    }

    pub(crate) fn track_file(&self, id: &str) -> PathBuf {
        self.root.join(TRACKS_DIR).join(format!("{id}.wav"))
    }

    pub fn has_blob(&self, hash: &str) -> bool {
        is_hash(hash) && self.blob_path(hash).is_file()
    }

    /// 写入 blob（已存在则跳过），返回 BLAKE3。
    pub fn put_blob(&self, bytes: &[u8]) -> Result<String> {
        let hash = up_format::blake3_hex(bytes);
        let path = self.cas_path(&hash);
        if !path.is_file() {
            fsutil::atomic_write(&path, bytes, false)?;
        }
        Ok(hash)
    }

    /// 读取 blob 并校验哈希。
    pub fn read_blob(&self, hash: &str) -> Result<Vec<u8>> {
        if !is_hash(hash) {
            return Err(LibraryError::InvalidInput(format!("非法哈希 `{hash}`")));
        }
        let path = self.blob_path(hash);
        let bytes = std::fs::read(&path).map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                LibraryError::not_found("blob", hash)
            } else {
                LibraryError::io(format!("读取 {}", path.display()), e)
            }
        })?;
        let actual = up_format::blake3_hex(&bytes);
        if !actual.eq_ignore_ascii_case(hash) {
            return Err(up_format::FormatError::HashMismatch {
                path: path.display().to_string(),
                expected: hash.to_string(),
                actual,
            }
            .into());
        }
        Ok(bytes)
    }

    /// 删除不再被任何 Kit/样本/作品引用的 blob，返回删除数量。
    pub fn gc_blobs(&self) -> Result<usize> {
        let referenced = self.referenced_blobs()?;
        let mut removed = 0;
        let samples = self.root.join(SAMPLES_DIR);
        for shard in std::fs::read_dir(&samples).ctx(|| "列出 samples/".into())? {
            let shard = shard.ctx(|| "列出 samples/".into())?;
            let name = shard.file_name().to_string_lossy().into_owned();
            if name.len() != 2 || !shard.path().is_dir() {
                continue;
            }
            for f in std::fs::read_dir(shard.path()).ctx(|| format!("列出 samples/{name}"))? {
                let f = f.ctx(|| format!("列出 samples/{name}"))?;
                let h = f.file_name().to_string_lossy().into_owned();
                if is_hash(&h) && !referenced.contains(&h) {
                    std::fs::remove_file(f.path()).ctx(|| format!("删除 blob {h}"))?;
                    removed += 1;
                }
            }
        }
        Ok(removed)
    }

    fn referenced_blobs(&self) -> Result<std::collections::BTreeSet<String>> {
        let ids: Vec<String> = self.lock().kits.keys().cloned().collect();
        let mut set = std::collections::BTreeSet::new();
        for id in ids {
            if let Ok(m) = self.kit_manifest(&id) {
                set.extend(m.files.iter().map(|f| f.blake3.to_ascii_lowercase()));
                set.insert(self.kit_manifest_hash(&id)?);
            }
        }
        set.extend(self.lock().samples.keys().cloned());
        Ok(set)
    }

    /// 从 `kits/` 与 `tracks/` 重建索引（用户状态无法恢复）。
    pub fn rebuild_index(&self) -> Result<()> {
        let mut idx = LibraryIndex::default();
        let kits_dir = self.root.join(KITS_DIR);
        for e in std::fs::read_dir(&kits_dir).ctx(|| "列出 kits/".into())? {
            let e = e.ctx(|| "列出 kits/".into())?;
            let id = e.file_name().to_string_lossy().into_owned();
            if !fsutil::is_safe_id(&id) {
                continue;
            }
            match self.summarize_stored_kit(&id, None) {
                Ok(s) => {
                    idx.kits.insert(id, s);
                }
                Err(_) => continue,
            }
        }
        let tracks_dir = self.root.join(TRACKS_DIR);
        for e in std::fs::read_dir(&tracks_dir).ctx(|| "列出 tracks/".into())? {
            let e = e.ctx(|| "列出 tracks/".into())?;
            let name = e.file_name().to_string_lossy().into_owned();
            let Some(id) = name.strip_suffix(".wav") else {
                continue;
            };
            if !fsutil::is_safe_id(id) {
                continue;
            }
            if let Ok(bytes) = std::fs::read(e.path()) {
                if let Ok(t) =
                    media::track_info_from_bytes(id, id, &bytes, None, None, fsutil::now_ms())
                {
                    idx.tracks.insert(id.to_string(), t);
                }
            }
        }
        self.save_index(&idx)?;
        *self.lock() = idx;
        Ok(())
    }
}

pub(crate) fn is_hash(s: &str) -> bool {
    s.len() == 64 && s.bytes().all(|b| b.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn open_creates_layout_and_cas_works() {
        let dir = tempfile::tempdir().unwrap();
        let lib = Library::open(dir.path()).unwrap();
        for d in [KITS_DIR, SAMPLES_DIR, TRACKS_DIR, PROJECTS_DIR] {
            assert!(dir.path().join(d).is_dir());
        }
        let h = lib.put_blob(b"hello").unwrap();
        assert!(lib.has_blob(&h));
        assert_eq!(lib.read_blob(&h).unwrap(), b"hello");
        std::fs::write(lib.cas_path(&h), b"tampered").unwrap();
        assert!(lib.read_blob(&h).is_err());
        assert_eq!(lib.gc_blobs().unwrap(), 1);
        // 损坏的索引会被重建
        std::fs::write(dir.path().join(index::INDEX_FILE), b"{oops").unwrap();
        let lib = Library::open(dir.path()).unwrap();
        assert!(lib.list_kits(&KitQuery::default()).is_empty());
    }
}
