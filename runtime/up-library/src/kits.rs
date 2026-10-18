//! Kit：入库、列表/搜索/筛选、收藏/最近使用、加载、保存、导出。

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use up_format::dawproject::{self, KitExportOptions};
use up_format::kit::{KitDoc, KitSource, PadKind};
use up_format::manifest::{self, Manifest};
use up_format::tutorial::TutorialDoc;
use up_format::upkit::{self, BuildOptions, LoadedPackage, ReadOptions, UpkitPackage};
use up_format::{Warning, wav};

use crate::error::{IoContext, LibraryError, Result};
use crate::index::{KitQuery, KitSort, KitSummary};
use crate::{KITS_DIR, Library, fsutil, is_hash};

/// 导出格式。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportFormat {
    /// `.upkit` ZIP。
    Upkit,
    /// `.upkit` 文件夹形态。
    UpkitFolder,
    /// 独立 SFZ 文件夹（`kit.sfz` + `samples/`），loop 采样写回 `acid`/`smpl`。
    SfzFolder,
    /// `.dawproject`（project.xml + metadata.xml + 嵌入的 `.upkit` 文件夹）。
    DawProject,
}

impl ExportFormat {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_ascii_lowercase().as_str() {
            "upkit" | "zip" => Some(Self::Upkit),
            "upkit-folder" | "folder" => Some(Self::UpkitFolder),
            "sfz" | "sfz-folder" => Some(Self::SfzFolder),
            "dawproject" => Some(Self::DawProject),
            _ => None,
        }
    }
}

/// 加载选项。
#[derive(Debug, Clone, Copy)]
pub struct LoadOptions {
    /// 解码 WAV 为 f32 PCM（其它格式只给路径）。
    pub decode: bool,
    /// 记为“最近使用”。
    pub mark_used: bool,
}

impl Default for LoadOptions {
    fn default() -> Self {
        Self {
            decode: true,
            mark_used: true,
        }
    }
}

/// 一个已就绪的采样。
#[derive(Debug, Clone)]
pub struct LoadedSample {
    /// 包内路径（`KitDoc` 中 `SampleLayer::sample` 的值）。
    pub package_path: String,
    /// BLAKE3（= `SampleId`）。
    pub sample_id: String,
    /// 磁盘上的文件（内容寻址存储中的 blob；无扩展名，按内容嗅探）。
    pub file: PathBuf,
    pub media_type: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub frames: u64,
    /// 交错 f32 PCM（`LoadOptions::decode` 且为 WAV 时）。
    pub pcm: Option<wav::DecodedPcm>,
}

/// `load_kit_assets` 的结果：引擎加载 Kit 所需的一切。
#[derive(Debug, Clone)]
pub struct LoadedKit {
    pub doc: KitDoc,
    /// 同一 Kit 的 `up_model::KitDoc`（引擎/FFI 用；采样的 `SampleRef.id` = BLAKE3 = `samples` 的
    /// `sample_id`）。
    pub model: up_model::KitDoc,
    pub summary: KitSummary,
    /// 包内路径 → 采样。
    pub samples: BTreeMap<String, LoadedSample>,
    pub warnings: Vec<Warning>,
}

/// 入库选项。
#[derive(Debug, Clone, Default)]
pub(crate) struct InstallOptions {
    /// 指定 Kit ID（保存已有 Kit 时）；否则按 manifest ID 或新 ID。
    pub force_id: Option<String>,
    /// 内容完全相同的 Kit 已存在时不重复入库。
    pub dedupe: bool,
    /// manifest 没有 source 时使用的来源类别。
    pub default_source_kind: Option<String>,
}

/// 入库结果。
#[derive(Debug, Clone)]
pub(crate) struct InstallOutcome {
    pub summary: KitSummary,
    pub duplicate: bool,
    pub warnings: Vec<Warning>,
}

fn content_signature(m: &Manifest) -> String {
    let mut h = blake3::Hasher::new();
    let mut files: Vec<_> = m
        .files
        .iter()
        .filter(|f| f.path != manifest::FILE_NAME && f.path != upkit::MIMETYPE_FILE)
        .collect();
    files.sort_by(|a, b| a.path.cmp(&b.path));
    for f in files {
        h.update(f.path.as_bytes());
        h.update(&[0]);
        h.update(f.blake3.to_ascii_lowercase().as_bytes());
        h.update(&[0]);
    }
    h.finalize().to_hex().to_string()
}

fn strip_urn(id: &str) -> &str {
    id.strip_prefix("urn:uuid:").unwrap_or(id)
}

impl Library {
    fn kit_dir(&self, id: &str) -> PathBuf {
        self.root().join(KITS_DIR).join(id)
    }

    fn check_kit_id(id: &str) -> Result<()> {
        if fsutil::is_safe_id(id) {
            Ok(())
        } else {
            Err(LibraryError::InvalidInput(format!("非法 Kit ID `{id}`")))
        }
    }

    pub(crate) fn kit_manifest_bytes(&self, id: &str) -> Result<Vec<u8>> {
        Self::check_kit_id(id)?;
        let p = self.kit_dir(id).join(manifest::FILE_NAME);
        std::fs::read(&p).map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                LibraryError::not_found("kit", id)
            } else {
                LibraryError::io(format!("读取 {}", p.display()), e)
            }
        })
    }

    /// Kit 的包清单。
    pub fn kit_manifest(&self, id: &str) -> Result<Manifest> {
        Ok(Manifest::from_slice(&self.kit_manifest_bytes(id)?)?)
    }

    pub(crate) fn kit_manifest_hash(&self, id: &str) -> Result<String> {
        Ok(up_format::blake3_hex(&self.kit_manifest_bytes(id)?))
    }

    /// 把库内 Kit 组装成完整的 `.upkit` 逻辑包（含 mimetype）。
    pub fn kit_package(&self, id: &str) -> Result<UpkitPackage> {
        let mbytes = self.kit_manifest_bytes(id)?;
        let m = Manifest::from_slice(&mbytes)?;
        let mut files = BTreeMap::new();
        for f in &m.files {
            files.insert(
                f.path.clone(),
                self.read_blob(&f.blake3.to_ascii_lowercase())?,
            );
        }
        files.insert(manifest::FILE_NAME.to_string(), mbytes);
        files.insert(
            upkit::MIMETYPE_FILE.to_string(),
            up_format::UPKIT_MEDIA_TYPE.as_bytes().to_vec(),
        );
        Ok(UpkitPackage { files })
    }

    fn read_stored(&self, id: &str) -> Result<LoadedPackage> {
        let pkg = self.kit_package(id)?;
        Ok(pkg.read(&ReadOptions {
            require_manifest: true,
            ..ReadOptions::default()
        })?)
    }

    /// Kit 文档。
    pub fn kit_doc(&self, id: &str) -> Result<KitDoc> {
        let mut doc = self.read_stored(id)?.doc;
        doc.id = id.to_string();
        Ok(doc)
    }

    pub(crate) fn summarize_stored_kit(
        &self,
        id: &str,
        prev: Option<&KitSummary>,
    ) -> Result<KitSummary> {
        let loaded = self.read_stored(id)?;
        let mhash = self.kit_manifest_hash(id)?;
        Ok(summary_from(
            id,
            &loaded.doc,
            &loaded.manifest,
            &mhash,
            prev,
            None,
        ))
    }

    /// 校验并入库一个逻辑包。
    pub(crate) fn install_package(
        &self,
        pkg: &UpkitPackage,
        opts: &InstallOptions,
    ) -> Result<InstallOutcome> {
        let loaded = pkg.read(&ReadOptions::default())?;
        let mut warnings = loaded.warnings.clone();
        let mut m = loaded.manifest.clone();
        // 采样数据格式检查（WAV 必须能解析）
        for p in loaded.doc.sample_paths() {
            if up_format::path::extension_lower(&p).as_deref() == Some("wav") {
                if let Err(e) = wav::info(&pkg.files[&p]) {
                    warnings.push(Warning::new("library.bad_wav", format!("{p}: {e}")));
                }
            }
        }
        let signature = content_signature(&m);
        let now = fsutil::now_ms();
        let mut idx = self.lock();
        if opts.dedupe {
            if let Some(existing) = idx.kits.values().find(|k| k.content_blake3 == signature) {
                return Ok(InstallOutcome {
                    summary: existing.clone(),
                    duplicate: true,
                    warnings,
                });
            }
        }
        let id = match &opts.force_id {
            Some(id) => {
                Self::check_kit_id(id)?;
                id.clone()
            }
            None => {
                let cand = strip_urn(&m.id);
                if fsutil::is_safe_id(cand) && !idx.kits.contains_key(cand) {
                    cand.to_string()
                } else {
                    if idx.kits.contains_key(cand) {
                        warnings.push(Warning::new(
                            "library.kit_id_conflict",
                            format!("Kit ID {cand} 已存在且内容不同，已分配新 ID"),
                        ));
                    }
                    fsutil::new_id()
                }
            }
        };
        let prev = idx.kits.get(&id).cloned();
        // 写 blob
        for (path, bytes) in &pkg.files {
            if path == manifest::FILE_NAME || path == upkit::MIMETYPE_FILE {
                continue;
            }
            self.put_blob(bytes)?;
        }
        m.id = id.clone();
        m.updated = Some(fsutil::rfc3339(now));
        if m.created.is_none() {
            m.created = Some(fsutil::rfc3339(
                prev.as_ref().map(|p| p.created_at_ms).unwrap_or(now),
            ));
        }
        if m.source.is_none() {
            if let Some(kind) = &opts.default_source_kind {
                m.source = Some(KitSource {
                    kind: kind.clone(),
                    ..KitSource::default()
                });
            }
        }
        let mbytes = m.to_vec_pretty();
        self.put_blob(&mbytes)?;
        fsutil::atomic_write(&self.kit_dir(&id).join(manifest::FILE_NAME), &mbytes, false)?;
        let mut doc = loaded.doc;
        doc.id = id.clone();
        doc.source = m.source.clone();
        let mhash = up_format::blake3_hex(&mbytes);
        let summary = summary_from(&id, &doc, &m, &mhash, prev.as_ref(), Some(now));
        idx.kits.insert(id.clone(), summary.clone());
        idx.tombstones.remove(&id);
        self.save_index(&idx)?;
        Ok(InstallOutcome {
            summary,
            duplicate: false,
            warnings,
        })
    }

    /// 按原样安装一份已在内容寻址存储中的 Kit manifest（多设备同步落地用）：
    /// manifest 字节不做任何改写，保证各设备的内容哈希一致。
    #[cfg(feature = "hub")]
    pub(crate) fn install_stored_manifest(&self, id: &str, mbytes: &[u8]) -> Result<KitSummary> {
        Self::check_kit_id(id)?;
        let m = Manifest::from_slice(mbytes)?;
        let mut files = BTreeMap::new();
        for f in &m.files {
            files.insert(
                f.path.clone(),
                self.read_blob(&f.blake3.to_ascii_lowercase())?,
            );
        }
        files.insert(manifest::FILE_NAME.to_string(), mbytes.to_vec());
        let loaded = UpkitPackage { files }.read(&ReadOptions {
            require_manifest: true,
            ..ReadOptions::default()
        })?;
        self.put_blob(mbytes)?;
        fsutil::atomic_write(&self.kit_dir(id).join(manifest::FILE_NAME), mbytes, false)?;
        let mut doc = loaded.doc;
        doc.id = id.to_string();
        let mhash = up_format::blake3_hex(mbytes);
        self.update_index(|idx| {
            let prev = idx.kits.get(id).cloned();
            let s = summary_from(id, &doc, &m, &mhash, prev.as_ref(), None);
            idx.kits.insert(id.to_string(), s.clone());
            idx.tombstones.remove(id);
            Ok(s)
        })
    }

    // ------------------------------------------------------------------
    // 列表 / 搜索 / 收藏 / 最近使用
    // ------------------------------------------------------------------

    /// 列出 Kit（搜索、曲风筛选、收藏、最近使用、排序）。
    pub fn list_kits(&self, q: &KitQuery) -> Vec<KitSummary> {
        let idx = self.lock();
        let mut v: Vec<KitSummary> = idx
            .kits
            .values()
            .filter(|k| k.matches(q))
            .cloned()
            .collect();
        match q.sort {
            KitSort::Name => v.sort_by(|a, b| {
                a.name
                    .to_lowercase()
                    .cmp(&b.name.to_lowercase())
                    .then(a.id.cmp(&b.id))
            }),
            KitSort::RecentlyUsed => v.sort_by(|a, b| {
                b.last_used_at_ms
                    .cmp(&a.last_used_at_ms)
                    .then(a.id.cmp(&b.id))
            }),
            KitSort::RecentlyAdded => {
                v.sort_by(|a, b| b.created_at_ms.cmp(&a.created_at_ms).then(a.id.cmp(&b.id)))
            }
            KitSort::Favorited => v.sort_by(|a, b| {
                b.favorited_at_ms
                    .cmp(&a.favorited_at_ms)
                    .then(a.id.cmp(&b.id))
            }),
        }
        if let Some(n) = q.limit {
            v.truncate(n);
        }
        v
    }

    pub fn kit_summary(&self, id: &str) -> Result<KitSummary> {
        self.lock()
            .kits
            .get(id)
            .cloned()
            .ok_or_else(|| LibraryError::not_found("kit", id))
    }

    /// 所有曲风及其 Kit 数量（按名称排序）。
    pub fn genres(&self) -> Vec<(String, usize)> {
        let mut m: BTreeMap<String, (String, usize)> = BTreeMap::new();
        for k in self.lock().kits.values() {
            for g in &k.genres {
                let e = m.entry(g.to_lowercase()).or_insert_with(|| (g.clone(), 0));
                e.1 += 1;
            }
        }
        m.into_values().collect()
    }

    /// 最近使用的 Kit。
    pub fn recent_kits(&self, limit: usize) -> Vec<KitSummary> {
        self.list_kits(&KitQuery {
            used_only: true,
            sort: KitSort::RecentlyUsed,
            limit: Some(limit),
            ..KitQuery::default()
        })
    }

    pub fn set_favorite(&self, id: &str, favorite: bool) -> Result<KitSummary> {
        self.update_index(|idx| {
            let k = idx
                .kits
                .get_mut(id)
                .ok_or_else(|| LibraryError::not_found("kit", id))?;
            if k.favorite != favorite {
                k.favorite = favorite;
                k.favorited_at_ms = favorite.then(fsutil::now_ms);
            }
            Ok(k.clone())
        })
    }

    pub fn mark_used(&self, id: &str) -> Result<()> {
        self.update_index(|idx| {
            let k = idx
                .kits
                .get_mut(id)
                .ok_or_else(|| LibraryError::not_found("kit", id))?;
            k.last_used_at_ms = Some(fsutil::now_ms().max(k.last_used_at_ms.unwrap_or(0) + 1));
            Ok(())
        })
    }

    /// 删除 Kit（blob 由 [`Library::gc_blobs`] 回收）。
    pub fn delete_kit(&self, id: &str) -> Result<()> {
        Self::check_kit_id(id)?;
        self.update_index(|idx| {
            if idx.kits.remove(id).is_none() {
                return Err(LibraryError::not_found("kit", id));
            }
            idx.tombstones.insert(id.to_string(), fsutil::now_ms());
            for e in idx.catalog.entries.values_mut() {
                if matches!(&e.status, crate::CatalogStatus::Downloaded { kit_id } if kit_id == id)
                {
                    e.status = crate::CatalogStatus::NotDownloaded;
                }
            }
            Ok(())
        })?;
        let dir = self.kit_dir(id);
        if dir.exists() {
            std::fs::remove_dir_all(&dir).ctx(|| format!("删除 {}", dir.display()))?;
        }
        Ok(())
    }

    /// Kit 的教程（`tutorial.json` + 可选 `chart.mid`），按 KitDoc 中的顺序。
    pub fn kit_tutorials(
        &self,
        id: &str,
    ) -> Result<Vec<(TutorialDoc, Option<up_format::smf::Chart>)>> {
        let pkg = self.kit_package(id)?;
        let doc = self.kit_doc(id)?;
        Ok(tutorials_of(&doc, &pkg))
    }

    /// 引擎/FFI 使用的 `up_model::KitDoc`（含合成后的教程谱）。
    pub fn kit_model(&self, id: &str) -> Result<up_model::KitDoc> {
        let pkg = self.kit_package(id)?;
        let doc = self.kit_doc(id)?;
        let chart = up_format::model::tutorial_chart(&doc, &tutorials_of(&doc, &pkg));
        Ok(up_format::model::to_model(&doc, chart))
    }

    /// 保存 UI 编辑后的 `up_model::KitDoc`：合并到原 Kit（保留模型表达不了的力度层/轮替/教程等），
    /// 新 ID 则新建。新分配的采样用 `SampleRef.blake3`（或 `id`）引用曲库中的样本。
    pub fn save_kit_model(&self, model: &up_model::KitDoc) -> Result<KitSummary> {
        let id = model.id.as_str();
        let mut base = if fsutil::is_safe_id(id) && self.lock().kits.contains_key(id) {
            self.kit_doc(id)?
        } else {
            KitDoc::new(id, model.name.clone())
        };
        up_format::model::apply_model(&mut base, model);
        self.save_kit(&base)
    }

    // ------------------------------------------------------------------
    // 加载
    // ------------------------------------------------------------------

    /// 加载 Kit 的全部资源（文档 + 采样路径 + 解码后的 PCM），并记为最近使用。
    pub fn load_kit_assets(&self, id: &str) -> Result<LoadedKit> {
        self.load_kit_assets_with(id, &LoadOptions::default())
    }

    pub fn load_kit_assets_with(&self, id: &str, opts: &LoadOptions) -> Result<LoadedKit> {
        let pkg = self.kit_package(id)?;
        let loaded = pkg.read(&ReadOptions {
            require_manifest: true,
            ..ReadOptions::default()
        })?;
        let mut warnings = loaded.warnings;
        let mut doc = loaded.doc;
        doc.id = id.to_string();
        let mut samples = BTreeMap::new();
        for path in doc.sample_paths() {
            let entry = loaded
                .manifest
                .find(&path)
                .ok_or_else(|| up_format::FormatError::MissingFile(path.clone()))?;
            let hash = entry.blake3.to_ascii_lowercase();
            let bytes = &pkg.files[&path];
            let (mut sr, mut ch, mut frames, mut pcm) = (0, 0, 0, None);
            match wav::info(bytes) {
                Ok(info) => {
                    sr = info.sample_rate;
                    ch = info.channels;
                    frames = info.frames;
                    if opts.decode {
                        pcm = Some(wav::decode(bytes)?);
                    }
                }
                Err(_) => {
                    let ext = up_format::path::extension_lower(&path).unwrap_or_default();
                    match up_codec::decode_bytes(bytes.clone(), Some(&ext)) {
                        Ok(buf) => {
                            sr = buf.sample_rate;
                            ch = buf.channels;
                            frames = (buf.data.len() / usize::from(buf.channels.max(1))) as u64;
                            if opts.decode {
                                pcm = Some(wav::DecodedPcm {
                                    channels: buf.channels,
                                    sample_rate: buf.sample_rate,
                                    samples: buf.data,
                                });
                            }
                        }
                        Err(e) => warnings.push(Warning::new(
                            "library.undecodable",
                            format!("{path}：{e}（只提供文件路径）"),
                        )),
                    }
                }
            }
            samples.insert(
                path.clone(),
                LoadedSample {
                    package_path: path.clone(),
                    file: self.cas_path(&hash),
                    sample_id: hash,
                    media_type: entry.media_type.clone(),
                    sample_rate: sr,
                    channels: ch,
                    frames,
                    pcm,
                },
            );
        }
        if opts.mark_used {
            self.mark_used(id)?;
        }
        let chart = up_format::model::tutorial_chart(&doc, &tutorials_of(&doc, &pkg));
        let mut model = up_format::model::to_model(&doc, chart);
        for p in &mut model.pads {
            if let Some(s) = p.sample.as_mut() {
                if let Some(ls) = s.path.as_ref().and_then(|path| samples.get(path)) {
                    let ls: &LoadedSample = ls;
                    s.sample_rate = Some(ls.sample_rate);
                    s.channels = Some(ls.channels);
                    s.frames = Some(ls.frames);
                }
            }
        }
        Ok(LoadedKit {
            model,
            doc,
            summary: self.kit_summary(id)?,
            samples,
            warnings,
        })
    }

    // ------------------------------------------------------------------
    // 保存
    // ------------------------------------------------------------------

    /// 保存编辑后的 Kit。`doc.id` 为已有 Kit 时覆盖保存（保留收藏/最近使用），否则新建。
    ///
    /// 采样层的来源：`sample_id` 有值时从内容寻址存储取（例如刚录的麦克风样本）；
    /// 否则按 `sample` 路径从原 Kit 的 manifest 中找。原包中的教程/封面/皮肤等非采样文件会被保留。
    pub fn save_kit(&self, doc: &KitDoc) -> Result<KitSummary> {
        let mut doc = doc.clone();
        let existing = fsutil::is_safe_id(&doc.id) && self.lock().kits.contains_key(&doc.id);
        if !existing {
            doc.id = if fsutil::is_safe_id(&doc.id) && !self.kit_dir(&doc.id).exists() {
                doc.id.clone()
            } else {
                fsutil::new_id()
            };
        }
        let old = if existing {
            Some(self.kit_manifest(&doc.id)?)
        } else {
            None
        };
        let mut assets: BTreeMap<String, Vec<u8>> = BTreeMap::new();
        let mut taken: BTreeSet<String> = BTreeSet::new();
        // 保留非采样文件
        if let Some(m) = &old {
            let sample_paths: BTreeSet<String> = m
                .files
                .iter()
                .filter(|f| f.media_type.starts_with("audio/") && f.path.starts_with("samples/"))
                .map(|f| f.path.clone())
                .collect();
            for f in &m.files {
                let reserved = [
                    upkit::SFZ_FILE,
                    up_format::kit_json::FILE_NAME,
                    manifest::FILE_NAME,
                    upkit::MIMETYPE_FILE,
                ];
                if reserved.contains(&f.path.as_str()) || sample_paths.contains(&f.path) {
                    continue;
                }
                assets.insert(
                    f.path.clone(),
                    self.read_blob(&f.blake3.to_ascii_lowercase())?,
                );
                taken.insert(f.path.clone());
            }
        }
        let mut by_hash: BTreeMap<String, String> = BTreeMap::new();
        for pad in &mut doc.pads {
            for layer in &mut pad.layers {
                let hash = match &layer.sample_id {
                    Some(h) if is_hash(h) => h.to_ascii_lowercase(),
                    Some(h) => {
                        return Err(LibraryError::InvalidInput(format!("非法 sampleId `{h}`")));
                    }
                    None => old
                        .as_ref()
                        .and_then(|m| m.find(&layer.sample))
                        .map(|f| f.blake3.to_ascii_lowercase())
                        .ok_or_else(|| {
                            LibraryError::InvalidInput(format!(
                                "采样 `{}` 既没有 sampleId，也不在原 Kit 中",
                                layer.sample
                            ))
                        })?,
                };
                if let Some(p) = by_hash.get(&hash) {
                    layer.sample = p.clone();
                } else {
                    let bytes = self.read_blob(&hash)?;
                    let wanted = up_format::path::normalize(&layer.sample).ok();
                    let path = match wanted {
                        Some(p) if !taken.contains(&p) => {
                            taken.insert(p.clone());
                            p
                        }
                        _ => upkit::unique_sample_path(&layer.sample, &mut taken),
                    };
                    layer.sample = path.clone();
                    by_hash.insert(hash.clone(), path.clone());
                    assets.insert(path, bytes);
                }
                layer.sample_id = Some(hash);
            }
        }
        let now = fsutil::now_ms();
        let pkg = UpkitPackage::build(
            &doc,
            assets,
            &BuildOptions {
                created: old.as_ref().and_then(|m| m.created.clone()),
                updated: Some(fsutil::rfc3339(now)),
                generator: None,
            },
        )?;
        let out = self.install_package(
            &pkg,
            &InstallOptions {
                force_id: Some(doc.id.clone()),
                dedupe: false,
                default_source_kind: Some("user".into()),
            },
        )?;
        Ok(out.summary)
    }

    // ------------------------------------------------------------------
    // 导出
    // ------------------------------------------------------------------

    /// 导出 Kit。`dest` 为目标文件（Upkit/DawProject）或目标文件夹（UpkitFolder/SfzFolder，
    /// 必须不存在或为空）。返回写出的路径。
    pub fn export_kit(&self, id: &str, dest: &Path, format: ExportFormat) -> Result<PathBuf> {
        let pkg = self.kit_package(id)?;
        match format {
            ExportFormat::Upkit => {
                let bytes = crate::archive::zip_to_vec(&pkg.zip_entries())?;
                fsutil::atomic_write(dest, &bytes, false)?;
            }
            ExportFormat::UpkitFolder => {
                write_folder(
                    dest,
                    pkg.files.iter().map(|(p, b)| (p.as_str(), b.as_slice())),
                )?;
            }
            ExportFormat::SfzFolder => {
                let loaded = pkg.read(&ReadOptions::default())?;
                let doc = &loaded.doc;
                let mut files: BTreeMap<String, Vec<u8>> = BTreeMap::new();
                files.insert(upkit::SFZ_FILE.into(), pkg.files[upkit::SFZ_FILE].clone());
                for pad in &doc.pads {
                    for l in &pad.layers {
                        let mut bytes = pkg.files[&l.sample].clone();
                        if pad.kind == PadKind::Loop {
                            bytes = with_loop_metadata(&bytes, pad, l).unwrap_or(bytes);
                        }
                        files.insert(l.sample.clone(), bytes);
                    }
                }
                if let Some(lic) = pkg.files.get("LICENSE.txt") {
                    files.insert("LICENSE.txt".into(), lic.clone());
                }
                write_folder(dest, files.iter().map(|(p, b)| (p.as_str(), b.as_slice())))?;
            }
            ExportFormat::DawProject => {
                let doc = pkg.read(&ReadOptions::default())?.doc;
                let slug = up_format::path::slug(&doc.name);
                let kit_dir = format!("kits/{slug}.upkit");
                let xml = dawproject::export_kit_project(
                    &doc,
                    &KitExportOptions {
                        kit_state_path: kit_dir.clone(),
                        ..KitExportOptions::default()
                    },
                )?;
                let mut entries: Vec<(String, Vec<u8>, bool)> = vec![
                    ("project.xml".into(), xml.project_xml.into_bytes(), false),
                    ("metadata.xml".into(), xml.metadata_xml.into_bytes(), false),
                ];
                for (p, b, stored) in pkg.zip_entries() {
                    entries.push((format!("{kit_dir}/{p}"), b.to_vec(), stored));
                }
                let refs: Vec<(&str, &[u8], bool)> = entries
                    .iter()
                    .map(|(p, b, s)| (p.as_str(), b.as_slice(), *s))
                    .collect();
                let bytes = crate::archive::zip_to_vec(&refs)?;
                fsutil::atomic_write(dest, &bytes, false)?;
            }
        }
        Ok(dest.to_path_buf())
    }
}

/// 把 BPM/拍数/根音/loop 点写回 WAV 的 `acid` + `smpl`（规格 §4 落地规则）。
fn with_loop_metadata(
    bytes: &[u8],
    pad: &up_format::kit::PadDoc,
    layer: &up_format::kit::SampleLayer,
) -> Option<Vec<u8>> {
    let info = wav::info(bytes).ok()?;
    let mut meta = wav::read_metadata(bytes).ok()?;
    let root = layer.root_key.unwrap_or(60);
    if let Some(t) = pad.tempo {
        let beats = t
            .beats
            .unwrap_or_else(|| wav::beats_for(info.duration_secs(), t.bpm));
        meta.acid = Some(wav::AcidChunk::looped(
            t.bpm as f32,
            beats.round() as u32,
            root,
            t.time_signature,
        ));
    }
    let mut smpl = meta
        .smpl
        .take()
        .unwrap_or_else(|| wav::SmplChunk::new(info.sample_rate, root));
    if smpl.loops.is_empty() && info.frames > 0 {
        let start = layer.loop_start.unwrap_or(0) as u32;
        let end = layer.loop_end.unwrap_or(info.frames - 1) as u32;
        smpl.loops.push(wav::SampleLoop {
            cue_id: 0,
            kind: wav::LoopType::Forward,
            start,
            end,
            fraction: 0,
            play_count: 0,
        });
    }
    meta.smpl = Some(smpl);
    wav::write_metadata(bytes, &meta).ok()
}

fn write_folder<'a>(dest: &Path, files: impl Iterator<Item = (&'a str, &'a [u8])>) -> Result<()> {
    if dest.exists() {
        let empty = std::fs::read_dir(dest)
            .ctx(|| format!("读取 {}", dest.display()))?
            .next()
            .is_none();
        if !empty {
            return Err(LibraryError::InvalidInput(format!(
                "导出目录 {} 已存在且非空",
                dest.display()
            )));
        }
    }
    for (p, b) in files {
        let rel = up_format::path::normalize(p)?;
        fsutil::atomic_write(&fsutil::join_rel(dest, &rel), b, false)?;
    }
    Ok(())
}

pub(crate) fn summary_from(
    id: &str,
    doc: &KitDoc,
    m: &Manifest,
    manifest_hash: &str,
    prev: Option<&KitSummary>,
    now: Option<i64>,
) -> KitSummary {
    let now = now.unwrap_or_else(fsutil::now_ms);
    let sample_paths = doc.sample_paths();
    let bpm = doc
        .tempo
        .map(|t| t.bpm)
        .or_else(|| doc.pads.iter().find_map(|p| p.tempo.map(|t| t.bpm)));
    let source = m.source.clone().or_else(|| doc.source.clone());
    KitSummary {
        id: id.to_string(),
        name: m.name.clone(),
        description: m.description.clone(),
        authors: m.authors.clone(),
        license: m.license.clone(),
        genres: m.genres.clone(),
        tags: m.tags.clone(),
        pad_count: doc.pad_count,
        pads_used: doc.pads.iter().filter(|p| !p.layers.is_empty()).count() as u8,
        sample_count: sample_paths.len() as u32,
        total_bytes: m.files.iter().map(|f| f.size).sum(),
        bpm,
        theme_color: doc.theme_color.clone(),
        cover_blob: doc
            .cover
            .as_ref()
            .and_then(|c| m.find(c))
            .map(|f| f.blake3.to_ascii_lowercase()),
        has_tutorial: !doc.tutorials.is_empty(),
        source_kind: source
            .as_ref()
            .map(|s| s.kind.clone())
            .unwrap_or_else(|| "upkit".into()),
        source_id: source.as_ref().and_then(|s| s.original_id.clone()),
        inspired_by: source.as_ref().and_then(|s| s.inspired_by.clone()),
        favorite: prev.is_some_and(|p| p.favorite),
        favorited_at_ms: prev.and_then(|p| p.favorited_at_ms),
        last_used_at_ms: prev.and_then(|p| p.last_used_at_ms),
        created_at_ms: prev.map(|p| p.created_at_ms).unwrap_or(now),
        updated_at_ms: now,
        manifest_blake3: manifest_hash.to_string(),
        content_blake3: content_signature(m),
    }
}

fn tutorials_of(
    doc: &KitDoc,
    pkg: &UpkitPackage,
) -> Vec<(TutorialDoc, Option<up_format::smf::Chart>)> {
    let mut out = Vec::new();
    for t in &doc.tutorials {
        let Some(bytes) = pkg.files.get(&t.path) else {
            continue;
        };
        let Ok(td) = TutorialDoc::from_slice(bytes) else {
            continue;
        };
        let dir = t.path.rfind('/').map(|i| &t.path[..i]).unwrap_or("");
        let chart = td
            .chart
            .as_ref()
            .and_then(|c| up_format::path::join(dir, c).ok())
            .and_then(|p| pkg.files.get(&p))
            .and_then(|b| up_format::smf::Chart::from_smf(b).ok());
        out.push((td, chart));
    }
    out
}

impl KitSummary {
    /// 转成引擎协议的 `KitSummary`（FFI 用）。
    pub fn to_protocol(&self) -> up_protocol::KitSummary {
        up_protocol::KitSummary {
            id: up_core::KitId::new(self.id.clone()),
            name: self.name.clone(),
            pad_count: u32::from(self.pads_used),
            bpm: self.bpm,
            has_tutorial: self.has_tutorial,
        }
    }
}
