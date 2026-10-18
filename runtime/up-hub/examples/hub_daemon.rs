//! 启动一个个人 Hub 并打印配对码，便于手动验证。
//!
//! ```text
//! cargo run -p up-hub --example hub_daemon -- [--data DIR] [--name NAME] [--port PORT] [--no-mdns]
//! ```
//!
//! - 数据目录默认 `<系统临时目录>/ultrapads-hub`（身份密钥、受信列表、`library/` 曲库）
//! - 配对码过期或被使用后会自动生成新码并打印
//! - 收到的远端 pad 事件直接打印到标准输出
//! - Ctrl-C 退出

use std::sync::Arc;
use std::time::Duration;

use up_hub::{DeviceId, FsLibraryStore, HubConfig, HubServer, PadSink};

struct PrintSink;

impl PadSink for PrintSink {
    fn pad_down(&self, origin: &DeviceId, bank: u8, index: u8, velocity: u8) {
        println!(
            "[pad] {} DOWN bank={bank} index={index} vel={velocity}",
            origin.short()
        );
    }
    fn pad_up(&self, origin: &DeviceId, bank: u8, index: u8) {
        println!("[pad] {} UP   bank={bank} index={index}", origin.short());
    }
    fn stop_all(&self, origin: &DeviceId) {
        println!("[pad] {} STOP ALL", origin.short());
    }
    fn controller_connected(&self, origin: &DeviceId, name: &str) {
        println!("[ctl] controller connected: {name} ({})", origin.short());
    }
    fn controller_disconnected(&self, origin: &DeviceId) {
        println!("[ctl] controller disconnected: {}", origin.short());
    }
}

fn usage() -> ! {
    eprintln!(
        "usage: hub_daemon [--data DIR] [--name NAME] [--port PORT] [--udp-port PORT] [--no-mdns]"
    );
    std::process::exit(2);
}

#[tokio::main]
async fn main() -> up_hub::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    let mut data = std::env::temp_dir().join("ultrapads-hub");
    let mut name = "UltraPads Desktop".to_string();
    let mut port = 47800u16;
    let mut udp_port = 47800u16;
    let mut mdns = true;
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--data" => data = args.next().unwrap_or_else(|| usage()).into(),
            "--name" => name = args.next().unwrap_or_else(|| usage()),
            "--port" => {
                port = args
                    .next()
                    .and_then(|v| v.parse().ok())
                    .unwrap_or_else(|| usage())
            }
            "--udp-port" => {
                udp_port = args
                    .next()
                    .and_then(|v| v.parse().ok())
                    .unwrap_or_else(|| usage())
            }
            "--no-mdns" => mdns = false,
            _ => usage(),
        }
    }

    let store = Arc::new(FsLibraryStore::open(data.join("library")).await?);
    let mut cfg = HubConfig::new(&data, &name);
    cfg.port = port;
    cfg.udp_port = udp_port;
    cfg.advertise = mdns;
    let server = HubServer::start(cfg, store, Arc::new(PrintSink)).await?;

    println!("UltraPads Hub \"{}\"", server.name());
    println!("  device id : {}", server.device_id());
    println!("  control   : tcp {}", server.local_addr());
    println!("  controller: udp {}", server.udp_addr());
    println!(
        "  mDNS      : {}",
        if server.is_advertising() {
            up_hub::SERVICE_TYPE
        } else {
            "off"
        }
    );
    for d in server.trusted_devices() {
        println!("  trusted   : {} ({})", d.name, d.id.short());
    }

    let mut tick = tokio::time::interval(Duration::from_secs(1));
    let mut stats_tick = 0u32;
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => break,
            _ = tick.tick() => {
                if !server.pairing_open() {
                    let code = server.new_pairing_code();
                    let secs = code
                        .expires_at
                        .duration_since(std::time::SystemTime::now())
                        .map(|d| d.as_secs())
                        .unwrap_or(0);
                    println!(">>> pairing code: {}  (valid {secs}s)", code.code);
                }
                stats_tick += 1;
                if stats_tick.is_multiple_of(5) {
                    for s in server.controller_stats() {
                        println!(
                            "[ctl] {} pkts={} events={} dup={} reordered={} bad_mac={} held={}",
                            s.name, s.packets, s.accepted_events, s.duplicates, s.reordered_dropped, s.bad_mac, s.held_pads
                        );
                    }
                }
            }
        }
    }
    println!("stopping...");
    server.stop().await;
    Ok(())
}
