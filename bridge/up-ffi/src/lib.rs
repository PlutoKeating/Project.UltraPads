//! UltraPads FFI surface (`docs/API.md` §3), exposed to Dart through
//! flutter_rust_bridge. Everything under [`api`] is scanned by
//! `flutter_rust_bridge_codegen`; DTOs in [`api::types`] mirror the engine
//! types so engine crates stay free of FRB attributes. The hub runtime
//! (`runtime/up-hub` wiring, tokio runtime, PadSink, LibraryStore) lives in
//! `hub_rt`.

mod android;
pub mod api;
mod events;
mod frb_generated;
mod hub_rt;
mod state;
#[doc(hidden)]
pub mod testing;
