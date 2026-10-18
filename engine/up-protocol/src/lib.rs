//! Engine protocol (`docs/API.md` §2).
//!
//! `Command` flows UI → engine, `EngineEvent` flows engine → UI. Both are
//! plain data and `serde`-serializable (used by the CLI event scripts, the
//! Hub and tests). Commands carrying heap data (e.g. `SampleId` strings) are
//! translated to allocation-free realtime commands by `up-engine` before
//! they reach the audio thread.

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
pub use up_core::{
    Bank, ColorRole, ErrorCode, KitId, PadId, PadMode, PadPlayState, Quantize, Retrigger, SampleId,
    TrackId, UpError,
};

/// Speed ratio bounds for [`Command::SetSpeed`].
pub const SPEED_MIN: f64 = 0.5;
pub const SPEED_MAX: f64 = 2.0;
/// Tempo bounds for [`Command::SetTempo`].
pub const BPM_MIN: f64 = 20.0;
pub const BPM_MAX: f64 = 400.0;

/// Transport sub-command.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum TransportCmd {
    Play,
    Stop,
    /// Seek to an absolute beat position.
    Seek(f64),
}

/// UI → engine command.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Command {
    PadDown {
        pad: PadId,
        velocity: f32,
    },
    PadUp {
        pad: PadId,
    },
    StopAll,
    SetTempo {
        bpm: f64,
    },
    /// Playback speed ratio, clamped to `0.5..=2.0`. Applies varispeed
    /// (pitch follows speed) to every voice and scales the transport tempo.
    SetSpeed {
        ratio: f64,
    },
    SetQuantize {
        q: Quantize,
    },
    SetPadParams {
        pad: PadId,
        params: PadParams,
    },
    SetMasterGain {
        gain: f32,
    },
    StartRecording,
    StopRecording,
    Transport(TransportCmd),
}

/// Per-pad parameters.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct PadParams {
    pub mode: PadMode,
    /// Linear gain, `0.0..=4.0`.
    pub gain: f32,
    /// `-1.0` (left) ..= `1.0` (right).
    pub pan: f32,
    /// Choke group this pad belongs to (SFZ `group`). Triggering the pad
    /// stops every *other* pad whose `choked_by` equals this group.
    pub choke_group: Option<u8>,
    /// Group that stops this pad (SFZ `off_by`). `None` = same as
    /// `choke_group` (symmetric mutual exclusion, Ref semantics).
    pub choked_by: Option<u8>,
    /// Fade-out used when this pad is choked, in ms (`None` = 5 ms).
    pub choke_release_ms: Option<f32>,
    /// Re-triggering the pad cuts its own previous voice (default `true`,
    /// Ref); `false` lets one-shots overlap.
    pub self_choke: bool,
    pub retrigger: Retrigger,
    pub color: ColorRole,
    /// Sample assigned to the pad (must be registered with the engine).
    pub sample: Option<SampleId>,
    pub start_frame: u64,
    pub end_frame: Option<u64>,
    /// Loop region for `Loop` pads (defaults to `start_frame..end_frame`).
    pub loop_start: Option<u64>,
    pub loop_end: Option<u64>,
    /// Overrides the global quantize for this pad. `None` = follow global for
    /// loops; one-shot/gate pads always start immediately unless overridden.
    pub quantize_override: Option<Quantize>,
    /// Realtime pitch in semitones (`-12.0..=12.0`). Implemented as a
    /// playback-rate multiplier `2^(pitch/12)` on top of the speed ratio
    /// (varispeed: length changes with pitch).
    pub pitch: f32,
}

/// Pitch bounds for [`PadParams::pitch`] (semitones).
pub const PITCH_MIN: f32 = -12.0;
pub const PITCH_MAX: f32 = 12.0;

impl Default for PadParams {
    fn default() -> Self {
        Self {
            mode: PadMode::OneShot,
            gain: 1.0,
            pan: 0.0,
            choke_group: None,
            choked_by: None,
            choke_release_ms: None,
            self_choke: true,
            retrigger: Retrigger::Restart,
            color: ColorRole::Blue,
            sample: None,
            start_frame: 0,
            end_frame: None,
            loop_start: None,
            loop_end: None,
            quantize_override: None,
            pitch: 0.0,
        }
    }
}

/// Recorder state.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum RecorderState {
    #[default]
    Idle,
    Recording,
    /// Recording stopped; the take is being finalised on the control thread.
    Saving,
}

/// Summary of a loaded/known kit.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct KitSummary {
    pub id: KitId,
    pub name: String,
    /// Number of pads with a sample assigned.
    pub pad_count: u32,
    pub bpm: Option<f64>,
    pub has_tutorial: bool,
}

/// Recorded take / track metadata.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct TrackInfo {
    pub id: TrackId,
    pub name: String,
    /// Creation time, unix epoch milliseconds.
    pub created_unix_ms: i64,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub channels: u16,
    /// Peak overview (0..=1), typically 128 buckets.
    pub waveform: Vec<f32>,
}

/// Hub (multi-device) events. Produced by `runtime/up-hub`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum HubEvent {
    ServerStarted { port: u16 },
    ServerStopped,
    PeerDiscovered { id: String, name: String },
    PeerLost { id: String },
    Paired { id: String, name: String },
    SyncProgress { peer: String, done: u64, total: u64 },
    ControllerConnected { peer: String },
    ControllerDisconnected,
}

/// Engine → UI event.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum EngineEvent {
    PadState {
        pad: PadId,
        state: PadPlayState,
    },
    Transport {
        playing: bool,
        beat: f64,
        /// Effective tempo (base bpm × speed ratio).
        bpm: f64,
        bar_len_beats: f64,
        /// Song clock: `beat × 60 / base_bpm`; advances at speed × real time.
        song_secs: f64,
    },
    Meters {
        master_peak: [f32; 2],
        master_rms: [f32; 2],
        /// 24 per-pad peak levels in flat pad order.
        pad_levels: Vec<f32>,
    },
    Recorder {
        state: RecorderState,
        elapsed_secs: f64,
    },
    KitLoaded {
        kit: KitSummary,
    },
    /// A recording was finalised and stored (extension to API v0.0.1).
    TrackSaved {
        track: TrackInfo,
    },
    /// Track preview playback started (`Some`) or ended (`None`).
    TrackPlayback {
        track: Option<TrackId>,
    },
    LibraryChanged,
    Hub(HubEvent),
    Error(UpError),
}

/// Per-pad state in a snapshot.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct PadSnapshot {
    pub pad: PadId,
    pub state: PadPlayState,
    pub params: PadParams,
    /// Length of the assigned sample in seconds (0 if none).
    pub sample_secs: f64,
}

/// Transport state.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TransportState {
    pub playing: bool,
    pub beat: f64,
    /// Song seconds (`beat × 60 / bpm`).
    pub song_secs: f64,
    /// Base tempo (before speed ratio).
    pub bpm: f64,
    pub speed: f64,
    pub beats_per_bar: u32,
    pub beat_unit: u32,
    pub quantize: Quantize,
}

impl Default for TransportState {
    fn default() -> Self {
        Self {
            playing: false,
            beat: 0.0,
            song_secs: 0.0,
            bpm: 120.0,
            speed: 1.0,
            beats_per_bar: 4,
            beat_unit: 4,
            quantize: Quantize::None,
        }
    }
}

/// Precise transport clock (`transport_clock()`), extrapolated from the
/// last audio block to "now". Used by the UI for tutorial judgement.
#[derive(Debug, Clone, Copy, PartialEq, Default, Serialize, Deserialize)]
pub struct TransportClock {
    pub playing: bool,
    pub beat: f64,
    /// Song seconds (time at speed 1.0); see [`EngineEvent::Transport`].
    pub song_secs: f64,
    /// Base tempo.
    pub bpm: f64,
    pub speed: f64,
}

/// Full engine snapshot (`snapshot()`).
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct EngineSnapshot {
    pub pads: Vec<PadSnapshot>,
    pub transport: TransportState,
    pub kit: Option<KitSummary>,
    pub master_gain: f32,
    pub recorder: RecorderState,
    pub recorder_elapsed_secs: f64,
    pub sample_rate: u32,
    pub active_voices: u32,
}

/// A timed command for offline rendering scripts and the CLI.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TimedCommand {
    /// Time in seconds from the start of the render.
    pub at_secs: f64,
    pub cmd: Command,
}

/// Offline render script.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RenderScript {
    /// Total render duration in seconds.
    pub duration_secs: f64,
    /// Commands, any order (sorted before rendering).
    pub events: Vec<TimedCommand>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn command_json_roundtrip() {
        let cmds = vec![
            Command::PadDown {
                pad: PadId { bank: 0, index: 3 },
                velocity: 0.8,
            },
            Command::SetQuantize { q: Quantize::Bar },
            Command::Transport(TransportCmd::Seek(4.0)),
            Command::SetPadParams {
                pad: PadId { bank: 1, index: 0 },
                params: PadParams {
                    mode: PadMode::Loop,
                    choke_group: Some(2),
                    sample: Some(SampleId::new("abc")),
                    ..Default::default()
                },
            },
        ];
        for c in cmds {
            let s = serde_json::to_string(&c).unwrap();
            let back: Command = serde_json::from_str(&s).unwrap();
            assert_eq!(back, c);
        }
    }

    #[test]
    fn script_from_json() {
        let s = r#"{"duration_secs":2.0,"events":[
            {"at_secs":0.0,"cmd":{"PadDown":{"pad":{"bank":0,"index":0},"velocity":1.0}}},
            {"at_secs":1.0,"cmd":"StopAll"}]}"#;
        let script: RenderScript = serde_json::from_str(s).unwrap();
        assert_eq!(script.events.len(), 2);
        assert_eq!(script.events[1].cmd, Command::StopAll);
    }

    #[test]
    fn pad_params_defaults_fill_missing_fields() {
        let p: PadParams = serde_json::from_str(r#"{"mode":"Gate"}"#).unwrap();
        assert_eq!(p.mode, PadMode::Gate);
        assert_eq!(p.gain, 1.0);
        assert_eq!(p.pitch, 0.0);
    }

    #[test]
    fn event_roundtrip() {
        let e = EngineEvent::Meters {
            master_peak: [0.5, 0.4],
            master_rms: [0.1, 0.1],
            pad_levels: vec![0.0; 24],
        };
        let s = serde_json::to_string(&e).unwrap();
        assert_eq!(serde_json::from_str::<EngineEvent>(&s).unwrap(), e);
    }
}
