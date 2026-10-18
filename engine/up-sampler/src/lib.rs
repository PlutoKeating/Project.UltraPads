//! 24-pad sampler.
//!
//! * Modes: [`PadMode::OneShot`] (retrigger restarts), [`PadMode::Loop`]
//!   (toggle), [`PadMode::Gate`] (plays while held).
//! * Loops launch on the [`Quantize`] grid (default `None` = immediately,
//!   like Ref); state machine `Idle → Pending → Playing → Stopping → Idle`.
//! * Choke groups: triggering a pad stops every *other* pad in its group.
//! * Velocity → gain (square law); per-pad gain and constant-power pan.
//! * Bounded polyphony with oldest-first voice stealing; stolen and stopped
//!   voices fade out (5 ms) to avoid clicks.
//! * Global speed ratio (0.5–2.0) = varispeed with 4-point Hermite
//!   interpolation. [`PitchMode`] reserves room for a time-stretch engine.
//!
//! Realtime contract: [`Sampler::process`] and [`Sampler::handle`] never
//! allocate or free; replaced samples are handed to a [`Retirer`].

mod sample;
mod sampler;
mod voice;

pub use sample::{SampleArc, SampleData};
pub use sampler::{
    BUS_COUNT, PREVIEW_OUTPUTS, PadState, RtPadParams, SampleUpdate, Sampler, SamplerCmd,
    SamplerConfig, SamplerEvent, SamplerEvents, outputs_needed, pitch_ratio,
};
pub use up_core::{PadMode, PadPlayState, Quantize};
pub use up_rt::retire::Retirer;

/// How the speed ratio is realised.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PitchMode {
    /// Tape-style varispeed: pitch follows speed (v0.0.1).
    #[default]
    Varispeed,
    /// Tempo change with preserved pitch (reserved for Signalsmith Stretch;
    /// currently falls back to varispeed).
    TimeStretch,
}
