//! Hub runtime behind `api::hub` (docs/API.md §3.1, ADR-0004).
//!
//! * one process-wide multi-threaded tokio runtime ([`rt`]); FRB `async`
//!   functions spawn their work onto it and await the `JoinHandle`, so they
//!   work whatever executor FRB polls them on;
//! * device identity, trust list, remembered hubs (`peers.json`) and the last
//!   server port (`server.json`) live in `<data_dir>/hub`;
//! * the library is exposed to `up-hub` through `up_library`'s
//!   [`LibraryHubStore`], wrapped to emit `LibraryChanged` and sync progress;
//! * remote pads reach the engine through [`EnginePadSink`] (lock-free
//!   `EngineHandle` pushes);
//! * while a controller link is up, the FFI hot path forwards pad events
//!   with [`forward`] (synchronous, non-blocking `ControllerHandle` calls).

use std::collections::{HashMap, HashSet};
use std::future::Future;
use std::net::{IpAddr, SocketAddr};
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::task::{Context, Poll};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use arc_swap::ArcSwapOption;
use async_trait::async_trait;
use crossbeam_channel::{Receiver, Sender, TrySendError};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncRead, ReadBuf};
use up_hub::{
    BlobHash, BlobReader, BlobStatus, BlobWriter, ClientConfig, ControllerHandle, DeviceId,
    DiscoveryEvent, HubClient, HubConfig, HubError, HubServer, LibraryManifest, LibraryStore,
    MergeOutcome, PadSink, PeerAddr, RemotePadEvent,
};
use up_library::hub_store::LibraryHubStore;

use crate::android::MulticastGuard;
use crate::api::types::{self as t, ErrorCode, HubEvent, UpError};
use crate::state;

type R<T> = Result<T, UpError>;

/// Preferred control-plane port of the hub (used by `hub_probe` when the
/// address has no port). Falls back to the last port, then a random one.
pub(crate) const DEFAULT_PORT: u16 = 47100;
/// The controller is considered lost when no Pong arrived for this long.
const CONTROLLER_TIMEOUT: Duration = Duration::from_secs(5);

// ---------------------------------------------------------------- runtime

/// The process-wide tokio runtime for all hub work.
pub(crate) fn rt() -> &'static tokio::runtime::Runtime {
    static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .thread_name("up-hub")
            .enable_all()
            .build()
            .expect("tokio runtime for up-hub")
    })
}

/// Run `f` on [`rt`] and await it from any executor.
pub(crate) async fn on_rt<T: Send + 'static>(
    f: impl Future<Output = R<T>> + Send + 'static,
) -> R<T> {
    match rt().spawn(f).await {
        Ok(r) => r,
        Err(e) => Err(internal(format!("hub task failed: {e}"))),
    }
}

fn internal(message: String) -> UpError {
    UpError {
        code: ErrorCode::Internal,
        message,
    }
}

pub(crate) fn invalid(message: impl Into<String>) -> UpError {
    UpError {
        code: ErrorCode::InvalidArgument,
        message: message.into(),
    }
}

/// Map hub errors onto FFI codes. The message starts with a stable tag in
/// brackets (`[not_paired]`, `[pairing_failed]`, `[timeout]`, …) so the UI
/// can tell the cases apart without new `ErrorCode` variants.
pub(crate) fn hub_err(e: HubError) -> UpError {
    let (code, tag): (ErrorCode, String) = match &e {
        HubError::Io(_) => (ErrorCode::Io, "io".into()),
        HubError::Tls(_) => (ErrorCode::Io, "tls".into()),
        HubError::Protocol(_) => (ErrorCode::Format, "protocol".into()),
        HubError::NotPaired(_) => (ErrorCode::PermissionDenied, "not_paired".into()),
        HubError::Pairing(_) => (ErrorCode::PermissionDenied, "pairing_failed".into()),
        HubError::Remote { code, .. } => (ErrorCode::Io, code.clone()),
        HubError::HashMismatch { .. } => (ErrorCode::Format, "hash_mismatch".into()),
        HubError::BlobNotFound(_) => (ErrorCode::NotFound, "blob_not_found".into()),
        HubError::OffsetMismatch { .. } => (ErrorCode::InvalidState, "offset_mismatch".into()),
        HubError::Busy(_) => (ErrorCode::InvalidState, "busy".into()),
        HubError::Store(_) => (ErrorCode::Io, "store".into()),
        HubError::Discovery(_) => (ErrorCode::Io, "discovery".into()),
        HubError::Timeout(_) => (ErrorCode::Io, "timeout".into()),
        HubError::InvalidInput(_) => (ErrorCode::InvalidArgument, "invalid_input".into()),
        HubError::Closed => (ErrorCode::InvalidState, "closed".into()),
        _ => (ErrorCode::Internal, "hub".into()),
    };
    UpError {
        code,
        message: format!("[{tag}] {e}"),
    }
}

fn unix_ms(t: SystemTime) -> i64 {
    t.duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

// ---------------------------------------------------------------- events

fn subscribers() -> &'static Mutex<Vec<Sender<HubEvent>>> {
    static SUBS: OnceLock<Mutex<Vec<Sender<HubEvent>>>> = OnceLock::new();
    SUBS.get_or_init(Default::default)
}

/// New subscription to hub events (merged into `events()`).
pub(crate) fn subscribe_events() -> Receiver<HubEvent> {
    let (tx, rx) = crossbeam_channel::bounded(1024);
    if let Ok(mut s) = subscribers().lock() {
        s.push(tx);
    }
    rx
}

pub(crate) fn emit(ev: HubEvent) {
    if let Ok(mut subs) = subscribers().lock() {
        subs.retain(|s| !matches!(s.try_send(ev.clone()), Err(TrySendError::Disconnected(_))));
    }
}

fn emit_error(op: &str, peer: Option<&str>, error: UpError) {
    emit(HubEvent::Error {
        op: op.into(),
        peer: peer.map(Into::into),
        error,
    });
}

fn library_changed() {
    if let Some(core) = state::installed() {
        core.emit(up_engine::EngineEvent::LibraryChanged);
    }
}

// ---------------------------------------------------------------- conversions

pub(crate) fn peer_dto(p: &up_hub::HubPeer, paired: bool) -> t::HubPeer {
    let addrs: Vec<SocketAddr> = match &p.addr {
        PeerAddr::Lan { addrs } => addrs.clone(),
        #[allow(unreachable_patterns)]
        _ => Vec::new(),
    };
    let first = addrs.first();
    t::HubPeer {
        id: p.id.to_b32(),
        name: p.name.clone(),
        address: first.map(|a| a.ip().to_string()).unwrap_or_default(),
        port: first.map(|a| a.port()).unwrap_or(0),
        paired,
        addresses: addrs.iter().map(|a| a.to_string()).collect(),
    }
}

pub(crate) fn device_dto(d: &up_hub::TrustedDevice) -> t::PairedDevice {
    t::PairedDevice {
        id: d.id.to_b32(),
        name: d.name.clone(),
        paired_unix_ms: d.paired_at_ms,
    }
}

fn report_dto(r: &up_hub::SyncReport) -> t::SyncReport {
    t::SyncReport {
        pulled: r.local_changed,
        pushed: r.remote_changed,
        conflicts: r.conflicts,
        bytes: r.uploaded_bytes + r.downloaded_bytes,
        uploaded_blobs: r.uploaded_blobs,
        uploaded_bytes: r.uploaded_bytes,
        downloaded_blobs: r.downloaded_blobs,
        downloaded_bytes: r.downloaded_bytes,
        resumed_blobs: r.resumed_blobs,
        conflict_ids: r.conflict_ids.clone(),
        duration_ms: r.duration_ms,
    }
}

pub(crate) fn stats_dto(s: &up_hub::ControllerSessionStats) -> t::ControllerSessionStats {
    t::ControllerSessionStats {
        session_id: s.session_id,
        device_id: s.device.to_b32(),
        name: s.name.clone(),
        packets: s.packets,
        accepted_events: s.accepted_events,
        duplicates: s.duplicates,
        reordered_dropped: s.reordered_dropped,
        too_old: s.too_old,
        bad_mac: s.bad_mac,
        idle_ms: s.idle_ms,
        held_pads: s.held_pads,
    }
}

fn latency_dto(l: &up_hub::LatencyStats) -> t::HubLatency {
    t::HubLatency {
        samples: l.samples,
        pings_sent: l.pings_sent,
        pongs_received: l.pongs_received,
        rtt_min_us: l.rtt_min_us,
        rtt_p50_us: l.rtt_p50_us,
        rtt_p95_us: l.rtt_p95_us,
        rtt_max_us: l.rtt_max_us,
        rtt_mean_us: l.rtt_mean_us,
        one_way_estimate_us: l.one_way_estimate_us,
    }
}

/// Parse `ip`, `ip:port`, `[v6]:port` or `host[:port]`.
pub(crate) async fn resolve_address(address: &str) -> R<SocketAddr> {
    let a = address.trim();
    if a.is_empty() {
        return Err(invalid("empty hub address"));
    }
    if let Ok(sa) = a.parse::<SocketAddr>() {
        return Ok(sa);
    }
    if let Ok(ip) = a.trim_matches(['[', ']']).parse::<IpAddr>() {
        return Ok(SocketAddr::new(ip, DEFAULT_PORT));
    }
    let with_port = if a
        .rsplit_once(':')
        .is_some_and(|(_, p)| p.parse::<u16>().is_ok())
    {
        a.to_string()
    } else {
        format!("{a}:{DEFAULT_PORT}")
    };
    let mut addrs: Vec<SocketAddr> = tokio::net::lookup_host(with_port)
        .await
        .map_err(|e| invalid(format!("cannot resolve hub address {a:?}: {e}")))?
        .collect();
    addrs.sort_by_key(|s| s.is_ipv6());
    addrs
        .into_iter()
        .next()
        .ok_or_else(|| invalid(format!("cannot resolve hub address {a:?}")))
}

fn lan_addresses(port: u16) -> Vec<String> {
    let mut ips: Vec<IpAddr> = if_addrs::get_if_addrs()
        .map(|v| {
            v.into_iter()
                .map(|i| i.ip())
                .filter(|ip| ip.is_ipv4() && !ip.is_loopback())
                .collect()
        })
        .unwrap_or_default();
    ips.sort();
    ips.dedup();
    if ips.is_empty() {
        ips.push(IpAddr::V4(std::net::Ipv4Addr::LOCALHOST));
    }
    ips.into_iter()
        .map(|ip| SocketAddr::new(ip, port).to_string())
        .collect()
}

// ---------------------------------------------------------------- store wrapper

/// Sync progress of one `hub_sync` (blob granularity).
struct Progress {
    peer: String,
    st: Mutex<ProgressState>,
}

struct ProgressState {
    needed: HashSet<BlobHash>,
    done: HashSet<BlobHash>,
    last_emit: Instant,
}

impl Progress {
    fn new(peer: String) -> Self {
        Self {
            peer,
            st: Mutex::new(ProgressState {
                needed: HashSet::new(),
                done: HashSet::new(),
                last_emit: Instant::now(),
            }),
        }
    }

    fn need(&self, h: BlobHash) {
        if let Ok(mut s) = self.st.lock()
            && s.needed.insert(h)
        {
            self.report(&mut s, false);
        }
    }

    fn finished(&self, h: BlobHash) {
        if let Ok(mut s) = self.st.lock() {
            s.needed.insert(h);
            if s.done.insert(h) {
                self.report(&mut s, false);
            }
        }
    }

    fn report(&self, s: &mut ProgressState, force: bool) {
        let (done, total) = (s.done.len() as u64, s.needed.len() as u64);
        if force || done == total || s.last_emit.elapsed() >= Duration::from_millis(50) {
            s.last_emit = Instant::now();
            emit(HubEvent::SyncProgress {
                peer: self.peer.clone(),
                done,
                total,
            });
        }
    }

    fn flush(&self) {
        if let Ok(mut s) = self.st.lock() {
            self.report(&mut s, true);
        }
    }
}

/// [`LibraryHubStore`] plus FFI side effects: `LibraryChanged` when a merge
/// changed the library (hub side) and sync progress (client side).
#[derive(Clone)]
struct FfiStore {
    inner: LibraryHubStore,
    notify_changes: bool,
    progress: Option<Arc<Progress>>,
}

#[async_trait]
impl LibraryStore for FfiStore {
    async fn manifest(&self) -> up_hub::Result<LibraryManifest> {
        self.inner.manifest().await
    }

    async fn put_manifest(&self, manifest: &LibraryManifest) -> up_hub::Result<()> {
        self.inner.put_manifest(manifest).await?;
        if self.notify_changes {
            library_changed();
        }
        Ok(())
    }

    async fn merge_manifest(&self, incoming: &LibraryManifest) -> up_hub::Result<MergeOutcome> {
        let out = self.inner.merge_manifest(incoming).await?;
        if self.notify_changes && out.changed > 0 {
            library_changed();
        }
        Ok(out)
    }

    async fn list_blobs(&self) -> up_hub::Result<Vec<BlobHash>> {
        self.inner.list_blobs().await
    }

    async fn blob_status(&self, hash: &BlobHash) -> up_hub::Result<BlobStatus> {
        let st = self.inner.blob_status(hash).await?;
        if let Some(p) = &self.progress
            && !matches!(st, BlobStatus::Complete(_))
        {
            p.need(*hash);
        }
        Ok(st)
    }

    async fn open_blob(
        &self,
        hash: &BlobHash,
        offset: u64,
    ) -> up_hub::Result<Option<(u64, BlobReader)>> {
        let r = self.inner.open_blob(hash, offset).await?;
        match (&self.progress, r) {
            (Some(p), Some((len, reader))) => {
                p.need(*hash);
                let reader: BlobReader = Box::pin(ProgressReader {
                    inner: reader,
                    hash: *hash,
                    progress: Arc::clone(p),
                    finished: false,
                });
                Ok(Some((len, reader)))
            }
            (_, r) => Ok(r),
        }
    }

    async fn blob_writer(
        &self,
        hash: &BlobHash,
        offset: u64,
    ) -> up_hub::Result<Box<dyn BlobWriter>> {
        let w = self.inner.blob_writer(hash, offset).await?;
        Ok(match &self.progress {
            Some(p) => Box::new(ProgressWriter {
                inner: w,
                hash: *hash,
                progress: Arc::clone(p),
            }),
            None => w,
        })
    }
}

struct ProgressReader {
    inner: BlobReader,
    hash: BlobHash,
    progress: Arc<Progress>,
    finished: bool,
}

impl AsyncRead for ProgressReader {
    fn poll_read(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<std::io::Result<()>> {
        let before = buf.filled().len();
        let r = self.inner.as_mut().poll_read(cx, buf);
        if let Poll::Ready(Ok(())) = &r
            && buf.filled().len() == before
            && buf.remaining() > 0
            && !self.finished
        {
            self.finished = true;
            self.progress.finished(self.hash);
        }
        r
    }
}

struct ProgressWriter {
    inner: Box<dyn BlobWriter>,
    hash: BlobHash,
    progress: Arc<Progress>,
}

#[async_trait]
impl BlobWriter for ProgressWriter {
    async fn write(&mut self, chunk: &[u8]) -> up_hub::Result<()> {
        self.inner.write(chunk).await
    }

    fn written(&self) -> u64 {
        self.inner.written()
    }

    async fn finish(self: Box<Self>) -> up_hub::Result<u64> {
        let n = self.inner.finish().await?;
        self.progress.finished(self.hash);
        Ok(n)
    }

    async fn abort(self: Box<Self>) -> up_hub::Result<()> {
        self.inner.abort().await
    }
}

// ---------------------------------------------------------------- pad sink

/// Remote controller → engine. Runs on the hub's UDP task; every call is a
/// lock-free `EngineHandle` push (`ArcSwap` load + bounded queue).
struct EnginePadSink;

impl PadSink for EnginePadSink {
    fn pad_down(&self, _origin: &DeviceId, bank: u8, index: u8, velocity: u8) {
        if let Some(core) = state::installed() {
            let _ = core.pad_down(
                up_core::PadId { bank, index },
                f32::from(velocity.min(127)) / 127.0,
            );
        }
    }

    fn pad_up(&self, _origin: &DeviceId, bank: u8, index: u8) {
        if let Some(core) = state::installed() {
            let _ = core.pad_up(up_core::PadId { bank, index });
        }
    }

    fn stop_all(&self, _origin: &DeviceId) {
        if let Some(core) = state::installed() {
            let _ = core.send(up_engine::Command::StopAll);
        }
    }

    fn controller_connected(&self, origin: &DeviceId, name: &str) {
        emit(HubEvent::RemoteControllerConnected {
            device: origin.to_b32(),
            name: name.into(),
        });
    }

    fn controller_disconnected(&self, origin: &DeviceId) {
        emit(HubEvent::RemoteControllerDisconnected {
            device: origin.to_b32(),
        });
    }
}

// ---------------------------------------------------------------- controller (hot path)

struct ActiveController {
    /// `ControllerHandle` is `Send` but not `Sync` (its close callback);
    /// the mutex is only ever held for one non-blocking call (µs).
    handle: Mutex<ControllerHandle>,
    peer_id: String,
    peer_name: String,
    serial: u64,
}

static CONTROLLER: ArcSwapOption<ActiveController> = ArcSwapOption::const_empty();
static LOCAL_ECHO: AtomicBool = AtomicBool::new(false);
static CONTROLLER_SERIAL: AtomicU64 = AtomicU64::new(0);

/// FFI hot path. `Ok(true)` = forwarded to the hub and must **not** sound
/// locally; `Ok(false)` = no controller link (or local echo on) → play
/// locally. Synchronous and non-blocking (HMAC + two non-blocking sends).
#[inline]
pub(crate) fn forward(ev: RemotePadEvent) -> R<bool> {
    let guard = CONTROLLER.load();
    let Some(c) = guard.as_ref() else {
        return Ok(false);
    };
    c.handle
        .lock()
        .map_err(|_| internal("controller state poisoned".into()))?
        .send(ev)
        .map_err(hub_err)?;
    Ok(!LOCAL_ECHO.load(Ordering::Relaxed))
}

pub(crate) fn set_local_echo(enabled: bool) {
    LOCAL_ECHO.store(enabled, Ordering::Relaxed);
}

pub(crate) fn controller_status() -> t::HubControllerStatus {
    let local_echo = LOCAL_ECHO.load(Ordering::Relaxed);
    match CONTROLLER.load_full() {
        Some(c) => t::HubControllerStatus {
            connected: true,
            peer: Some(c.peer_id.clone()),
            peer_name: Some(c.peer_name.clone()),
            session_id: c.handle.lock().ok().map(|h| h.session_id()),
            local_echo,
            latency: c.handle.lock().ok().map(|h| latency_dto(&h.latency())),
        },
        None => t::HubControllerStatus {
            connected: false,
            peer: None,
            peer_name: None,
            session_id: None,
            local_echo,
            latency: None,
        },
    }
}

/// Take the active controller out of the hot path and close it.
async fn close_controller(c: Arc<ActiveController>) {
    // In-flight hot-path calls may still hold a reference for a moment.
    let mut c = c;
    for _ in 0..50 {
        match Arc::try_unwrap(c) {
            Ok(active) => {
                let Ok(handle) = active.handle.into_inner() else {
                    return;
                };
                let _ = tokio::time::timeout(Duration::from_secs(2), handle.close()).await;
                return;
            }
            Err(back) => {
                c = back;
                tokio::time::sleep(Duration::from_millis(2)).await;
            }
        }
    }
    // Dropping the last reference still sends the UDP Close.
}

/// Detect a hub that stopped answering pings and end the link.
async fn controller_watchdog(serial: u64) {
    let mut last_pongs = 0u64;
    let mut last_change = Instant::now();
    let mut tick = tokio::time::interval(Duration::from_millis(500));
    loop {
        tick.tick().await;
        let Some(c) = CONTROLLER.load_full() else {
            return;
        };
        if c.serial != serial {
            return;
        }
        let Some(pongs) = c.handle.lock().ok().map(|h| h.latency().pongs_received) else {
            return;
        };
        if pongs != last_pongs {
            last_pongs = pongs;
            last_change = Instant::now();
            continue;
        }
        if last_change.elapsed() < CONTROLLER_TIMEOUT {
            continue;
        }
        let peer = c.peer_id.clone();
        drop(c);
        let current = CONTROLLER.load_full();
        if current.as_ref().is_some_and(|x| x.serial == serial) {
            CONTROLLER.store(None);
            emit_error(
                "controller",
                Some(&peer),
                UpError {
                    code: ErrorCode::Io,
                    message: "[timeout] hub stopped answering the controller link".into(),
                },
            );
            emit(HubEvent::ControllerDisconnected);
            if let Some(c) = current {
                close_controller(c).await;
            }
        }
        return;
    }
}

// ---------------------------------------------------------------- hub state

#[derive(Serialize, Deserialize, Default)]
struct PeersFile {
    version: u32,
    peers: Vec<up_hub::HubPeer>,
}

#[derive(Serialize, Deserialize, Default)]
struct ServerFile {
    port: u16,
}

struct Running {
    server: HubServer,
    info: t::HubServerInfo,
    pairing_watch: Option<tokio::task::JoinHandle<()>>,
    _multicast: MulticastGuard,
}

/// Process-wide hub state (created on the first `hub_*` call after `init`).
pub(crate) struct Hub {
    dir: PathBuf,
    base_store: LibraryHubStore,
    device_id: DeviceId,
    lifecycle: tokio::sync::Mutex<()>,
    server: Mutex<Option<Running>>,
    client: Mutex<Option<HubClient>>,
    device_name: Mutex<Option<String>>,
    peers: Mutex<HashMap<String, up_hub::HubPeer>>,
    discovery: Mutex<Option<tokio::task::JoinHandle<()>>>,
    sync_lock: tokio::sync::Mutex<()>,
}

pub(crate) fn hub() -> R<Arc<Hub>> {
    static HUB: Mutex<Option<Arc<Hub>>> = Mutex::new(None);
    let mut g = HUB
        .lock()
        .map_err(|_| internal("hub state poisoned".into()))?;
    if let Some(h) = g.as_ref() {
        return Ok(Arc::clone(h));
    }
    let core = state::core()?;
    let library = state::library()?;
    let dir = Path::new(&core.dirs().data_dir).join("hub");
    std::fs::create_dir_all(&dir).map_err(|e| UpError {
        code: ErrorCode::Io,
        message: format!("create {}: {e}", dir.display()),
    })?;
    // Identity first: the store's version vectors use the device id.
    let probe = HubClient::new(ClientConfig::new(&dir, default_name())).map_err(hub_err)?;
    let device_id = probe.device_id();
    let peers = load_peers(&dir);
    let h = Arc::new(Hub {
        base_store: LibraryHubStore::new(library, device_id),
        device_id,
        lifecycle: tokio::sync::Mutex::new(()),
        server: Mutex::new(None),
        client: Mutex::new(Some(probe)),
        device_name: Mutex::new(None),
        peers: Mutex::new(peers),
        discovery: Mutex::new(None),
        sync_lock: tokio::sync::Mutex::new(()),
        dir,
    });
    *g = Some(Arc::clone(&h));
    Ok(h)
}

fn default_name() -> String {
    format!("UltraPads {}", std::env::consts::OS)
}

fn load_peers(dir: &Path) -> HashMap<String, up_hub::HubPeer> {
    std::fs::read(dir.join("peers.json"))
        .ok()
        .and_then(|b| serde_json::from_slice::<PeersFile>(&b).ok())
        .map(|f| f.peers.into_iter().map(|p| (p.id.to_b32(), p)).collect())
        .unwrap_or_default()
}

fn write_json(path: &Path, value: &impl Serialize) {
    let Ok(bytes) = serde_json::to_vec_pretty(value) else {
        return;
    };
    let tmp = path.with_extension("json.tmp");
    if std::fs::write(&tmp, bytes).is_ok() && std::fs::rename(&tmp, path).is_err() {
        let _ = std::fs::remove_file(&tmp);
    }
}

impl Hub {
    fn lock<'a, T>(m: &'a Mutex<T>) -> R<std::sync::MutexGuard<'a, T>> {
        m.lock().map_err(|_| internal("hub state poisoned".into()))
    }

    pub(crate) fn device_id(&self) -> DeviceId {
        self.device_id
    }

    fn device_name(&self) -> String {
        if let Ok(g) = self.device_name.lock()
            && let Some(n) = g.as_ref()
        {
            return n.clone();
        }
        if let Ok(g) = self.server.lock()
            && let Some(r) = g.as_ref()
        {
            return r.info.name.clone();
        }
        default_name()
    }

    pub(crate) fn set_device_name(&self, name: String) -> R<()> {
        let name = name.trim().to_string();
        if name.is_empty() {
            return Err(invalid("device name must not be empty"));
        }
        *Self::lock(&self.device_name)? = Some(name);
        // The name is baked into the client config: rebuild lazily.
        *Self::lock(&self.client)? = None;
        Ok(())
    }

    fn client(&self) -> R<HubClient> {
        let mut g = Self::lock(&self.client)?;
        if let Some(c) = g.as_ref() {
            return Ok(c.clone());
        }
        let c =
            HubClient::new(ClientConfig::new(&self.dir, self.device_name())).map_err(hub_err)?;
        *g = Some(c.clone());
        Ok(c)
    }

    fn remember(&self, peer: &up_hub::HubPeer) {
        if let Ok(mut m) = self.peers.lock() {
            m.insert(peer.id.to_b32(), peer.clone());
        }
    }

    /// Persist the hubs this device trusts (with their last addresses).
    fn save_peers(&self) {
        let Ok(client) = self.client() else { return };
        let peers: Vec<up_hub::HubPeer> = match self.peers.lock() {
            Ok(m) => m
                .values()
                .filter(|p| client.is_paired(&p.id))
                .cloned()
                .collect(),
            Err(_) => return,
        };
        write_json(
            &self.dir.join("peers.json"),
            &PeersFile { version: 1, peers },
        );
    }

    /// Known peer by id, or (for convenience) an address to probe.
    async fn resolve_peer(&self, peer: &str) -> R<up_hub::HubPeer> {
        if let Some(p) = Self::lock(&self.peers)?.get(peer.trim()) {
            return Ok(p.clone());
        }
        if DeviceId::parse(peer.trim()).is_ok() {
            return Err(UpError {
                code: ErrorCode::NotFound,
                message: format!(
                    "unknown hub {peer}: discover it (hub_discover) or probe its address (hub_probe) first"
                ),
            });
        }
        let addr = resolve_address(peer).await?;
        let (p, _) = self
            .client()?
            .probe(PeerAddr::lan(addr))
            .await
            .map_err(hub_err)?;
        self.remember(&p);
        Ok(p)
    }

    pub(crate) fn peer_dto(&self, p: &up_hub::HubPeer) -> t::HubPeer {
        let paired = self.client().map(|c| c.is_paired(&p.id)).unwrap_or(false);
        peer_dto(p, paired)
    }

    pub(crate) fn known_peers(&self) -> R<Vec<t::HubPeer>> {
        let peers: Vec<up_hub::HubPeer> = Self::lock(&self.peers)?.values().cloned().collect();
        let mut v: Vec<t::HubPeer> = peers.iter().map(|p| self.peer_dto(p)).collect();
        v.sort_by(|a, b| (!a.paired, &a.name, &a.id).cmp(&(!b.paired, &b.name, &b.id)));
        Ok(v)
    }

    // ---- server ------------------------------------------------------

    pub(crate) async fn start_server(self: Arc<Self>, name: String) -> R<t::HubServerInfo> {
        let name = name.trim().to_string();
        if name.is_empty() {
            return Err(invalid("hub name must not be empty"));
        }
        let _life = self.lifecycle.lock().await;
        let previous = {
            let mut g = Self::lock(&self.server)?;
            match g.as_ref() {
                Some(r) if r.info.name == name => return Ok(r.info.clone()),
                _ => g.take(),
            }
        };
        if let Some(r) = previous {
            Self::shutdown(r).await;
        }
        // mDNS advertising needs the Wi-Fi multicast lock on Android.
        let multicast = MulticastGuard::acquire("server");
        let saved: ServerFile = std::fs::read(self.dir.join("server.json"))
            .ok()
            .and_then(|b| serde_json::from_slice(&b).ok())
            .unwrap_or_default();
        let mut ports = vec![saved.port, DEFAULT_PORT, 0];
        ports.retain(|p| *p != 0);
        ports.dedup();
        ports.push(0);
        let store: Arc<dyn LibraryStore> = Arc::new(FfiStore {
            inner: self.base_store.clone(),
            notify_changes: true,
            progress: None,
        });
        let sink: Arc<dyn PadSink> = Arc::new(EnginePadSink);
        let mut last_err = None;
        let mut server = None;
        for port in ports {
            let mut cfg = HubConfig::new(&self.dir, name.clone());
            cfg.port = port;
            match HubServer::start(cfg, Arc::clone(&store), Arc::clone(&sink)).await {
                Ok(s) => {
                    server = Some(s);
                    break;
                }
                Err(HubError::Io(e)) if port != 0 => last_err = Some(HubError::Io(e)),
                Err(e) => {
                    last_err = Some(e);
                    break;
                }
            }
        }
        let Some(server) = server else {
            return Err(hub_err(last_err.unwrap_or(HubError::Closed)));
        };
        let addr = server.local_addr();
        write_json(
            &self.dir.join("server.json"),
            &ServerFile { port: addr.port() },
        );
        let info = t::HubServerInfo {
            id: server.device_id().to_b32(),
            name: server.name().to_string(),
            listen_address: addr.to_string(),
            port: addr.port(),
            udp_port: server.udp_addr().port(),
            addresses: lan_addresses(addr.port()),
            advertising: server.is_advertising(),
        };
        *Self::lock(&self.server)? = Some(Running {
            server,
            info: info.clone(),
            pairing_watch: None,
            _multicast: multicast,
        });
        emit(HubEvent::ServerStarted { port: info.port });
        Ok(info)
    }

    async fn shutdown(r: Running) {
        if let Some(w) = &r.pairing_watch {
            w.abort();
        }
        r.server.stop().await;
        emit(HubEvent::ServerStopped);
        // `_multicast` is released here.
    }

    pub(crate) async fn stop_server(self: Arc<Self>) -> R<()> {
        let _life = self.lifecycle.lock().await;
        let r = Self::lock(&self.server)?.take();
        if let Some(r) = r {
            Self::shutdown(r).await;
        }
        Ok(())
    }

    pub(crate) fn server_info(&self) -> R<Option<t::HubServerInfo>> {
        Ok(Self::lock(&self.server)?.as_ref().map(|r| {
            let mut info = r.info.clone();
            info.advertising = r.server.is_advertising();
            info
        }))
    }

    fn with_server<T>(&self, f: impl FnOnce(&mut Running) -> R<T>) -> R<T> {
        let mut g = Self::lock(&self.server)?;
        match g.as_mut() {
            Some(r) => f(r),
            None => Err(UpError {
                code: ErrorCode::InvalidState,
                message: "hub server is not running; call hub_start_server first".into(),
            }),
        }
    }

    pub(crate) fn new_pairing_code(self: Arc<Self>) -> R<t::PairingCode> {
        let me = Arc::clone(&self);
        self.with_server(|r| {
            let code = r.server.new_pairing_code();
            let ttl = code
                .expires_at
                .duration_since(SystemTime::now())
                .unwrap_or_default();
            let known: HashSet<DeviceId> =
                r.server.trusted_devices().iter().map(|d| d.id).collect();
            if let Some(w) = r.pairing_watch.take() {
                w.abort();
            }
            // Tell the hub UI when a device paired with this code.
            r.pairing_watch = Some(rt().spawn(watch_pairing(me, known, ttl)));
            Ok(t::PairingCode {
                code: code.code,
                expires_unix_ms: unix_ms(code.expires_at),
                ttl_secs: ttl.as_secs_f64().round() as u32,
            })
        })
    }

    pub(crate) fn cancel_pairing(&self) -> R<()> {
        self.with_server(|r| {
            r.server.cancel_pairing();
            if let Some(w) = r.pairing_watch.take() {
                w.abort();
            }
            Ok(())
        })
    }

    pub(crate) fn trusted_devices(&self) -> R<Vec<t::PairedDevice>> {
        let mut v: Vec<t::PairedDevice> = self
            .client()?
            .trusted_devices()
            .iter()
            .map(device_dto)
            .collect();
        v.sort_by_key(|d| std::cmp::Reverse(d.paired_unix_ms));
        Ok(v)
    }

    /// Revoke trust in a device (closes its controller session when we are
    /// the hub). Works whether or not the server is running.
    pub(crate) fn revoke(&self, id: &str) -> R<bool> {
        let id = DeviceId::parse(id.trim()).map_err(hub_err)?;
        let removed = {
            let g = Self::lock(&self.server)?;
            match g.as_ref() {
                Some(r) => r.server.revoke(&id).map_err(hub_err)?,
                None => self.client()?.forget(&id).map_err(hub_err)?,
            }
        };
        if let Ok(c) = self.client() {
            let _ = c.forget(&id);
        }
        self.save_peers();
        Ok(removed)
    }

    pub(crate) fn controller_stats(&self) -> R<Vec<t::ControllerSessionStats>> {
        Ok(Self::lock(&self.server)?
            .as_ref()
            .map(|r| r.server.controller_stats().iter().map(stats_dto).collect())
            .unwrap_or_default())
    }

    // ---- client ------------------------------------------------------

    /// Start mDNS browsing; `sink` returns `false` when the consumer is gone.
    pub(crate) fn discover(
        self: Arc<Self>,
        sink: impl Fn(t::HubPeerEvent) -> bool + Send + 'static,
    ) -> R<()> {
        self.stop_discovery();
        let client = self.client()?;
        // Android filters Wi-Fi multicast unless the lock is held.
        static SEQ: AtomicU64 = AtomicU64::new(0);
        let multicast =
            MulticastGuard::acquire(&format!("discover-{}", SEQ.fetch_add(1, Ordering::Relaxed)));
        let mut disc = {
            let _enter = rt().enter();
            client.discover().map_err(hub_err)?
        };
        let me = Arc::clone(&self);
        let task = rt().spawn(async move {
            let _multicast = multicast;
            while let Some(ev) = disc.next_event().await {
                let out = match ev {
                    DiscoveryEvent::Found(p) => {
                        me.remember(&p);
                        if client.is_paired(&p.id) {
                            me.save_peers();
                        }
                        emit(HubEvent::PeerDiscovered {
                            id: p.id.to_b32(),
                            name: p.name.clone(),
                        });
                        t::HubPeerEvent::Found(peer_dto(&p, client.is_paired(&p.id)))
                    }
                    DiscoveryEvent::Lost(id) => {
                        emit(HubEvent::PeerLost { id: id.to_b32() });
                        t::HubPeerEvent::Lost { id: id.to_b32() }
                    }
                };
                if !sink(out) {
                    break;
                }
            }
        });
        *Self::lock(&self.discovery)? = Some(task);
        Ok(())
    }

    pub(crate) fn stop_discovery(&self) {
        if let Ok(mut g) = self.discovery.lock()
            && let Some(task) = g.take()
        {
            task.abort();
        }
    }

    pub(crate) async fn probe(self: Arc<Self>, address: String) -> R<t::HubPeer> {
        let addr = resolve_address(&address).await?;
        let (p, _) = self
            .client()?
            .probe(PeerAddr::lan(addr))
            .await
            .map_err(hub_err)?;
        self.remember(&p);
        if self.client()?.is_paired(&p.id) {
            self.save_peers();
        }
        Ok(self.peer_dto(&p))
    }

    pub(crate) async fn pair(self: Arc<Self>, peer: String, code: String) -> R<t::PairedDevice> {
        let p = self.resolve_peer(&peer).await?;
        let dev = self.client()?.pair(&p, &code).await.map_err(hub_err)?;
        self.remember(&p);
        self.save_peers();
        emit(HubEvent::Paired {
            id: dev.id.to_b32(),
            name: dev.name.clone(),
        });
        Ok(device_dto(&dev))
    }

    pub(crate) async fn forget(self: Arc<Self>, peer: String) -> R<bool> {
        let id = DeviceId::parse(peer.trim()).map_err(hub_err)?;
        let removed = self.client()?.forget(&id).map_err(hub_err)?;
        if let Ok(mut m) = self.peers.lock() {
            m.remove(&id.to_b32());
        }
        self.save_peers();
        Ok(removed)
    }

    pub(crate) async fn sync(self: Arc<Self>, peer: String) -> R<t::SyncReport> {
        let p = self.resolve_peer(&peer).await?;
        let _one = self.sync_lock.lock().await;
        let peer_id = p.id.to_b32();
        emit(HubEvent::SyncStarted {
            peer: peer_id.clone(),
        });
        let progress = Arc::new(Progress::new(peer_id.clone()));
        let store = FfiStore {
            inner: self.base_store.clone(),
            notify_changes: false,
            progress: Some(Arc::clone(&progress)),
        };
        match self.client()?.sync(&p, &store).await {
            Ok(report) => {
                progress.flush();
                if report.local_changed > 0 {
                    library_changed();
                }
                let dto = report_dto(&report);
                emit(HubEvent::SyncFinished {
                    peer: peer_id,
                    report: dto.clone(),
                });
                Ok(dto)
            }
            Err(e) => {
                let e = hub_err(e);
                emit_error("sync", Some(&peer_id), e.clone());
                Err(e)
            }
        }
    }

    pub(crate) async fn controller_connect(
        self: Arc<Self>,
        peer: String,
    ) -> R<t::HubControllerStatus> {
        let p = self.resolve_peer(&peer).await?;
        let _life = self.lifecycle.lock().await;
        if let Some(old) = CONTROLLER.swap(None) {
            close_controller(old).await;
            emit(HubEvent::ControllerDisconnected);
        }
        let handle = self
            .client()?
            .controller_connect(&p)
            .await
            .map_err(hub_err)?;
        let serial = CONTROLLER_SERIAL.fetch_add(1, Ordering::Relaxed) + 1;
        let peer_id = p.id.to_b32();
        CONTROLLER.store(Some(Arc::new(ActiveController {
            handle: Mutex::new(handle),
            peer_id: peer_id.clone(),
            peer_name: p.name.clone(),
            serial,
        })));
        rt().spawn(controller_watchdog(serial));
        emit(HubEvent::ControllerConnected { peer: peer_id });
        Ok(controller_status())
    }

    pub(crate) async fn controller_disconnect(self: Arc<Self>) -> R<()> {
        let _life = self.lifecycle.lock().await;
        if let Some(old) = CONTROLLER.swap(None) {
            close_controller(old).await;
            emit(HubEvent::ControllerDisconnected);
        }
        Ok(())
    }
}

/// Emit `Paired` when a device joins the trust list while a code is active.
async fn watch_pairing(hub: Arc<Hub>, mut known: HashSet<DeviceId>, ttl: Duration) {
    let deadline = Instant::now() + ttl + Duration::from_secs(5);
    let mut tick = tokio::time::interval(Duration::from_millis(250));
    while Instant::now() < deadline {
        tick.tick().await;
        let devices = match hub.server.lock() {
            Ok(g) => match g.as_ref() {
                Some(r) => r.server.trusted_devices(),
                None => return,
            },
            Err(_) => return,
        };
        let mut paired = false;
        for d in devices {
            if known.insert(d.id) {
                paired = true;
                emit(HubEvent::Paired {
                    id: d.id.to_b32(),
                    name: d.name.clone(),
                });
            }
        }
        if paired {
            // Codes are single-use.
            return;
        }
    }
}
