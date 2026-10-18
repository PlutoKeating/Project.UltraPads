//! 包容器：带限额的 ZIP/文件夹读取、ZIP 写出，以及导入器共用的只读文件源 [`SourceFs`]。
//!
//! 安全规则（规格 §5.6）：
//! - 条目名用 `up_format::path::normalize` 规范化，拒绝绝对路径、`..`、盘符、控制字符
//! - 拒绝符号链接条目；文件夹遍历不跟随符号链接
//! - 限制条目数、单条目大小、总大小（以实际解压字节计，不信任头部声明）和压缩比（zip bomb）

use std::collections::BTreeMap;
use std::io::{Read, Seek, Write};
use std::path::{Path, PathBuf};

use crate::error::{IoContext, LibraryError, Result};

/// 导入限额。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ImportLimits {
    pub max_entries: usize,
    pub max_entry_bytes: u64,
    pub max_total_bytes: u64,
    /// 解压后/压缩后 的最大比值（仅对大于 1 MiB 的条目检查）。
    pub max_compression_ratio: u64,
    /// 文件夹遍历的最大深度。
    pub max_depth: usize,
}

impl Default for ImportLimits {
    fn default() -> Self {
        Self {
            max_entries: 10_000,
            max_entry_bytes: 512 * 1024 * 1024,
            max_total_bytes: 2 * 1024 * 1024 * 1024,
            max_compression_ratio: 200,
            max_depth: 24,
        }
    }
}

/// 只读文件源：导入器通过它访问文件夹或 ZIP，不关心底层是什么。
pub trait SourceFs {
    /// 所有文件的规范化相对路径（`/` 分隔），已排序。
    fn files(&self) -> Vec<String>;
    /// 读取文件内容（受限额约束）。
    fn read(&self, path: &str) -> Result<Vec<u8>>;
    /// 文件大小（未知时为 `None`）。
    fn size(&self, path: &str) -> Option<u64>;
    /// 显示用名称（文件夹名或 ZIP 文件名，不含扩展名）。
    fn display_name(&self) -> String;

    fn exists(&self, path: &str) -> bool {
        self.size(path).is_some()
    }

    /// 大小写不敏感地查找文件。
    fn find_ci(&self, path: &str) -> Option<String> {
        if self.exists(path) {
            return Some(path.to_string());
        }
        let lower = path.to_lowercase();
        self.files().into_iter().find(|f| f.to_lowercase() == lower)
    }
}

/// 内存中的文件源（ZIP 解包结果）。
#[derive(Debug, Clone, Default)]
pub struct MemFs {
    pub name: String,
    pub files: BTreeMap<String, Vec<u8>>,
}

impl SourceFs for MemFs {
    fn files(&self) -> Vec<String> {
        self.files.keys().cloned().collect()
    }
    fn read(&self, path: &str) -> Result<Vec<u8>> {
        self.files
            .get(path)
            .cloned()
            .ok_or_else(|| LibraryError::not_found("file", path))
    }
    fn size(&self, path: &str) -> Option<u64> {
        self.files.get(path).map(|b| b.len() as u64)
    }
    fn display_name(&self) -> String {
        self.name.clone()
    }
}

/// 文件夹文件源（不跟随符号链接）。文件列表按需遍历并缓存；单个文件的访问直接检查磁盘，
/// 因此导入单个 `.sfz` 时不会遍历它所在的整个目录树。
#[derive(Debug)]
pub struct DirFs {
    pub root: PathBuf,
    listing: std::sync::OnceLock<std::result::Result<BTreeMap<String, u64>, String>>,
    limits: ImportLimits,
}

impl DirFs {
    pub fn open(root: &Path, limits: ImportLimits) -> Result<Self> {
        let meta = std::fs::symlink_metadata(root).ctx(|| format!("读取 {}", root.display()))?;
        if !meta.is_dir() {
            return Err(LibraryError::InvalidInput(format!(
                "{} 不是文件夹",
                root.display()
            )));
        }
        Ok(Self {
            root: root.to_path_buf(),
            listing: std::sync::OnceLock::new(),
            limits,
        })
    }

    fn listing(&self) -> Result<&BTreeMap<String, u64>> {
        self.listing
            .get_or_init(|| {
                let mut files = BTreeMap::new();
                walk(&self.root, "", 0, &self.limits, &mut files).map_err(|e| e.to_string())?;
                Ok(files)
            })
            .as_ref()
            .map_err(|e| LibraryError::LimitExceeded(e.clone()))
    }

    /// 检查相对路径的每一级都不是符号链接，返回文件大小。
    fn stat(&self, rel: &str) -> Option<u64> {
        let rel = up_format::path::normalize(rel).ok()?;
        let mut p = self.root.clone();
        let parts: Vec<&str> = rel.split('/').collect();
        for (i, c) in parts.iter().enumerate() {
            p.push(c);
            let m = std::fs::symlink_metadata(&p).ok()?;
            if m.file_type().is_symlink() {
                return None;
            }
            if i + 1 == parts.len() {
                return m.is_file().then_some(m.len());
            }
            if !m.is_dir() {
                return None;
            }
        }
        None
    }

    /// 按需列出整个文件夹（受限额约束）。
    pub fn try_files(&self) -> Result<Vec<String>> {
        Ok(self.listing()?.keys().cloned().collect())
    }
}

fn walk(
    dir: &Path,
    prefix: &str,
    depth: usize,
    limits: &ImportLimits,
    out: &mut BTreeMap<String, u64>,
) -> Result<()> {
    if depth > limits.max_depth {
        return Ok(());
    }
    let rd = std::fs::read_dir(dir).ctx(|| format!("列出 {}", dir.display()))?;
    for entry in rd {
        let entry = entry.ctx(|| format!("列出 {}", dir.display()))?;
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        if name.starts_with('.') {
            continue;
        }
        let ft = entry.file_type().ctx(|| format!("stat {name}"))?;
        if ft.is_symlink() {
            continue;
        }
        let rel = if prefix.is_empty() {
            name.to_string()
        } else {
            format!("{prefix}/{name}")
        };
        if up_format::path::normalize(&rel).is_err() {
            continue;
        }
        if ft.is_dir() {
            walk(&entry.path(), &rel, depth + 1, limits, out)?;
        } else if ft.is_file() {
            let len = entry.metadata().map(|m| m.len()).unwrap_or(0);
            out.insert(rel, len);
            if out.len() > limits.max_entries * 20 {
                return Err(LibraryError::LimitExceeded(format!(
                    "文件夹中的文件超过 {} 个",
                    limits.max_entries * 20
                )));
            }
        }
    }
    Ok(())
}

impl SourceFs for DirFs {
    fn files(&self) -> Vec<String> {
        self.try_files().unwrap_or_default()
    }
    fn read(&self, path: &str) -> Result<Vec<u8>> {
        let len = self
            .stat(path)
            .ok_or_else(|| LibraryError::not_found("file", path))?;
        if len > self.limits.max_entry_bytes {
            return Err(LibraryError::LimitExceeded(format!(
                "{path} 有 {len} 字节，超过单文件上限 {}",
                self.limits.max_entry_bytes
            )));
        }
        let p = crate::fsutil::join_rel(&self.root, path);
        std::fs::read(&p).ctx(|| format!("读取 {}", p.display()))
    }
    fn size(&self, path: &str) -> Option<u64> {
        self.stat(path)
    }
    fn display_name(&self) -> String {
        self.root
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| "Imported".into())
    }
    fn find_ci(&self, path: &str) -> Option<String> {
        if self.stat(path).is_some() {
            return up_format::path::normalize(path).ok();
        }
        // 逐级大小写不敏感匹配，只读取路径上的目录
        let norm = up_format::path::normalize(path).ok()?;
        let mut dir = self.root.clone();
        let mut out: Vec<String> = Vec::new();
        for c in norm.split('/') {
            let lower = c.to_lowercase();
            let hit = std::fs::read_dir(&dir)
                .ok()?
                .filter_map(|e| e.ok())
                .filter_map(|e| e.file_name().to_str().map(str::to_string))
                .find(|n| n.to_lowercase() == lower)?;
            dir.push(&hit);
            out.push(hit);
        }
        let rel = out.join("/");
        self.stat(&rel).map(|_| rel)
    }
}

/// 读取 ZIP 到内存，执行全部安全检查。
pub fn read_zip<R: Read + Seek>(reader: R, name: &str, limits: &ImportLimits) -> Result<MemFs> {
    let mut zip = zip::ZipArchive::new(reader)?;
    if zip.len() > limits.max_entries {
        return Err(LibraryError::LimitExceeded(format!(
            "ZIP 有 {} 个条目，超过上限 {}",
            zip.len(),
            limits.max_entries
        )));
    }
    let mut files = BTreeMap::new();
    let mut total = 0u64;
    for i in 0..zip.len() {
        let mut f = zip.by_index(i)?;
        let raw_name = f.name()?.to_string();
        if f.is_symlink() {
            return Err(LibraryError::Unsafe(format!(
                "ZIP 条目 `{raw_name}` 是符号链接"
            )));
        }
        if f.is_dir() {
            continue;
        }
        let norm = up_format::path::normalize(&raw_name)
            .map_err(|e| LibraryError::Unsafe(format!("ZIP 条目：{e}")))?;
        if f.enclosed_name().is_none() {
            return Err(LibraryError::Unsafe(format!(
                "ZIP 条目 `{raw_name}` 路径不安全"
            )));
        }
        if norm.split('/').any(|c| c == "__MACOSX") || crate::fsutil::is_junk(&norm) {
            continue;
        }
        let declared = f.size();
        if declared > limits.max_entry_bytes {
            return Err(LibraryError::LimitExceeded(format!(
                "`{norm}` 声明 {declared} 字节，超过单文件上限 {}",
                limits.max_entry_bytes
            )));
        }
        let compressed = f.compressed_size().max(1);
        if declared > 1024 * 1024 && declared / compressed > limits.max_compression_ratio {
            return Err(LibraryError::LimitExceeded(format!(
                "`{norm}` 压缩比 {} 超过上限 {}（疑似 zip bomb）",
                declared / compressed,
                limits.max_compression_ratio
            )));
        }
        let cap = limits
            .max_entry_bytes
            .min(limits.max_total_bytes.saturating_sub(total));
        let mut buf = Vec::with_capacity(declared.min(64 * 1024 * 1024) as usize);
        (&mut f)
            .take(cap + 1)
            .read_to_end(&mut buf)
            .map_err(|e| LibraryError::Zip(format!("解压 `{norm}`：{e}")))?;
        if buf.len() as u64 > cap {
            return Err(LibraryError::LimitExceeded(format!(
                "`{norm}` 解压后超过上限（单文件 {} / 总计 {}）",
                limits.max_entry_bytes, limits.max_total_bytes
            )));
        }
        total += buf.len() as u64;
        if files.insert(norm.clone(), buf).is_some() {
            return Err(LibraryError::Unsafe(format!("ZIP 中重复的条目 `{norm}`")));
        }
    }
    Ok(MemFs {
        name: name.to_string(),
        files,
    })
}

/// 读取磁盘上的 ZIP 文件。
pub fn read_zip_file(path: &Path, limits: &ImportLimits) -> Result<MemFs> {
    let f = std::fs::File::open(path).ctx(|| format!("打开 {}", path.display()))?;
    let name = path
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| "Imported".into());
    read_zip(std::io::BufReader::new(f), &name, limits)
}

/// 把 `(路径, 字节, 是否 STORED)` 写成 ZIP。时间戳固定为 1980-01-01，输出可复现。
pub fn write_zip<W: Write + Seek>(w: W, entries: &[(&str, &[u8], bool)]) -> Result<W> {
    let mut zw = zip::ZipWriter::new(w);
    for (path, bytes, stored) in entries {
        let method = if *stored {
            zip::CompressionMethod::Stored
        } else {
            zip::CompressionMethod::Deflated
        };
        let opts = zip::write::SimpleFileOptions::DEFAULT
            .compression_method(method)
            .large_file(bytes.len() as u64 >= u32::MAX as u64)
            .unix_permissions(0o644);
        zw.start_file(*path, opts)?;
        zw.write_all(bytes)
            .map_err(|e| LibraryError::Zip(format!("写入 `{path}`：{e}")))?;
    }
    Ok(zw.finish()?)
}

/// 写 ZIP 到内存。
pub fn zip_to_vec(entries: &[(&str, &[u8], bool)]) -> Result<Vec<u8>> {
    let cur = write_zip(std::io::Cursor::new(Vec::new()), entries)?;
    Ok(cur.into_inner())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zip_roundtrip() {
        let data = zip_to_vec(&[("mimetype", b"x", true), ("a/b.txt", b"hello", false)]).unwrap();
        let fs = read_zip(std::io::Cursor::new(data), "t", &ImportLimits::default()).unwrap();
        assert_eq!(fs.read("a/b.txt").unwrap(), b"hello");
        assert_eq!(
            fs.files(),
            vec!["a/b.txt".to_string(), "mimetype".to_string()]
        );
        assert_eq!(fs.find_ci("A/B.TXT").as_deref(), Some("a/b.txt"));
    }
}
