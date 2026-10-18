//! Recorded tracks: `<dir>/<id>.wav` + `<id>.json` ([`TrackInfo`]).

use std::path::{Path, PathBuf};
use up_codec::{AudioBuffer, WavFormat};
use up_core::{SampleId, TrackId, UpError, UpResult};
use up_engine::{SampleData, Take, TrackInfo};

/// Track storage (thread-safe: every call goes to the filesystem).
#[derive(Debug, Clone)]
pub struct TrackStore {
    dir: PathBuf,
}

impl TrackStore {
    pub fn new(dir: impl Into<PathBuf>) -> UpResult<Self> {
        let dir = dir.into();
        std::fs::create_dir_all(&dir)?;
        Ok(Self { dir })
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    fn valid(id: &TrackId) -> UpResult<()> {
        let s = id.as_str();
        if s.is_empty() || !s.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') {
            return Err(UpError::invalid(format!("invalid track id {s:?}")));
        }
        Ok(())
    }

    pub fn wav_path(&self, id: &TrackId) -> PathBuf {
        self.dir.join(format!("{id}.wav"))
    }

    fn meta_path(&self, id: &TrackId) -> PathBuf {
        self.dir.join(format!("{id}.json"))
    }

    /// All tracks, newest first.
    pub fn list(&self) -> UpResult<Vec<TrackInfo>> {
        let mut out = Vec::new();
        for e in std::fs::read_dir(&self.dir)?.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            match std::fs::read_to_string(&p)
                .map_err(UpError::from)
                .and_then(|t| {
                    serde_json::from_str::<TrackInfo>(&t)
                        .map_err(|e| UpError::format(e.to_string()))
                }) {
                Ok(info) if self.wav_path(&info.id).is_file() => out.push(info),
                Ok(_) => {}
                Err(e) => log::warn!("bad track metadata {}: {e}", p.display()),
            }
        }
        out.sort_by(|a, b| {
            b.created_unix_ms
                .cmp(&a.created_unix_ms)
                .then(b.id.cmp(&a.id))
        });
        Ok(out)
    }

    pub fn get(&self, id: &TrackId) -> UpResult<TrackInfo> {
        Self::valid(id)?;
        let text = std::fs::read_to_string(self.meta_path(id))
            .map_err(|_| UpError::not_found(format!("track {id}")))?;
        serde_json::from_str(&text).map_err(|e| UpError::format(e.to_string()))
    }

    /// Store a take as a new track named "TRACK N".
    pub fn save_take(&self, take: &Take) -> UpResult<TrackInfo> {
        let id = TrackId::new(uuid::Uuid::now_v7().to_string());
        let n = self.list().map(|l| l.len()).unwrap_or(0) + 1;
        let info = TrackInfo {
            id: id.clone(),
            name: format!("TRACK {n}"),
            created_unix_ms: crate::now_unix_ms(),
            duration_secs: take.duration_secs,
            sample_rate: take.audio.sample_rate,
            channels: take.audio.channels,
            waveform: take.waveform.clone(),
        };
        let tmp = self.dir.join(format!("{id}.wav.part"));
        {
            let f = std::fs::File::create(&tmp)?;
            up_codec::write_wav(std::io::BufWriter::new(f), &take.audio, WavFormat::Pcm24)?;
        }
        std::fs::rename(&tmp, self.wav_path(&id))?;
        let json =
            serde_json::to_string_pretty(&info).map_err(|e| UpError::format(e.to_string()))?;
        std::fs::write(self.meta_path(&id), json)?;
        Ok(info)
    }

    /// Decode a track (resampled to `sample_rate`) for preview playback.
    pub fn load_sample(&self, id: &TrackId, sample_rate: u32) -> UpResult<SampleData> {
        let audio = self.load_audio(id)?;
        let audio = up_codec::resample(&audio, sample_rate)?;
        Ok(SampleData::new(
            SampleId::new(format!("track:{id}")),
            id.as_str(),
            sample_rate,
            audio.to_planar(),
        ))
    }

    pub fn load_audio(&self, id: &TrackId) -> UpResult<AudioBuffer> {
        Self::valid(id)?;
        let f = std::fs::File::open(self.wav_path(id))
            .map_err(|_| UpError::not_found(format!("track {id}")))?;
        up_codec::decode(f, Some("wav"))
    }

    /// Export to `path`. `format`: `wav` (24-bit), `wav16`, `wav32f`.
    pub fn export(&self, id: &TrackId, path: &Path, format: &str) -> UpResult<()> {
        let fmt = match format.to_ascii_lowercase().as_str() {
            "wav" | "wav24" => WavFormat::Pcm24,
            "wav16" => WavFormat::Pcm16,
            "wav32f" | "wavf32" => WavFormat::Float32,
            other => return Err(UpError::not_implemented(format!("export format {other:?}"))),
        };
        let audio = self.load_audio(id)?;
        if let Some(parent) = path.parent().filter(|p| !p.as_os_str().is_empty()) {
            std::fs::create_dir_all(parent)?;
        }
        let f = std::fs::File::create(path)?;
        up_codec::write_wav(std::io::BufWriter::new(f), &audio, fmt)
    }

    pub fn delete(&self, id: &TrackId) -> UpResult<()> {
        Self::valid(id)?;
        let wav = self.wav_path(id);
        if !wav.exists() && !self.meta_path(id).exists() {
            return Err(UpError::not_found(format!("track {id}")));
        }
        let _ = std::fs::remove_file(wav);
        let _ = std::fs::remove_file(self.meta_path(id));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn save_list_export_delete() {
        let dir = std::env::temp_dir().join(format!("up-tracks-{}", uuid::Uuid::now_v7()));
        let store = TrackStore::new(&dir).unwrap();
        let data: Vec<f32> = (0..9600).map(|i| (i as f32 * 0.05).sin() * 0.5).collect();
        let take = Take::finalize(data, 48_000, 2, 0);
        let info = store.save_take(&take).unwrap();
        assert_eq!(info.name, "TRACK 1");
        assert!((info.duration_secs - 0.1).abs() < 1e-9);
        let list = store.list().unwrap();
        assert_eq!(list.len(), 1);
        let s = store.load_sample(&info.id, 44_100).unwrap();
        assert!(s.frames() > 4000);
        let out = dir.join("export/out.wav");
        store.export(&info.id, &out, "wav16").unwrap();
        let back = up_codec::decode(std::fs::File::open(&out).unwrap(), Some("wav")).unwrap();
        assert_eq!(back.frames(), 4800);
        assert!(store.export(&info.id, &out, "mp3").is_err());
        assert!(store.get(&TrackId::new("../etc")).is_err());
        store.delete(&info.id).unwrap();
        assert!(store.list().unwrap().is_empty());
        let _ = std::fs::remove_dir_all(dir);
    }
}
