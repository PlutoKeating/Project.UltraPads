//! Recorded tracks (takes recorded with `StartRecording`/`StopRecording`),
//! stored in the library (`<data_dir>/library/tracks`).

use super::types::*;
use crate::state::{self, lib_err};
use std::path::Path;
use up_core::TrackId;

type R<T> = Result<T, UpError>;

const WAVEFORM_BUCKETS: u32 = 128;

fn waveform_of(lib: &up_library::Library, id: &str) -> Vec<f32> {
    if let Some(w) = state::waveform_cache()
        .lock()
        .ok()
        .and_then(|c| c.get(id).cloned())
    {
        return w;
    }
    let w = lib
        .track_path(id)
        .ok()
        .and_then(|p| std::fs::File::open(p).ok())
        .and_then(|f| up_codec::decode(f, Some("wav")).ok())
        .map(|a| up_codec::waveform(&a.data, a.channels, WAVEFORM_BUCKETS))
        .unwrap_or_default();
    if let Ok(mut c) = state::waveform_cache().lock() {
        c.insert(id.to_owned(), w.clone());
    }
    w
}

/// All tracks, newest first (with 128-bucket waveform overviews).
pub fn tracks_list() -> R<Vec<TrackInfo>> {
    let lib = state::library()?;
    Ok(lib
        .tracks_list()
        .iter()
        .map(|t| track_from_library(t, waveform_of(&lib, &t.id)))
        .collect())
}

/// Play a track on the preview voice (emits `TrackPlayback`). With
/// `looping` it repeats until `track_stop`.
pub fn track_play(id: String, looping: bool) -> R<()> {
    let lib = state::library()?;
    let path = lib.track_path(&id).map_err(lib_err)?;
    let f = std::fs::File::open(path).map_err(|e| UpError::from(up_core::UpError::from(e)))?;
    let audio = up_codec::decode(f, Some("wav"))?;
    Ok(state::core()?.play_audio(&TrackId(id), &audio, looping)?)
}

pub fn track_stop() -> R<()> {
    Ok(state::core()?.track_stop()?)
}

/// Export to `path`. `fmt`: `wav` (BWF), `flac` or `dawproject`. `credits` is the attribution
/// text for CC BY / BY-SA material used in the take (written to the WAV `bext` chunk or the FLAC
/// `COMMENT` tag). Returns the written path.
pub fn track_export(id: String, path: String, fmt: String, credits: Option<String>) -> R<String> {
    let format = match fmt.to_ascii_lowercase().as_str() {
        "wav" => up_library::TrackExportFormat::Wav,
        "flac" => up_library::TrackExportFormat::Flac,
        "dawproject" => up_library::TrackExportFormat::DawProject,
        other => {
            return Err(UpError {
                code: ErrorCode::InvalidArgument,
                message: format!("unknown track format {other:?} (wav, flac, dawproject)"),
            });
        }
    };
    let out = state::library()?
        .track_export(&id, Path::new(&path), format, credits.as_deref())
        .map_err(lib_err)?;
    Ok(out.to_string_lossy().into_owned())
}

pub fn track_rename(id: String, name: String) -> R<TrackInfo> {
    let lib = state::library()?;
    let t = lib.track_rename(&id, &name).map_err(lib_err)?;
    Ok(track_from_library(&t, waveform_of(&lib, &t.id)))
}

pub fn track_delete(id: String) -> R<()> {
    state::library()?.track_delete(&id).map_err(lib_err)?;
    if let Ok(mut c) = state::waveform_cache().lock() {
        c.remove(&id);
    }
    state::core()?.emit(up_engine::EngineEvent::LibraryChanged);
    Ok(())
}
