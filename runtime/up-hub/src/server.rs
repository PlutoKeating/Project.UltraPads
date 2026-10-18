//! 桌面个人 Hub：TLS + HTTP/1.1（axum）控制面、UDP 控制器数据面、mDNS 广播。

use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};

use axum::body::Body;
use axum::extract::{DefaultBodyLimit, Path, State};
use axum::http::{HeaderMap, HeaderValue, StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use futures_util::StreamExt;
use hyper_util::rt::{TokioIo, TokioTimer};
use hyper_util::service::TowerToHyperService;
use spake2::{Ed25519Group, Identity, Password, Spake2};
use tokio::io::{AsyncRead, AsyncWrite};
use tokio::net::{TcpListener, UdpSocket};
use tokio_rustls::TlsAcceptor;
use tokio_util::io::ReaderStream;
use tokio_util::sync::CancellationToken;
use tokio_util::task::TaskTracker;

use crate::client::HubPeer;
use crate::controller::{ControllerRegistry, ControllerSessionStats, run_udp};
use crate::discovery::Advertiser;
use crate::identity::{DeviceId, HubContext, TrustedDevice, open_context};
use crate::model::{self, BlobHash};
use crate::pairing::{self, ROLE_DEVICE, ROLE_HUB, SPAKE_ID_DEVICE, SPAKE_ID_HUB};
use crate::sink::PadSink;
use crate::store::{BlobStatus, LibraryStore};
use crate::tls::{self, TlsMaterial};
use crate::transport::PeerAddr;
use crate::util::{b64, ct_eq, unb64};
use crate::wire::*;
use crate::{HubError, PROTOCOL_VERSION, Result};

/// Hub 配置。
#[derive(Clone, Debug)]
pub struct HubConfig {
    /// 数据目录（身份密钥、受信列表）。
    pub data_dir: PathBuf,
    /// 设备名（mDNS 与配对时展示）。
    pub device_name: String,
    /// 监听地址，默认 `0.0.0.0`。
    pub bind_addr: IpAddr,
    /// 控制面 TCP 端口，0 = 随机。
    pub port: u16,
    /// 控制器 UDP 端口，0 = 随机。
    pub udp_port: u16,
    /// 是否通过 mDNS 广播。
    pub advertise: bool,
    /// 配对码有效期。
    pub pairing_code_ttl: Duration,
    /// 每个配对码允许的尝试次数。
    pub pairing_max_attempts: u32,
    /// 控制器会话空闲超时。
    pub controller_idle_timeout: Duration,
    /// 控制器建议 ping 间隔。
    pub controller_ping_interval: Duration,
    /// 单个 blob 最大字节数。
    pub max_blob_size: u64,
    /// 最大并发连接数。
    pub max_connections: usize,
}

impl HubConfig {
    /// 默认配置。
    pub fn new(data_dir: impl Into<PathBuf>, device_name: impl Into<String>) -> Self {
        Self {
            data_dir: data_dir.into(),
            device_name: device_name.into(),
            bind_addr: IpAddr::V4(Ipv4Addr::UNSPECIFIED),
            port: 0,
            udp_port: 0,
            advertise: true,
            pairing_code_ttl: Duration::from_secs(300),
            pairing_max_attempts: 5,
            controller_idle_timeout: Duration::from_secs(10),
            controller_ping_interval: Duration::from_millis(1000),
            max_blob_size: 8 << 30,
            max_connections: 64,
        }
    }
}

/// 一次性配对码。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PairingCode {
    /// 6 位数字。
    pub code: String,
    /// 过期时间。
    pub expires_at: SystemTime,
}

struct ActiveCode {
    code: String,
    expires: Instant,
    attempts_left: u32,
    generation: u64,
}

struct PendingPair {
    device: DeviceId,
    name: String,
    expect: [u8; 32],
    generation: u64,
    created: Instant,
}

#[derive(Default)]
struct PairingState {
    active: Option<ActiveCode>,
    pending: HashMap<String, PendingPair>,
    generation: u64,
}

impl PairingState {
    fn purge(&mut self) {
        let now = Instant::now();
        if self.active.as_ref().is_some_and(|a| a.expires <= now) {
            self.active = None;
        }
        self.pending
            .retain(|_, p| now.duration_since(p.created) < Duration::from_secs(120));
    }
}

struct Shared {
    ctx: Arc<HubContext>,
    name: String,
    store: Arc<dyn LibraryStore>,
    controllers: Arc<ControllerRegistry>,
    pairing: Mutex<PairingState>,
    merge_lock: tokio::sync::Mutex<()>,
    udp_port: u16,
    cfg: HubConfig,
}

#[derive(Clone, Copy)]
struct Peer(DeviceId);

/// 运行中的 Hub。
pub struct HubServer {
    shared: Arc<Shared>,
    cancel: CancellationToken,
    tracker: TaskTracker,
    local_addr: SocketAddr,
    udp_addr: SocketAddr,
    advertiser: Mutex<Option<Advertiser>>,
}

impl std::fmt::Debug for HubServer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("HubServer")
            .field("id", &self.device_id())
            .field("local_addr", &self.local_addr)
            .field("udp_addr", &self.udp_addr)
            .finish()
    }
}

impl HubServer {
    /// 启动 Hub。mDNS 广播失败只记录警告（仍可通过 IP 直连）。
    pub async fn start(
        cfg: HubConfig,
        store: Arc<dyn LibraryStore>,
        pad_sink: Arc<dyn PadSink>,
    ) -> Result<Self> {
        let ctx = open_context(&cfg.data_dir)?;
        let material = TlsMaterial::new(&ctx.identity)?;
        let acceptor = TlsAcceptor::from(tls::server_config(&material)?);
        let listener = TcpListener::bind((cfg.bind_addr, cfg.port)).await?;
        let local_addr = listener.local_addr()?;
        let udp = Arc::new(UdpSocket::bind((cfg.bind_addr, cfg.udp_port)).await?);
        let udp_addr = udp.local_addr()?;
        let controllers = Arc::new(ControllerRegistry::new(
            pad_sink,
            cfg.controller_idle_timeout,
        ));
        let shared = Arc::new(Shared {
            ctx: ctx.clone(),
            name: cfg.device_name.clone(),
            store,
            controllers: controllers.clone(),
            pairing: Mutex::new(PairingState::default()),
            merge_lock: tokio::sync::Mutex::new(()),
            udp_port: udp_addr.port(),
            cfg: cfg.clone(),
        });
        let cancel = CancellationToken::new();
        let tracker = TaskTracker::new();
        let router = router(shared.clone());

        tracker.spawn(run_udp(udp, controllers, cancel.clone()));
        tracker.spawn(accept_loop(
            listener,
            acceptor,
            router,
            cancel.clone(),
            tracker.clone(),
            cfg.max_connections,
        ));

        let advertiser = if cfg.advertise {
            match Advertiser::start(
                &ctx.identity.id(),
                &cfg.device_name,
                local_addr.port(),
                cfg.bind_addr,
            ) {
                Ok(a) => Some(a),
                Err(e) => {
                    tracing::warn!("mDNS advertise failed, LAN discovery disabled: {e}");
                    None
                }
            }
        } else {
            None
        };
        tracing::info!(id = %ctx.identity.id(), %local_addr, %udp_addr, "hub started");
        Ok(Self {
            shared,
            cancel,
            tracker,
            local_addr,
            udp_addr,
            advertiser: Mutex::new(advertiser),
        })
    }

    /// 本机设备 ID。
    pub fn device_id(&self) -> DeviceId {
        self.shared.ctx.identity.id()
    }

    /// 设备名。
    pub fn name(&self) -> &str {
        &self.shared.name
    }

    /// 控制面监听地址。
    pub fn local_addr(&self) -> SocketAddr {
        self.local_addr
    }

    /// 控制器 UDP 地址。
    pub fn udp_addr(&self) -> SocketAddr {
        self.udp_addr
    }

    /// 是否正在 mDNS 广播。
    pub fn is_advertising(&self) -> bool {
        self.advertiser.lock().expect("advertiser").is_some()
    }

    /// 以本机回环（或绑定地址）描述自己，便于同进程测试或手动直连。
    pub fn local_peer(&self) -> HubPeer {
        let ip = if self.local_addr.ip().is_unspecified() {
            IpAddr::V4(Ipv4Addr::LOCALHOST)
        } else {
            self.local_addr.ip()
        };
        HubPeer {
            id: self.device_id(),
            name: self.shared.name.clone(),
            addr: PeerAddr::lan(SocketAddr::new(ip, self.local_addr.port())),
        }
    }

    /// 生成新的一次性配对码（作废旧码与进行中的配对）。
    pub fn new_pairing_code(&self) -> PairingCode {
        let ttl = self.shared.cfg.pairing_code_ttl;
        let code = pairing::generate_code();
        let mut st = self.shared.pairing.lock().expect("pairing");
        st.generation += 1;
        st.pending.clear();
        st.active = Some(ActiveCode {
            code: code.clone(),
            expires: Instant::now() + ttl,
            attempts_left: self.shared.cfg.pairing_max_attempts,
            generation: st.generation,
        });
        PairingCode {
            code,
            expires_at: SystemTime::now() + ttl,
        }
    }

    /// 关闭配对窗口。
    pub fn cancel_pairing(&self) {
        let mut st = self.shared.pairing.lock().expect("pairing");
        st.active = None;
        st.pending.clear();
    }

    /// 当前配对码是否仍有效。
    pub fn pairing_open(&self) -> bool {
        let mut st = self.shared.pairing.lock().expect("pairing");
        st.purge();
        st.active.as_ref().is_some_and(|a| a.attempts_left > 0)
    }

    /// 受信设备列表。
    pub fn trusted_devices(&self) -> Vec<TrustedDevice> {
        self.shared.ctx.trust.list()
    }

    /// 撤销设备信任，并立即关闭它的控制器会话。之后它的所有请求都会被拒绝。
    pub fn revoke(&self, id: &DeviceId) -> Result<bool> {
        let removed = self.shared.ctx.trust.remove(id)?;
        self.shared.controllers.close_device(id);
        Ok(removed)
    }

    /// 控制器会话统计。
    pub fn controller_stats(&self) -> Vec<ControllerSessionStats> {
        self.shared.controllers.stats()
    }

    /// 停止服务：停止广播、关闭连接（最多等待 3 秒）、释放所有控制器按住的 pad。
    pub async fn stop(self) {
        let adv = self.advertiser.lock().expect("advertiser").take();
        if let Some(adv) = adv {
            let _ = tokio::task::spawn_blocking(move || adv.stop()).await;
        }
        self.cancel.cancel();
        self.tracker.close();
        if tokio::time::timeout(Duration::from_secs(3), self.tracker.wait())
            .await
            .is_err()
        {
            tracing::warn!("hub stop: some connections did not close in time");
        }
        self.shared.controllers.close_all();
        tracing::info!("hub stopped");
    }
}

impl Drop for HubServer {
    fn drop(&mut self) {
        self.cancel.cancel();
        if let Some(adv) = self.advertiser.lock().expect("advertiser").take() {
            std::thread::spawn(move || adv.stop());
        }
    }
}

async fn accept_loop(
    listener: TcpListener,
    acceptor: TlsAcceptor,
    router: Router,
    cancel: CancellationToken,
    tracker: TaskTracker,
    max_connections: usize,
) {
    let limit = Arc::new(tokio::sync::Semaphore::new(max_connections));
    loop {
        let (tcp, remote) = tokio::select! {
            _ = cancel.cancelled() => break,
            r = listener.accept() => match r {
                Ok(v) => v,
                Err(e) => {
                    tracing::warn!("accept failed: {e}");
                    tokio::time::sleep(Duration::from_millis(100)).await;
                    continue;
                }
            },
        };
        let Ok(permit) = limit.clone().try_acquire_owned() else {
            tracing::warn!(%remote, "too many connections, dropping");
            continue;
        };
        let acceptor = acceptor.clone();
        let router = router.clone();
        let cancel = cancel.clone();
        tracker.spawn(async move {
            let _permit = permit;
            let _ = tcp.set_nodelay(true);
            let tls =
                match tokio::time::timeout(Duration::from_secs(10), acceptor.accept(tcp)).await {
                    Ok(Ok(s)) => s,
                    Ok(Err(e)) => {
                        tracing::debug!(%remote, "tls handshake failed: {e}");
                        return;
                    }
                    Err(_) => {
                        tracing::debug!(%remote, "tls handshake timed out");
                        return;
                    }
                };
            let peer = match tls::peer_id(tls.get_ref().1.peer_certificates()) {
                Ok(p) => p,
                Err(e) => {
                    tracing::debug!(%remote, "bad client cert: {e}");
                    return;
                }
            };
            serve_connection(tls, peer, router, cancel).await;
        });
    }
}

/// 在任意已认证的字节流上提供 Hub HTTP 服务（LAN/TLS 与未来的 iroh 共用）。
async fn serve_connection<I>(io: I, peer: DeviceId, router: Router, cancel: CancellationToken)
where
    I: AsyncRead + AsyncWrite + Send + Unpin + 'static,
{
    let svc = TowerToHyperService::new(router.layer(Extension(Peer(peer))));
    let mut builder = hyper::server::conn::http1::Builder::new();
    builder
        .timer(TokioTimer::new())
        .header_read_timeout(Duration::from_secs(30));
    let conn = builder.serve_connection(TokioIo::new(io), svc);
    tokio::pin!(conn);
    tokio::select! {
        r = conn.as_mut() => {
            if let Err(e) = r {
                tracing::debug!(peer = %peer.short(), "connection error: {e}");
            }
        }
        _ = cancel.cancelled() => {
            conn.as_mut().graceful_shutdown();
            let _ = tokio::time::timeout(Duration::from_secs(2), conn).await;
        }
    }
}

fn router(shared: Arc<Shared>) -> Router {
    Router::new()
        .route("/v1/info", get(info))
        .route("/v1/pair/start", post(pair_start))
        .route("/v1/pair/finish", post(pair_finish))
        .route("/v1/manifest", get(get_manifest))
        .route("/v1/manifest/merge", post(merge_manifest))
        .route("/v1/blobs/missing", post(blobs_missing))
        .route("/v1/blob/{hash}", get(get_blob).put(put_blob))
        .route("/v1/controller/open", post(controller_open))
        .route("/v1/controller/close", post(controller_close))
        .layer(DefaultBodyLimit::max(64 << 20))
        .with_state(shared)
}

// ---------------------------------------------------------------- errors

struct ApiError {
    status: StatusCode,
    body: ErrorBody,
}

impl ApiError {
    fn new(status: StatusCode, code: &str, message: impl Into<String>) -> Self {
        Self {
            status,
            body: ErrorBody {
                error: code.into(),
                message: message.into(),
                ..Default::default()
            },
        }
    }
    fn not_paired() -> Self {
        Self::new(
            StatusCode::FORBIDDEN,
            "not_paired",
            "device is not paired with this hub",
        )
    }
    fn bad_request(msg: impl Into<String>) -> Self {
        Self::new(StatusCode::BAD_REQUEST, "bad_request", msg)
    }
}

impl From<HubError> for ApiError {
    fn from(e: HubError) -> Self {
        match e {
            HubError::InvalidInput(m) | HubError::Protocol(m) => Self::bad_request(m),
            HubError::HashMismatch { .. } => Self::new(
                StatusCode::UNPROCESSABLE_ENTITY,
                "hash_mismatch",
                e.to_string(),
            ),
            HubError::OffsetMismatch { expected } => {
                let mut err = Self::new(StatusCode::CONFLICT, "offset_mismatch", e.to_string());
                err.body.expected_offset = Some(expected);
                err
            }
            HubError::Busy(_) => Self::new(StatusCode::CONFLICT, "busy", e.to_string()),
            HubError::BlobNotFound(_) => {
                Self::new(StatusCode::NOT_FOUND, "not_found", e.to_string())
            }
            other => {
                tracing::error!("internal error: {other}");
                Self::new(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal",
                    other.to_string(),
                )
            }
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(self.body)).into_response()
    }
}

type ApiResult<T> = std::result::Result<T, ApiError>;

fn require_trusted(s: &Shared, peer: &DeviceId) -> ApiResult<TrustedDevice> {
    s.ctx.trust.get(peer).ok_or_else(ApiError::not_paired)
}

fn sanitize_name(name: &str) -> ApiResult<String> {
    let n: String = name.chars().filter(|c| !c.is_control()).take(64).collect();
    let n = n.trim().to_string();
    if n.is_empty() {
        return Err(ApiError::bad_request("device name must not be empty"));
    }
    Ok(n)
}

// ---------------------------------------------------------------- handlers

async fn info(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
) -> Json<InfoResponse> {
    let pairing_open = {
        let mut st = s.pairing.lock().expect("pairing");
        st.purge();
        st.active.as_ref().is_some_and(|a| a.attempts_left > 0)
    };
    Json(InfoResponse {
        v: PROTOCOL_VERSION,
        id: s.ctx.identity.id(),
        name: s.name.clone(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        paired: s.ctx.trust.get(&peer).is_some(),
        pairing_open,
    })
}

async fn pair_start(
    State(s): State<Arc<Shared>>,
    Extension(Peer(device)): Extension<Peer>,
    Json(req): Json<PairStartRequest>,
) -> ApiResult<Json<PairStartResponse>> {
    let name = sanitize_name(&req.name)?;
    let msg_a = unb64(&req.spake)?;
    if msg_a.len() != 33 {
        return Err(ApiError::bad_request("bad spake message"));
    }
    let (code, generation) = {
        let mut st = s.pairing.lock().expect("pairing");
        st.purge();
        let Some(active) = st.active.as_mut() else {
            return Err(ApiError::new(
                StatusCode::GONE,
                "pairing_closed",
                "no active pairing code",
            ));
        };
        if active.attempts_left == 0 {
            st.active = None;
            return Err(ApiError::new(
                StatusCode::GONE,
                "pairing_closed",
                "pairing attempts exhausted",
            ));
        }
        active.attempts_left -= 1;
        (active.code.clone(), active.generation)
    };
    let (spake, msg_b) = Spake2::<Ed25519Group>::start_b(
        &Password::new(code.as_bytes()),
        &Identity::new(SPAKE_ID_DEVICE),
        &Identity::new(SPAKE_ID_HUB),
    );
    let key = spake
        .finish(&msg_a)
        .map_err(|_| ApiError::bad_request("bad spake message"))?;
    let t = pairing::transcript(&s.ctx.identity.id(), &device, &msg_a, &msg_b);
    let hub_confirm = pairing::confirm(&key, ROLE_HUB, &t);
    let expect = pairing::confirm(&key, ROLE_DEVICE, &t);
    let pair_id = data_encoding::HEXLOWER.encode(&rand::random::<[u8; 16]>());
    {
        let mut st = s.pairing.lock().expect("pairing");
        if st.pending.len() >= 16
            && let Some(oldest) = st
                .pending
                .iter()
                .min_by_key(|(_, p)| p.created)
                .map(|(k, _)| k.clone())
        {
            st.pending.remove(&oldest);
        }
        st.pending.insert(
            pair_id.clone(),
            PendingPair {
                device,
                name,
                expect,
                generation,
                created: Instant::now(),
            },
        );
    }
    Ok(Json(PairStartResponse {
        pair_id,
        spake: b64(&msg_b),
        confirm: b64(&hub_confirm),
    }))
}

async fn pair_finish(
    State(s): State<Arc<Shared>>,
    Extension(Peer(device)): Extension<Peer>,
    Json(req): Json<PairFinishRequest>,
) -> ApiResult<Json<PairFinishResponse>> {
    let got = unb64(&req.confirm)?;
    let p = {
        let mut st = s.pairing.lock().expect("pairing");
        st.purge();
        let Some(p) = st.pending.remove(&req.pair_id) else {
            return Err(ApiError::new(
                StatusCode::NOT_FOUND,
                "unknown_pair",
                "unknown or expired pairing session",
            ));
        };
        if p.device != device {
            return Err(ApiError::new(
                StatusCode::FORBIDDEN,
                "pairing_failed",
                "pairing session belongs to another device",
            ));
        }
        let gen_ok = st
            .active
            .as_ref()
            .is_some_and(|a| a.generation == p.generation);
        if !gen_ok {
            return Err(ApiError::new(
                StatusCode::GONE,
                "pairing_closed",
                "pairing code expired",
            ));
        }
        if !ct_eq(&got, &p.expect) {
            tracing::warn!(device = %device.short(), "pairing confirmation failed");
            return Err(ApiError::new(
                StatusCode::FORBIDDEN,
                "pairing_failed",
                "wrong pairing code",
            ));
        }
        // 一次性：成功即作废。
        st.active = None;
        st.pending.clear();
        p
    };
    s.ctx.trust.insert(device, &p.name)?;
    tracing::info!(device = %device, name = %p.name, "device paired");
    Ok(Json(PairFinishResponse {
        hub_id: s.ctx.identity.id(),
        hub_name: s.name.clone(),
    }))
}

async fn get_manifest(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
) -> ApiResult<Json<model::LibraryManifest>> {
    require_trusted(&s, &peer)?;
    Ok(Json(s.store.manifest().await?))
}

async fn merge_manifest(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
    Json(req): Json<MergeRequest>,
) -> ApiResult<Json<MergeResponse>> {
    require_trusted(&s, &peer)?;
    req.manifest.validate()?;
    let _g = s.merge_lock.lock().await;
    let current = s.store.manifest().await?;
    let preview = model::merge(&current, &req.manifest);
    // 不变量：清单永远不引用本地缺失的 blob。只检查本次会改变的条目。
    let mut missing = Vec::new();
    let mut checked = std::collections::HashSet::new();
    for e in preview.manifest.live_entries() {
        if current.entries.get(&e.id) == Some(e) {
            continue;
        }
        for b in &e.blobs {
            if checked.insert(b.hash)
                && !matches!(s.store.blob_status(&b.hash).await?, BlobStatus::Complete(_))
            {
                missing.push(b.hash);
            }
        }
    }
    if !missing.is_empty() {
        let mut err = ApiError::new(
            StatusCode::CONFLICT,
            "missing_blobs",
            format!("{} referenced blobs are not uploaded yet", missing.len()),
        );
        err.body.missing = missing;
        return Err(err);
    }
    let out = s.store.merge_manifest(&req.manifest).await?;
    Ok(Json(MergeResponse {
        manifest: out.manifest,
        conflicts: out.conflicts,
        changed: out.changed,
    }))
}

async fn blobs_missing(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
    Json(req): Json<MissingRequest>,
) -> ApiResult<Json<MissingResponse>> {
    require_trusted(&s, &peer)?;
    if req.hashes.len() > 100_000 {
        return Err(ApiError::bad_request("too many hashes (max 100000)"));
    }
    let mut missing = Vec::new();
    for h in req.hashes {
        match s.store.blob_status(&h).await? {
            BlobStatus::Complete(_) => {}
            BlobStatus::Partial(n) => missing.push(MissingBlob { hash: h, offset: n }),
            BlobStatus::Missing => missing.push(MissingBlob { hash: h, offset: 0 }),
        }
    }
    Ok(Json(MissingResponse { missing }))
}

fn parse_range(headers: &HeaderMap) -> Option<u64> {
    let v = headers.get(header::RANGE)?.to_str().ok()?;
    let rest = v.trim().strip_prefix("bytes=")?;
    let (start, end) = rest.split_once('-')?;
    if !end.is_empty() || start.contains(',') {
        return None; // 只支持 "bytes=N-"；其他形式按 RFC 9110 忽略 Range。
    }
    start.parse().ok()
}

async fn get_blob(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
    Path(hash): Path<String>,
    headers: HeaderMap,
) -> ApiResult<Response> {
    require_trusted(&s, &peer)?;
    let h = BlobHash::parse(&hash)?;
    let BlobStatus::Complete(len) = s.store.blob_status(&h).await? else {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "not_found",
            "blob not found",
        ));
    };
    let offset = parse_range(&headers);
    if let Some(off) = offset
        && off >= len
    {
        let mut r = ApiError::new(
            StatusCode::RANGE_NOT_SATISFIABLE,
            "range",
            "range not satisfiable",
        )
        .into_response();
        r.headers_mut().insert(
            header::CONTENT_RANGE,
            HeaderValue::from_str(&format!("bytes */{len}")).expect("header"),
        );
        return Ok(r);
    }
    let off = offset.unwrap_or(0);
    let Some((len, reader)) = s.store.open_blob(&h, off).await? else {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "not_found",
            "blob not found",
        ));
    };
    let body = Body::from_stream(ReaderStream::with_capacity(reader, 64 * 1024));
    let mut resp = Response::new(body);
    *resp.status_mut() = if offset.is_some() {
        StatusCode::PARTIAL_CONTENT
    } else {
        StatusCode::OK
    };
    let hm = resp.headers_mut();
    hm.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("application/octet-stream"),
    );
    hm.insert(header::CONTENT_LENGTH, HeaderValue::from(len - off));
    hm.insert(HEADER_BLOB_SIZE, HeaderValue::from(len));
    if offset.is_some() {
        hm.insert(
            header::CONTENT_RANGE,
            HeaderValue::from_str(&format!("bytes {off}-{}/{len}", len.saturating_sub(1)))
                .expect("header"),
        );
    }
    Ok(resp)
}

async fn put_blob(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
    Path(hash): Path<String>,
    headers: HeaderMap,
    body: Body,
) -> ApiResult<(StatusCode, Json<PutBlobResponse>)> {
    require_trusted(&s, &peer)?;
    let h = BlobHash::parse(&hash)?;
    let offset: u64 = match headers.get(HEADER_OFFSET) {
        Some(v) => v
            .to_str()
            .ok()
            .and_then(|v| v.parse().ok())
            .ok_or_else(|| ApiError::bad_request("bad x-up-offset"))?,
        None => 0,
    };
    match s.store.blob_status(&h).await? {
        BlobStatus::Complete(n) => {
            return Ok((
                StatusCode::OK,
                Json(PutBlobResponse {
                    hash: h,
                    size: n,
                    status: "exists".into(),
                }),
            ));
        }
        BlobStatus::Partial(n) if offset != 0 && offset != n => {
            return Err(HubError::OffsetMismatch { expected: n }.into());
        }
        BlobStatus::Missing if offset != 0 => {
            return Err(HubError::OffsetMismatch { expected: 0 }.into());
        }
        _ => {}
    }
    let max = s.cfg.max_blob_size;
    let mut w = s.store.blob_writer(&h, offset).await?;
    let mut stream = body.into_data_stream();
    while let Some(chunk) = stream.next().await {
        // 传输中断：直接返回，writer 被 drop，部分数据保留以便续传。
        let chunk = chunk.map_err(|e| ApiError::bad_request(format!("body: {e}")))?;
        if w.written() + chunk.len() as u64 > max {
            let _ = w.abort().await;
            return Err(ApiError::new(
                StatusCode::PAYLOAD_TOO_LARGE,
                "too_large",
                "blob exceeds max size",
            ));
        }
        w.write(&chunk).await?;
    }
    let size = w.finish().await?;
    Ok((
        StatusCode::CREATED,
        Json(PutBlobResponse {
            hash: h,
            size,
            status: "stored".into(),
        }),
    ))
}

async fn controller_open(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
) -> ApiResult<Json<ControllerOpenResponse>> {
    let dev = require_trusted(&s, &peer)?;
    let (session_id, key) = s.controllers.open(peer, &dev.name);
    Ok(Json(ControllerOpenResponse {
        session_id,
        key: b64(&key),
        udp_port: s.udp_port,
        ping_interval_ms: s.cfg.controller_ping_interval.as_millis() as u64,
        idle_timeout_ms: s.controllers.idle_timeout().as_millis() as u64,
    }))
}

async fn controller_close(
    State(s): State<Arc<Shared>>,
    Extension(Peer(peer)): Extension<Peer>,
    Json(req): Json<ControllerCloseRequest>,
) -> ApiResult<StatusCode> {
    require_trusted(&s, &peer)?;
    s.controllers.close(req.session_id, &peer);
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn range_parsing() {
        let mut h = HeaderMap::new();
        assert_eq!(parse_range(&h), None);
        h.insert(header::RANGE, HeaderValue::from_static("bytes=100-"));
        assert_eq!(parse_range(&h), Some(100));
        h.insert(header::RANGE, HeaderValue::from_static("bytes=0-10"));
        assert_eq!(parse_range(&h), None);
        h.insert(header::RANGE, HeaderValue::from_static("items=1-"));
        assert_eq!(parse_range(&h), None);
    }
}
