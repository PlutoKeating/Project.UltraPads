//! Hub 客户端：探测、配对、同步、控制器连接。
//!
//! 每个对端一个 `PeerSession`：按 Hub 公钥钉扎的 TLS 1.3 + HTTP/1.1 连接池。

use std::collections::{BTreeSet, HashMap};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use bytes::Bytes;
use futures_util::{FutureExt, StreamExt, TryStreamExt};
use http_body_util::combinators::UnsyncBoxBody;
use http_body_util::{BodyExt, Full, Limited, StreamBody};
use hyper::body::{Frame, Incoming};
use hyper::client::conn::http1::SendRequest;
use hyper::header::{CONTENT_LENGTH, CONTENT_TYPE, HOST, RANGE};
use hyper::{Method, Request, Response, StatusCode};
use hyper_util::rt::TokioIo;
use rustls::pki_types::ServerName;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use spake2::{Ed25519Group, Identity, Password, Spake2};
use tokio_rustls::TlsConnector;
use tokio_util::io::ReaderStream;

use crate::controller::ControllerHandle;
use crate::discovery::{self, Discovery};
use crate::identity::{DeviceId, HubContext, TrustedDevice, open_context};
use crate::model::{BlobHash, LibraryManifest, SyncReport, merge};
use crate::pairing::{self, ROLE_DEVICE, ROLE_HUB, SPAKE_ID_DEVICE, SPAKE_ID_HUB};
use crate::store::{BlobStatus, LibraryStore};
use crate::tls::{self, TLS_SERVER_NAME, TlsMaterial};
use crate::transport::{HubTransport, LanTransport, PeerAddr};
use crate::util::{b64, ct_eq, unb64};
use crate::wire::*;
use crate::{HubError, PROTOCOL_VERSION, Result};

type ReqBody = UnsyncBoxBody<Bytes, std::io::Error>;

/// 一个可连接的 Hub。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HubPeer {
    /// Hub 设备 ID（TLS 握手时按此公钥钉扎）。
    pub id: DeviceId,
    /// 设备名。
    pub name: String,
    /// 地址。
    pub addr: PeerAddr,
}

/// 客户端配置。
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// 数据目录（身份密钥、受信列表）。可与 HubConfig 使用同一目录。
    pub data_dir: PathBuf,
    /// 本机设备名（配对时发送给 Hub）。
    pub device_name: String,
    /// JSON 请求超时。
    pub request_timeout: Duration,
    /// blob 传输时，单次读取的空闲超时。
    pub transfer_idle_timeout: Duration,
    /// 并发传输的 blob 数。
    pub transfer_concurrency: usize,
}

impl ClientConfig {
    /// 默认配置。
    pub fn new(data_dir: impl Into<PathBuf>, device_name: impl Into<String>) -> Self {
        Self {
            data_dir: data_dir.into(),
            device_name: device_name.into(),
            request_timeout: Duration::from_secs(20),
            transfer_idle_timeout: Duration::from_secs(30),
            transfer_concurrency: 4,
        }
    }
}

/// Hub 客户端。克隆开销很小（内部 `Arc`）。
#[derive(Clone)]
pub struct HubClient {
    inner: Arc<ClientInner>,
}

struct ClientInner {
    ctx: Arc<HubContext>,
    cfg: ClientConfig,
    transport: Arc<dyn HubTransport>,
    tls: TlsMaterial,
    sessions: Mutex<HashMap<DeviceId, Arc<PeerSession>>>,
}

impl std::fmt::Debug for HubClient {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("HubClient")
            .field("id", &self.device_id())
            .finish_non_exhaustive()
    }
}

impl HubClient {
    /// 使用局域网传输创建客户端。
    pub fn new(cfg: ClientConfig) -> Result<Self> {
        Self::with_transport(cfg, Arc::new(LanTransport::default()))
    }

    /// 使用自定义传输创建客户端（例如将来的 iroh）。
    pub fn with_transport(cfg: ClientConfig, transport: Arc<dyn HubTransport>) -> Result<Self> {
        let ctx = open_context(&cfg.data_dir)?;
        let tls = TlsMaterial::new(&ctx.identity)?;
        Ok(Self {
            inner: Arc::new(ClientInner {
                ctx,
                cfg,
                transport,
                tls,
                sessions: Mutex::new(HashMap::new()),
            }),
        })
    }

    /// 本机设备 ID。
    pub fn device_id(&self) -> DeviceId {
        self.inner.ctx.identity.id()
    }

    /// 本机信任的 Hub/设备。
    pub fn trusted_devices(&self) -> Vec<TrustedDevice> {
        self.inner.ctx.trust.list()
    }

    /// 是否已与该设备配对（本地视角）。
    pub fn is_paired(&self, id: &DeviceId) -> bool {
        self.inner.ctx.trust.get(id).is_some()
    }

    /// 取消对某设备的信任（本地）。
    pub fn forget(&self, id: &DeviceId) -> Result<bool> {
        self.inner.sessions.lock().expect("sessions").remove(id);
        self.inner.ctx.trust.remove(id)
    }

    /// 通过 mDNS 浏览局域网中的 Hub（不包含本机）。
    pub fn discover(&self) -> Result<Discovery> {
        discovery::discover(Some(self.device_id()))
    }

    /// 直连地址探测：读取对端身份（取自 TLS 证书，并与 `/v1/info` 核对）。
    /// 适用于用户手动输入 IP 或扫描二维码的场景。
    pub async fn probe(&self, addr: PeerAddr) -> Result<(HubPeer, InfoResponse)> {
        let cfg = tls::probe_client_config(&self.inner.tls)?;
        let session = Arc::new(PeerSession::new(self, addr.clone(), cfg, None));
        let info: InfoResponse = session.json(Method::GET, "/v1/info", None::<&()>).await?;
        let seen = session
            .last_peer
            .lock()
            .expect("peer")
            .ok_or_else(|| HubError::Tls("no peer identity".into()))?;
        if info.id != seen {
            return Err(HubError::Tls(
                "hub /v1/info id does not match its TLS key".into(),
            ));
        }
        if info.v != PROTOCOL_VERSION {
            return Err(HubError::Protocol(format!(
                "unsupported hub protocol v{}",
                info.v
            )));
        }
        Ok((
            HubPeer {
                id: seen,
                name: info.name.clone(),
                addr,
            },
            info,
        ))
    }

    fn session(&self, peer: &HubPeer) -> Result<Arc<PeerSession>> {
        let mut map = self.inner.sessions.lock().expect("sessions");
        if let Some(s) = map.get(&peer.id)
            && s.addr == peer.addr
        {
            return Ok(s.clone());
        }
        let cfg = tls::client_config(&self.inner.tls, peer.id)?;
        let s = Arc::new(PeerSession::new(
            self,
            peer.addr.clone(),
            cfg,
            Some(peer.id),
        ));
        map.insert(peer.id, s.clone());
        Ok(s)
    }

    fn require_trusted(&self, peer: &HubPeer) -> Result<()> {
        if self.is_paired(&peer.id) {
            Ok(())
        } else {
            Err(HubError::NotPaired(peer.id.to_string()))
        }
    }

    /// 用 Hub 上显示的 6 位配对码配对。成功后双方互相信任。
    pub async fn pair(&self, peer: &HubPeer, code: &str) -> Result<TrustedDevice> {
        let code = pairing::normalize_code(code)?;
        let session = self.session(peer)?;
        let (spake, msg_a) = Spake2::<Ed25519Group>::start_a(
            &Password::new(code.as_bytes()),
            &Identity::new(SPAKE_ID_DEVICE),
            &Identity::new(SPAKE_ID_HUB),
        );
        let start: PairStartResponse = session
            .json(
                Method::POST,
                "/v1/pair/start",
                Some(&PairStartRequest {
                    name: self.inner.cfg.device_name.clone(),
                    spake: b64(&msg_a),
                }),
            )
            .await
            .map_err(pairing_err)?;
        let msg_b = unb64(&start.spake)?;
        let key = spake
            .finish(&msg_b)
            .map_err(|_| HubError::Pairing("bad spake message from hub".into()))?;
        // T 中的 Hub 公钥 = TLS 钉扎的 peer.id；中间人无法同时伪造。
        let t = pairing::transcript(&peer.id, &self.device_id(), &msg_a, &msg_b);
        if !ct_eq(
            &unb64(&start.confirm)?,
            &pairing::confirm(&key, ROLE_HUB, &t),
        ) {
            return Err(HubError::Pairing(
                "wrong pairing code (or hub identity mismatch)".into(),
            ));
        }
        let fin: PairFinishResponse = session
            .json(
                Method::POST,
                "/v1/pair/finish",
                Some(&PairFinishRequest {
                    pair_id: start.pair_id,
                    confirm: b64(&pairing::confirm(&key, ROLE_DEVICE, &t)),
                }),
            )
            .await
            .map_err(pairing_err)?;
        if fin.hub_id != peer.id {
            return Err(HubError::Pairing("hub id mismatch".into()));
        }
        let dev = self.inner.ctx.trust.insert(peer.id, &fin.hub_name)?;
        tracing::info!(hub = %peer.id, name = %fin.hub_name, "paired with hub");
        Ok(dev)
    }

    /// 与 Hub 双向增量同步曲库。
    ///
    /// 1. 拉取 Hub 清单，与本地合并（LWW + 冲突副本）；
    /// 2. 下载本地缺失的 blob（部分数据用 Range 续传）；
    /// 3. 询问 Hub 缺失的 blob 并上传（`x-up-offset` 续传）；
    /// 4. 把合并后的清单推给 Hub 合并，再把 Hub 的结果合并回本地。
    ///
    /// 任意步骤中断后重跑，只会传输仍缺失的部分。清单只在其引用的 blob 全部就位后才写入。
    pub async fn sync(&self, peer: &HubPeer, store: &dyn LibraryStore) -> Result<SyncReport> {
        self.require_trusted(peer)?;
        let started = Instant::now();
        let session = self.session(peer)?;
        let mut report = SyncReport::default();
        let mut conflict_ids: BTreeSet<String> = BTreeSet::new();
        let mut round = 0;
        loop {
            round += 1;
            let remote: LibraryManifest = session
                .json(Method::GET, "/v1/manifest", None::<&()>)
                .await?;
            remote.validate()?;
            let local = store.manifest().await?;
            let pre = merge(&local, &remote);
            conflict_ids.extend(pre.conflicts.iter().cloned());

            self.download_missing(&session, store, &pre.manifest, &mut report)
                .await?;
            self.upload_missing(&session, store, &pre.manifest, &mut report)
                .await?;

            let resp = session
                .json::<MergeResponse, _>(
                    Method::POST,
                    "/v1/manifest/merge",
                    Some(&MergeRequest {
                        manifest: pre.manifest.clone(),
                    }),
                )
                .await;
            let resp = match resp {
                Ok(r) => r,
                // Hub 在此期间被第三台设备改动：重来一轮。
                Err(HubError::Remote { code, .. }) if code == "missing_blobs" && round < 4 => {
                    continue;
                }
                Err(e) => return Err(e),
            };
            resp.manifest.validate()?;
            report.remote_changed += resp.changed;
            conflict_ids.extend(resp.conflicts);

            let fin = merge(&pre.manifest, &resp.manifest).manifest;
            self.download_missing(&session, store, &fin, &mut report)
                .await?;
            let out = store.merge_manifest(&fin).await?;
            report.local_changed += out.changed;
            conflict_ids.extend(out.conflicts);
            break;
        }
        report.conflicts = conflict_ids.len() as u32;
        report.conflict_ids = conflict_ids.into_iter().collect();
        report.duration_ms = started.elapsed().as_millis() as u64;
        tracing::info!(?report, hub = %peer.id.short(), "sync finished");
        Ok(report)
    }

    async fn download_missing(
        &self,
        session: &Arc<PeerSession>,
        store: &dyn LibraryStore,
        manifest: &LibraryManifest,
        report: &mut SyncReport,
    ) -> Result<()> {
        let mut todo = Vec::new();
        for (h, size) in manifest.referenced_blobs() {
            match store.blob_status(&h).await? {
                BlobStatus::Complete(_) => {}
                BlobStatus::Partial(n) => todo.push((h, size, n)),
                BlobStatus::Missing => todo.push((h, size, 0)),
            }
        }
        let results: Vec<Result<Transfer>> = futures_util::stream::iter(todo)
            .map(|(h, size, off)| self.download_one(session, store, h, size, off))
            .buffer_unordered(self.inner.cfg.transfer_concurrency.max(1))
            .collect()
            .await;
        let mut first_err = None;
        for r in results {
            match r {
                Ok(t) => {
                    report.downloaded_blobs += 1;
                    report.downloaded_bytes += t.bytes;
                    report.resumed_blobs += t.resumed as u32;
                }
                Err(e) => {
                    first_err.get_or_insert(e);
                }
            }
        }
        first_err.map_or(Ok(()), Err)
    }

    async fn download_one(
        &self,
        session: &Arc<PeerSession>,
        store: &dyn LibraryStore,
        h: BlobHash,
        size: u64,
        mut offset: u64,
    ) -> Result<Transfer> {
        if offset > 0 && offset >= size {
            // 数据已全部到达但未提交（例如上次在校验前中断）。
            match store.blob_writer(&h, offset).await?.finish().await {
                Ok(_) => {
                    return Ok(Transfer {
                        bytes: 0,
                        resumed: true,
                    });
                }
                Err(HubError::HashMismatch { .. }) => offset = 0,
                Err(e) => return Err(e),
            }
        }
        let mut req = Request::get(format!("/v1/blob/{h}"));
        if offset > 0 {
            req = req.header(RANGE, format!("bytes={offset}-"));
        }
        let (resp, pooled) = session
            .send(req.body(empty_body()).expect("request"))
            .await?;
        let status = resp.status();
        match status {
            StatusCode::PARTIAL_CONTENT if offset > 0 => {}
            StatusCode::OK => offset = 0,
            StatusCode::RANGE_NOT_SATISFIABLE => {
                // 本地部分数据比 Hub 上的 blob 还长：丢弃重下。
                if let Ok(w) = store.blob_writer(&h, 0).await {
                    let _ = w.abort().await;
                }
                return Err(HubError::Protocol(format!(
                    "range not satisfiable for {h}, will restart"
                )));
            }
            _ => return Err(read_error(resp).await),
        }
        let mut w = store.blob_writer(&h, offset).await?;
        let mut body = resp.into_body();
        let mut bytes = 0u64;
        let idle = self.inner.cfg.transfer_idle_timeout;
        loop {
            let frame = tokio::time::timeout(idle, body.frame())
                .await
                .map_err(|_| HubError::Timeout("blob download"))?;
            let Some(frame) = frame else { break };
            if let Ok(data) = frame?.into_data() {
                w.write(&data).await?;
                bytes += data.len() as u64;
            }
        }
        w.finish().await?;
        pooled.release();
        Ok(Transfer {
            bytes,
            resumed: offset > 0,
        })
    }

    async fn upload_missing(
        &self,
        session: &Arc<PeerSession>,
        store: &dyn LibraryStore,
        manifest: &LibraryManifest,
        report: &mut SyncReport,
    ) -> Result<()> {
        let refs: Vec<BlobHash> = manifest.referenced_blobs().into_keys().collect();
        let mut missing = Vec::new();
        for chunk in refs.chunks(10_000) {
            let r: MissingResponse = session
                .json(
                    Method::POST,
                    "/v1/blobs/missing",
                    Some(&MissingRequest {
                        hashes: chunk.to_vec(),
                    }),
                )
                .await?;
            missing.extend(r.missing);
        }
        let results: Vec<Result<Transfer>> = futures_util::stream::iter(missing)
            .map(|m| self.upload_one(session, store, m.hash, m.offset))
            .buffer_unordered(self.inner.cfg.transfer_concurrency.max(1))
            .collect()
            .await;
        let mut first_err = None;
        for r in results {
            match r {
                Ok(t) => {
                    report.uploaded_blobs += 1;
                    report.uploaded_bytes += t.bytes;
                    report.resumed_blobs += t.resumed as u32;
                }
                Err(e) => {
                    first_err.get_or_insert(e);
                }
            }
        }
        first_err.map_or(Ok(()), Err)
    }

    async fn upload_one(
        &self,
        session: &Arc<PeerSession>,
        store: &dyn LibraryStore,
        h: BlobHash,
        mut offset: u64,
    ) -> Result<Transfer> {
        for _ in 0..3 {
            let Some((len, reader)) = store.open_blob(&h, offset).await? else {
                return Err(HubError::BlobNotFound(h));
            };
            if offset > len {
                offset = 0;
                continue;
            }
            let stream = ReaderStream::with_capacity(reader, 64 * 1024).map_ok(Frame::data);
            let body: ReqBody = BodyExt::boxed_unsync(StreamBody::new(stream));
            let req = Request::put(format!("/v1/blob/{h}"))
                .header(HEADER_OFFSET, offset.to_string())
                .header(CONTENT_LENGTH, (len - offset).to_string())
                .header(CONTENT_TYPE, "application/octet-stream")
                .body(body)
                .expect("request");
            let (resp, pooled) = session.send(req).await?;
            match resp.status() {
                StatusCode::CREATED => {
                    drain(resp).await;
                    pooled.release();
                    return Ok(Transfer {
                        bytes: len - offset,
                        resumed: offset > 0,
                    });
                }
                StatusCode::OK => {
                    drain(resp).await;
                    pooled.release();
                    return Ok(Transfer {
                        bytes: 0,
                        resumed: false,
                    });
                }
                _ => match read_error(resp).await {
                    HubError::OffsetMismatch { expected } => offset = expected,
                    e => return Err(e),
                },
            }
        }
        Err(HubError::Protocol(format!(
            "upload of {h} kept failing with offset mismatch"
        )))
    }

    /// 把本机变成 Hub 的远端打击垫。
    pub async fn controller_connect(&self, peer: &HubPeer) -> Result<ControllerHandle> {
        self.require_trusted(peer)?;
        let session = self.session(peer)?;
        let open: ControllerOpenResponse = session
            .json(
                Method::POST,
                "/v1/controller/open",
                Some(&serde_json::json!({})),
            )
            .await?;
        let key: [u8; 32] = unb64(&open.key)?
            .try_into()
            .map_err(|_| HubError::Protocol("controller key must be 32 bytes".into()))?;
        let remote = session
            .remote
            .lock()
            .expect("remote")
            .clone()
            .unwrap_or_else(|| peer.addr.clone());
        let chan = self
            .inner
            .transport
            .connect_datagram(&remote, open.udp_port)
            .await?;
        let closer_session = session.clone();
        let closer = Box::new(move |sid: u32| {
            async move {
                closer_session
                    .call(
                        Method::POST,
                        "/v1/controller/close",
                        Some(&ControllerCloseRequest { session_id: sid }),
                    )
                    .await
                    .map(|_| ())
            }
            .boxed()
        });
        let handle = ControllerHandle::start(
            peer.id,
            chan,
            open.session_id,
            key,
            Duration::from_millis(open.ping_interval_ms.clamp(100, 5_000)),
            closer,
        );
        Ok(handle)
    }
}

fn pairing_err(e: HubError) -> HubError {
    match e {
        HubError::Remote { code, message, .. }
            if code == "pairing_closed" || code == "pairing_failed" || code == "unknown_pair" =>
        {
            HubError::Pairing(format!("{code}: {message}"))
        }
        other => other,
    }
}

struct Transfer {
    bytes: u64,
    resumed: bool,
}

fn empty_body() -> ReqBody {
    BodyExt::boxed_unsync(Full::new(Bytes::new()).map_err(|never| match never {}))
}

async fn drain(resp: Response<Incoming>) {
    let _ = Limited::new(resp.into_body(), 1 << 20).collect().await;
}

async fn read_error(resp: Response<Incoming>) -> HubError {
    let status = resp.status().as_u16();
    let body = match Limited::new(resp.into_body(), 1 << 20).collect().await {
        Ok(b) => b.to_bytes(),
        Err(e) => return HubError::Protocol(format!("http {status}: {e}")),
    };
    let err: ErrorBody = serde_json::from_slice(&body).unwrap_or_else(|_| ErrorBody {
        error: "http".into(),
        message: String::from_utf8_lossy(&body).into_owned(),
        ..Default::default()
    });
    match err.error.as_str() {
        "not_paired" => HubError::NotPaired(format!("hub rejected this device: {}", err.message)),
        "offset_mismatch" => HubError::OffsetMismatch {
            expected: err.expected_offset.unwrap_or(0),
        },
        _ => HubError::Remote {
            status,
            code: err.error,
            message: err.message,
        },
    }
}

/// 一个对端的连接池。
pub(crate) struct PeerSession {
    transport: Arc<dyn HubTransport>,
    tls: Arc<rustls::ClientConfig>,
    addr: PeerAddr,
    expected: Option<DeviceId>,
    request_timeout: Duration,
    pool: Mutex<Vec<SendRequest<ReqBody>>>,
    remote: Mutex<Option<PeerAddr>>,
    last_peer: Mutex<Option<DeviceId>>,
}

/// 借出的连接；`release` 归还到池中，直接 drop 则丢弃该连接。
pub(crate) struct Pooled {
    session: Arc<PeerSession>,
    sender: SendRequest<ReqBody>,
}

impl Pooled {
    fn release(self) {
        let mut pool = self.session.pool.lock().expect("pool");
        if pool.len() < 8 && !self.sender.is_closed() {
            pool.push(self.sender);
        }
    }
}

impl PeerSession {
    fn new(
        client: &HubClient,
        addr: PeerAddr,
        tls: Arc<rustls::ClientConfig>,
        expected: Option<DeviceId>,
    ) -> Self {
        Self {
            transport: client.inner.transport.clone(),
            tls,
            addr,
            expected,
            request_timeout: client.inner.cfg.request_timeout,
            pool: Mutex::new(Vec::new()),
            remote: Mutex::new(None),
            last_peer: Mutex::new(None),
        }
    }

    async fn connect(&self) -> Result<SendRequest<ReqBody>> {
        let c = self.transport.connect_stream(&self.addr).await?;
        let connector = TlsConnector::from(self.tls.clone());
        let sn = ServerName::try_from(TLS_SERVER_NAME)
            .map_err(|e| HubError::Tls(e.to_string()))?
            .to_owned();
        let tls_stream =
            tokio::time::timeout(Duration::from_secs(10), connector.connect(sn, c.stream))
                .await
                .map_err(|_| HubError::Timeout("tls handshake"))?
                .map_err(|e| HubError::Tls(e.to_string()))?;
        let peer = tls::peer_id(tls_stream.get_ref().1.peer_certificates())?;
        if let Some(exp) = self.expected
            && exp != peer
        {
            return Err(HubError::Tls("hub key does not match pinned id".into()));
        }
        *self.last_peer.lock().expect("peer") = Some(peer);
        *self.remote.lock().expect("remote") = Some(c.remote);
        let (sender, conn) =
            hyper::client::conn::http1::handshake(TokioIo::new(tls_stream)).await?;
        tokio::spawn(async move {
            if let Err(e) = conn.await {
                tracing::debug!("hub connection closed: {e}");
            }
        });
        Ok(sender)
    }

    async fn checkout(&self) -> Result<SendRequest<ReqBody>> {
        loop {
            let candidate = self.pool.lock().expect("pool").pop();
            let Some(mut s) = candidate else { break };
            if !s.is_closed() && s.ready().await.is_ok() {
                return Ok(s);
            }
        }
        let mut s = self.connect().await?;
        s.ready().await?;
        Ok(s)
    }

    async fn send(
        self: &Arc<Self>,
        mut req: Request<ReqBody>,
    ) -> Result<(Response<Incoming>, Pooled)> {
        req.headers_mut().insert(
            HOST,
            hyper::header::HeaderValue::from_static(TLS_SERVER_NAME),
        );
        let mut sender = self.checkout().await?;
        let resp = sender.send_request(req).await?;
        Ok((
            resp,
            Pooled {
                session: self.clone(),
                sender,
            },
        ))
    }

    /// 发送请求并读取完整响应体（非 2xx 转为错误）。
    async fn call<B: Serialize>(
        self: &Arc<Self>,
        method: Method,
        path: &str,
        body: Option<&B>,
    ) -> Result<Bytes> {
        let fut = async {
            let mut req = Request::builder().method(method).uri(path);
            let body: ReqBody = match body {
                Some(b) => {
                    req = req.header(CONTENT_TYPE, "application/json");
                    BodyExt::boxed_unsync(
                        Full::new(Bytes::from(serde_json::to_vec(b)?))
                            .map_err(|never| match never {}),
                    )
                }
                None => empty_body(),
            };
            let (resp, pooled) = self
                .send(
                    req.body(body)
                        .map_err(|e| HubError::Protocol(e.to_string()))?,
                )
                .await?;
            if !resp.status().is_success() {
                return Err(read_error(resp).await);
            }
            let bytes = Limited::new(resp.into_body(), 256 << 20)
                .collect()
                .await
                .map_err(|e| HubError::Protocol(format!("read body: {e}")))?
                .to_bytes();
            pooled.release();
            Ok(bytes)
        };
        tokio::time::timeout(self.request_timeout, fut)
            .await
            .map_err(|_| HubError::Timeout("hub request"))?
    }

    async fn json<T: DeserializeOwned, B: Serialize>(
        self: &Arc<Self>,
        method: Method,
        path: &str,
        body: Option<&B>,
    ) -> Result<T> {
        let bytes = self.call(method, path, body).await?;
        Ok(serde_json::from_slice(&bytes)?)
    }
}
