//! mDNS / DNS-SD 发现：服务类型 `_ultrapads._tcp.local.`。
//!
//! TXT 记录：`v=1`、`id=<设备公钥 base32>`、`name=<设备名>`、`port=<控制面 TCP 端口>`。
//! TXT 中的 `id` 只是"声称"，真正的身份在 TLS 握手时按公钥钉扎校验。
//!
//! **Android**：mdns-sd 需要收发 224.0.0.251:5353 组播。应用必须声明
//! `CHANGE_WIFI_MULTICAST_STATE`，并在调用 `discover()` / `HubServer::start(advertise=true)`
//! **之前** 通过 `WifiManager.createMulticastLock(..).acquire()` 获取组播锁，
//! 在停止发现/服务（或 App 进入后台）后 `release()`。详见 docs/adr/0004-personal-hub.md。

use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::pin::Pin;
use std::task::{Context, Poll};

use mdns_sd::{IfKind, ServiceDaemon, ServiceEvent, ServiceInfo};
use tokio::sync::mpsc;

use crate::client::HubPeer;
use crate::identity::DeviceId;
use crate::transport::PeerAddr;
use crate::{HubError, PROTOCOL_VERSION, Result};

/// DNS-SD 服务类型。
pub const SERVICE_TYPE: &str = "_ultrapads._tcp.local.";

fn mdns_err(e: mdns_sd::Error) -> HubError {
    HubError::Discovery(e.to_string())
}

/// 把设备名清洗成合法的 DNS-SD 实例名（≤ 63 字节，追加短 ID 防重名）。
fn instance_name(name: &str, id: &DeviceId) -> String {
    let clean: String = name
        .chars()
        .map(|c| if c.is_control() || c == '.' { '-' } else { c })
        .collect();
    let mut base = clean.trim().to_string();
    if base.is_empty() {
        base = "UltraPads".into();
    }
    while base.len() > 50 {
        base.pop();
    }
    format!("{base} ({})", id.short())
}

/// 正在广播的 Hub 服务。
pub(crate) struct Advertiser {
    daemon: ServiceDaemon,
    fullname: String,
}

impl Advertiser {
    /// `bind` 为 Hub 的监听地址：只广播能连上的地址族（绑定 IPv4 时不广播 IPv6 地址）。
    pub(crate) fn start(id: &DeviceId, name: &str, port: u16, bind: IpAddr) -> Result<Self> {
        let daemon = ServiceDaemon::new().map_err(mdns_err)?;
        if bind.is_ipv4() {
            daemon.disable_interface(IfKind::IPv6).map_err(mdns_err)?;
        }
        let host = format!("ultrapads-{}.local.", id.short());
        let port_s = port.to_string();
        let props = [
            ("v", PROTOCOL_VERSION.to_string()),
            ("id", id.to_b32()),
            ("name", name.chars().take(100).collect::<String>()),
            ("port", port_s),
        ];
        let info = ServiceInfo::new(
            SERVICE_TYPE,
            &instance_name(name, id),
            &host,
            "",
            port,
            &props[..],
        )
        .map_err(mdns_err)?
        .enable_addr_auto();
        let fullname = info.get_fullname().to_string();
        daemon.register(info).map_err(mdns_err)?;
        tracing::info!(%fullname, port, "mDNS advertising");
        Ok(Self { daemon, fullname })
    }

    pub(crate) fn stop(self) {
        if let Ok(rx) = self.daemon.unregister(&self.fullname) {
            let _ = rx.recv_timeout(std::time::Duration::from_secs(1));
        }
        let _ = self.daemon.shutdown();
    }
}

/// 发现事件。
#[derive(Clone, Debug, PartialEq)]
pub enum DiscoveryEvent {
    /// 发现（或更新）了一个 Hub。
    Found(HubPeer),
    /// Hub 下线。
    Lost(DeviceId),
}

/// 发现流。实现 `futures::Stream<Item = DiscoveryEvent>`；drop 即停止浏览。
pub struct Discovery {
    rx: mpsc::Receiver<DiscoveryEvent>,
    daemon: ServiceDaemon,
    task: tokio::task::JoinHandle<()>,
}

impl std::fmt::Debug for Discovery {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Discovery").finish_non_exhaustive()
    }
}

impl Discovery {
    /// 等待下一个事件。
    pub async fn next_event(&mut self) -> Option<DiscoveryEvent> {
        self.rx.recv().await
    }
}

impl futures_util::Stream for Discovery {
    type Item = DiscoveryEvent;
    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        self.rx.poll_recv(cx)
    }
}

impl Drop for Discovery {
    fn drop(&mut self) {
        self.task.abort();
        let _ = self.daemon.stop_browse(SERVICE_TYPE);
        let _ = self.daemon.shutdown();
    }
}

fn order_addrs(ips: impl Iterator<Item = IpAddr>, port: u16) -> Vec<SocketAddr> {
    let mut v: Vec<IpAddr> = ips
        .filter(|ip| match ip {
            // 无 scope id 的链路本地 IPv6 无法连接。
            IpAddr::V6(v6) => (v6.segments()[0] & 0xffc0) != 0xfe80,
            IpAddr::V4(_) => true,
        })
        .collect();
    // IPv4 优先，回环最后。
    v.sort_by_key(|ip| (ip.is_loopback(), ip.is_ipv6(), *ip));
    v.dedup();
    v.into_iter().map(|ip| SocketAddr::new(ip, port)).collect()
}

/// 开始浏览局域网中的 Hub。`exclude` 通常为本机 ID（不报告自己）。
pub fn discover(exclude: Option<DeviceId>) -> Result<Discovery> {
    let daemon = ServiceDaemon::new().map_err(mdns_err)?;
    let browse = daemon.browse(SERVICE_TYPE).map_err(mdns_err)?;
    let (tx, rx) = mpsc::channel(64);
    let task = tokio::spawn(async move {
        let mut by_fullname: HashMap<String, DeviceId> = HashMap::new();
        while let Ok(ev) = browse.recv_async().await {
            let out = match ev {
                ServiceEvent::ServiceResolved(info) => {
                    let props = info.get_properties();
                    let v = props
                        .get_property_val_str("v")
                        .and_then(|s| s.parse::<u32>().ok());
                    let Some(id) = props
                        .get_property_val_str("id")
                        .and_then(|s| DeviceId::parse(s).ok())
                    else {
                        continue;
                    };
                    if v != Some(PROTOCOL_VERSION) || Some(id) == exclude {
                        continue;
                    }
                    let port = props
                        .get_property_val_str("port")
                        .and_then(|s| s.parse::<u16>().ok())
                        .unwrap_or(info.get_port());
                    let addrs =
                        order_addrs(info.get_addresses().iter().map(|a| a.to_ip_addr()), port);
                    if addrs.is_empty() {
                        continue;
                    }
                    let name = props.get_property_val_str("name").unwrap_or("").to_string();
                    by_fullname.insert(info.get_fullname().to_string(), id);
                    DiscoveryEvent::Found(HubPeer {
                        id,
                        name,
                        addr: PeerAddr::Lan { addrs },
                    })
                }
                ServiceEvent::ServiceRemoved(_, fullname) => match by_fullname.remove(&fullname) {
                    Some(id) => DiscoveryEvent::Lost(id),
                    None => continue,
                },
                _ => continue,
            };
            if tx.send(out).await.is_err() {
                break;
            }
        }
    });
    Ok(Discovery { rx, daemon, task })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::identity::DeviceIdentity;

    #[test]
    fn instance_names_are_sane() {
        let id = DeviceIdentity::generate().id();
        let n = instance_name("Pluto's.PC\n", &id);
        assert!(!n.contains('.') && !n.contains('\n'));
        assert!(instance_name(&"x".repeat(200), &id).len() <= 63);
        assert!(instance_name("", &id).starts_with("UltraPads"));
    }

    #[test]
    fn addr_ordering() {
        let ips: Vec<IpAddr> = ["127.0.0.1", "fe80::1", "2001:db8::1", "192.168.1.5"]
            .iter()
            .map(|s| s.parse().unwrap())
            .collect();
        let v = order_addrs(ips.into_iter(), 9000);
        assert_eq!(v[0], "192.168.1.5:9000".parse().unwrap());
        assert_eq!(v.len(), 3);
        assert!(v.last().unwrap().ip().is_loopback());
    }
}
