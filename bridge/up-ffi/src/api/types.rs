//! DTOs mirrored to Dart. They intentionally duplicate engine types so the
//! engine has no FFI dependencies; conversions live at the bottom.

use up_core as core;
use up_protocol as proto;

/// Error category (mirrors `up_core::ErrorCode`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCode {
    InvalidArgument,
    NotFound,
    NotInitialized,
    QueueFull,
    Audio,
    Codec,
    Io,
    Format,
    PermissionDenied,
    InvalidState,
    NotImplemented,
    Internal,
}

/// Error returned by every fallible function (thrown in Dart).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UpError {
    pub code: ErrorCode,
    pub message: String,
}

impl UpError {
    pub(crate) fn not_implemented(what: &str) -> Self {
        Self {
            code: ErrorCode::NotImplemented,
            message: format!("{what} is not implemented yet"),
        }
    }
}

impl std::fmt::Display for UpError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}: {}", self.code, self.message)
    }
}

impl std::error::Error for UpError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PadId {
    /// 0 = A, 1 = B.
    pub bank: u8,
    /// 0..12.
    pub index: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Bank {
    A,
    B,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PadMode {
    OneShot,
    Loop,
    Gate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Quantize {
    None,
    Sixteenth,
    Eighth,
    Beat,
    Bar,
    TwoBars,
    FourBars,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Retrigger {
    Restart,
    Continue,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PadPlayState {
    Idle,
    Pending,
    Playing,
    Stopping,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ColorRole {
    Blue,
    Orange,
    Pink,
    Green,
    Purple,
    Yellow,
    Red,
    Cyan,
    Lime,
    Grey,
    Neutral,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PadParams {
    pub mode: PadMode,
    pub gain: f32,
    pub pan: f32,
    /// Group this pad belongs to (triggering it chokes pads `choked_by` it).
    pub choke_group: Option<u8>,
    /// Group that chokes this pad (`None` = same as `choke_group`).
    pub choked_by: Option<u8>,
    /// Fade-out when choked, ms (`None` = 5 ms).
    pub choke_release_ms: Option<f32>,
    /// Re-trigger cuts the pad's previous voice (default true).
    pub self_choke: bool,
    pub retrigger: Retrigger,
    pub color: ColorRole,
    /// Sample id (must be registered: loaded kit, mic recording).
    pub sample: Option<String>,
    pub start_frame: u64,
    pub end_frame: Option<u64>,
    pub loop_start: Option<u64>,
    pub loop_end: Option<u64>,
    pub quantize_override: Option<Quantize>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TransportCmd {
    Play,
    Stop,
    Seek(f64),
}

/// UI → engine command (`docs/API.md` §2).
#[derive(Debug, Clone, PartialEq)]
pub enum Command {
    PadDown { pad: PadId, velocity: f32 },
    PadUp { pad: PadId },
    StopAll,
    SetTempo { bpm: f64 },
    SetSpeed { ratio: f64 },
    SetQuantize { q: Quantize },
    SetPadParams { pad: PadId, params: PadParams },
    SetMasterGain { gain: f32 },
    StartRecording,
    StopRecording,
    Transport(TransportCmd),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecorderState {
    Idle,
    Recording,
    Saving,
}

/// Kit summary. The base fields come from the engine; the library fields
/// are filled by `library_*` calls and empty in engine events.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct KitSummary {
    pub id: String,
    pub name: String,
    /// Pads with a sample.
    pub pad_count: u32,
    pub bpm: Option<f64>,
    pub has_tutorial: bool,
    pub description: Option<String>,
    pub authors: Vec<String>,
    pub genres: Vec<String>,
    pub tags: Vec<String>,
    /// `#RRGGBB`.
    pub theme_color: Option<String>,
    pub inspired_by: Option<String>,
    /// Absolute path of the cover image, if any.
    pub cover_path: Option<String>,
    pub favorite: bool,
    pub source_kind: String,
    pub last_used_at_ms: Option<i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TrackInfo {
    pub id: String,
    pub name: String,
    pub created_unix_ms: i64,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub channels: u16,
    pub waveform: Vec<f32>,
}

#[derive(Debug, Clone, PartialEq)]
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
#[derive(Debug, Clone, PartialEq)]
pub enum EngineEvent {
    PadState {
        pad: PadId,
        state: PadPlayState,
    },
    Transport {
        playing: bool,
        beat: f64,
        bpm: f64,
        bar_len_beats: f64,
        song_secs: f64,
    },
    Meters {
        master_peak: Vec<f32>,
        master_rms: Vec<f32>,
        pad_levels: Vec<f32>,
    },
    Recorder {
        state: RecorderState,
        elapsed_secs: f64,
    },
    KitLoaded {
        kit: KitSummary,
    },
    TrackSaved {
        track: TrackInfo,
    },
    TrackPlayback {
        track: Option<String>,
    },
    LibraryChanged,
    Hub(HubEvent),
    Error(UpError),
}

#[derive(Debug, Clone, PartialEq)]
pub struct PadSnapshot {
    pub pad: PadId,
    pub state: PadPlayState,
    pub params: PadParams,
    pub sample_secs: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TransportState {
    pub playing: bool,
    pub beat: f64,
    pub song_secs: f64,
    pub bpm: f64,
    pub speed: f64,
    pub beats_per_bar: u32,
    pub beat_unit: u32,
    pub quantize: Quantize,
}

#[derive(Debug, Clone, PartialEq)]
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

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TransportClock {
    pub playing: bool,
    pub beat: f64,
    pub song_secs: f64,
    pub bpm: f64,
    pub speed: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppDirs {
    pub data_dir: String,
    pub cache_dir: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct EngineInfo {
    pub version: String,
    pub sample_rate: u32,
    pub graph_backend: String,
    pub platform: String,
    pub data_dir: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct AudioConfig {
    pub buffer_frames: Option<u32>,
    pub sample_rate: Option<u32>,
    pub output_device: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct AudioStatus {
    pub running: bool,
    pub host: String,
    pub device: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub buffer_frames: Option<u32>,
    pub sample_format: String,
    pub output_latency_ms: Option<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct AudioDeviceInfo {
    pub id: String,
    pub name: String,
    pub is_input: bool,
    pub is_output: bool,
    pub is_default_output: bool,
    pub is_default_input: bool,
    pub default_sample_rate: Option<u32>,
    pub max_output_channels: u16,
    pub max_input_channels: u16,
    pub min_buffer_frames: Option<u32>,
    pub max_buffer_frames: Option<u32>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TutorialAction {
    Tap,
    LoopToggle,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TutorialEvent {
    /// Song seconds at speed 1.0 (compare with `TransportClock.song_secs`).
    pub time_secs: f64,
    /// Target pad, or `None` when the step is a page switch.
    pub pad: Option<PadId>,
    pub page_switch: Option<Bank>,
    pub color: Option<ColorRole>,
    pub action: TutorialAction,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TutorialLesson {
    pub events: Vec<TutorialEvent>,
    pub duration_secs: f64,
    pub song_start_secs: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TutorialChart {
    pub events: Vec<TutorialEvent>,
    pub lessons: Vec<TutorialLesson>,
    pub bpm: Option<f64>,
    /// PERFECT window (± ms, real time). Default 80.
    pub perfect_ms: f64,
    /// Beyond this error a press counts as a miss. Default 600.
    pub miss_ms: f64,
    pub timed: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Judgement {
    Perfect,
    TooFast,
    TooSlow,
    Miss,
}

/// Result of `library_import`.
#[derive(Debug, Clone, PartialEq)]
pub struct ImportReport {
    /// `upkit` | `sfz` | `wav-folder` | `compat:<source>` | `sample`.
    pub kind: String,
    pub kits: Vec<KitSummary>,
    /// Kits that were already in the library (identical content).
    pub duplicates: u32,
    /// Ids of newly stored standalone samples.
    pub samples: Vec<String>,
    pub catalog_entries: u32,
    pub warnings: Vec<String>,
}

/// Sort order for `library_search_kits`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KitSort {
    Name,
    RecentlyUsed,
    RecentlyAdded,
    Favorited,
}

/// Standalone library sample (mic recordings, imports).
#[derive(Debug, Clone, PartialEq)]
pub struct SampleInfo {
    pub id: String,
    pub name: String,
    pub origin: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub duration_secs: f64,
    pub created_unix_ms: i64,
}

/// Hub peer (owned by `runtime/up-hub`).
#[derive(Debug, Clone, PartialEq)]
pub struct HubPeer {
    pub id: String,
    pub name: String,
    pub address: String,
    pub port: u16,
    pub paired: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PairedDevice {
    pub id: String,
    pub name: String,
    pub paired_unix_ms: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct SyncReport {
    pub pulled: u32,
    pub pushed: u32,
    pub conflicts: u32,
    pub bytes: u64,
}

// ---------------------------------------------------------------- conversions

impl From<core::UpError> for UpError {
    fn from(e: core::UpError) -> Self {
        use core::ErrorCode as C;
        let code = match e.code {
            C::InvalidArgument => ErrorCode::InvalidArgument,
            C::NotFound => ErrorCode::NotFound,
            C::NotInitialized => ErrorCode::NotInitialized,
            C::QueueFull => ErrorCode::QueueFull,
            C::Audio => ErrorCode::Audio,
            C::Codec => ErrorCode::Codec,
            C::Io => ErrorCode::Io,
            C::Format => ErrorCode::Format,
            C::PermissionDenied => ErrorCode::PermissionDenied,
            C::InvalidState => ErrorCode::InvalidState,
            C::NotImplemented => ErrorCode::NotImplemented,
            C::Internal => ErrorCode::Internal,
        };
        Self {
            code,
            message: e.message,
        }
    }
}

impl From<core::PadId> for PadId {
    fn from(p: core::PadId) -> Self {
        Self {
            bank: p.bank,
            index: p.index,
        }
    }
}

impl From<PadId> for core::PadId {
    fn from(p: PadId) -> Self {
        Self {
            bank: p.bank,
            index: p.index,
        }
    }
}

impl From<core::Bank> for Bank {
    fn from(b: core::Bank) -> Self {
        match b {
            core::Bank::A => Bank::A,
            core::Bank::B => Bank::B,
        }
    }
}

macro_rules! enum_map {
    ($a:ty, $b:ty, $($v:ident),+) => {
        impl From<$a> for $b {
            fn from(x: $a) -> Self {
                match x { $(<$a>::$v => <$b>::$v),+ }
            }
        }
        impl From<$b> for $a {
            fn from(x: $b) -> Self {
                match x { $(<$b>::$v => <$a>::$v),+ }
            }
        }
    };
}

enum_map!(core::PadMode, PadMode, OneShot, Loop, Gate);
enum_map!(
    core::Quantize,
    Quantize,
    None,
    Sixteenth,
    Eighth,
    Beat,
    Bar,
    TwoBars,
    FourBars
);
enum_map!(core::Retrigger, Retrigger, Restart, Continue);
enum_map!(
    core::PadPlayState,
    PadPlayState,
    Idle,
    Pending,
    Playing,
    Stopping
);
enum_map!(
    core::ColorRole,
    ColorRole,
    Blue,
    Orange,
    Pink,
    Green,
    Purple,
    Yellow,
    Red,
    Cyan,
    Lime,
    Grey,
    Neutral
);
enum_map!(proto::RecorderState, RecorderState, Idle, Recording, Saving);

impl From<proto::PadParams> for PadParams {
    fn from(p: proto::PadParams) -> Self {
        Self {
            mode: p.mode.into(),
            gain: p.gain,
            pan: p.pan,
            choke_group: p.choke_group,
            choked_by: p.choked_by,
            choke_release_ms: p.choke_release_ms,
            self_choke: p.self_choke,
            retrigger: p.retrigger.into(),
            color: p.color.into(),
            sample: p.sample.map(|s| s.0),
            start_frame: p.start_frame,
            end_frame: p.end_frame,
            loop_start: p.loop_start,
            loop_end: p.loop_end,
            quantize_override: p.quantize_override.map(Into::into),
        }
    }
}

impl From<PadParams> for proto::PadParams {
    fn from(p: PadParams) -> Self {
        Self {
            mode: p.mode.into(),
            gain: p.gain,
            pan: p.pan,
            choke_group: p.choke_group,
            choked_by: p.choked_by,
            choke_release_ms: p.choke_release_ms,
            self_choke: p.self_choke,
            retrigger: p.retrigger.into(),
            color: p.color.into(),
            sample: p.sample.map(core::SampleId),
            start_frame: p.start_frame,
            end_frame: p.end_frame,
            loop_start: p.loop_start,
            loop_end: p.loop_end,
            quantize_override: p.quantize_override.map(Into::into),
        }
    }
}

impl From<Command> for proto::Command {
    fn from(c: Command) -> Self {
        use proto::Command as P;
        match c {
            Command::PadDown { pad, velocity } => P::PadDown {
                pad: pad.into(),
                velocity,
            },
            Command::PadUp { pad } => P::PadUp { pad: pad.into() },
            Command::StopAll => P::StopAll,
            Command::SetTempo { bpm } => P::SetTempo { bpm },
            Command::SetSpeed { ratio } => P::SetSpeed { ratio },
            Command::SetQuantize { q } => P::SetQuantize { q: q.into() },
            Command::SetPadParams { pad, params } => P::SetPadParams {
                pad: pad.into(),
                params: params.into(),
            },
            Command::SetMasterGain { gain } => P::SetMasterGain { gain },
            Command::StartRecording => P::StartRecording,
            Command::StopRecording => P::StopRecording,
            Command::Transport(t) => P::Transport(match t {
                TransportCmd::Play => proto::TransportCmd::Play,
                TransportCmd::Stop => proto::TransportCmd::Stop,
                TransportCmd::Seek(b) => proto::TransportCmd::Seek(b),
            }),
        }
    }
}

impl From<proto::KitSummary> for KitSummary {
    fn from(k: proto::KitSummary) -> Self {
        Self {
            id: k.id.0,
            name: k.name,
            pad_count: k.pad_count,
            bpm: k.bpm,
            has_tutorial: k.has_tutorial,
            ..Default::default()
        }
    }
}

impl From<proto::TrackInfo> for TrackInfo {
    fn from(t: proto::TrackInfo) -> Self {
        Self {
            id: t.id.0,
            name: t.name,
            created_unix_ms: t.created_unix_ms,
            duration_secs: t.duration_secs,
            sample_rate: t.sample_rate,
            channels: t.channels,
            waveform: t.waveform,
        }
    }
}

impl From<proto::HubEvent> for HubEvent {
    fn from(h: proto::HubEvent) -> Self {
        use proto::HubEvent as P;
        match h {
            P::ServerStarted { port } => HubEvent::ServerStarted { port },
            P::ServerStopped => HubEvent::ServerStopped,
            P::PeerDiscovered { id, name } => HubEvent::PeerDiscovered { id, name },
            P::PeerLost { id } => HubEvent::PeerLost { id },
            P::Paired { id, name } => HubEvent::Paired { id, name },
            P::SyncProgress { peer, done, total } => HubEvent::SyncProgress { peer, done, total },
            P::ControllerConnected { peer } => HubEvent::ControllerConnected { peer },
            P::ControllerDisconnected => HubEvent::ControllerDisconnected,
        }
    }
}

impl From<proto::EngineEvent> for EngineEvent {
    fn from(e: proto::EngineEvent) -> Self {
        use proto::EngineEvent as P;
        match e {
            P::PadState { pad, state } => EngineEvent::PadState {
                pad: pad.into(),
                state: state.into(),
            },
            P::Transport {
                playing,
                beat,
                bpm,
                bar_len_beats,
                song_secs,
            } => EngineEvent::Transport {
                playing,
                beat,
                bpm,
                bar_len_beats,
                song_secs,
            },
            P::Meters {
                master_peak,
                master_rms,
                pad_levels,
            } => EngineEvent::Meters {
                master_peak: master_peak.to_vec(),
                master_rms: master_rms.to_vec(),
                pad_levels,
            },
            P::Recorder {
                state,
                elapsed_secs,
            } => EngineEvent::Recorder {
                state: state.into(),
                elapsed_secs,
            },
            P::KitLoaded { kit } => EngineEvent::KitLoaded { kit: kit.into() },
            P::TrackSaved { track } => EngineEvent::TrackSaved {
                track: track.into(),
            },
            P::TrackPlayback { track } => EngineEvent::TrackPlayback {
                track: track.map(|t| t.0),
            },
            P::LibraryChanged => EngineEvent::LibraryChanged,
            P::Hub(h) => EngineEvent::Hub(h.into()),
            P::Error(e) => EngineEvent::Error(e.into()),
        }
    }
}

impl From<proto::EngineSnapshot> for EngineSnapshot {
    fn from(s: proto::EngineSnapshot) -> Self {
        Self {
            pads: s
                .pads
                .into_iter()
                .map(|p| PadSnapshot {
                    pad: p.pad.into(),
                    state: p.state.into(),
                    params: p.params.into(),
                    sample_secs: p.sample_secs,
                })
                .collect(),
            transport: TransportState {
                playing: s.transport.playing,
                beat: s.transport.beat,
                song_secs: s.transport.song_secs,
                bpm: s.transport.bpm,
                speed: s.transport.speed,
                beats_per_bar: s.transport.beats_per_bar,
                beat_unit: s.transport.beat_unit,
                quantize: s.transport.quantize.into(),
            },
            kit: s.kit.map(Into::into),
            master_gain: s.master_gain,
            recorder: s.recorder.into(),
            recorder_elapsed_secs: s.recorder_elapsed_secs,
            sample_rate: s.sample_rate,
            active_voices: s.active_voices,
        }
    }
}

impl From<proto::TransportClock> for TransportClock {
    fn from(c: proto::TransportClock) -> Self {
        Self {
            playing: c.playing,
            beat: c.beat,
            song_secs: c.song_secs,
            bpm: c.bpm,
            speed: c.speed,
        }
    }
}

impl From<up_host::AudioStatus> for AudioStatus {
    fn from(s: up_host::AudioStatus) -> Self {
        Self {
            running: s.running,
            host: s.host,
            device: s.device,
            sample_rate: s.sample_rate,
            channels: s.channels,
            buffer_frames: s.buffer_frames,
            sample_format: s.sample_format,
            output_latency_ms: s.output_latency_ms,
        }
    }
}

impl From<up_host::AudioDeviceInfo> for AudioDeviceInfo {
    fn from(d: up_host::AudioDeviceInfo) -> Self {
        Self {
            id: d.id,
            name: d.name,
            is_input: d.is_input,
            is_output: d.is_output,
            is_default_output: d.is_default_output,
            is_default_input: d.is_default_input,
            default_sample_rate: d.default_sample_rate,
            max_output_channels: d.max_output_channels,
            max_input_channels: d.max_input_channels,
            min_buffer_frames: d.min_buffer_frames,
            max_buffer_frames: d.max_buffer_frames,
        }
    }
}

impl From<up_host::EngineInfo> for EngineInfo {
    fn from(i: up_host::EngineInfo) -> Self {
        Self {
            version: i.version,
            sample_rate: i.sample_rate,
            graph_backend: i.graph_backend,
            platform: i.platform,
            data_dir: i.data_dir,
        }
    }
}

fn tutorial_event(e: &up_model::TutorialEvent) -> TutorialEvent {
    let (pad, page_switch) = match e.target {
        up_model::TutorialTarget::Pad { pad } => (Some(pad.into()), None),
        up_model::TutorialTarget::Page { bank } => (None, Some(bank.into())),
    };
    TutorialEvent {
        time_secs: e.time_secs,
        pad,
        page_switch,
        color: e.color.map(Into::into),
        action: match e.action {
            up_model::TutorialAction::Tap => TutorialAction::Tap,
            up_model::TutorialAction::LoopToggle => TutorialAction::LoopToggle,
        },
    }
}

impl From<up_model::TutorialChart> for TutorialChart {
    fn from(c: up_model::TutorialChart) -> Self {
        Self {
            events: c.events.iter().map(tutorial_event).collect(),
            lessons: c
                .lessons
                .iter()
                .map(|l| TutorialLesson {
                    events: l.events.iter().map(tutorial_event).collect(),
                    duration_secs: l.duration_secs,
                    song_start_secs: l.song_start_secs,
                })
                .collect(),
            bpm: c.bpm,
            perfect_ms: c.judge.perfect_ms,
            miss_ms: c.judge.miss_ms,
            timed: c.timed,
        }
    }
}

impl From<up_model::Judgement> for Judgement {
    fn from(j: up_model::Judgement) -> Self {
        match j {
            up_model::Judgement::Perfect => Judgement::Perfect,
            up_model::Judgement::TooFast => Judgement::TooFast,
            up_model::Judgement::TooSlow => Judgement::TooSlow,
            up_model::Judgement::Miss => Judgement::Miss,
        }
    }
}

pub(crate) fn kit_summary_from_library(
    k: &up_library::index::KitSummary,
    lib: &up_library::Library,
) -> KitSummary {
    KitSummary {
        id: k.id.clone(),
        name: k.name.clone(),
        pad_count: u32::from(k.pads_used),
        bpm: k.bpm,
        has_tutorial: k.has_tutorial,
        description: k.description.clone(),
        authors: k.authors.clone(),
        genres: k.genres.clone(),
        tags: k.tags.clone(),
        theme_color: k.theme_color.clone(),
        inspired_by: k.inspired_by.clone(),
        cover_path: k
            .cover_blob
            .as_deref()
            .map(|h| lib.blob_path(h).to_string_lossy().into_owned()),
        favorite: k.favorite,
        source_kind: k.source_kind.clone(),
        last_used_at_ms: k.last_used_at_ms,
    }
}

pub(crate) fn track_from_library(
    t: &up_library::index::TrackInfo,
    waveform: Vec<f32>,
) -> TrackInfo {
    TrackInfo {
        id: t.id.clone(),
        name: t.name.clone(),
        created_unix_ms: t.created_at_ms,
        duration_secs: t.duration_secs,
        sample_rate: t.sample_rate,
        channels: t.channels,
        waveform,
    }
}
