//! 传输抽象：控制面需要一条可靠字节流，控制器数据面需要一个不可靠数据报通道。
//!
//! v0.0.1 只实现 [`LanTransport`]（TCP + UDP）。TLS、HTTP、配对、同步和控制器报文都在
//! 这一层之上，与传输无关。
//!
//! # P2P（iroh）接入方式（v0.0.1 未实现）
//! - 以设备 Ed25519 私钥作为 iroh `SecretKey`，则 iroh `NodeId` == [`DeviceId`]，
//!   受信列表无需变化；
//! - 新增 `PeerAddr::Iroh { node_id, relay_url, direct_addrs }`；
//! - `connect_stream`：`endpoint.connect(node_addr, b"ultrapads/hub/1")` 后 `open_bi()`，
//!   把 (SendStream, RecvStream) 合成一个 `AsyncRead + AsyncWrite` 返回；上层 TLS 可保留
//!   （双层加密，简单）或在 iroh 下跳过（QUIC 已对 NodeId 做双向认证）；
//! - `connect_datagram`：使用 QUIC datagram（`conn.send_datagram`），报文格式不变；
//! - 服务端：在 `HubServer` 中增加 iroh accept 循环，把每个双向流交给与 TCP 相同的
//!   `serve_connection`。
//!
//! [`DeviceId`]: crate::DeviceId

use std::io;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncRead, AsyncWrite};

use crate::{HubError, Result};

/// 可靠双向字节流。
pub trait AsyncStream: AsyncRead + AsyncWrite + Send + Unpin + 'static {}
impl<T: AsyncRead + AsyncWrite + Send + Unpin + 'static> AsyncStream for T {}

/// 装箱的字节流。
pub type BoxedStream = Box<dyn AsyncStream>;

/// 对端地址。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
#[non_exhaustive]
pub enum PeerAddr {
    /// 局域网：按顺序尝试的 socket 地址（端口为控制面 TCP 端口）。
    Lan {
        /// 候选地址。
        addrs: Vec<SocketAddr>,
    },
}

impl PeerAddr {
    /// 单个局域网地址。
    pub fn lan(addr: SocketAddr) -> Self {
        PeerAddr::Lan { addrs: vec![addr] }
    }
}

/// 已建立的字节流连接。
pub struct Connected {
    /// 字节流。
    pub stream: BoxedStream,
    /// 实际连上的地址（收窄后的 `PeerAddr`，数据报通道沿用它）。
    pub remote: PeerAddr,
}

/// 不可靠数据报通道（控制器数据面）。
#[async_trait]
pub trait DatagramChannel: Send + Sync + 'static {
    /// 非阻塞发送（热路径，可在任意线程调用）。
    fn try_send(&self, buf: &[u8]) -> io::Result<()>;
    /// 接收一个数据报。
    async fn recv(&self, buf: &mut [u8]) -> io::Result<usize>;
}

/// 传输层。
#[async_trait]
pub trait HubTransport: Send + Sync + 'static {
    /// 名称（日志用）。
    fn name(&self) -> &'static str;
    /// 建立到对端控制面的可靠字节流。
    async fn connect_stream(&self, peer: &PeerAddr) -> Result<Connected>;
    /// 建立到对端控制器数据面的数据报通道。`port` 为 Hub 在 `/v1/controller/open` 中返回的端口。
    async fn connect_datagram(
        &self,
        peer: &PeerAddr,
        port: u16,
    ) -> Result<Arc<dyn DatagramChannel>>;
}

/// 局域网传输：TCP（控制面）+ UDP（数据面）。
#[derive(Clone, Debug)]
pub struct LanTransport {
    /// 单个地址的 TCP 连接超时。
    pub connect_timeout: Duration,
}

impl Default for LanTransport {
    fn default() -> Self {
        Self {
            connect_timeout: Duration::from_secs(3),
        }
    }
}

#[async_trait]
impl HubTransport for LanTransport {
    fn name(&self) -> &'static str {
        "lan"
    }

    async fn connect_stream(&self, peer: &PeerAddr) -> Result<Connected> {
        let PeerAddr::Lan { addrs } = peer;
        let mut last_err: Option<HubError> = None;
        for addr in addrs {
            match tokio::time::timeout(self.connect_timeout, tokio::net::TcpStream::connect(addr))
                .await
            {
                Ok(Ok(s)) => {
                    let _ = s.set_nodelay(true);
                    return Ok(Connected {
                        stream: Box::new(s),
                        remote: PeerAddr::lan(*addr),
                    });
                }
                Ok(Err(e)) => last_err = Some(e.into()),
                Err(_) => last_err = Some(HubError::Timeout("tcp connect")),
            }
        }
        Err(last_err.unwrap_or_else(|| HubError::InvalidInput("peer has no addresses".into())))
    }

    async fn connect_datagram(
        &self,
        peer: &PeerAddr,
        port: u16,
    ) -> Result<Arc<dyn DatagramChannel>> {
        let PeerAddr::Lan { addrs } = peer;
        let mut target = *addrs
            .first()
            .ok_or_else(|| HubError::InvalidInput("peer has no addresses".into()))?;
        target.set_port(port);
        let bind: SocketAddr = if target.is_ipv4() {
            "0.0.0.0:0".parse().expect("addr")
        } else {
            "[::]:0".parse().expect("addr")
        };
        // 发送走非阻塞的 std socket（直接系统调用）：tokio 的 `try_send` 在反应器
        // 观察到可写之前会返回 WouldBlock，刚连上时的第一个 pad 事件可能因此丢失。
        // 接收走共享同一 fd 的 tokio socket。
        let send = std::net::UdpSocket::bind(bind)?;
        send.connect(target)?;
        send.set_nonblocking(true)?;
        let recv = tokio::net::UdpSocket::from_std(send.try_clone()?)?;
        Ok(Arc::new(UdpChannel { send, recv }))
    }
}

struct UdpChannel {
    send: std::net::UdpSocket,
    recv: tokio::net::UdpSocket,
}

#[async_trait]
impl DatagramChannel for UdpChannel {
    fn try_send(&self, buf: &[u8]) -> io::Result<()> {
        self.send.send(buf).map(|_| ())
    }

    async fn recv(&self, buf: &mut [u8]) -> io::Result<usize> {
        loop {
            match self.recv.recv(buf).await {
                // 对端端口未就绪时 Linux 会回报 ECONNREFUSED，忽略即可。
                Err(e) if e.kind() == io::ErrorKind::ConnectionRefused => continue,
                r => return r,
            }
        }
    }
}
