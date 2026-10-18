//! WAV 文件夹导入：按文件名自然排序依次映射到 pad，读取 `acid`/`smpl`/文件名判断 loop 与 BPM。

use std::collections::{BTreeMap, BTreeSet};

use up_format::kit::{
    KitDoc, KitSource, KitTempo, LaunchMode, LoopTempo, MAX_PADS, PadAddr, PadDoc, PadKind,
    Quantize, SampleLayer, Stretch,
};
use up_format::upkit::{self, BuildOptions, UpkitPackage};
use up_format::{Warning, wav};

use super::{ImportReport, imported};
use crate::archive::SourceFs;
use crate::error::{LibraryError, Result};
use crate::kits::InstallOptions;
use crate::{Library, fsutil};

pub(crate) fn is_audio(path: &str) -> bool {
    let ext = up_format::path::extension_lower(path).unwrap_or_default();
    (ext == "wav" || ext == "wave" || crate::transcode::is_transcodable(&ext))
        && !fsutil::is_junk(path)
}

/// 把 WAV 列表映射为 KitDoc + 资源。供 WAV 文件夹导入与示例 Kit 生成共用。
pub fn kit_from_wavs(
    name: &str,
    wavs: Vec<(String, Vec<u8>)>,
    warnings: &mut Vec<Warning>,
) -> (KitDoc, BTreeMap<String, Vec<u8>>) {
    let mut doc = KitDoc::new(fsutil::new_id(), name);
    let mut assets = BTreeMap::new();
    let mut taken = BTreeSet::new();
    let mut flat = 0u8;
    for (path, bytes) in wavs {
        if flat >= MAX_PADS {
            warnings.push(Warning::new(
                "import.too_many_files",
                format!("{path}：超过 24 个 pad，已忽略"),
            ));
            continue;
        }
        let hint = match wav::loop_hint(&bytes, up_format::path::file_name(&path), None) {
            Ok(h) => h,
            Err(e) => {
                warnings.push(Warning::new(
                    "import.bad_wav",
                    format!("{path}：{e}，已忽略"),
                ));
                continue;
            }
        };
        let dest = upkit::unique_sample_path(&path, &mut taken);
        let mut pad = PadDoc::new(PadAddr::from_flat(flat));
        pad.name = Some(up_format::path::file_stem(&path).to_string());
        let mut layer = SampleLayer::new(dest.clone());
        layer.root_key = hint.root_note.filter(|_| hint.source.is_some());
        if hint.is_loop {
            pad.kind = PadKind::Loop;
            pad.launch.mode = LaunchMode::Toggle;
            if let Some((s, e)) = hint.loop_points {
                layer.loop_start = Some(s);
                layer.loop_end = Some(e);
            }
            if let Some(bpm) = hint.bpm {
                pad.tempo = Some(LoopTempo {
                    bpm,
                    beats: hint.beats,
                    time_signature: [4, 4],
                    stretch: Stretch::None,
                });
                pad.launch.quantize = Quantize::Bar;
            }
        } else {
            pad.self_choke = true;
        }
        pad.color = upkit::default_color(&pad);
        pad.layers.push(layer);
        doc.pads.push(pad);
        assets.insert(dest, bytes);
        flat += 1;
    }
    doc.pad_count = if flat > 12 { 24 } else { 12 };
    doc.tempo = doc.pads.iter().find_map(|p| p.tempo).map(|t| KitTempo {
        bpm: t.bpm,
        time_signature: t.time_signature,
    });
    (doc, assets)
}

impl Library {
    pub(crate) fn import_wav_folder(
        &self,
        fs: &dyn SourceFs,
        report: &mut ImportReport,
    ) -> Result<()> {
        let mut files: Vec<String> = fs.files().into_iter().filter(|f| is_audio(f)).collect();
        files.sort_by_key(|f| fsutil::natural_key(f));
        let mut wavs = Vec::new();
        for f in files {
            let ext = up_format::path::extension_lower(&f).unwrap_or_default();
            match crate::transcode::ensure_wav(
                fs.read(&f)?,
                &ext,
                self.limits().max_entry_bytes / 4,
            ) {
                // 转码后的文件名改成 .wav，保留原文件名主干（BPM 等信息常在文件名里）
                Ok(w) => wavs.push((
                    format!("{}.wav", f.strip_suffix(&format!(".{ext}")).unwrap_or(&f)),
                    w,
                )),
                Err(e) => report.warnings.push(Warning::new(
                    "import.bad_audio",
                    format!("{f}：{e}，已忽略"),
                )),
            }
        }
        let (mut doc, assets) = kit_from_wavs(&fs.display_name(), wavs, &mut report.warnings);
        if doc.pads.is_empty() {
            return Err(LibraryError::UnsupportedSource("没有可用的 WAV".into()));
        }
        doc.source = Some(KitSource {
            kind: "wav-folder".into(),
            original_name: Some(fs.display_name()),
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
                default_source_kind: Some("wav-folder".into()),
                ..InstallOptions::default()
            },
        )?;
        report.warnings.extend(out.warnings);
        report.kits.push(imported(&out.summary, out.duplicate));
        Ok(())
    }
}
