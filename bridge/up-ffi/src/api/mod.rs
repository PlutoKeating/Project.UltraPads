//! FFI API (scanned by flutter_rust_bridge_codegen).
//!
//! * [`engine`] — init, audio, events, snapshot, pads, commands, sampling, tutorial.
//! * [`tracks`] — recorded tracks.
//! * [`library`] — kit library (`library_*`, mostly owned by `runtime/up-library`).
//! * [`hub`] — multi-device hub (`hub_*`, owned by `runtime/up-hub`).
//! * [`update`] — in-app update (`update_*`, owned by `runtime/up-update`).
//! * [`split`] — song import + auto-split into kits (`split_*`, owned by `runtime/up-split`).
//! * [`types`] — DTOs mirrored to Dart.

pub mod engine;
pub mod hub;
pub mod library;
pub mod split;
pub mod tracks;
pub mod types;
pub mod update;
