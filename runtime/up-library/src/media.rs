//! 样本入库（麦克风录音、导入文件、录音作品转样本）与录音作品（tracks）。

use std::path::{Path, PathBuf};

use up_format::dawproject::{self, AudioTrackExport};
use up_format::wav;

use crate::error::{IoContext, LibraryError, Result};
use crate::index::{SampleOrigin, SampleRecord, TrackInfo};
use crate::{Library, fsutil, is_hash};

/// 录音作品导出格式。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrackExportFormat {
    Wav,
    /// `.dawproject`：一条 audio 轨引用 `audio/<name>.wav`。
    DawProject,
}

pub(crate) fn track_info_from_bytes(
    id: &str,
    name: &str,
    bytes: &[u8],
    kit_id: Option<String>,
    bpm: Option<f64>,
    now: i64,
) -> Result<TrackInfo> {
    let info = wav::info(bytes)?;
    Ok(TrackInfo {
        id: id.to_string(),
        name: name.to_string(),
        blob: up_format::blake3_hex(bytes),
        size: bytes.len() as u64,
        sample_rate: info.sample_rate,
        channels: info.channels,
        duration_secs: info.duration_secs(),
        kit_id,
        bpm,
        created_at_ms: now,
        updated_at_ms: now,
    })
}

fn check_id(id: &str) -> Result<()> {
    if fsutil::is_safe_id(id) {
        Ok(())
    } else {
        Err(LibraryError::InvalidInput(format!("非法 ID `{id}`")))
    }
}

impl Library {
    // ------------------------------------------------------------------
    // 样本
    // ------------------------------------------------------------------

    /// 样本入库（WAV 字节）。同内容的样本只存一份，返回其记录（`id` = BLAKE3 = `SampleId`）。
    pub fn add_sample(
        &self,
        bytes: &[u8],
        name: &str,
        origin: SampleOrigin,
    ) -> Result<SampleRecord> {
        let info = wav::info(bytes)?;
        let hash = self.put_blob(bytes)?;
        self.update_index(|idx| {
            if let Some(existing) = idx.samples.get(&hash) {
                return Ok(existing.clone());
            }
            let rec = SampleRecord {
                id: hash.clone(),
                name: if name.trim().is_empty() {
                    "Sample".into()
                } else {
                    name.trim().to_string()
                },
                origin,
                size: bytes.len() as u64,
                media_type: "audio/wav".into(),
                sample_rate: info.sample_rate,
                channels: info.channels,
                frames: info.frames,
                created_at_ms: fsutil::now_ms(),
            };
            idx.samples.insert(hash.clone(), rec.clone());
            idx.tombstones.remove(&format!("sample:{hash}"));
            Ok(rec)
        })
    }

    /// 从文件入库样本（例如录音线程写好的临时 WAV）。
    pub fn add_sample_file(&self, path: &Path, origin: SampleOrigin) -> Result<SampleRecord> {
        let bytes = std::fs::read(path).ctx(|| format!("读取 {}", path.display()))?;
        let name = path
            .file_stem()
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_default();
        self.add_sample(&bytes, &name, origin)
    }

    pub fn list_samples(&self) -> Vec<SampleRecord> {
        let mut v: Vec<_> = self.lock().samples.values().cloned().collect();
        v.sort_by_key(|a| std::cmp::Reverse(a.created_at_ms));
        v
    }

    pub fn sample(&self, id: &str) -> Result<SampleRecord> {
        self.lock()
            .samples
            .get(id)
            .cloned()
            .ok_or_else(|| LibraryError::not_found("sample", id))
    }

    /// 样本文件路径（内容寻址存储中的 blob）。任何 Kit 采样的 `sampleId` 也可以用。
    pub fn sample_path(&self, id: &str) -> Result<PathBuf> {
        if !is_hash(id) {
            return Err(LibraryError::InvalidInput(format!("非法 sampleId `{id}`")));
        }
        let p = self.blob_path(id);
        if p.is_file() {
            Ok(p)
        } else {
            Err(LibraryError::not_found("sample", id))
        }
    }

    pub fn rename_sample(&self, id: &str, name: &str) -> Result<SampleRecord> {
        self.update_index(|idx| {
            let s = idx
                .samples
                .get_mut(id)
                .ok_or_else(|| LibraryError::not_found("sample", id))?;
            s.name = name.trim().to_string();
            Ok(s.clone())
        })
    }

    /// 从样本列表移除（blob 仍被 Kit 引用时保留，见 [`Library::gc_blobs`]）。
    pub fn delete_sample(&self, id: &str) -> Result<()> {
        self.update_index(|idx| {
            idx.samples
                .remove(id)
                .ok_or_else(|| LibraryError::not_found("sample", id))?;
            idx.tombstones
                .insert(format!("sample:{id}"), fsutil::now_ms());
            Ok(())
        })
    }

    /// 峰值概要：把采样分成 `buckets` 段，每段取各声道绝对值最大值（0..=1），供 UI 绘制波形。
    pub fn sample_waveform(&self, id: &str, buckets: u32) -> Result<Vec<f32>> {
        let bytes = self.read_blob(id)?;
        let pcm = wav::decode(&bytes)?;
        Ok(peaks(&pcm, buckets as usize))
    }

    // ------------------------------------------------------------------
    // 录音作品
    // ------------------------------------------------------------------

    /// 列出录音作品（新的在前）。
    pub fn tracks_list(&self) -> Vec<TrackInfo> {
        let mut v: Vec<_> = self.lock().tracks.values().cloned().collect();
        v.sort_by(|a, b| b.created_at_ms.cmp(&a.created_at_ms).then(a.id.cmp(&b.id)));
        v
    }

    pub fn track(&self, id: &str) -> Result<TrackInfo> {
        self.lock()
            .tracks
            .get(id)
            .cloned()
            .ok_or_else(|| LibraryError::not_found("track", id))
    }

    /// 录音作品的音频文件。
    pub fn track_path(&self, id: &str) -> Result<PathBuf> {
        check_id(id)?;
        self.track(id)?;
        Ok(self.track_file(id))
    }

    /// 保存一条录音作品（WAV 字节）。
    pub fn track_add(
        &self,
        bytes: &[u8],
        name: &str,
        kit_id: Option<&str>,
        bpm: Option<f64>,
    ) -> Result<TrackInfo> {
        let id = fsutil::new_id();
        self.track_add_with_id(&id, bytes, name, kit_id, bpm, fsutil::now_ms())
    }

    pub(crate) fn track_add_with_id(
        &self,
        id: &str,
        bytes: &[u8],
        name: &str,
        kit_id: Option<&str>,
        bpm: Option<f64>,
        created: i64,
    ) -> Result<TrackInfo> {
        check_id(id)?;
        let name = if name.trim().is_empty() {
            "Recording"
        } else {
            name.trim()
        };
        let info =
            track_info_from_bytes(id, name, bytes, kit_id.map(str::to_string), bpm, created)?;
        fsutil::atomic_write(&self.track_file(id), bytes, false)?;
        self.update_index(|idx| {
            idx.tracks.insert(id.to_string(), info.clone());
            idx.tombstones.remove(id);
            Ok(info)
        })
    }

    /// 从文件保存录音作品（录音线程写好的 WAV）。
    pub fn track_add_file(
        &self,
        path: &Path,
        name: &str,
        kit_id: Option<&str>,
    ) -> Result<TrackInfo> {
        let bytes = std::fs::read(path).ctx(|| format!("读取 {}", path.display()))?;
        self.track_add(&bytes, name, kit_id, None)
    }

    pub fn track_rename(&self, id: &str, name: &str) -> Result<TrackInfo> {
        self.update_index(|idx| {
            let t = idx
                .tracks
                .get_mut(id)
                .ok_or_else(|| LibraryError::not_found("track", id))?;
            t.name = name.trim().to_string();
            t.updated_at_ms = fsutil::now_ms();
            Ok(t.clone())
        })
    }

    pub fn track_delete(&self, id: &str) -> Result<()> {
        check_id(id)?;
        self.update_index(|idx| {
            idx.tracks
                .remove(id)
                .ok_or_else(|| LibraryError::not_found("track", id))?;
            idx.tombstones.insert(id.to_string(), fsutil::now_ms());
            Ok(())
        })?;
        let p = self.track_file(id);
        if p.exists() {
            std::fs::remove_file(&p).ctx(|| format!("删除 {}", p.display()))?;
        }
        Ok(())
    }

    /// 导出录音作品：WAV（写入 BWF `bext` 来源信息）或 `.dawproject`。
    pub fn track_export(
        &self,
        id: &str,
        dest: &Path,
        format: TrackExportFormat,
    ) -> Result<PathBuf> {
        let t = self.track(id)?;
        let bytes = std::fs::read(self.track_file(id)).ctx(|| format!("读取作品 {id}"))?;
        match format {
            TrackExportFormat::Wav => {
                let mut meta = wav::read_metadata(&bytes)?;
                let created = fsutil::rfc3339(t.created_at_ms);
                meta.bext = Some(wav::BextChunk {
                    description: t.name.clone(),
                    originator: "UltraPads".into(),
                    originator_reference: t.id.chars().take(32).collect(),
                    origination_date: created[..10].to_string(),
                    origination_time: created[11..19].to_string(),
                    version: 2,
                    ..wav::BextChunk::default()
                });
                let out = wav::write_metadata(&bytes, &meta)?;
                fsutil::atomic_write(dest, &out, false)?;
            }
            TrackExportFormat::DawProject => {
                let audio_path = format!("audio/{}.wav", up_format::path::slug(&t.name));
                let xml = dawproject::export_audio_track_project(&AudioTrackExport {
                    name: t.name.clone(),
                    audio_path: audio_path.clone(),
                    duration_secs: t.duration_secs,
                    sample_rate: t.sample_rate,
                    channels: u32::from(t.channels),
                    bpm: t.bpm.unwrap_or(120.0),
                    application_version: env!("CARGO_PKG_VERSION").into(),
                })?;
                let zip = crate::archive::zip_to_vec(&[
                    ("project.xml", xml.project_xml.as_bytes(), false),
                    ("metadata.xml", xml.metadata_xml.as_bytes(), false),
                    (audio_path.as_str(), &bytes, true),
                ])?;
                fsutil::atomic_write(dest, &zip, false)?;
            }
        }
        Ok(dest.to_path_buf())
    }

    /// 把录音作品转成样本（可分配给 pad）。
    pub fn track_to_sample(&self, id: &str) -> Result<SampleRecord> {
        let t = self.track(id)?;
        let bytes = std::fs::read(self.track_file(id)).ctx(|| format!("读取作品 {id}"))?;
        self.add_sample(&bytes, &t.name, SampleOrigin::Track)
    }
}

/// 计算峰值概要。
pub fn peaks(pcm: &wav::DecodedPcm, buckets: usize) -> Vec<f32> {
    let frames = pcm.frames();
    let ch = usize::from(pcm.channels.max(1));
    if buckets == 0 || frames == 0 {
        return vec![0.0; buckets];
    }
    (0..buckets)
        .map(|b| {
            let start = b * frames / buckets;
            let end = ((b + 1) * frames / buckets).max(start + 1).min(frames);
            pcm.samples[start * ch..end * ch]
                .iter()
                .fold(0f32, |m, s| m.max(s.abs()))
                .min(1.0)
        })
        .collect()
}
