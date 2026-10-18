//! 手动验证用的客户端（可在另一台设备上运行）。
//!
//! ```text
//! cargo run -p up-hub --example hub_client -- [--data DIR] [--name NAME] discover [SECS]
//! cargo run -p up-hub --example hub_client -- [--data DIR] pair  <ip:port> <code>
//! cargo run -p up-hub --example hub_client -- [--data DIR] sync  <ip:port>
//! cargo run -p up-hub --example hub_client -- [--data DIR] pad   <ip:port> [COUNT]
//! ```
//! 数据目录默认 `<系统临时目录>/ultrapads-client`，曲库在 `<DIR>/library`。

use std::net::SocketAddr;
use std::time::{Duration, Instant};

use up_hub::{ClientConfig, DiscoveryEvent, FsLibraryStore, HubClient, HubError, PeerAddr};

fn usage() -> ! {
    eprintln!(
        "usage: hub_client [--data DIR] [--name NAME] (discover [SECS] | pair ADDR CODE | sync ADDR | pad ADDR [COUNT])"
    );
    std::process::exit(2);
}

fn addr(s: Option<String>) -> PeerAddr {
    let a: SocketAddr = s.and_then(|s| s.parse().ok()).unwrap_or_else(|| usage());
    PeerAddr::lan(a)
}

#[tokio::main]
async fn main() -> up_hub::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("warn")),
        )
        .init();
    let mut data = std::env::temp_dir().join("ultrapads-client");
    let mut name = "UltraPads Client".to_string();
    let mut rest = Vec::new();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--data" => data = args.next().unwrap_or_else(|| usage()).into(),
            "--name" => name = args.next().unwrap_or_else(|| usage()),
            _ => rest.push(a),
        }
    }
    let client = HubClient::new(ClientConfig::new(&data, &name))?;
    println!("this device: {}", client.device_id());
    let mut rest = rest.into_iter();
    match rest.next().as_deref() {
        Some("discover") => {
            let secs: u64 = rest.next().and_then(|s| s.parse().ok()).unwrap_or(5);
            let mut d = client.discover()?;
            let deadline = tokio::time::Instant::now() + Duration::from_secs(secs);
            while let Ok(Some(ev)) = tokio::time::timeout_at(deadline, d.next_event()).await {
                match ev {
                    DiscoveryEvent::Found(p) => {
                        let paired = if client.is_paired(&p.id) {
                            "paired"
                        } else {
                            "not paired"
                        };
                        println!(
                            "found  {} \"{}\" {:?} [{paired}]",
                            p.id.short(),
                            p.name,
                            p.addr
                        );
                    }
                    DiscoveryEvent::Lost(id) => println!("lost   {}", id.short()),
                }
            }
        }
        Some("pair") => {
            let a = addr(rest.next());
            let code = rest.next().unwrap_or_else(|| usage());
            let (peer, _) = client.probe(a).await?;
            println!("hub: \"{}\" {}", peer.name, peer.id);
            let t = client.pair(&peer, &code).await?;
            println!("paired with \"{}\"", t.name);
        }
        Some("sync") => {
            let a = addr(rest.next());
            let (peer, _) = client.probe(a).await?;
            let store = FsLibraryStore::open(data.join("library")).await?;
            let r = client.sync(&peer, &store).await?;
            println!("{r:#?}");
        }
        Some("pad") => {
            let a = addr(rest.next());
            let count: u32 = rest.next().and_then(|s| s.parse().ok()).unwrap_or(16);
            let (peer, _) = client.probe(a).await?;
            if !client.is_paired(&peer.id) {
                return Err(HubError::NotPaired(peer.id.to_string()));
            }
            let ctl = client.controller_connect(&peer).await?;
            let start = Instant::now();
            for i in 0..count {
                let idx = (i % 16) as u8;
                ctl.pad_down(0, idx, 100)?;
                tokio::time::sleep(Duration::from_millis(60)).await;
                ctl.pad_up(0, idx)?;
                tokio::time::sleep(Duration::from_millis(60)).await;
                ctl.ping()?;
            }
            ctl.stop_all()?;
            tokio::time::sleep(Duration::from_millis(300)).await;
            println!("sent {count} taps in {:?}", start.elapsed());
            println!("{:#?}", ctl.latency());
            ctl.close().await?;
        }
        _ => usage(),
    }
    Ok(())
}
