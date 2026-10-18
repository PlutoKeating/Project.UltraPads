//! Session view (clip launcher): tracks × scenes grid of clip slots.

use serde::{Deserialize, Serialize};
use up_core::{PadId, SampleId};

/// Launch quantization for clips; superset of the pad `Quantize`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LaunchQuantize {
    /// Use the session's global quantize.
    #[default]
    Global,
    None,
    Sixteenth,
    Eighth,
    Quarter,
    Bar,
    TwoBars,
    FourBars,
}

impl LaunchQuantize {
    /// Grid length in beats (quarter notes) for a given bar length.
    pub fn beats(self, bar_len: f64) -> Option<f64> {
        match self {
            LaunchQuantize::Global | LaunchQuantize::None => None,
            LaunchQuantize::Sixteenth => Some(0.25),
            LaunchQuantize::Eighth => Some(0.5),
            LaunchQuantize::Quarter => Some(1.0),
            LaunchQuantize::Bar => Some(bar_len),
            LaunchQuantize::TwoBars => Some(2.0 * bar_len),
            LaunchQuantize::FourBars => Some(4.0 * bar_len),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LaunchMode {
    /// Start on press, play to end / loop.
    #[default]
    Trigger,
    /// Press toggles start/stop.
    Toggle,
    /// Plays while held.
    Gate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FollowActionKind {
    Stop,
    Again,
    Next,
    Previous,
    First,
    Last,
    Any,
    Other,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FollowAction {
    /// Time after launch, in beats.
    pub after_beats: f64,
    pub action: FollowActionKind,
    /// Probability `0..=1`.
    pub chance: f32,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct LaunchSettings {
    pub mode: LaunchMode,
    pub quantize: LaunchQuantize,
    pub follow_action: Option<FollowAction>,
}

/// Clip content.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum ClipContent {
    /// Audio clip referencing a sample.
    Audio {
        sample: SampleId,
        #[serde(default)]
        warp: bool,
    },
    /// Step-sequencer pattern reference (see [`crate::pattern`]).
    Pattern { pattern: String },
    /// Free MIDI-like notes.
    Notes { notes: Vec<Note> },
}

/// A note event (pad-addressed or raw MIDI key).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Note {
    pub time_beats: f64,
    pub duration_beats: f64,
    pub key: u8,
    pub velocity: f32,
    #[serde(default)]
    pub channel: u8,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Clip {
    pub id: String,
    pub name: String,
    pub content: ClipContent,
    pub length_beats: f64,
    #[serde(default)]
    pub looping: bool,
    #[serde(default)]
    pub launch: LaunchSettings,
    #[serde(default)]
    pub color: Option<up_core::ColorRole>,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ClipSlot {
    pub clip: Option<Clip>,
    /// Slot has a stop button.
    pub has_stop: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TrackKind {
    #[default]
    Audio,
    /// Drives a kit's pads (notes → pads).
    Pads,
    Instrument,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct SessionTrack {
    pub id: String,
    pub name: String,
    pub kind: TrackKind,
    /// Mixer channel id this track outputs to.
    pub channel: Option<String>,
    /// Optional pad mapping for `Pads` tracks.
    pub kit: Option<up_core::KitId>,
    pub slots: Vec<ClipSlot>,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Scene {
    pub id: String,
    pub name: String,
    pub tempo: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Session {
    pub tracks: Vec<SessionTrack>,
    pub scenes: Vec<Scene>,
    pub global_quantize: LaunchQuantize,
    /// Active pad bank per pads-track id.
    pub active_bank: Vec<(String, up_core::Bank)>,
    /// Pads armed for live recording into the session.
    pub armed_pads: Vec<PadId>,
}

impl Default for Session {
    fn default() -> Self {
        Self {
            tracks: Vec::new(),
            scenes: Vec::new(),
            global_quantize: LaunchQuantize::Bar,
            active_bank: Vec::new(),
            armed_pads: Vec::new(),
        }
    }
}
