//! SFZ 导入：`#include` 从同一文件源解析，采样按相对路径（大小写不敏感）查找后复制进包。

use std::collections::{BTreeMap, BTreeSet};

use up_format::Warning;
use up_format::kit::KitSource;
use up_format::sfz::{self, ParseOptions};
use up_format::upkit::{self, BuildOptions, ReadOptions, UpkitPackage};

use super::{ImportReport, imported};
use crate::archive::SourceFs;
use crate::error::{LibraryError, Result};
use crate::kits::InstallOptions;
use crate::{Library, fsutil};

fn parent(path: &str) -> &str {
    path.rfind('/').map(|i| &path[..i]).unwrap_or("")
}

impl Library {
    pub(crate) fn import_sfz(
        &self,
        fs: &dyn SourceFs,
        sfz_path: &str,
        report: &mut ImportReport,
    ) -> Result<()> {
        let bytes = fs.read(sfz_path)?;
        let text = String::from_utf8_lossy(&bytes).into_owned();
        let base = parent(sfz_path).to_string();
        let mut resolver = |p: &str| -> std::result::Result<String, String> {
            let rel = up_format::path::join(&base, p).map_err(|e| e.to_string())?;
            let found = fs.find_ci(&rel).ok_or_else(|| format!("找不到 {rel}"))?;
            fs.read(&found)
                .map(|b| String::from_utf8_lossy(&b).into_owned())
                .map_err(|e| e.to_string())
        };
        let parsed = sfz::parse_with(&text, &mut resolver, &ParseOptions::default())?;
        let name = up_format::path::file_stem(sfz_path).to_string();
        let (mut doc, w) = upkit::kit_from_parts(
            None,
            &parsed.file,
            None,
            &base,
            &ReadOptions {
                fallback_name: name.clone(),
                fallback_id: fsutil::new_id(),
                ..ReadOptions::default()
            },
        );
        let mut warnings: Vec<Warning> = parsed.warnings;
        warnings.extend(w);
        let mut assets: BTreeMap<String, Vec<u8>> = BTreeMap::new();
        let mut mapped: BTreeMap<String, Option<String>> = BTreeMap::new();
        let mut taken = BTreeSet::new();
        for pad in &mut doc.pads {
            let mut keep = Vec::new();
            for mut layer in std::mem::take(&mut pad.layers) {
                let target = match mapped.get(&layer.sample) {
                    Some(t) => t.clone(),
                    None => {
                        let t = match fs.find_ci(&layer.sample) {
                            Some(found) => {
                                let ext =
                                    up_format::path::extension_lower(&found).unwrap_or_default();
                                match crate::transcode::ensure_wav(
                                    fs.read(&found)?,
                                    &ext,
                                    self.limits().max_entry_bytes / 4,
                                ) {
                                    Ok(data) => {
                                        let name =
                                            format!("{}.wav", up_format::path::file_stem(&found));
                                        let dest = upkit::unique_sample_path(&name, &mut taken);
                                        assets.insert(dest.clone(), data);
                                        Some(dest)
                                    }
                                    Err(e) => {
                                        warnings.push(Warning::new(
                                            "import.bad_audio",
                                            format!("{found}：{e}，已忽略该 region"),
                                        ));
                                        None
                                    }
                                }
                            }
                            None => {
                                warnings.push(Warning::new(
                                    "import.missing_sample",
                                    format!("找不到采样 {}，已忽略该 region", layer.sample),
                                ));
                                None
                            }
                        };
                        mapped.insert(layer.sample.clone(), t.clone());
                        t
                    }
                };
                if let Some(t) = target {
                    layer.sample = t;
                    keep.push(layer);
                }
            }
            pad.layers = keep;
        }
        doc.pads.retain(|p| !p.layers.is_empty());
        if doc.pads.iter().all(|p| p.layers.is_empty()) {
            return Err(LibraryError::UnsupportedSource(format!(
                "{sfz_path}：没有可用的采样"
            )));
        }
        doc.source = Some(KitSource {
            kind: "sfz".into(),
            original_name: Some(up_format::path::file_name(sfz_path).to_string()),
            ..KitSource::default()
        });
        let pkg = UpkitPackage::build(
            &doc,
            assets,
            &BuildOptions {
                created: Some(fsutil::rfc3339(fsutil::now_ms())),
                ..BuildOptions::default()
            },
        )?;
        let out = self.install_package(
            &pkg,
            &InstallOptions {
                dedupe: true,
                default_source_kind: Some("sfz".into()),
                ..InstallOptions::default()
            },
        )?;
        report.warnings.extend(warnings);
        report.warnings.extend(out.warnings);
        report.kits.push(imported(&out.summary, out.duplicate));
        Ok(())
    }
}
