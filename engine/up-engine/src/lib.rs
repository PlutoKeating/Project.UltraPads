//! UltraPads engine facade.
//!
//! ```text
//!   UI / Hub / CLI ──send(Command)──► EngineHandle ──lock-free queues──► AudioProcessor (audio thread)
//!         ▲                              │  (translate, resolve samples)        │ graph: Sampler → Mixer → Master
//!         └──── EngineEvent (≈60 Hz) ◄── control thread ◄── SPSC event rings ◄──┘   (+ recorder ring, retire ring)
//! ```
//!
//! * [`Engine::new`] returns a thread-safe, cloneable [`EngineHandle`] and the
//!   realtime [`AudioProcessor`] that the host drives from its device callback.
//! * [`EngineHandle::send`] never locks: commands go through a lock-free
//!   bounded queue. Sample references are resolved against a lock-free
//!   (`ArcSwap`) registry before they reach the audio thread.
//! * A control thread owns the audio graph, drains audio-thread events,
//!   frees retired resources, coalesces meters to ~60 Hz, maintains the
//!   [`EngineSnapshot`] and finalises recordings.
//! * [`render_offline`] renders a [`RenderScript`] sample-accurately.

mod control;
mod handle;
mod meters;
mod nodes;
mod offline;
mod processor;
mod rt;

pub use handle::{EngineHandle, TakeHandler};
pub use offline::render_offline;
pub use processor::AudioProcessor;
pub use up_graph::GraphBackend;
pub use up_protocol::*;
pub use up_recorder::Take;
pub use up_sampler::{SampleArc, SampleData};

pub use handle::EngineStats;
pub use up_core::UpResult;

/// Engine construction parameters.
#[derive(Debug, Clone)]
pub struct EngineConfig {
    pub sample_rate: u32,
    /// Largest block processed at once; larger host buffers are split.
    pub max_block_frames: usize,
    /// Maximum simultaneously sounding voices (excluding fade-out tails).
    pub max_voices: usize,
    pub command_capacity: usize,
    pub event_capacity: usize,
    /// Capacity of the recorder ring in seconds (the control thread drains
    /// it continuously; this only bounds control-thread stalls).
    pub record_ring_seconds: f32,
    pub graph_backend: GraphBackend,
    /// Event coalescing rate for meters.
    pub meter_hz: f64,
    /// Initial tempo.
    pub bpm: f64,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            sample_rate: up_core::DEFAULT_SAMPLE_RATE,
            max_block_frames: 512,
            max_voices: 32,
            command_capacity: 1024,
            event_capacity: 4096,
            record_ring_seconds: 8.0,
            graph_backend: GraphBackend::default(),
            meter_hz: 60.0,
            bpm: 120.0,
        }
    }
}

impl EngineConfig {
    fn validate(&self) -> UpResult<()> {
        if !(8_000..=384_000).contains(&self.sample_rate) {
            return Err(UpError::invalid(
                "sample_rate must be within 8 kHz..384 kHz",
            ));
        }
        if !(16..=8192).contains(&self.max_block_frames) {
            return Err(UpError::invalid(
                "max_block_frames must be within 16..=8192",
            ));
        }
        if self.max_voices == 0 || self.command_capacity == 0 || self.event_capacity == 0 {
            return Err(UpError::invalid("capacities must be > 0"));
        }
        Ok(())
    }
}

/// Engine constructor namespace.
pub struct Engine;

impl Engine {
    /// Build an engine. Spawns the control thread (which owns the audio
    /// graph) and returns the control handle plus the realtime processor.
    // The API contract (docs/API.md) names this `Engine::new`.
    #[allow(clippy::new_ret_no_self)]
    pub fn new(cfg: EngineConfig) -> UpResult<(EngineHandle, AudioProcessor)> {
        cfg.validate()?;
        handle::build(cfg)
    }
}
