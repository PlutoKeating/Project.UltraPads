//! Runtime host: everything that touches the platform.
//!
//! * [`audio`] — cpal output streams driving an [`up_engine::AudioProcessor`],
//!   device enumeration, buffer sizing, stream statistics and the latency
//!   probe.
//! * [`input`] — microphone capture for sampling.
//! * [`kit_folder`] — temporary v0.0.1 kit loader ("WAV folder" → 24 pads).
//! * [`tracks`] — recorded takes stored as WAV + JSON sidecar.
//! * [`core`] — [`AppCore`], the object behind the FFI and CLI.
//! * [`android`] — `ndk_context` initialisation for cpal's AAudio backend.

pub mod android;
pub mod audio;
pub mod core;
pub mod input;
pub mod kit_folder;
pub mod tracks;

pub use audio::{AudioConfig, AudioDeviceInfo, AudioHost, AudioStatus, OutputPlan, StreamStats};
pub use core::{AppCore, AppDirs, EngineInfo, TrackSink};
pub use input::InputCapture;
pub use kit_folder::{KitAudio, LoadedKit, apply_kit, load_folder_kit};
pub use tracks::TrackStore;

/// Unix epoch milliseconds.
pub(crate) fn now_unix_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}
