//! Kit documents.

use crate::TimeSignature;
use crate::tutorial::TutorialChart;
use serde::{Deserialize, Serialize};
use up_core::{ColorRole, KitId, PadId, PadMode, Quantize, Retrigger, SampleId};
use up_protocol::{KitSummary, PadParams};

/// Reference to a sample file belonging to a kit.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct SampleRef {
    pub id: SampleId,
    /// Path relative to the kit root (e.g. `samples/kick.wav`).
    pub path: Option<String>,
    pub name: String,
    /// BLAKE3 hex digest of the file, if known.
    pub blake3: Option<String>,
    pub sample_rate: Option<u32>,
    pub channels: Option<u16>,
    pub frames: Option<u64>,
}

/// How a loop follows the project tempo.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Stretch {
    /// Play at the recorded speed.
    #[default]
    None,
    /// Time-stretch to the tempo, keeping pitch (Signalsmith Stretch, planned).
    Beats,
    /// Varispeed to the tempo (pitch follows).
    Repitch,
}

/// Loop metadata (from acid/smpl chunks, file name or the user).
#[derive(Debug, Clone, Copy, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct LoopMeta {
    pub bpm: Option<f64>,
    pub beats: Option<f64>,
    pub root_note: Option<u8>,
    /// Time signature of the loop, if different from the kit's.
    pub time_signature: Option<crate::TimeSignature>,
    pub stretch: Stretch,
}

/// One sample layer of a pad (SFZ `<region>`): velocity range, round-robin
/// position, trim and loop points.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct SampleLayer {
    pub sample: SampleRef,
    /// Velocity range (MIDI 0..=127, inclusive).
    pub lovel: u8,
    pub hivel: u8,
    /// Round-robin position (1-based), see [`PadDoc::seq_length`].
    pub seq_position: Option<u32>,
    /// Random selection range `[lo, hi)` within `0..1`.
    pub rand_range: Option<[f32; 2]>,
    pub root_key: Option<u8>,
    pub start_frame: Option<u64>,
    /// Inclusive end frame (SFZ `end`).
    pub end_frame: Option<u64>,
    pub loop_start: Option<u64>,
    pub loop_end: Option<u64>,
    pub transpose: i32,
    pub tune_cents: i32,
    pub volume_db: f32,
}

impl Default for SampleLayer {
    fn default() -> Self {
        Self {
            sample: SampleRef::default(),
            lovel: 0,
            hivel: 127,
            seq_position: None,
            rand_range: None,
            root_key: None,
            start_frame: None,
            end_frame: None,
            loop_start: None,
            loop_end: None,
            transpose: 0,
            tune_cents: 0,
            volume_db: 0.0,
        }
    }
}

impl SampleLayer {
    pub fn new(sample: SampleRef) -> Self {
        Self {
            sample,
            ..Default::default()
        }
    }

    /// Whether this layer answers `velocity` (0..=1).
    pub fn matches_velocity(&self, velocity: f32) -> bool {
        let v = (velocity.clamp(0.0, 1.0) * 127.0).round() as u8;
        (self.lovel..=self.hivel).contains(&v)
    }
}

/// Fade used when a pad is choked.
#[derive(Debug, Clone, Copy, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum ChokeRelease {
    /// Short de-click fade (≈5 ms, SFZ `off_mode=fast`).
    #[default]
    Fast,
    /// Normal release (SFZ `off_mode=normal`).
    Normal,
    /// Fade over the given time (SFZ `off_mode=time` + `off_time`).
    Time { secs: f32 },
}

/// One pad of a kit.
///
/// Sample layers: `layers` is authoritative when non-empty (velocity layers,
/// round-robin). `sample` / `start_frame` / `end_frame` describe the
/// **primary** layer the v0.0.1 engine plays and must mirror `layers[0]`
/// ([`PadDoc::normalize`] keeps them in sync; single-layer pads may leave
/// `layers` empty).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct PadDoc {
    pub pad: PadId,
    pub name: String,
    /// MIDI note mapped to this pad (default `36 + flat`).
    pub note: u8,
    pub mode: PadMode,
    /// **Linear** gain (1.0 = unity, 0.5 ≈ −6 dB). Formats storing dB
    /// convert at the boundary.
    pub gain: f32,
    pub pan: f32,
    /// Choke group this pad belongs to (SFZ `group`).
    pub choke_group: Option<u8>,
    /// Group that stops this pad (SFZ `off_by`); `None` = `choke_group`
    /// (symmetric mutual exclusion).
    pub choked_by: Option<u8>,
    pub choke_release: ChokeRelease,
    /// Re-triggering cuts the pad's previous voice (SFZ `note_polyphony=1`).
    pub self_choke: bool,
    pub retrigger: Retrigger,
    /// Exclusive launch tag (clip-launcher style: one loop per tag plays).
    pub exclusive: Option<String>,
    pub color: ColorRole,
    pub sample: Option<SampleRef>,
    pub start_frame: u64,
    pub end_frame: Option<u64>,
    /// All sample layers (see type docs).
    pub layers: Vec<SampleLayer>,
    /// Round-robin cycle length (SFZ `seq_length`).
    pub seq_length: Option<u32>,
    /// Launch quantize; `None` = follow the global quantize.
    pub quantize: Option<Quantize>,
    /// Pitch shift in semitones (-12..=12). The v0.0.1 engine applies it in
    /// realtime as a playback-rate multiplier (`PadParams::pitch`).
    pub pitch_semitones: f32,
    /// Offline time ratio applied at load/edit time (0.5..=2.0).
    pub time_ratio: f32,
    /// Fade-in / fade-out applied by the editor (ms).
    pub fade_in_ms: f32,
    pub fade_out_ms: f32,
    pub loop_meta: Option<LoopMeta>,
}

impl Default for PadDoc {
    fn default() -> Self {
        Self {
            pad: PadId::default(),
            name: String::new(),
            note: 36,
            mode: PadMode::OneShot,
            gain: 1.0,
            pan: 0.0,
            choke_group: None,
            choked_by: None,
            choke_release: ChokeRelease::Fast,
            self_choke: true,
            retrigger: Retrigger::Restart,
            exclusive: None,
            color: ColorRole::Blue,
            sample: None,
            start_frame: 0,
            end_frame: None,
            layers: Vec::new(),
            seq_length: None,
            quantize: None,
            pitch_semitones: 0.0,
            time_ratio: 1.0,
            fade_in_ms: 0.0,
            fade_out_ms: 0.0,
            loop_meta: None,
        }
    }
}

impl PadDoc {
    pub fn new(pad: PadId) -> Self {
        Self {
            pad,
            note: pad.default_note(),
            ..Default::default()
        }
    }

    /// Make `sample`/`start_frame`/`end_frame` mirror `layers[0]`.
    pub fn normalize(&mut self) {
        if let Some(l) = self.layers.first() {
            self.sample = Some(l.sample.clone());
            self.start_frame = l.start_frame.unwrap_or(0);
            self.end_frame = l.end_frame.map(|e| e.saturating_add(1));
        }
    }

    /// Layer to play for `velocity` and round-robin counter `rr` (1-based),
    /// falling back to the primary layer.
    pub fn select_layer(&self, velocity: f32, rr: u32) -> Option<&SampleLayer> {
        let len = self.seq_length.unwrap_or(1).max(1);
        let pos = (rr.saturating_sub(1) % len) + 1;
        self.layers
            .iter()
            .find(|l| l.matches_velocity(velocity) && l.seq_position.is_none_or(|p| p == pos))
            .or_else(|| self.layers.iter().find(|l| l.matches_velocity(velocity)))
            .or(self.layers.first())
    }

    /// Engine parameters for this pad (primary layer).
    pub fn to_params(&self) -> PadParams {
        let primary = self.layers.first();
        PadParams {
            mode: self.mode,
            gain: self.gain,
            pan: self.pan,
            choke_group: self.choke_group,
            choked_by: self.choked_by,
            choke_release_ms: match self.choke_release {
                ChokeRelease::Fast | ChokeRelease::Normal => None,
                ChokeRelease::Time { secs } => Some(secs * 1000.0),
            },
            self_choke: self.self_choke,
            retrigger: self.retrigger,
            color: self.color,
            sample: primary
                .map(|l| l.sample.id.clone())
                .or_else(|| self.sample.as_ref().map(|s| s.id.clone())),
            start_frame: primary
                .and_then(|l| l.start_frame)
                .unwrap_or(self.start_frame),
            end_frame: primary
                .and_then(|l| l.end_frame.map(|e| e.saturating_add(1)))
                .or(self.end_frame),
            loop_start: primary.and_then(|l| l.loop_start),
            loop_end: primary.and_then(|l| l.loop_end.map(|e| e.saturating_add(1))),
            quantize_override: self.quantize,
            pitch: self.pitch_semitones.clamp(-12.0, 12.0),
        }
    }
}

/// Kit metadata for display (author, inspiration, cover…).
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KitMeta {
    pub description: Option<String>,
    /// Theme color (`#RRGGBB`) for list/preview tinting.
    pub theme_color: Option<String>,
    pub source: Option<KitSource>,
    pub author: Option<String>,
    pub inspired_by_artist: Option<String>,
    pub inspired_by_title: Option<String>,
    pub genre: Vec<String>,
    pub tags: Vec<String>,
    pub cover: Option<String>,
    pub license: Option<String>,
    pub video_url: Option<String>,
}

/// Where a kit came from.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KitSource {
    /// `upkit` | `sfz` | `wav-folder` | `compat-android` | `compat-ios` | `generated` | `user` …
    pub kind: String,
    pub original_id: Option<String>,
    pub original_name: Option<String>,
}

/// A kit (one song): one or more sound groups of 12 pads (up to
/// [`up_core::BANK_COUNT`] groups) plus metadata.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KitDoc {
    pub schema_version: u32,
    pub id: KitId,
    pub name: String,
    pub bpm: Option<f64>,
    pub time_signature: TimeSignature,
    pub pads: Vec<PadDoc>,
    /// Number of sound groups (A, B, C …). `0` = derive from the pads
    /// (highest group in use + 1); see [`KitDoc::groups`]. Set explicitly by
    /// the editor so that a newly added, still empty group is kept.
    pub group_count: u8,
    pub tutorial: Option<TutorialChart>,
    pub meta: KitMeta,
}

impl Default for KitDoc {
    fn default() -> Self {
        Self {
            schema_version: crate::KIT_SCHEMA_VERSION,
            id: KitId::default(),
            name: String::new(),
            bpm: None,
            time_signature: TimeSignature::default(),
            pads: Vec::new(),
            group_count: 0,
            tutorial: None,
            meta: KitMeta::default(),
        }
    }
}

impl KitDoc {
    pub fn pad(&self, pad: PadId) -> Option<&PadDoc> {
        self.pads.iter().find(|p| p.pad == pad)
    }

    pub fn pad_mut(&mut self, pad: PadId) -> Option<&mut PadDoc> {
        self.pads.iter_mut().find(|p| p.pad == pad)
    }

    /// True if any pad with a sample lives outside group A.
    pub fn uses_bank_b(&self) -> bool {
        self.pads
            .iter()
            .any(|p| p.pad.bank > 0 && p.sample.is_some())
    }

    /// Effective number of sound groups: the explicit [`KitDoc::group_count`],
    /// at least as many as the pads in [`KitDoc::pads`] need (a group cannot be
    /// dropped while it still has pads — the editor removes them first), at
    /// least 1, at most [`up_core::BANK_COUNT`].
    pub fn groups(&self) -> u8 {
        let used = self.pads.iter().map(|p| p.pad.bank + 1).max().unwrap_or(1);
        self.group_count
            .max(used)
            .clamp(1, up_core::BANK_COUNT as u8)
    }

    pub fn summary(&self) -> KitSummary {
        KitSummary {
            id: self.id.clone(),
            name: self.name.clone(),
            pad_count: self.pads.iter().filter(|p| p.sample.is_some()).count() as u32,
            group_count: u32::from(self.groups()),
            bpm: self.bpm,
            has_tutorial: self.tutorial.as_ref().is_some_and(|t| !t.is_empty()),
        }
    }

    /// Validate structural invariants (unique, in-range pads).
    pub fn validate(&self) -> Result<(), up_core::UpError> {
        if self.group_count as usize > up_core::BANK_COUNT {
            return Err(up_core::UpError::format(format!(
                "too many sound groups: {} (max {})",
                self.group_count,
                up_core::BANK_COUNT
            )));
        }
        let mut seen = [false; up_core::PAD_COUNT];
        for p in &self.pads {
            if !p.pad.is_valid() {
                return Err(up_core::UpError::format(format!(
                    "pad out of range: {}",
                    p.pad
                )));
            }
            if std::mem::replace(&mut seen[p.pad.flat()], true) {
                return Err(up_core::UpError::format(format!("duplicate pad {}", p.pad)));
            }
            if !(0.5..=2.0).contains(&p.time_ratio) || !(-12.0..=12.0).contains(&p.pitch_semitones)
            {
                return Err(up_core::UpError::format(format!(
                    "pad {}: pitch/time out of range",
                    p.pad
                )));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_kit() -> KitDoc {
        let mut pad = PadDoc::new(PadId { bank: 1, index: 2 });
        pad.mode = PadMode::Loop;
        pad.choke_group = Some(2);
        pad.sample = Some(SampleRef {
            id: SampleId::new("s1"),
            path: Some("samples/loop.wav".into()),
            name: "loop".into(),
            ..Default::default()
        });
        KitDoc {
            id: KitId::new("k1"),
            name: "Sunset".into(),
            bpm: Some(80.0),
            pads: vec![pad, PadDoc::new(PadId { bank: 0, index: 0 })],
            ..Default::default()
        }
    }

    #[test]
    fn group_count_is_explicit_or_derived_and_capped() {
        let mut k = KitDoc::default();
        assert_eq!(k.groups(), 1, "空 Kit 至少一组");
        k.pads.push(PadDoc::new(PadId { bank: 2, index: 0 }));
        assert_eq!(k.groups(), 3, "按 pad 所在的组推断");
        k.group_count = 5;
        assert_eq!(k.groups(), 5, "显式组数（含空组）");
        k.group_count = 1;
        assert_eq!(k.groups(), 3, "不会少于用到的组");
        k.group_count = 200;
        assert_eq!(usize::from(k.groups()), up_core::BANK_COUNT);
        assert!(k.validate().is_err());
    }

    #[test]
    fn json_roundtrip_and_camel_case() {
        let k = sample_kit();
        let j = serde_json::to_string_pretty(&k).unwrap();
        assert!(j.contains("\"schemaVersion\""));
        assert!(j.contains("\"chokeGroup\""));
        let back: KitDoc = serde_json::from_str(&j).unwrap();
        assert_eq!(back, k);
        assert!(k.validate().is_ok());
        assert!(k.uses_bank_b());
        let s = k.summary();
        assert_eq!(s.pad_count, 1);
        assert_eq!(k.pads[0].note, 36 + 14);
    }

    #[test]
    fn to_params_maps_fields() {
        let k = sample_kit();
        let p = k.pads[0].to_params();
        assert_eq!(p.mode, PadMode::Loop);
        assert_eq!(p.sample, Some(SampleId::new("s1")));
        assert_eq!(p.choke_group, Some(2));
    }

    #[test]
    fn duplicate_pads_rejected() {
        let mut k = sample_kit();
        k.pads.push(PadDoc::new(PadId { bank: 0, index: 0 }));
        assert!(k.validate().is_err());
    }

    #[test]
    fn layers_drive_params_and_selection() {
        let r = |id: &str| SampleRef {
            id: SampleId::new(id),
            ..Default::default()
        };
        let mut p = PadDoc::new(PadId { bank: 0, index: 1 });
        p.mode = PadMode::Loop;
        p.seq_length = Some(2);
        p.choke_group = Some(4);
        p.choked_by = Some(3);
        p.choke_release = ChokeRelease::Time { secs: 0.03 };
        p.layers = vec![
            SampleLayer {
                hivel: 100,
                seq_position: Some(1),
                loop_start: Some(10),
                loop_end: Some(99),
                end_frame: Some(199),
                ..SampleLayer::new(r("soft1"))
            },
            SampleLayer {
                hivel: 100,
                seq_position: Some(2),
                ..SampleLayer::new(r("soft2"))
            },
            SampleLayer {
                lovel: 101,
                ..SampleLayer::new(r("hard"))
            },
        ];
        p.normalize();
        assert_eq!(p.sample.as_ref().unwrap().id.as_str(), "soft1");
        let params = p.to_params();
        assert_eq!(params.sample.as_ref().unwrap().as_str(), "soft1");
        assert_eq!(
            (params.loop_start, params.loop_end, params.end_frame),
            (Some(10), Some(100), Some(200))
        );
        assert_eq!((params.choke_group, params.choked_by), (Some(4), Some(3)));
        assert!((params.choke_release_ms.unwrap() - 30.0).abs() < 1e-3);
        assert_eq!(p.select_layer(0.5, 2).unwrap().sample.id.as_str(), "soft2");
        assert_eq!(p.select_layer(0.5, 3).unwrap().sample.id.as_str(), "soft1");
        assert_eq!(p.select_layer(1.0, 1).unwrap().sample.id.as_str(), "hard");
        let j = serde_json::to_string(&p).unwrap();
        assert_eq!(serde_json::from_str::<PadDoc>(&j).unwrap(), p);
    }
}
