//! Multi-device hub (`runtime/up-hub`, docs/API.md §3.1, ADR-0004).
//!
//! Every function needs `init()` first. Identity, trust list and remembered
//! hubs live in `<data_dir>/hub`; the hub and client roles share one device
//! identity. Long-running calls are `async` and run on the FFI's tokio
//! runtime. Hub events arrive on `events()` as `EngineEvent::Hub(HubEvent)`.
//!
//! After `hub_controller_connect`, the hot-path `pad_down` / `pad_up` (and
//! `send(PadDown | PadUp | StopAll)`) are forwarded to the hub over UDP and do
//! **not** sound locally unless `hub_controller_set_local_echo(true)`.

use super::types::*;
use crate::frb_generated::StreamSink;
use crate::hub_rt::{self, hub, on_rt};
use flutter_rust_bridge::frb;

type R<T> = Result<T, UpError>;

// ---------------------------------------------------------------- hub (desktop)

/// Start the hub server (TLS control plane, controller UDP, mDNS advert).
/// Tries the last port, then 47100, then a random one. Calling it again
/// with the same name returns the running server; another name restarts it.
/// On Android the Wi-Fi multicast lock is taken automatically.
pub async fn hub_start_server(name: String) -> R<HubServerInfo> {
    let h = hub()?;
    on_rt(h.start_server(name)).await
}

/// Stop the hub server (releases pads held by remote controllers).
pub async fn hub_stop_server() -> R<()> {
    let h = hub()?;
    on_rt(h.stop_server()).await
}

/// The running server, if any.
pub fn hub_server_info() -> R<Option<HubServerInfo>> {
    hub()?.server_info()
}

/// New 6-digit one-time pairing code (5 min, 5 attempts; replaces the
/// previous code). `HubEvent::Paired` is emitted when a device pairs with it.
pub fn hub_new_pairing_code() -> R<PairingCode> {
    hub()?.new_pairing_code()
}

/// Close the pairing window.
pub fn hub_cancel_pairing() -> R<()> {
    hub()?.cancel_pairing()
}

/// Devices this device trusts (paired phones when acting as hub, paired
/// hubs when acting as client — one shared trust list), newest first.
pub fn hub_trusted_devices() -> R<Vec<PairedDevice>> {
    hub()?.trusted_devices()
}

/// Revoke trust in a device; its requests are rejected immediately and its
/// controller session is closed. Returns whether it was trusted.
pub fn hub_revoke(id: String) -> R<bool> {
    hub()?.revoke(&id)
}

/// Live controller sessions on the local hub (empty when not running).
pub fn hub_controller_stats() -> R<Vec<ControllerSessionStats>> {
    hub()?.controller_stats()
}

// ---------------------------------------------------------------- client (phone)

/// Name this device presents when pairing (default: the hub name if a server
/// was started, else `UltraPads <os>`).
pub fn hub_set_device_name(name: String) -> R<()> {
    hub()?.set_device_name(name)
}

/// This device's id (base32 public key).
pub fn hub_device_id() -> R<String> {
    Ok(hub()?.device_id().to_b32())
}

/// Browse the LAN for hubs (mDNS). Only one discovery runs at a time: a new
/// call ends the previous stream. Stop with `hub_discover_stop` (cancelling
/// the Dart subscription alone is only noticed at the next event). On
/// Android the multicast lock is held while discovery runs.
pub fn hub_discover(sink: StreamSink<HubPeerEvent>) -> R<()> {
    hub()?.discover(move |ev| sink.add(ev).is_ok())
}

/// Stop discovery (and release the multicast lock).
pub fn hub_discover_stop() -> R<()> {
    hub()?.stop_discovery();
    Ok(())
}

/// Connect to `address` (`ip`, `ip:port`, `host[:port]`; default port 47100)
/// and read the hub's identity from its TLS key — for manual IP entry when
/// mDNS is blocked. The peer is remembered for `hub_pair` etc.
pub async fn hub_probe(address: String) -> R<HubPeer> {
    let h = hub()?;
    on_rt(h.probe(address)).await
}

/// Hubs seen this session or paired before (with their last addresses).
pub fn hub_known_peers() -> R<Vec<HubPeer>> {
    hub()?.known_peers()
}

/// Pair with a hub (`peer` = id from discovery/probe, or an address) using
/// the 6-digit code shown on it. Wrong code → `PermissionDenied`,
/// message `[pairing_failed] …`.
pub async fn hub_pair(peer: String, code: String) -> R<PairedDevice> {
    let h = hub()?;
    on_rt(h.pair(peer, code)).await
}

/// Forget a paired hub locally.
pub async fn hub_forget(peer: String) -> R<bool> {
    let h = hub()?;
    on_rt(h.forget(peer)).await
}

/// Two-way incremental library sync with a paired hub. Emits
/// `SyncStarted` → `SyncProgress`* → `SyncFinished` (or `Error{op:"sync"}`),
/// and `LibraryChanged` when local entries changed.
pub async fn hub_sync(peer: String) -> R<SyncReport> {
    let h = hub()?;
    on_rt(h.sync(peer)).await
}

/// Become a remote pad controller of a paired hub. Replaces an existing
/// link. Emits `ControllerConnected`.
pub async fn hub_controller_connect(peer: String) -> R<HubControllerStatus> {
    let h = hub()?;
    on_rt(h.controller_connect(peer)).await
}

/// End the controller link (pads play locally again).
pub async fn hub_controller_disconnect() -> R<()> {
    let h = hub()?;
    on_rt(h.controller_disconnect()).await
}

/// Controller link state and round-trip latency.
#[frb(sync)]
pub fn hub_controller_status() -> HubControllerStatus {
    hub_rt::controller_status()
}

/// Also play pads locally while connected as a controller (default off).
#[frb(sync)]
pub fn hub_controller_set_local_echo(enabled: bool) {
    hub_rt::set_local_echo(enabled);
}
