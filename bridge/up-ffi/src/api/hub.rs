//! Multi-device hub. Implemented in `runtime/up-hub` (owned by the hub
//! agent) and wired in by the integrator; every function currently returns
//! `ErrorCode::NotImplemented`.

use super::types::*;
use crate::frb_generated::StreamSink;

type R<T> = Result<T, UpError>;

/// TODO(up-hub): start the desktop hub server.
pub fn hub_start_server(name: String) -> R<()> {
    let _ = name;
    Err(UpError::not_implemented(
        "hub_start_server (runtime/up-hub)",
    ))
}

/// TODO(up-hub)
pub fn hub_stop_server() -> R<()> {
    Err(UpError::not_implemented("hub_stop_server (runtime/up-hub)"))
}

/// TODO(up-hub): mDNS discovery stream.
pub fn hub_discover(sink: StreamSink<HubPeer>) -> R<()> {
    let _ = sink;
    Err(UpError::not_implemented("hub_discover (runtime/up-hub)"))
}

/// TODO(up-hub)
pub fn hub_pair(peer: String, code: String) -> R<PairedDevice> {
    let _ = (peer, code);
    Err(UpError::not_implemented("hub_pair (runtime/up-hub)"))
}

/// TODO(up-hub)
pub fn hub_sync(peer: String) -> R<SyncReport> {
    let _ = peer;
    Err(UpError::not_implemented("hub_sync (runtime/up-hub)"))
}

/// TODO(up-hub): after connecting, `pad_down`/`pad_up` are forwarded to the peer.
pub fn hub_controller_connect(peer: String) -> R<()> {
    let _ = peer;
    Err(UpError::not_implemented(
        "hub_controller_connect (runtime/up-hub)",
    ))
}

/// TODO(up-hub)
pub fn hub_controller_disconnect() -> R<()> {
    Err(UpError::not_implemented(
        "hub_controller_disconnect (runtime/up-hub)",
    ))
}
