//! UltraPads core types shared by every layer.
//!
//! This crate is dependency-light and contains no I/O. Everything here is
//! `serde`-serializable and is mirrored 1:1 in `docs/API.md`.

#![forbid(unsafe_code)]

mod error;
mod ids;
mod pad;

pub use error::{ErrorCode, UpError, UpResult};
pub use ids::{KitId, ProjectId, SampleId, TrackId};
pub use pad::{Bank, ColorRole, PadId, PadMode, PadPlayState, Quantize, Retrigger};

/// Sample-time position or duration, in frames.
pub type Frames = u64;
/// Musical time, in beats (quarter notes for 4/4).
pub type Beats = f64;

/// Pads per bank (3 × 4 grid).
pub const PADS_PER_BANK: usize = 12;
/// Number of banks (A/B).
pub const BANK_COUNT: usize = 2;
/// Total number of addressable pads.
pub const PAD_COUNT: usize = PADS_PER_BANK * BANK_COUNT;
/// Default sample rate used before an audio device has been opened.
pub const DEFAULT_SAMPLE_RATE: u32 = 48_000;
