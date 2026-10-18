//! 导入器：`.upkit`（ZIP/文件夹）、SFZ（含相对路径采样）、WAV 文件夹、原 App 素材（可插拔多来源）、单个 WAV。
//!
//! 入口 [`Library::import`] 自动识别输入类型。识别顺序（文件夹/ZIP）：
//! 1. 原 App 素材（[`compat::CompatSource`] 逐个探测）
//! 2. `.upkit`（根目录或唯一顶层子目录中有 `manifest.json` / `ultrapads-kit.json` / `kit.sfz`）
//! 3. SFZ（每个 `.sfz` 导入为一个 Kit）
//! 4. WAV 文件夹

pub mod compat;
mod sfz;
mod wavdir;

use std::collections::BTreeMap;
use std::path::Path;

use serde::{Deserialize, Serialize};
use up_format::upkit::UpkitPackage;
use up_format::{Warning, kit_json, manifest};

use crate::archive::{DirFs, MemFs, SourceFs, read_zip_file};
use crate::error::{LibraryError, Result};
use crate::index::SampleOrigin;
use crate::kits::InstallOptions;
use crate::{Library, fsutil};

/// 识别出的导入类型。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ImportKind {
    Upkit,
    Sfz,
    WavFolder,
    /// 原 App 素材；值为来源 ID（如 `compat-android`）。
    Compat(String),
    Sample,
}

/// 一个导入的 Kit。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportedKit {
    pub kit_id: String,
    pub name: String,
    pub pad_count: u8,
    pub pads_used: u8,
    /// 内容相同的 Kit 已在库中，未重复入库。
    pub duplicate: bool,
}

/// 导入报告（FFI 的 `ImportReport`）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportReport {
    pub kind: ImportKind,
    pub kits: Vec<ImportedKit>,
    /// 新入库的独立样本 ID。
    pub samples: Vec<String>,
    /// 合并进曲库目录的外部目录条目数（原 App list.json）。
    pub catalog_entries: usize,
    pub warnings: Vec<Warning>,
}

impl ImportReport {
    fn new(kind: ImportKind) -> Self {
        Self {
            kind,
            kits: Vec::new(),
            samples: Vec::new(),
            catalog_entries: 0,
            warnings: Vec::new(),
        }
    }
}

fn is_upkit_root(fs: &dyn SourceFs, prefix: &str) -> bool {
    [
        manifest::FILE_NAME,
        kit_json::FILE_NAME,
        up_format::upkit::SFZ_FILE,
    ]
    .iter()
    .any(|f| fs.exists(&format!("{prefix}{f}")))
}

/// 若所有文件都在唯一的顶层目录下，返回 `"<dir>/"`。
fn single_top_dir(files: &[String]) -> Option<String> {
    let first = files.first()?;
    let (top, _) = first.split_once('/')?;
    files
        .iter()
        .all(|f| f.starts_with(&format!("{top}/")))
        .then(|| format!("{top}/"))
}

/// 读取 `prefix` 下的所有文件为 `.upkit` 逻辑包（去掉前缀）。
fn upkit_from_fs(fs: &dyn SourceFs, prefix: &str) -> Result<UpkitPackage> {
    let mut files = Vec::new();
    for f in fs.files() {
        if let Some(rel) = f.strip_prefix(prefix) {
            if fsutil::is_junk(rel) {
                continue;
            }
            files.push((rel.to_string(), fs.read(&f)?));
        }
    }
    Ok(UpkitPackage::from_files(files)?)
}

impl Library {
    /// 导入文件或文件夹，自动识别类型。
    pub fn import(&self, path: impl AsRef<Path>) -> Result<ImportReport> {
        let path = path.as_ref();
        let meta = std::fs::symlink_metadata(path)
            .map_err(|e| LibraryError::io(format!("读取 {}", path.display()), e))?;
        if meta.file_type().is_symlink() {
            return Err(LibraryError::Unsafe(format!(
                "{} 是符号链接",
                path.display()
            )));
        }
        if meta.is_dir() {
            let fs = DirFs::open(path, self.limits())?;
            return self.import_fs(&fs, false);
        }
        let ext = up_format::path::extension_lower(&path.to_string_lossy()).unwrap_or_default();
        match ext.as_str() {
            "upkit" | "zip" => {
                let fs = read_zip_file(path, &self.limits())?;
                self.import_fs(&fs, ext == "upkit")
            }
            "sfz" => {
                let dir = path.parent().unwrap_or_else(|| Path::new("."));
                let fs = DirFs::open(dir, self.limits())?;
                let name = path
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_default();
                let mut report = ImportReport::new(ImportKind::Sfz);
                self.import_sfz(&fs, &name, &mut report)?;
                Ok(report)
            }
            "wav" | "wave" => {
                let rec = self.add_sample_file(path, SampleOrigin::Import)?;
                let mut report = ImportReport::new(ImportKind::Sample);
                report.samples.push(rec.id);
                Ok(report)
            }
            other => Err(LibraryError::UnsupportedSource(format!(
                "不支持的文件类型 `.{other}`（支持 .upkit/.zip/.sfz/.wav 和文件夹）"
            ))),
        }
    }

    /// 从内存中的 `.upkit`/ZIP 字节导入（例如下载结果）。
    pub fn import_zip_bytes(&self, name: &str, bytes: &[u8]) -> Result<ImportReport> {
        let fs = crate::archive::read_zip(std::io::Cursor::new(bytes), name, &self.limits())?;
        self.import_fs(&fs, name.to_ascii_lowercase().ends_with(".upkit"))
    }

    /// 从任意文件源导入。
    pub fn import_fs(&self, fs: &dyn SourceFs, force_upkit: bool) -> Result<ImportReport> {
        let files = fs.files();
        if !force_upkit {
            for src in &self.compat {
                if src.detect(fs) {
                    return self.import_compat(src.as_ref(), fs);
                }
            }
        }
        let prefix = if is_upkit_root(fs, "") {
            Some(String::new())
        } else {
            single_top_dir(&files).filter(|p| is_upkit_root(fs, p))
        };
        if let Some(prefix) = prefix {
            let mut report = ImportReport::new(ImportKind::Upkit);
            let pkg = upkit_from_fs(fs, &prefix)?;
            let out = self.install_package(
                &pkg,
                &InstallOptions {
                    dedupe: true,
                    default_source_kind: Some("upkit".into()),
                    ..InstallOptions::default()
                },
            )?;
            report.warnings.extend(out.warnings);
            report.kits.push(imported(&out.summary, out.duplicate));
            return Ok(report);
        }
        if force_upkit {
            return Err(LibraryError::UnsupportedSource(
                ".upkit 中没有 manifest.json / ultrapads-kit.json / kit.sfz".into(),
            ));
        }
        let sfz_files: Vec<&String> = files
            .iter()
            .filter(|f| f.to_ascii_lowercase().ends_with(".sfz"))
            .collect();
        if !sfz_files.is_empty() {
            let mut report = ImportReport::new(ImportKind::Sfz);
            for f in sfz_files {
                if let Err(e) = self.import_sfz(fs, f, &mut report) {
                    report
                        .warnings
                        .push(Warning::new("import.sfz_failed", format!("{f}：{e}")));
                }
            }
            if report.kits.is_empty() {
                return Err(LibraryError::UnsupportedSource(
                    "所有 SFZ 都导入失败".into(),
                ));
            }
            return Ok(report);
        }
        let has_wav = files.iter().any(|f| wavdir::is_audio(f));
        if has_wav {
            let mut report = ImportReport::new(ImportKind::WavFolder);
            self.import_wav_folder(fs, &mut report)?;
            return Ok(report);
        }
        Err(LibraryError::UnsupportedSource(format!(
            "{} 中没有可识别的 Kit（.upkit、SFZ、WAV 或原 App 素材）",
            fs.display_name()
        )))
    }

    fn import_compat(
        &self,
        src: &dyn compat::CompatSource,
        fs: &dyn SourceFs,
    ) -> Result<ImportReport> {
        let mut report = ImportReport::new(ImportKind::Compat(src.id().to_string()));
        let mut linked: BTreeMap<String, String> = BTreeMap::new();
        let limits = self.limits();
        let scan = src.import(fs, &limits, &mut |kit: compat::CompatKit| {
            let pkg = UpkitPackage::build(
                &kit.doc,
                kit.assets,
                // 不写导入时间：同一来源在不同设备上导入的包逐字节一致（多设备同步不冲突）。
                &up_format::upkit::BuildOptions::default(),
            )?;
            let out = self.install_package(
                &pkg,
                &InstallOptions {
                    dedupe: true,
                    default_source_kind: Some(src.id().to_string()),
                    ..InstallOptions::default()
                },
            )?;
            if let Some(cid) = kit.catalog_id {
                linked.insert(cid, out.summary.id.clone());
            }
            report.warnings.extend(out.warnings);
            report.kits.push(imported(&out.summary, out.duplicate));
            Ok(())
        })?;
        report.warnings.extend(scan.warnings);
        if let Some(catalog) = scan.catalog {
            report.catalog_entries = catalog.entries.len();
            self.merge_catalog(src.id(), catalog, &linked)?;
        } else if !linked.is_empty() {
            self.merge_catalog(src.id(), Default::default(), &linked)?;
        }
        if report.kits.is_empty() && report.catalog_entries == 0 {
            return Err(LibraryError::UnsupportedSource(format!(
                "{}：没有找到 Kit 或目录",
                src.id()
            )));
        }
        Ok(report)
    }

    /// 合并外部目录：替换该来源的条目与分类，保留已下载状态；`linked` 为本次导入的 目录 ID → Kit ID。
    fn merge_catalog(
        &self,
        source: &str,
        incoming: crate::index::Catalog,
        linked: &BTreeMap<String, String>,
    ) -> Result<()> {
        use crate::index::CatalogStatus;
        self.update_index(|idx| {
            let has_new = !incoming.entries.is_empty();
            if has_new {
                let old: BTreeMap<String, CatalogStatus> = idx
                    .catalog
                    .entries
                    .iter()
                    .filter(|(_, e)| e.source == source)
                    .map(|(k, e)| (k.clone(), e.status.clone()))
                    .collect();
                idx.catalog.entries.retain(|_, e| e.source != source);
                idx.catalog.categories.retain(|_, c| c.source != source);
                for (id, mut e) in incoming.entries {
                    if let Some(s) = old.get(&id) {
                        e.status = s.clone();
                    }
                    idx.catalog.entries.insert(id, e);
                }
                idx.catalog.categories.extend(incoming.categories);
            }
            for (cid, kit_id) in linked {
                if let Some(e) = idx.catalog.entries.get_mut(cid) {
                    e.status = CatalogStatus::Downloaded {
                        kit_id: kit_id.clone(),
                    };
                }
            }
            // 已删除的 Kit 回到“未下载”
            let kits: Vec<String> = idx.kits.keys().cloned().collect();
            for e in idx.catalog.entries.values_mut() {
                if let CatalogStatus::Downloaded { kit_id } = &e.status {
                    if !kits.contains(kit_id) {
                        e.status = CatalogStatus::NotDownloaded;
                    }
                }
            }
            Ok(())
        })
    }

    /// 外部目录条目（可按来源过滤），按 `order` 排序。
    pub fn catalog_entries(&self, source: Option<&str>) -> Vec<crate::CatalogEntry> {
        let mut v: Vec<_> = self
            .lock()
            .catalog
            .entries
            .values()
            .filter(|e| source.is_none_or(|s| e.source == s))
            .cloned()
            .collect();
        v.sort_by(|a, b| a.order.cmp(&b.order).then(a.name.cmp(&b.name)));
        v
    }

    /// 外部目录分类。
    pub fn catalog_categories(&self, source: Option<&str>) -> Vec<crate::CatalogCategory> {
        let mut v: Vec<_> = self
            .lock()
            .catalog
            .categories
            .values()
            .filter(|c| source.is_none_or(|s| c.source == s))
            .cloned()
            .collect();
        v.sort_by(|a, b| a.order.cmp(&b.order).then(a.name.cmp(&b.name)));
        v
    }
}

pub(crate) fn imported(s: &crate::KitSummary, duplicate: bool) -> ImportedKit {
    ImportedKit {
        kit_id: s.id.clone(),
        name: s.name.clone(),
        pad_count: s.pad_count,
        pads_used: s.pads_used,
        duplicate,
    }
}

/// 供测试/工具使用：把 `(路径, 字节)` 列表包装成内存文件源。
pub fn mem_fs(name: &str, files: impl IntoIterator<Item = (String, Vec<u8>)>) -> MemFs {
    MemFs {
        name: name.to_string(),
        files: files.into_iter().collect(),
    }
}
