//! Kit library, backed by `runtime/up-library` (`Library` opened by `init`
//! at `<data_dir>/library`).

use super::types::*;
use crate::state::{self, lib_err};
use std::path::Path;
use up_core::SampleId;
use up_host::KitAudio;

type R<T> = Result<T, UpError>;

/// All kits, sorted by name.
pub fn library_list_kits() -> R<Vec<KitSummary>> {
    library_search_kits(None, None, false, KitSort::Name, None)
}

/// Search kits: `text` matches name/author/genre/tags/inspiration (all
/// words), `genre` exact (case-insensitive).
pub fn library_search_kits(
    text: Option<String>,
    genre: Option<String>,
    favorites_only: bool,
    sort: KitSort,
    limit: Option<u32>,
) -> R<Vec<KitSummary>> {
    let lib = state::library()?;
    let q = up_library::KitQuery {
        text,
        genre,
        favorites_only,
        used_only: false,
        sort: match sort {
            KitSort::Name => up_library::KitSort::Name,
            KitSort::RecentlyUsed => up_library::KitSort::RecentlyUsed,
            KitSort::RecentlyAdded => up_library::KitSort::RecentlyAdded,
            KitSort::Favorited => up_library::KitSort::Favorited,
        },
        limit: limit.map(|l| l as usize),
    };
    Ok(lib
        .list_kits(&q)
        .iter()
        .map(|k| kit_summary_from_library(k, &lib))
        .collect())
}

/// Genres with kit counts, most common first.
pub fn library_genres() -> R<Vec<String>> {
    Ok(state::library()?
        .genres()
        .into_iter()
        .map(|(g, _)| g)
        .collect())
}

pub fn library_set_favorite(kit: String, favorite: bool) -> R<KitSummary> {
    let lib = state::library()?;
    let k = lib.set_favorite(&kit, favorite).map_err(lib_err)?;
    Ok(kit_summary_from_library(&k, &lib))
}

pub fn library_delete_kit(kit: String) -> R<()> {
    state::library()?.delete_kit(&kit).map_err(lib_err)?;
    state::core()?.emit(up_engine::EngineEvent::LibraryChanged);
    Ok(())
}

fn pcm_to_buffer(s: &up_library::LoadedSample) -> R<up_codec::AudioBuffer> {
    if let Some(pcm) = &s.pcm {
        return Ok(up_codec::AudioBuffer::new(
            pcm.sample_rate,
            pcm.channels,
            pcm.samples.clone(),
        ));
    }
    let f = std::fs::File::open(&s.file).map_err(|e| UpError::from(up_core::UpError::from(e)))?;
    Ok(up_codec::decode(f, None)?)
}

/// Decode a library kit and hand it to the engine (emits `KitLoaded`).
/// For development, a folder path that is not a library kit id is loaded
/// as a folder kit (audio files sorted by name → pads).
pub fn library_load_kit(kit: String) -> R<KitSummary> {
    let core = state::core()?;
    // Development path: an existing folder (library ids never contain path
    // separators).
    let as_path = Path::new(&kit);
    if (kit.contains('/') || kit.contains('\\')) && as_path.is_dir() {
        state::set_current_kit(None);
        return Ok(core.load_kit_folder(as_path)?.into());
    }
    let lib = state::library()?;
    let loaded = lib.load_kit_assets(&kit).map_err(lib_err)?;
    let mut audio: Vec<KitAudio> = Vec::new();
    for s in loaded.samples.values() {
        if audio.iter().any(|a| a.id.as_str() == s.sample_id) {
            continue;
        }
        let name = Path::new(&s.package_path)
            .file_stem()
            .and_then(|n| n.to_str())
            .unwrap_or("sample")
            .to_owned();
        audio.push(KitAudio {
            id: SampleId::new(s.sample_id.clone()),
            name,
            audio: pcm_to_buffer(s)?,
        });
    }
    core.load_kit(loaded.model, audio)?;
    state::set_current_kit(Some(kit));
    Ok(kit_summary_from_library(&loaded.summary, &lib))
}

/// Import a `.upkit` (ZIP or folder), SFZ, audio folder, single audio file
/// (stored as a sample) or the original app's asset folder.
pub fn library_import(path: String) -> R<ImportReport> {
    let lib = state::library()?;
    let rep = lib.import(Path::new(&path)).map_err(lib_err)?;
    let kits = rep
        .kits
        .iter()
        .map(|k| match lib.kit_summary(&k.kit_id) {
            Ok(s) => kit_summary_from_library(&s, &lib),
            Err(_) => KitSummary {
                id: k.kit_id.clone(),
                name: k.name.clone(),
                pad_count: u32::from(k.pads_used),
                ..Default::default()
            },
        })
        .collect();
    let kind = match &rep.kind {
        up_library::ImportKind::Upkit => "upkit".to_owned(),
        up_library::ImportKind::Sfz => "sfz".to_owned(),
        up_library::ImportKind::WavFolder => "wav-folder".to_owned(),
        up_library::ImportKind::Compat(src) => format!("compat:{src}"),
        up_library::ImportKind::Sample => "sample".to_owned(),
    };
    state::core()?.emit(up_engine::EngineEvent::LibraryChanged);
    Ok(ImportReport {
        kind,
        kits,
        duplicates: rep.kits.iter().filter(|k| k.duplicate).count() as u32,
        samples: rep.samples.clone(),
        catalog_entries: rep.catalog_entries as u32,
        warnings: rep.warnings.iter().map(ToString::to_string).collect(),
    })
}

/// Export a kit. `format`: `upkit` | `upkit-folder` | `sfz` | `dawproject`.
/// Returns the written path.
pub fn library_export_kit(kit: String, path: String, format: String) -> R<String> {
    let fmt = up_library::ExportFormat::parse(&format).ok_or_else(|| UpError {
        code: ErrorCode::InvalidArgument,
        message: format!("unknown export format {format:?} (upkit, upkit-folder, sfz, dawproject)"),
    })?;
    let out = state::library()?
        .export_kit(&kit, Path::new(&path), fmt)
        .map_err(lib_err)?;
    Ok(out.to_string_lossy().into_owned())
}

/// Save an edited kit. `kit_json` is an `up_model::KitDoc` as camelCase
/// JSON (see `library_current_kit_json`). Returns the stored summary.
pub fn library_save_kit(kit_json: String) -> R<KitSummary> {
    let doc = up_model::KitDoc::from_json(&kit_json)?;
    let lib = state::library()?;
    let s = lib.save_kit_model(&doc).map_err(lib_err)?;
    state::core()?.emit(up_engine::EngineEvent::LibraryChanged);
    Ok(kit_summary_from_library(&s, &lib))
}

/// Current kit document as camelCase JSON (`up_model::KitDoc`).
pub fn library_current_kit_json() -> R<Option<String>> {
    let doc = state::core()?.current_kit()?;
    doc.map(|d| d.to_json().map_err(Into::into)).transpose()
}

/// Kit document of any library kit as camelCase JSON.
pub fn library_kit_json(kit: String) -> R<String> {
    Ok(state::library()?
        .kit_model(&kit)
        .map_err(lib_err)?
        .to_json()?)
}

/// Standalone samples (mic recordings, imported files).
pub fn library_list_samples() -> R<Vec<SampleInfo>> {
    Ok(state::library()?
        .list_samples()
        .into_iter()
        .map(|s| SampleInfo {
            duration_secs: s.duration_secs(),
            id: s.id,
            name: s.name,
            origin: format!("{:?}", s.origin),
            sample_rate: s.sample_rate,
            channels: s.channels,
            created_unix_ms: s.created_at_ms,
        })
        .collect())
}

/// Make a library sample playable (registers it with the engine) so it
/// can be assigned with `SetPadParams`.
pub fn library_use_sample(sample: String) -> R<()> {
    let lib = state::library()?;
    let path = lib.sample_path(&sample).map_err(lib_err)?;
    let f = std::fs::File::open(&path).map_err(|e| UpError::from(up_core::UpError::from(e)))?;
    let audio = up_codec::decode(f, None)?;
    let name = lib
        .sample(&sample)
        .map(|r| r.name)
        .unwrap_or_else(|_| "sample".into());
    Ok(state::core()?.register_audio(SampleId::new(sample), &name, &audio)?)
}
