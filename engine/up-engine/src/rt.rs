//! Messages crossing the realtime boundary (allocation-free payloads).

use up_core::PadPlayState;
use up_protocol::TransportCmd;
use up_sampler::SamplerCmd;

/// Control → sampler node.
#[derive(Debug)]
pub(crate) enum RtCommand {
    Sampler(SamplerCmd),
    SetTempo(f64),
    Transport(TransportCmd),
    /// Marker used by the latency probe / tests: echoed back as an event.
    Ping(u64),
}

/// Control → master node.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum MasterCmd {
    StartRecording,
    StopRecording,
}

/// Audio → control events.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum RtEvent {
    PadState {
        pad: u8,
        state: PadPlayState,
    },
    PreviewEnded,
    Transport {
        playing: bool,
        beat: f64,
        bpm: f64,
        bar_len_beats: f64,
        song_secs: f64,
    },
    RecorderStarted,
    RecorderStopped {
        frames: u64,
    },
    Pong(u64),
    /// Commands dropped because a node's event ring was full.
    Overflow,
}
