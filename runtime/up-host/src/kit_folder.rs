//! Temporary v0.0.1 kit loader: a folder of audio files becomes a kit.
//!
//! * Files are sorted by name (case-insensitive, natural number order) and
//!   mapped to pads A0..B11 in flat order.
//! * Old-style names `pad{N}_{preset}.wav` map to pad `N-1`.
//! * An optional Ref config (`*.txt`/`*.json` with a `behaviour`
//!   object: 100 = Loop, 200 = One-shot, 300 = Gate; `colors`, `groups`)
//!   sets modes, colors and choke groups. Otherwise names containing
//!   "loop" become loops.
//! * An optional `tutorial.json` (native [`up_model::TutorialChart`] or the
//!   Ref 4.x `[{time,pad,color,state}]` array) and `*_lesson.json`
//!   files are attached as the kit's tutorial.
//!
//! The real kit formats (`.upkit`, SFZ, …) live in `runtime/up-library`.

use std::path::{Path, PathBuf};
use up_codec::AudioBuffer;
use up_core::{ColorRole, KitId, PAD_COUNT, PadId, PadMode, SampleId, UpError, UpResult};
use up_engine::{Command, EngineHandle, PadParams, SampleData};
use up_model::{KitDoc, PadDoc, SampleRef, TutorialChart};

pub const AUDIO_EXTENSIONS: &[&str] = &[
    "wav", "wave", "mp3", "ogg", "oga", "flac", "m4a", "mp4", "aac", "aif", "aiff", "caf",
];

/// Decoded audio of one kit sample at its original sample rate.
#[derive(Debug, Clone)]
pub struct KitAudio {
    pub id: SampleId,
    pub name: String,
    pub audio: AudioBuffer,
}

/// A decoded kit ready to be applied to an engine.
#[derive(Debug, Clone)]
pub struct LoadedKit {
    /// Source folder (folder kits only).
    pub dir: Option<PathBuf>,
    pub doc: KitDoc,
    /// Samples resampled to the engine rate.
    pub samples: Vec<SampleData>,
    /// Original-rate audio, kept so the kit can be re-applied after an
    /// engine rebuild at another sample rate.
    pub originals: Vec<KitAudio>,
    /// Files that failed to decode (path, error).
    pub skipped: Vec<(PathBuf, UpError)>,
}

impl LoadedKit {
    /// Build from a document and original-rate audio, resampling to `sample_rate`.
    pub fn from_audio(
        dir: Option<PathBuf>,
        doc: KitDoc,
        originals: Vec<KitAudio>,
        sample_rate: u32,
    ) -> UpResult<Self> {
        let samples = originals
            .iter()
            .map(|a| {
                let rs = up_codec::resample(&a.audio, sample_rate)?;
                Ok(SampleData::new(
                    a.id.clone(),
                    a.name.clone(),
                    sample_rate,
                    rs.to_planar(),
                ))
            })
            .collect::<UpResult<Vec<_>>>()?;
        Ok(Self {
            dir,
            doc,
            samples,
            originals,
            skipped: Vec::new(),
        })
    }

    /// Same kit at another engine rate.
    pub fn resampled(&self, sample_rate: u32) -> UpResult<Self> {
        let mut k = Self::from_audio(
            self.dir.clone(),
            self.doc.clone(),
            self.originals.clone(),
            sample_rate,
        )?;
        k.skipped = self.skipped.clone();
        Ok(k)
    }
}

fn natural_key(s: &str) -> Vec<(u8, u64, String)> {
    // Split into digit / non-digit runs so "pad10" sorts after "pad2".
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut digits = false;
    for c in s.to_lowercase().chars() {
        if c.is_ascii_digit() != digits && !cur.is_empty() {
            out.push(run(&cur, digits));
            cur.clear();
        }
        digits = c.is_ascii_digit();
        cur.push(c);
    }
    if !cur.is_empty() {
        out.push(run(&cur, digits));
    }
    out
}

fn run(s: &str, digits: bool) -> (u8, u64, String) {
    if digits {
        (0, s.parse().unwrap_or(u64::MAX), String::new())
    } else {
        (1, 0, s.to_owned())
    }
}

/// `pad12_sunset.wav` → `Some(11)`.
fn compat_pad_index(stem: &str) -> Option<usize> {
    let rest = stem.strip_prefix("pad")?;
    let num: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
    let n: usize = num.parse().ok()?;
    (1..=PAD_COUNT).contains(&n).then(|| n - 1)
}

fn is_audio(p: &Path) -> bool {
    p.extension()
        .and_then(|e| e.to_str())
        .is_some_and(|e| AUDIO_EXTENSIONS.contains(&e.to_ascii_lowercase().as_str()))
}

struct CompatConfig {
    behaviour: [Option<i64>; PAD_COUNT],
    colors: [Option<String>; PAD_COUNT],
    groups: [Option<i64>; PAD_COUNT],
}

impl Default for CompatConfig {
    fn default() -> Self {
        Self {
            behaviour: [None; PAD_COUNT],
            colors: std::array::from_fn(|_| None),
            groups: [None; PAD_COUNT],
        }
    }
}

fn read_compat_config(dir: &Path) -> Option<CompatConfig> {
    let entries = std::fs::read_dir(dir).ok()?;
    for e in entries.flatten() {
        let p = e.path();
        let ext = p
            .extension()
            .and_then(|x| x.to_str())
            .unwrap_or("")
            .to_ascii_lowercase();
        if ext != "txt" && ext != "json" {
            continue;
        }
        let Ok(text) = std::fs::read_to_string(&p) else {
            continue;
        };
        let Ok(v) = serde_json::from_str::<serde_json::Value>(&text) else {
            continue;
        };
        let Some(beh) = v.get("behaviour").and_then(|b| b.as_object()) else {
            continue;
        };
        let mut cfg = CompatConfig::default();
        let idx = |k: &str| compat_pad_index(k);
        for (k, val) in beh {
            if let Some(i) = idx(k) {
                cfg.behaviour[i] = val.as_i64();
            }
        }
        if let Some(c) = v.get("colors").and_then(|c| c.as_object()) {
            for (k, val) in c {
                if let Some(i) = idx(k) {
                    cfg.colors[i] = val.as_str().map(str::to_owned);
                }
            }
        }
        if let Some(g) = v.get("groups").and_then(|g| g.as_object()) {
            for (k, val) in g {
                if let Some(i) = idx(k) {
                    cfg.groups[i] = val.as_i64();
                }
            }
        }
        return Some(cfg);
    }
    None
}

/// Decoded sample, BLAKE3 hex of the file, original (pre-resample) audio.
type Decoded = (SampleData, String, AudioBuffer);

fn decode_file(path: &Path, target_rate: u32) -> UpResult<Decoded> {
    let bytes = std::fs::read(path)?;
    let hash = blake3::hash(&bytes).to_hex().to_string();
    let ext = path.extension().and_then(|e| e.to_str()).map(str::to_owned);
    let decoded = up_codec::decode_bytes(bytes, ext.as_deref())?;
    let resampled = up_codec::resample(&decoded, target_rate)?;
    let name = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("sample")
        .to_owned();
    let planar = resampled.to_planar();
    Ok((
        SampleData::new(SampleId::new(hash.clone()), name, target_rate, planar),
        hash,
        decoded,
    ))
}

/// Load a folder kit, decoding and resampling every file to `sample_rate`.
pub fn load_folder_kit(dir: &Path, sample_rate: u32) -> UpResult<LoadedKit> {
    let dir = dir
        .canonicalize()
        .map_err(|e| UpError::not_found(format!("kit folder {}: {e}", dir.display())))?;
    if !dir.is_dir() {
        return Err(UpError::invalid(format!(
            "{} is not a folder",
            dir.display()
        )));
    }
    // Ref kits keep their files in a `Sounds/` sub-folder.
    let sounds = dir.join("Sounds");
    let src = if sounds.is_dir() { sounds } else { dir.clone() };
    let mut files: Vec<PathBuf> = std::fs::read_dir(&src)?
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_file() && is_audio(p))
        .collect();
    files.sort_by_cached_key(|p| {
        natural_key(
            &p.file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_default(),
        )
    });
    if files.is_empty() {
        return Err(UpError::not_found(format!(
            "no audio files in {}",
            src.display()
        )));
    }

    // Pad assignment.
    let named: Vec<Option<usize>> = files
        .iter()
        .map(|p| {
            p.file_stem()
                .and_then(|s| s.to_str())
                .and_then(|s| compat_pad_index(&s.to_lowercase()))
        })
        .collect();
    let use_names = named.iter().any(Option::is_some);
    let mut assignment: Vec<(usize, PathBuf)> = Vec::new();
    let mut taken = [false; PAD_COUNT];
    if use_names {
        for (p, n) in files.iter().zip(&named) {
            if let Some(i) = n
                && !std::mem::replace(&mut taken[*i], true)
            {
                assignment.push((*i, p.clone()));
            }
        }
    } else {
        for (i, p) in files.iter().take(PAD_COUNT).enumerate() {
            assignment.push((i, p.clone()));
        }
    }

    // Decode in parallel (decode + resample are CPU bound).
    let threads = std::thread::available_parallelism()
        .map_or(4, |n| n.get())
        .clamp(1, 8);
    let chunk = assignment.len().div_ceil(threads).max(1);
    let results: Vec<(usize, PathBuf, UpResult<Decoded>)> = std::thread::scope(|s| {
        let handles: Vec<_> = assignment
            .chunks(chunk)
            .map(|part| {
                s.spawn(move || {
                    part.iter()
                        .map(|(i, p)| (*i, p.clone(), decode_file(p, sample_rate)))
                        .collect::<Vec<_>>()
                })
            })
            .collect();
        handles
            .into_iter()
            .flat_map(|h| h.join().unwrap_or_default())
            .collect()
    });

    let config = read_compat_config(&src);
    let mut doc = KitDoc {
        id: KitId::new(dir.to_string_lossy().into_owned()),
        name: kit_name(&dir),
        ..Default::default()
    };
    let mut samples = Vec::new();
    let mut originals = Vec::new();
    let mut skipped = Vec::new();
    for (i, path, res) in results {
        let (sample, hash, original) = match res {
            Ok(x) => x,
            Err(e) => {
                log::warn!("skipping {}: {e}", path.display());
                skipped.push((path, e));
                continue;
            }
        };
        let Some(pad) = PadId::from_flat(i) else {
            continue;
        };
        let mut pd = PadDoc::new(pad);
        pd.name = sample.name.clone();
        pd.mode = if sample.name.to_lowercase().contains("loop") {
            PadMode::Loop
        } else {
            PadMode::OneShot
        };
        pd.color = [
            ColorRole::Pink,
            ColorRole::Orange,
            ColorRole::Green,
            ColorRole::Blue,
        ][i % 3];
        if let Some(cfg) = &config {
            if let Some(code) = cfg.behaviour[i] {
                match PadMode::from_compat_code(code as i32) {
                    Some(m) => pd.mode = m,
                    None => continue, // -1 = empty pad
                }
            }
            if let Some(c) = cfg.colors[i]
                .as_deref()
                .and_then(ColorRole::from_compat_name)
            {
                pd.color = c;
            }
            pd.choke_group = cfg.groups[i]
                .and_then(|g| u8::try_from(g).ok())
                .filter(|g| *g > 0);
        }
        pd.sample = Some(SampleRef {
            id: sample.id.clone(),
            path: path
                .strip_prefix(&dir)
                .ok()
                .map(|p| p.to_string_lossy().into_owned()),
            name: sample.name.clone(),
            blake3: Some(hash),
            sample_rate: Some(original.sample_rate),
            channels: Some(original.channels),
            frames: Some(original.frames() as u64),
        });
        doc.pads.push(pd);
        originals.push(KitAudio {
            id: sample.id.clone(),
            name: sample.name.clone(),
            audio: original,
        });
        samples.push(sample);
    }
    doc.pads.sort_by_key(|p| p.pad.flat());
    if samples.is_empty() {
        return Err(skipped
            .into_iter()
            .next()
            .map(|(_, e)| e)
            .unwrap_or_else(|| UpError::codec("no decodable audio")));
    }
    let tutorial = src.join("tutorial.json");
    let tutorial = if tutorial.is_file() {
        tutorial
    } else {
        dir.join("tutorial.json")
    };
    if let Ok(text) = std::fs::read_to_string(&tutorial) {
        match TutorialChart::from_json_any(&text) {
            Ok(t) => doc.tutorial = Some(t),
            Err(e) => log::warn!("invalid tutorial.json: {e}"),
        }
    }
    // Ref 4.x lessons (`<id>_lesson.json`).
    if let Ok(rd) = std::fs::read_dir(&src) {
        for e in rd.flatten() {
            let p = e.path();
            let is_lesson = p
                .file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.ends_with("_lesson.json"));
            if is_lesson && let Ok(text) = std::fs::read_to_string(&p) {
                let chart = doc.tutorial.get_or_insert_with(|| TutorialChart {
                    timed: true,
                    ..Default::default()
                });
                if let Err(e) = chart.add_compat_lessons(&text) {
                    log::warn!("invalid {}: {e}", p.display());
                }
            }
        }
    }
    doc.validate()?;
    Ok(LoadedKit {
        dir: Some(dir),
        doc,
        samples,
        originals,
        skipped,
    })
}

fn kit_name(dir: &Path) -> String {
    let base = dir.file_name().and_then(|n| n.to_str()).unwrap_or("Kit");
    if base.eq_ignore_ascii_case("sounds") {
        dir.parent()
            .and_then(|p| p.file_name())
            .and_then(|n| n.to_str())
            .unwrap_or(base)
            .to_owned()
    } else {
        base.to_owned()
    }
}

/// Register the kit's samples with the engine and configure all 24 pads
/// (pads without a sample are cleared). Broadcasts `KitLoaded`.
pub fn apply_kit(handle: &EngineHandle, kit: &LoadedKit) -> UpResult<()> {
    if kit
        .samples
        .iter()
        .any(|s| s.sample_rate != handle.sample_rate())
    {
        return Err(UpError::invalid(
            "kit was decoded for a different sample rate",
        ));
    }
    for s in &kit.samples {
        handle.register_sample(s.clone());
    }
    for pad in PadId::all() {
        let params = kit
            .doc
            .pad(pad)
            .map(PadDoc::to_params)
            .unwrap_or(PadParams {
                color: ColorRole::Neutral,
                ..Default::default()
            });
        handle.send(Command::SetPadParams { pad, params })?;
    }
    handle.set_kit(Some(kit.doc.summary()));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn natural_sort_and_names() {
        let mut v = vec!["pad10_x", "pad2_x", "Pad1_x"];
        v.sort_by_key(|s| natural_key(s));
        assert_eq!(v, vec!["Pad1_x", "pad2_x", "pad10_x"]);
        assert_eq!(compat_pad_index("pad12_sunset"), Some(11));
        assert_eq!(compat_pad_index("pad25_x"), Some(24));
        assert_eq!(compat_pad_index("pad84_x"), Some(83));
        assert_eq!(compat_pad_index("pad85_x"), None);
        assert_eq!(compat_pad_index("kick"), None);
    }
}
