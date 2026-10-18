//! 控制器数据面：手机作为电脑的远端打击垫，UDP 低延迟传输。
//!
//! # 报文格式（v1，大端）
//! ```text
//! 0   u8   ver = 1
//! 1   u8   kind      1=PadDown 2=PadUp 3=StopAll 4=Ping 5=Pong 6=Close
//! 2   u32  seq       每个会话、每个方向从 1 递增
//! 6   u32  session   /v1/controller/open 返回的会话 ID
//! 10  ..   payload   PadDown{bank u8, index u8, vel u8} | PadUp{bank, index} | Ping/Pong{t_us u64} | 空
//! end 16B  tag       HMAC-SHA256(会话密钥, 前面所有字节) 截断到 16 字节
//! ```
//! - 发送端对 pad 事件每个 `seq` 连发 2 次；
//! - 接收端：HMAC 校验 → 1024 位滑动窗口去重/防重放 → 按 pad 的乱序处理：
//!   同一 pad 上 `seq` 小于已应用的事件、或早于最近一次 StopAll 的事件视为过期并丢弃
//!   （避免"抬起先到、按下后到"造成的挂音），不同 pad 的乱序事件照常立即应用；
//! - 会话密钥 32 字节随机数，只经已认证的 TLS 控制面下发，会话关闭/超时即作废。

use std::collections::{HashMap, HashSet, VecDeque};
use std::net::SocketAddr;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use tokio_util::sync::CancellationToken;

use crate::identity::DeviceId;
use crate::sink::PadSink;
use crate::transport::DatagramChannel;
use crate::{HubError, Result};

pub(crate) const PKT_VERSION: u8 = 1;
const HEADER_LEN: usize = 10;
const TAG_LEN: usize = 16;
const WINDOW: u32 = 1024;
/// 每个 pad 事件发送的副本数。
pub const EVENT_COPIES: u8 = 2;

/// 远端 pad 事件。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum RemotePadEvent {
    /// 按下。`velocity` 0..=127。
    PadDown {
        /// bank。
        bank: u8,
        /// pad 序号。
        index: u8,
        /// 力度 0..=127。
        velocity: u8,
    },
    /// 抬起。
    PadUp {
        /// bank。
        bank: u8,
        /// pad 序号。
        index: u8,
    },
    /// 全部停止。
    StopAll,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Payload {
    Event(RemotePadEvent),
    Ping { t_us: u64 },
    Pong { t_us: u64 },
    Close,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Packet {
    pub seq: u32,
    pub session: u32,
    pub payload: Payload,
}

fn mac(key: &[u8; 32], data: &[u8]) -> [u8; 32] {
    let mut m = <Hmac<Sha256> as Mac>::new_from_slice(key).expect("hmac key");
    m.update(data);
    m.finalize().into_bytes().into()
}

pub(crate) fn encode(pkt: &Packet, key: &[u8; 32]) -> Vec<u8> {
    let mut b = Vec::with_capacity(HEADER_LEN + 8 + TAG_LEN);
    let (kind, body): (u8, Vec<u8>) = match pkt.payload {
        Payload::Event(RemotePadEvent::PadDown {
            bank,
            index,
            velocity,
        }) => (1, vec![bank, index, velocity.min(127)]),
        Payload::Event(RemotePadEvent::PadUp { bank, index }) => (2, vec![bank, index]),
        Payload::Event(RemotePadEvent::StopAll) => (3, vec![]),
        Payload::Ping { t_us } => (4, t_us.to_be_bytes().to_vec()),
        Payload::Pong { t_us } => (5, t_us.to_be_bytes().to_vec()),
        Payload::Close => (6, vec![]),
    };
    b.push(PKT_VERSION);
    b.push(kind);
    b.extend_from_slice(&pkt.seq.to_be_bytes());
    b.extend_from_slice(&pkt.session.to_be_bytes());
    b.extend_from_slice(&body);
    let tag = mac(key, &b);
    b.extend_from_slice(&tag[..TAG_LEN]);
    b
}

/// 只解析会话 ID（用于查找密钥），不做认证。
pub(crate) fn peek_session(buf: &[u8]) -> Option<u32> {
    if buf.len() < HEADER_LEN + TAG_LEN || buf[0] != PKT_VERSION {
        return None;
    }
    Some(u32::from_be_bytes(buf[6..10].try_into().ok()?))
}

#[derive(Debug, PartialEq, Eq)]
pub(crate) enum DecodeError {
    Malformed,
    BadMac,
}

pub(crate) fn decode(buf: &[u8], key: &[u8; 32]) -> std::result::Result<Packet, DecodeError> {
    if buf.len() < HEADER_LEN + TAG_LEN || buf[0] != PKT_VERSION {
        return Err(DecodeError::Malformed);
    }
    let (body, tag) = buf.split_at(buf.len() - TAG_LEN);
    let expect = mac(key, body);
    if !crate::util::ct_eq(&expect[..TAG_LEN], tag) {
        return Err(DecodeError::BadMac);
    }
    let kind = body[1];
    let seq = u32::from_be_bytes(body[2..6].try_into().expect("len"));
    let session = u32::from_be_bytes(body[6..10].try_into().expect("len"));
    let p = &body[HEADER_LEN..];
    let u64_at = |p: &[u8]| -> std::result::Result<u64, DecodeError> {
        Ok(u64::from_be_bytes(
            p.try_into().map_err(|_| DecodeError::Malformed)?,
        ))
    };
    let payload = match (kind, p.len()) {
        (1, 3) => Payload::Event(RemotePadEvent::PadDown {
            bank: p[0],
            index: p[1],
            velocity: p[2].min(127),
        }),
        (2, 2) => Payload::Event(RemotePadEvent::PadUp {
            bank: p[0],
            index: p[1],
        }),
        (3, 0) => Payload::Event(RemotePadEvent::StopAll),
        (4, 8) => Payload::Ping { t_us: u64_at(p)? },
        (5, 8) => Payload::Pong { t_us: u64_at(p)? },
        (6, 0) => Payload::Close,
        _ => return Err(DecodeError::Malformed),
    };
    if seq == 0 {
        return Err(DecodeError::Malformed);
    }
    Ok(Packet {
        seq,
        session,
        payload,
    })
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub(crate) enum SeqCheck {
    Fresh,
    Duplicate,
    TooOld,
}

/// 1024 位滑动窗口（与 IPsec 防重放窗口相同的思路）。
#[derive(Debug)]
pub(crate) struct ReplayWindow {
    highest: u32,
    bits: [u64; (WINDOW / 64) as usize],
}

impl Default for ReplayWindow {
    fn default() -> Self {
        Self {
            highest: 0,
            bits: [0; (WINDOW / 64) as usize],
        }
    }
}

impl ReplayWindow {
    fn bit(&mut self, seq: u32) -> (&mut u64, u64) {
        let i = (seq % WINDOW) as usize;
        (&mut self.bits[i / 64], 1u64 << (i % 64))
    }

    pub(crate) fn check(&mut self, seq: u32) -> SeqCheck {
        if seq > self.highest {
            let diff = seq - self.highest;
            if diff >= WINDOW {
                self.bits = [0; (WINDOW / 64) as usize];
            } else {
                for s in self.highest + 1..=seq {
                    let (w, m) = self.bit(s);
                    *w &= !m;
                }
            }
            self.highest = seq;
            let (w, m) = self.bit(seq);
            *w |= m;
            return SeqCheck::Fresh;
        }
        if self.highest - seq >= WINDOW {
            return SeqCheck::TooOld;
        }
        let (w, m) = self.bit(seq);
        if *w & m != 0 {
            SeqCheck::Duplicate
        } else {
            *w |= m;
            SeqCheck::Fresh
        }
    }
}

/// 按 pad 的乱序处理与按住状态跟踪。
#[derive(Debug, Default)]
pub(crate) struct EventOrdering {
    last: HashMap<(u8, u8), u32>,
    stop_seq: u32,
    pub(crate) held: HashSet<(u8, u8)>,
}

impl EventOrdering {
    /// 返回事件是否应当应用。
    pub(crate) fn accept(&mut self, seq: u32, ev: &RemotePadEvent) -> bool {
        match *ev {
            RemotePadEvent::StopAll => {
                if seq < self.stop_seq {
                    return false;
                }
                self.stop_seq = seq;
                self.held.clear();
                true
            }
            RemotePadEvent::PadDown { bank, index, .. } | RemotePadEvent::PadUp { bank, index } => {
                if seq < self.stop_seq {
                    return false;
                }
                let last = self.last.entry((bank, index)).or_insert(0);
                if seq < *last {
                    return false;
                }
                *last = seq;
                if matches!(ev, RemotePadEvent::PadDown { .. }) {
                    self.held.insert((bank, index));
                } else {
                    self.held.remove(&(bank, index));
                }
                true
            }
        }
    }
}

/// Hub 侧控制器会话统计。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ControllerSessionStats {
    /// 会话 ID。
    pub session_id: u32,
    /// 控制器设备。
    pub device: DeviceId,
    /// 设备名。
    pub name: String,
    /// 收到并通过认证的报文数。
    pub packets: u64,
    /// 交给 PadSink 的事件数。
    pub accepted_events: u64,
    /// 重复报文（含有意的双发副本）。
    pub duplicates: u64,
    /// 因同 pad 乱序过期而丢弃的事件。
    pub reordered_dropped: u64,
    /// 超出滑动窗口的过旧报文。
    pub too_old: u64,
    /// HMAC 校验失败的报文。
    pub bad_mac: u64,
    /// 距最后一个报文的毫秒数。
    pub idle_ms: u64,
    /// 当前仍按住的 pad 数。
    pub held_pads: u32,
}

struct ServerSession {
    device: DeviceId,
    key: [u8; 32],
    window: ReplayWindow,
    order: EventOrdering,
    addr: Option<SocketAddr>,
    last_seen: Instant,
    tx_seq: u32,
    stats: ControllerSessionStats,
}

enum SinkAction {
    Event(RemotePadEvent),
    Disconnected { held: Vec<(u8, u8)> },
}

/// Hub 侧会话表。
pub(crate) struct ControllerRegistry {
    sessions: Mutex<HashMap<u32, ServerSession>>,
    sink: Arc<dyn PadSink>,
    idle_timeout: Duration,
}

impl ControllerRegistry {
    pub(crate) fn new(sink: Arc<dyn PadSink>, idle_timeout: Duration) -> Self {
        Self {
            sessions: Mutex::new(HashMap::new()),
            sink,
            idle_timeout,
        }
    }

    pub(crate) fn idle_timeout(&self) -> Duration {
        self.idle_timeout
    }

    /// 为设备新建会话；同一设备的旧会话会被关闭（一台设备同时只有一个控制器会话）。
    pub(crate) fn open(&self, device: DeviceId, name: &str) -> (u32, [u8; 32]) {
        let key: [u8; 32] = rand::random();
        let mut closed = Vec::new();
        let id = {
            let mut map = self.sessions.lock().expect("sessions");
            let old: Vec<u32> = map
                .iter()
                .filter(|(_, s)| s.device == device)
                .map(|(k, _)| *k)
                .collect();
            for k in old {
                if let Some(s) = map.remove(&k) {
                    closed.push(s);
                }
            }
            let id = loop {
                let id: u32 = rand::random();
                if id != 0 && !map.contains_key(&id) {
                    break id;
                }
            };
            map.insert(
                id,
                ServerSession {
                    device,
                    key,
                    window: ReplayWindow::default(),
                    order: EventOrdering::default(),
                    addr: None,
                    last_seen: Instant::now(),
                    tx_seq: 0,
                    stats: ControllerSessionStats {
                        session_id: id,
                        device,
                        name: name.to_string(),
                        packets: 0,
                        accepted_events: 0,
                        duplicates: 0,
                        reordered_dropped: 0,
                        too_old: 0,
                        bad_mac: 0,
                        idle_ms: 0,
                        held_pads: 0,
                    },
                },
            );
            id
        };
        for s in closed {
            self.release(s);
        }
        self.sink.controller_connected(&device, name);
        (id, key)
    }

    fn release(&self, s: ServerSession) {
        for (bank, index) in s.order.held {
            self.sink.pad_up(&s.device, bank, index);
        }
        self.sink.controller_disconnected(&s.device);
    }

    /// 关闭设备自己的会话。
    pub(crate) fn close(&self, session_id: u32, device: &DeviceId) -> bool {
        let s = {
            let mut map = self.sessions.lock().expect("sessions");
            match map.get(&session_id) {
                Some(s) if &s.device == device => map.remove(&session_id),
                _ => None,
            }
        };
        match s {
            Some(s) => {
                self.release(s);
                true
            }
            None => false,
        }
    }

    /// 关闭某设备的全部会话（撤销配对时）。
    pub(crate) fn close_device(&self, device: &DeviceId) {
        let removed: Vec<ServerSession> = {
            let mut map = self.sessions.lock().expect("sessions");
            let ids: Vec<u32> = map
                .iter()
                .filter(|(_, s)| &s.device == device)
                .map(|(k, _)| *k)
                .collect();
            ids.into_iter().filter_map(|k| map.remove(&k)).collect()
        };
        for s in removed {
            self.release(s);
        }
    }

    pub(crate) fn close_all(&self) {
        let all: Vec<ServerSession> = self
            .sessions
            .lock()
            .expect("sessions")
            .drain()
            .map(|(_, s)| s)
            .collect();
        for s in all {
            self.release(s);
        }
    }

    pub(crate) fn sweep_idle(&self) {
        let now = Instant::now();
        let expired: Vec<ServerSession> = {
            let mut map = self.sessions.lock().expect("sessions");
            let ids: Vec<u32> = map
                .iter()
                .filter(|(_, s)| now.duration_since(s.last_seen) > self.idle_timeout)
                .map(|(k, _)| *k)
                .collect();
            ids.into_iter().filter_map(|k| map.remove(&k)).collect()
        };
        for s in expired {
            tracing::info!(device = %s.device, "controller session timed out");
            self.release(s);
        }
    }

    pub(crate) fn stats(&self) -> Vec<ControllerSessionStats> {
        let now = Instant::now();
        let map = self.sessions.lock().expect("sessions");
        let mut v: Vec<_> = map
            .values()
            .map(|s| {
                let mut st = s.stats.clone();
                st.idle_ms = now.duration_since(s.last_seen).as_millis() as u64;
                st.held_pads = s.order.held.len() as u32;
                st
            })
            .collect();
        v.sort_by_key(|s| s.session_id);
        v
    }

    /// 处理一个数据报；返回需要回给对端的报文（Pong）。
    pub(crate) fn handle_datagram(&self, buf: &[u8], from: SocketAddr) -> Option<Vec<u8>> {
        let sid = peek_session(buf)?;
        let mut actions: Vec<SinkAction> = Vec::new();
        let mut reply = None;
        let device;
        {
            let mut map = self.sessions.lock().expect("sessions");
            let s = map.get_mut(&sid)?;
            device = s.device;
            let pkt = match decode(buf, &s.key) {
                Ok(p) => p,
                Err(DecodeError::BadMac) => {
                    s.stats.bad_mac += 1;
                    return None;
                }
                Err(DecodeError::Malformed) => return None,
            };
            match s.window.check(pkt.seq) {
                SeqCheck::Fresh => {}
                SeqCheck::Duplicate => {
                    s.stats.duplicates += 1;
                    return None;
                }
                SeqCheck::TooOld => {
                    s.stats.too_old += 1;
                    return None;
                }
            }
            s.stats.packets += 1;
            s.last_seen = Instant::now();
            s.addr = Some(from);
            match pkt.payload {
                Payload::Event(ev) => {
                    if s.order.accept(pkt.seq, &ev) {
                        s.stats.accepted_events += 1;
                        actions.push(SinkAction::Event(ev));
                    } else {
                        s.stats.reordered_dropped += 1;
                    }
                }
                Payload::Ping { t_us } => {
                    s.tx_seq += 1;
                    reply = Some(encode(
                        &Packet {
                            seq: s.tx_seq,
                            session: sid,
                            payload: Payload::Pong { t_us },
                        },
                        &s.key,
                    ));
                }
                Payload::Pong { .. } => {}
                Payload::Close => {
                    let s = map.remove(&sid).expect("present");
                    actions.push(SinkAction::Disconnected {
                        held: s.order.held.into_iter().collect(),
                    });
                }
            }
        }
        for a in actions {
            match a {
                SinkAction::Event(RemotePadEvent::PadDown {
                    bank,
                    index,
                    velocity,
                }) => self.sink.pad_down(&device, bank, index, velocity),
                SinkAction::Event(RemotePadEvent::PadUp { bank, index }) => {
                    self.sink.pad_up(&device, bank, index)
                }
                SinkAction::Event(RemotePadEvent::StopAll) => self.sink.stop_all(&device),
                SinkAction::Disconnected { held } => {
                    for (b, i) in held {
                        self.sink.pad_up(&device, b, i);
                    }
                    self.sink.controller_disconnected(&device);
                }
            }
        }
        reply
    }
}

/// Hub 侧 UDP 循环。
pub(crate) async fn run_udp(
    socket: Arc<tokio::net::UdpSocket>,
    registry: Arc<ControllerRegistry>,
    cancel: CancellationToken,
) {
    let mut buf = [0u8; 2048];
    let mut sweep = tokio::time::interval(Duration::from_millis(500));
    loop {
        tokio::select! {
            _ = cancel.cancelled() => break,
            _ = sweep.tick() => registry.sweep_idle(),
            r = socket.recv_from(&mut buf) => match r {
                Ok((n, from)) => {
                    if let Some(reply) = registry.handle_datagram(&buf[..n], from) {
                        let _ = socket.send_to(&reply, from).await;
                    }
                }
                Err(e) => {
                    // Windows/Linux 上 ICMP 端口不可达会表现为 recv 错误，忽略继续。
                    tracing::debug!("udp recv error: {e}");
                }
            },
        }
    }
}

/// 控制器端延迟统计（基于 ping 往返时间）。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct LatencyStats {
    /// 样本数（最近 128 个 ping）。
    pub samples: u32,
    /// 已发送 ping 数。
    pub pings_sent: u64,
    /// 已收到 pong 数（与 `pings_sent` 对比可估算丢包）。
    pub pongs_received: u64,
    /// 最小 RTT（微秒）。
    pub rtt_min_us: u64,
    /// RTT 中位数（微秒）。
    pub rtt_p50_us: u64,
    /// RTT p95（微秒）。
    pub rtt_p95_us: u64,
    /// 最大 RTT（微秒）。
    pub rtt_max_us: u64,
    /// RTT 均值（微秒）。
    pub rtt_mean_us: u64,
    /// 单程延迟估计 = RTT 中位数 / 2（微秒）。
    pub one_way_estimate_us: u64,
}

#[derive(Default)]
struct LatencyTracker {
    rtts: VecDeque<u64>,
    pongs: u64,
}

impl LatencyTracker {
    const CAP: usize = 128;

    fn push(&mut self, rtt_us: u64) {
        if self.rtts.len() == Self::CAP {
            self.rtts.pop_front();
        }
        self.rtts.push_back(rtt_us);
        self.pongs += 1;
    }

    fn stats(&self, pings_sent: u64) -> LatencyStats {
        let mut v: Vec<u64> = self.rtts.iter().copied().collect();
        if v.is_empty() {
            return LatencyStats {
                pings_sent,
                ..Default::default()
            };
        }
        v.sort_unstable();
        let pct = |p: usize| v[((v.len() - 1) * p) / 100];
        let p50 = pct(50);
        LatencyStats {
            samples: v.len() as u32,
            pings_sent,
            pongs_received: self.pongs,
            rtt_min_us: v[0],
            rtt_p50_us: p50,
            rtt_p95_us: pct(95),
            rtt_max_us: *v.last().expect("non-empty"),
            rtt_mean_us: v.iter().sum::<u64>() / v.len() as u64,
            one_way_estimate_us: p50 / 2,
        }
    }
}

pub(crate) struct HandleInner {
    chan: Arc<dyn DatagramChannel>,
    key: [u8; 32],
    session_id: u32,
    seq: AtomicU32,
    epoch: Instant,
    pings_sent: AtomicU64,
    latency: Mutex<LatencyTracker>,
    rx_window: Mutex<ReplayWindow>,
    closed: AtomicBool,
}

impl HandleInner {
    fn now_us(&self) -> u64 {
        self.epoch.elapsed().as_micros() as u64
    }

    fn send(&self, seq: u32, payload: Payload, copies: u8) -> Result<()> {
        if self.closed.load(Ordering::Acquire) {
            return Err(HubError::Closed);
        }
        let pkt = encode(
            &Packet {
                seq,
                session: self.session_id,
                payload,
            },
            &self.key,
        );
        let mut ok = false;
        let mut last_err = None;
        for _ in 0..copies.max(1) {
            match self.chan.try_send(&pkt) {
                Ok(()) => ok = true,
                Err(e) => last_err = Some(e),
            }
        }
        match (ok, last_err) {
            (true, _) => Ok(()),
            (false, Some(e)) => Err(e.into()),
            (false, None) => Ok(()),
        }
    }

    fn next_seq(&self) -> u32 {
        self.seq.fetch_add(1, Ordering::AcqRel) + 1
    }

    fn ping(&self) -> Result<()> {
        let seq = self.next_seq();
        self.pings_sent.fetch_add(1, Ordering::Relaxed);
        self.send(
            seq,
            Payload::Ping {
                t_us: self.now_us(),
            },
            1,
        )
    }

    fn on_datagram(&self, buf: &[u8]) {
        let Ok(pkt) = decode(buf, &self.key) else {
            return;
        };
        if pkt.session != self.session_id
            || self.rx_window.lock().expect("rx").check(pkt.seq) != SeqCheck::Fresh
        {
            return;
        }
        if let Payload::Pong { t_us } = pkt.payload {
            let now = self.now_us();
            if t_us <= now {
                self.latency.lock().expect("latency").push(now - t_us);
            }
        }
    }
}

/// 关闭控制面会话的回调（HTTP `/v1/controller/close`）。
pub(crate) type SessionCloser =
    Box<dyn FnOnce(u32) -> futures_util::future::BoxFuture<'static, Result<()>> + Send>;

/// 控制器句柄：手机端把本机 pad 操作转发到 Hub。
///
/// `pad_down` / `pad_up` / `stop_all` 是同步、非阻塞的（只做一次 HMAC 和两次 `send`），
/// 可直接在 FFI 热路径上调用。drop 时自动发送 Close 并停止后台 ping。
pub struct ControllerHandle {
    inner: Arc<HandleInner>,
    hub: DeviceId,
    cancel: CancellationToken,
    closer: Option<SessionCloser>,
}

impl std::fmt::Debug for ControllerHandle {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ControllerHandle")
            .field("hub", &self.hub)
            .field("session_id", &self.inner.session_id)
            .finish()
    }
}

impl ControllerHandle {
    pub(crate) fn start(
        hub: DeviceId,
        chan: Arc<dyn DatagramChannel>,
        session_id: u32,
        key: [u8; 32],
        ping_interval: Duration,
        closer: SessionCloser,
    ) -> Self {
        let inner = Arc::new(HandleInner {
            chan,
            key,
            session_id,
            seq: AtomicU32::new(0),
            epoch: Instant::now(),
            pings_sent: AtomicU64::new(0),
            latency: Mutex::new(LatencyTracker::default()),
            rx_window: Mutex::new(ReplayWindow::default()),
            closed: AtomicBool::new(false),
        });
        let cancel = CancellationToken::new();
        {
            let inner = inner.clone();
            let cancel = cancel.clone();
            tokio::spawn(async move {
                let mut buf = [0u8; 2048];
                loop {
                    tokio::select! {
                        _ = cancel.cancelled() => break,
                        r = inner.chan.recv(&mut buf) => match r {
                            Ok(n) => inner.on_datagram(&buf[..n]),
                            Err(e) => {
                                tracing::debug!("controller recv error: {e}");
                                tokio::time::sleep(Duration::from_millis(50)).await;
                            }
                        }
                    }
                }
            });
        }
        {
            let inner = inner.clone();
            let cancel = cancel.clone();
            tokio::spawn(async move {
                let mut tick = tokio::time::interval(ping_interval);
                loop {
                    tokio::select! {
                        _ = cancel.cancelled() => break,
                        _ = tick.tick() => { let _ = inner.ping(); }
                    }
                }
            });
        }
        Self {
            inner,
            hub,
            cancel,
            closer: Some(closer),
        }
    }

    /// Hub 设备 ID。
    pub fn hub(&self) -> DeviceId {
        self.hub
    }

    /// 会话 ID。
    pub fn session_id(&self) -> u32 {
        self.inner.session_id
    }

    /// 发送一个事件（双发）。
    pub fn send(&self, ev: RemotePadEvent) -> Result<()> {
        let seq = self.inner.next_seq();
        self.inner.send(seq, Payload::Event(ev), EVENT_COPIES)
    }

    /// 按下 pad，`velocity` 0..=127（超出部分截断为 127）。
    pub fn pad_down(&self, bank: u8, index: u8, velocity: u8) -> Result<()> {
        self.send(RemotePadEvent::PadDown {
            bank,
            index,
            velocity: velocity.min(127),
        })
    }

    /// 抬起 pad。
    pub fn pad_up(&self, bank: u8, index: u8) -> Result<()> {
        self.send(RemotePadEvent::PadUp { bank, index })
    }

    /// 停止所有发声。
    pub fn stop_all(&self) -> Result<()> {
        self.send(RemotePadEvent::StopAll)
    }

    /// 立即发送一次 ping（后台也会按间隔自动发送）。
    pub fn ping(&self) -> Result<()> {
        self.inner.ping()
    }

    /// 延迟统计。
    pub fn latency(&self) -> LatencyStats {
        self.inner
            .latency
            .lock()
            .expect("latency")
            .stats(self.inner.pings_sent.load(Ordering::Relaxed))
    }

    /// 测试/诊断用：以指定 seq 发送事件（用于验证乱序、重放处理）。
    #[doc(hidden)]
    pub fn send_raw_with_seq(&self, seq: u32, ev: RemotePadEvent, copies: u8) -> Result<()> {
        self.inner.send(seq, Payload::Event(ev), copies)
    }

    /// 测试/诊断用：保留接下来的 n 个序号，返回第一个。
    #[doc(hidden)]
    pub fn reserve_seqs(&self, n: u32) -> u32 {
        self.inner.seq.fetch_add(n, Ordering::AcqRel) + 1
    }

    fn shutdown_udp(&mut self) {
        if !self.inner.closed.load(Ordering::Acquire) {
            let seq = self.inner.next_seq();
            let _ = self.inner.send(seq, Payload::Close, EVENT_COPIES);
            self.inner.closed.store(true, Ordering::Release);
        }
        self.cancel.cancel();
    }

    /// 关闭会话（UDP Close + HTTP `/v1/controller/close`）。
    pub async fn close(mut self) -> Result<()> {
        self.shutdown_udp();
        match self.closer.take() {
            Some(c) => c(self.inner.session_id).await,
            None => Ok(()),
        }
    }
}

impl Drop for ControllerHandle {
    fn drop(&mut self) {
        self.shutdown_udp();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY: [u8; 32] = [7u8; 32];

    #[test]
    fn codec_roundtrip_and_mac() {
        let cases = [
            Payload::Event(RemotePadEvent::PadDown {
                bank: 1,
                index: 15,
                velocity: 100,
            }),
            Payload::Event(RemotePadEvent::PadUp { bank: 1, index: 15 }),
            Payload::Event(RemotePadEvent::StopAll),
            Payload::Ping { t_us: 123_456_789 },
            Payload::Pong { t_us: 42 },
            Payload::Close,
        ];
        for (i, p) in cases.into_iter().enumerate() {
            let pkt = Packet {
                seq: i as u32 + 1,
                session: 0xdead_beef,
                payload: p,
            };
            let mut b = encode(&pkt, &KEY);
            assert_eq!(b[0], 1);
            assert_eq!(peek_session(&b), Some(0xdead_beef));
            assert_eq!(decode(&b, &KEY).unwrap(), pkt);
            assert_eq!(decode(&b, &[8u8; 32]), Err(DecodeError::BadMac));
            b[3] ^= 1;
            assert_eq!(decode(&b, &KEY), Err(DecodeError::BadMac));
        }
        assert_eq!(decode(&[1, 2, 3], &KEY), Err(DecodeError::Malformed));
    }

    #[test]
    fn velocity_is_clamped() {
        let pkt = Packet {
            seq: 1,
            session: 1,
            payload: Payload::Event(RemotePadEvent::PadDown {
                bank: 0,
                index: 0,
                velocity: 255,
            }),
        };
        let back = decode(&encode(&pkt, &KEY), &KEY).unwrap();
        assert_eq!(
            back.payload,
            Payload::Event(RemotePadEvent::PadDown {
                bank: 0,
                index: 0,
                velocity: 127
            })
        );
    }

    #[test]
    fn replay_window() {
        let mut w = ReplayWindow::default();
        assert_eq!(w.check(1), SeqCheck::Fresh);
        assert_eq!(w.check(1), SeqCheck::Duplicate);
        assert_eq!(w.check(3), SeqCheck::Fresh);
        assert_eq!(w.check(2), SeqCheck::Fresh, "late but within window");
        assert_eq!(w.check(2), SeqCheck::Duplicate);
        assert_eq!(w.check(2000), SeqCheck::Fresh);
        assert_eq!(w.check(3), SeqCheck::TooOld);
        assert_eq!(w.check(2000 - 1023), SeqCheck::Fresh);
        assert_eq!(w.check(2000 - 1024), SeqCheck::TooOld);
        // 跨越 bitmap 的环绕后旧位已清除。
        assert_eq!(w.check(2000 + 1024), SeqCheck::Fresh);
        assert_eq!(w.check(2000 + 1), SeqCheck::Fresh);
        for s in 5000..7000 {
            assert_eq!(w.check(s), SeqCheck::Fresh);
            assert_eq!(w.check(s), SeqCheck::Duplicate);
        }
    }

    #[test]
    fn per_pad_ordering() {
        let mut o = EventOrdering::default();
        let down = |b, i| RemotePadEvent::PadDown {
            bank: b,
            index: i,
            velocity: 90,
        };
        let up = |b, i| RemotePadEvent::PadUp { bank: b, index: i };
        // 抬起（seq 2）先到，按下（seq 1）后到 → 按下被丢弃，不会挂音。
        assert!(o.accept(2, &up(0, 1)));
        assert!(!o.accept(1, &down(0, 1)));
        assert!(o.held.is_empty());
        // 不同 pad 乱序都应用。
        assert!(o.accept(4, &down(0, 2)));
        assert!(o.accept(3, &down(0, 3)));
        assert_eq!(o.held.len(), 2);
        // StopAll 之前的事件全部过期。
        assert!(o.accept(10, &RemotePadEvent::StopAll));
        assert!(o.held.is_empty());
        assert!(!o.accept(9, &down(0, 4)));
        assert!(!o.accept(8, &RemotePadEvent::StopAll));
        assert!(o.accept(11, &down(0, 4)));
    }

    #[test]
    fn latency_stats() {
        let mut t = LatencyTracker::default();
        for v in [100, 200, 300, 400, 1000] {
            t.push(v);
        }
        let s = t.stats(6);
        assert_eq!(s.samples, 5);
        assert_eq!(s.rtt_min_us, 100);
        assert_eq!(s.rtt_p50_us, 300);
        assert_eq!(s.rtt_max_us, 1000);
        assert_eq!(s.one_way_estimate_us, 150);
        assert_eq!(s.pongs_received, 5);
        assert_eq!(s.pings_sent, 6);
    }
}
