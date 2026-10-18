//! 同进程起 Hub 与 Client（localhost），走完：
//! 配对 → 同步（含冲突、断点续传）→ 控制器事件（含重复包和乱序）→ 撤销。

use std::net::{IpAddr, Ipv4Addr};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use up_hub::*;

#[derive(Clone, Debug, PartialEq, Eq)]
enum Ev {
    Down(u8, u8, u8),
    Up(u8, u8),
    Stop,
    Connected,
    Disconnected,
}

#[derive(Default)]
struct RecordingSink(Mutex<Vec<Ev>>);

impl RecordingSink {
    fn take(&self) -> Vec<Ev> {
        std::mem::take(&mut *self.0.lock().unwrap())
    }
}

impl PadSink for RecordingSink {
    fn pad_down(&self, _: &DeviceId, bank: u8, index: u8, velocity: u8) {
        self.0.lock().unwrap().push(Ev::Down(bank, index, velocity));
    }
    fn pad_up(&self, _: &DeviceId, bank: u8, index: u8) {
        self.0.lock().unwrap().push(Ev::Up(bank, index));
    }
    fn stop_all(&self, _: &DeviceId) {
        self.0.lock().unwrap().push(Ev::Stop);
    }
    fn controller_connected(&self, _: &DeviceId, _: &str) {
        self.0.lock().unwrap().push(Ev::Connected);
    }
    fn controller_disconnected(&self, _: &DeviceId) {
        self.0.lock().unwrap().push(Ev::Disconnected);
    }
}

async fn wait_for<F: Fn() -> bool>(what: &str, f: F) {
    for _ in 0..200 {
        if f() {
            return;
        }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }
    panic!("timed out waiting for {what}");
}

fn data(seed: u8, len: usize) -> Vec<u8> {
    (0..len)
        .map(|i| (i as u8).wrapping_mul(31).wrapping_add(seed))
        .collect()
}

async fn add_entry(
    store: &FsLibraryStore,
    device: DeviceId,
    id: &str,
    kind: EntryKind,
    name: &str,
    blobs: &[&[u8]],
) {
    let mut m = store.manifest().await.unwrap();
    let mut e = ManifestEntry::new(id, kind, name, device);
    for b in blobs {
        let hash = store.put_blob(b).await.unwrap();
        e.blobs.push(BlobRef {
            hash,
            size: b.len() as u64,
            role: "audio".into(),
        });
    }
    m.upsert(e);
    store.put_manifest(&m).await.unwrap();
}

async fn edit_entry(store: &FsLibraryStore, device: DeviceId, id: &str, name: &str, at_ms: i64) {
    let mut m = store.manifest().await.unwrap();
    let e = m.entries.get_mut(id).unwrap();
    e.name = name.into();
    e.touch(device);
    e.modified_at_ms = at_ms;
    store.put_manifest(&m).await.unwrap();
}

fn entries_without_versions(m: &LibraryManifest) -> Vec<(String, String, bool)> {
    m.entries
        .values()
        .map(|e| (e.id.clone(), e.name.clone(), e.deleted))
        .collect()
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn pair_sync_controller_end_to_end() {
    let _ = tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .with_test_writer()
        .try_init();

    let hub_dir = tempfile::tempdir().unwrap();
    let phone_dir = tempfile::tempdir().unwrap();
    let stranger_dir = tempfile::tempdir().unwrap();

    let hub_store = Arc::new(
        FsLibraryStore::open(hub_dir.path().join("library"))
            .await
            .unwrap(),
    );
    let phone_store = FsLibraryStore::open(phone_dir.path().join("library"))
        .await
        .unwrap();
    let sink = Arc::new(RecordingSink::default());

    let mut cfg = HubConfig::new(hub_dir.path().join("hub"), "Desktop");
    cfg.bind_addr = IpAddr::V4(Ipv4Addr::LOCALHOST);
    cfg.advertise = false;
    cfg.controller_ping_interval = Duration::from_millis(50);
    let server = HubServer::start(cfg, hub_store.clone(), sink.clone())
        .await
        .unwrap();
    let hub_id = server.device_id();

    let phone = HubClient::new(ClientConfig::new(phone_dir.path().join("hub"), "Phone")).unwrap();
    let phone_id = phone.device_id();

    // ---------------------------------------------------------------- 探测
    let (peer, info) = phone.probe(server.local_peer().addr).await.unwrap();
    assert_eq!(peer.id, hub_id);
    assert_eq!(info.name, "Desktop");
    assert!(!info.paired);
    assert!(!info.pairing_open);

    // 未配对：本地拒绝；绕过本地检查直接访问也会被 Hub 拒绝（见下方 stranger）。
    assert!(matches!(
        phone.sync(&peer, &phone_store).await,
        Err(HubError::NotPaired(_))
    ));

    // ---------------------------------------------------------------- 配对
    // 没有配对码时
    assert!(matches!(
        phone.pair(&peer, "123456").await,
        Err(HubError::Pairing(_))
    ));
    let code = server.new_pairing_code();
    assert_eq!(code.code.len(), 6);
    assert!(server.pairing_open());
    // 错误配对码：客户端在 Hub 的确认 MAC 上就能发现
    let wrong = format!("{:06}", (code.code.parse::<u32>().unwrap() + 1) % 1_000_000);
    assert!(matches!(
        phone.pair(&peer, &wrong).await,
        Err(HubError::Pairing(_))
    ));
    assert!(phone.trusted_devices().is_empty());
    assert!(server.trusted_devices().is_empty());
    // 正确配对码
    let trusted = phone.pair(&peer, &code.code).await.unwrap();
    assert_eq!(trusted.id, hub_id);
    assert_eq!(trusted.name, "Desktop");
    assert!(phone.is_paired(&hub_id));
    let hub_side = server.trusted_devices();
    assert_eq!(hub_side.len(), 1);
    assert_eq!(hub_side[0].id, phone_id);
    assert_eq!(hub_side[0].name, "Phone");
    // 一次性
    assert!(!server.pairing_open());
    let stranger = HubClient::new(ClientConfig::new(stranger_dir.path(), "Stranger")).unwrap();
    assert!(matches!(
        stranger.pair(&peer, &code.code).await,
        Err(HubError::Pairing(_))
    ));

    // 钉扎：拿错误 ID 连接同一地址会在 TLS 握手失败
    let fake_peer = HubPeer {
        id: stranger.device_id(),
        ..peer.clone()
    };
    assert!(phone.probe(peer.addr.clone()).await.is_ok());
    let fake_code = server.new_pairing_code();
    assert!(matches!(
        phone.pair(&fake_peer, &fake_code.code).await,
        Err(HubError::Tls(_))
    ));
    server.cancel_pairing();

    // ---------------------------------------------------------------- 首次同步
    let kit_a = data(1, 200_000);
    let kit_b = data(2, 50_000);
    let sample = data(3, 120_000);
    add_entry(
        &hub_store,
        hub_id,
        "kit-1",
        EntryKind::Kit,
        "Hub Kit",
        &[&kit_a, &kit_b],
    )
    .await;
    add_entry(
        &hub_store,
        hub_id,
        "shared-1",
        EntryKind::Project,
        "Song v1",
        &[],
    )
    .await;
    add_entry(
        &phone_store,
        phone_id,
        "sample-1",
        EntryKind::Sample,
        "Phone Sample",
        &[&sample],
    )
    .await;
    add_entry(
        &phone_store,
        phone_id,
        "track-1",
        EntryKind::Track,
        "Take 1",
        &[&data(4, 1000)],
    )
    .await;

    let r1 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!(r1.downloaded_blobs, 2);
    assert_eq!(r1.downloaded_bytes, (kit_a.len() + kit_b.len()) as u64);
    assert_eq!(r1.uploaded_blobs, 2);
    assert_eq!(r1.uploaded_bytes, (sample.len() + 1000) as u64);
    assert_eq!(r1.conflicts, 0);
    assert_eq!(r1.local_changed, 2);
    assert_eq!(r1.remote_changed, 2);
    let hm = hub_store.manifest().await.unwrap();
    let pm = phone_store.manifest().await.unwrap();
    assert_eq!(hm, pm, "manifests converge");
    assert_eq!(hm.entries.len(), 4);
    assert_eq!(
        phone_store.read_blob(&BlobHash::of(&kit_a)).await.unwrap(),
        kit_a
    );
    assert_eq!(
        hub_store.read_blob(&BlobHash::of(&sample)).await.unwrap(),
        sample
    );

    // 幂等：再次同步不传输任何东西
    let r2 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!(
        (r2.uploaded_blobs, r2.downloaded_blobs, r2.conflicts),
        (0, 0, 0)
    );
    assert_eq!((r2.local_changed, r2.remote_changed), (0, 0));

    // ---------------------------------------------------------------- 冲突 + 单边修改 + 删除
    edit_entry(&hub_store, hub_id, "shared-1", "Song (desk edit)", 1_000).await;
    edit_entry(
        &phone_store,
        phone_id,
        "shared-1",
        "Song (phone edit)",
        2_000,
    )
    .await;
    edit_entry(
        &phone_store,
        phone_id,
        "sample-1",
        "Phone Sample renamed",
        3_000,
    )
    .await;
    {
        let mut m = hub_store.manifest().await.unwrap();
        m.entries.get_mut("track-1").unwrap().mark_deleted(hub_id);
        hub_store.put_manifest(&m).await.unwrap();
    }
    let r3 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!(r3.conflicts, 1, "{r3:?}");
    let copy_id = &r3.conflict_ids[0];
    assert!(copy_id.starts_with("shared-1~conflict~"));
    let hm = hub_store.manifest().await.unwrap();
    let pm = phone_store.manifest().await.unwrap();
    assert_eq!(hm, pm);
    assert_eq!(
        hm.entries["shared-1"].name, "Song (phone edit)",
        "last writer wins"
    );
    assert_eq!(
        hm.entries[copy_id].name, "Song (desk edit)",
        "loser kept as copy"
    );
    assert_eq!(hm.entries[copy_id].conflict_of.as_deref(), Some("shared-1"));
    assert_eq!(hm.entries["sample-1"].name, "Phone Sample renamed");
    assert!(hm.entries["track-1"].deleted, "deletion propagates");
    // 冲突不会重复产生
    let r4 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!(r4.conflicts, 0);

    // ---------------------------------------------------------------- 断点续传
    let big_up = data(9, 3 * 1024 * 1024 + 17);
    let big_down = data(10, 2 * 1024 * 1024 + 5);
    add_entry(
        &phone_store,
        phone_id,
        "proj-big",
        EntryKind::Project,
        "Big Project",
        &[&big_up],
    )
    .await;
    add_entry(
        &hub_store,
        hub_id,
        "kit-big",
        EntryKind::Kit,
        "Big Kit",
        &[&big_down],
    )
    .await;
    // 模拟上次同步中断：Hub 已收到上传的前 1 MiB，手机已下载了前 700 KiB。
    let up_hash = BlobHash::of(&big_up);
    let down_hash = BlobHash::of(&big_down);
    {
        let mut w = hub_store.blob_writer(&up_hash, 0).await.unwrap();
        w.write(&big_up[..1024 * 1024]).await.unwrap();
        drop(w);
        let mut w = phone_store.blob_writer(&down_hash, 0).await.unwrap();
        w.write(&big_down[..700 * 1024]).await.unwrap();
        drop(w);
    }
    assert_eq!(
        hub_store.blob_status(&up_hash).await.unwrap(),
        BlobStatus::Partial(1024 * 1024)
    );
    let r5 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!(r5.uploaded_blobs, 1);
    assert_eq!(
        r5.uploaded_bytes,
        (big_up.len() - 1024 * 1024) as u64,
        "only the missing tail is uploaded"
    );
    assert_eq!(r5.downloaded_blobs, 1);
    assert_eq!(
        r5.downloaded_bytes,
        (big_down.len() - 700 * 1024) as u64,
        "only the missing tail is downloaded"
    );
    assert_eq!(r5.resumed_blobs, 2);
    assert_eq!(hub_store.read_blob(&up_hash).await.unwrap(), big_up);
    assert_eq!(phone_store.read_blob(&down_hash).await.unwrap(), big_down);
    assert_eq!(
        entries_without_versions(&hub_store.manifest().await.unwrap()),
        entries_without_versions(&phone_store.manifest().await.unwrap())
    );
    let r6 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!((r6.uploaded_bytes, r6.downloaded_bytes), (0, 0));

    // 损坏的部分数据：Hub 侧前缀被篡改 → 续传后校验失败并丢弃，重跑后从头上传成功。
    let bad = data(11, 300_000);
    let bad_hash = BlobHash::of(&bad);
    add_entry(
        &phone_store,
        phone_id,
        "s-bad",
        EntryKind::Sample,
        "Bad",
        &[&bad],
    )
    .await;
    {
        let mut w = hub_store.blob_writer(&bad_hash, 0).await.unwrap();
        w.write(&vec![0xAA; 1000]).await.unwrap();
    }
    let err = phone.sync(&peer, &phone_store).await.unwrap_err();
    assert!(
        matches!(err, HubError::Remote { status: 422, .. }),
        "{err:?}"
    );
    assert_eq!(
        hub_store.blob_status(&bad_hash).await.unwrap(),
        BlobStatus::Missing
    );
    assert!(
        !hub_store
            .manifest()
            .await
            .unwrap()
            .entries
            .contains_key("s-bad")
    );
    let r7 = phone.sync(&peer, &phone_store).await.unwrap();
    assert_eq!(r7.uploaded_bytes, bad.len() as u64);
    assert!(
        hub_store
            .manifest()
            .await
            .unwrap()
            .entries
            .contains_key("s-bad")
    );

    // 未配对设备在 Hub 视角下也是未配对（Hub 端的拒绝在下方"撤销"部分验证）
    let (_, info) = stranger.probe(peer.addr.clone()).await.unwrap();
    assert!(!info.paired);
    let (_, info) = phone.probe(peer.addr.clone()).await.unwrap();
    assert!(info.paired);

    // ---------------------------------------------------------------- 控制器
    sink.take();
    let ctl = phone.controller_connect(&peer).await.unwrap();
    wait_for("connected", || {
        sink.0.lock().unwrap().contains(&Ev::Connected)
    })
    .await;
    sink.take();
    ctl.pad_down(0, 3, 100).unwrap();
    ctl.pad_up(0, 3).unwrap();
    ctl.pad_down(1, 7, 200).unwrap(); // 力度截断到 127
    ctl.stop_all().unwrap();
    wait_for("4 events", || sink.0.lock().unwrap().len() >= 4).await;
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert_eq!(
        sink.take(),
        vec![
            Ev::Down(0, 3, 100),
            Ev::Up(0, 3),
            Ev::Down(1, 7, 127),
            Ev::Stop
        ],
        "each event delivered exactly once despite double-send"
    );
    let st = server.controller_stats();
    assert_eq!(st.len(), 1);
    assert_eq!(st[0].device, phone_id);
    assert!(st[0].duplicates >= 4, "{st:?}");

    // 乱序：同一 pad 的 Up(seq s+1) 先到，Down(seq s) 后到 → Down 作废，不挂音；
    // 不同 pad 的乱序事件照常应用。
    let s = ctl.reserve_seqs(4);
    ctl.send_raw_with_seq(s + 1, RemotePadEvent::PadUp { bank: 2, index: 2 }, 1)
        .unwrap();
    ctl.send_raw_with_seq(
        s,
        RemotePadEvent::PadDown {
            bank: 2,
            index: 2,
            velocity: 90,
        },
        1,
    )
    .unwrap();
    ctl.send_raw_with_seq(
        s + 3,
        RemotePadEvent::PadDown {
            bank: 3,
            index: 1,
            velocity: 80,
        },
        1,
    )
    .unwrap();
    ctl.send_raw_with_seq(
        s + 2,
        RemotePadEvent::PadDown {
            bank: 3,
            index: 0,
            velocity: 70,
        },
        1,
    )
    .unwrap();
    wait_for("reordered events", || sink.0.lock().unwrap().len() >= 3).await;
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert_eq!(
        sink.take(),
        vec![Ev::Up(2, 2), Ev::Down(3, 1, 80), Ev::Down(3, 0, 70)]
    );
    // 重放旧 seq：被窗口拒绝
    ctl.send_raw_with_seq(
        s + 3,
        RemotePadEvent::PadDown {
            bank: 3,
            index: 1,
            velocity: 80,
        },
        1,
    )
    .unwrap();
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert!(sink.take().is_empty());
    let st = server.controller_stats();
    assert_eq!(st[0].reordered_dropped, 1);
    assert_eq!(st[0].held_pads, 2);

    // 伪造报文（错误密钥）
    {
        let sock = std::net::UdpSocket::bind("127.0.0.1:0").unwrap();
        let mut pkt = vec![1u8, 1, 0, 0, 0, 99];
        pkt.extend_from_slice(&ctl.session_id().to_be_bytes());
        pkt.extend_from_slice(&[0, 1, 127]);
        pkt.extend_from_slice(&[0u8; 16]);
        sock.send_to(&pkt, server.udp_addr()).unwrap();
        wait_for("bad mac counted", || {
            server.controller_stats()[0].bad_mac == 1
        })
        .await;
        assert!(sink.take().is_empty());
    }

    // 延迟统计（后台 ping 50ms 一次）
    wait_for("latency samples", || ctl.latency().samples >= 3).await;
    let lat = ctl.latency();
    assert!(lat.rtt_p50_us < 50_000, "{lat:?}");
    eprintln!("loopback controller latency: {lat:?}");

    // 关闭：Hub 对仍按住的 pad 补发 PadUp
    ctl.close().await.unwrap();
    wait_for("disconnected", || {
        sink.0.lock().unwrap().contains(&Ev::Disconnected)
    })
    .await;
    let mut evs = sink.take();
    let last = evs.pop();
    evs.sort_by_key(|e| format!("{e:?}"));
    assert_eq!(evs, vec![Ev::Up(3, 0), Ev::Up(3, 1)]);
    assert_eq!(last, Some(Ev::Disconnected));
    assert!(server.controller_stats().is_empty());

    // drop 句柄也会关闭会话
    let ctl2 = phone.controller_connect(&peer).await.unwrap();
    ctl2.pad_down(0, 0, 64).unwrap();
    wait_for("down", || {
        sink.0.lock().unwrap().contains(&Ev::Down(0, 0, 64))
    })
    .await;
    drop(ctl2);
    wait_for("released on drop", || {
        sink.0.lock().unwrap().contains(&Ev::Disconnected)
    })
    .await;
    assert!(sink.take().contains(&Ev::Up(0, 0)));

    // ---------------------------------------------------------------- 撤销
    let ctl3 = phone.controller_connect(&peer).await.unwrap();
    assert!(server.revoke(&phone_id).unwrap());
    assert!(server.controller_stats().is_empty());
    let err = phone.sync(&peer, &phone_store).await.unwrap_err();
    assert!(matches!(err, HubError::NotPaired(_)), "{err:?}");
    assert!(matches!(
        phone.controller_connect(&peer).await,
        Err(HubError::NotPaired(_))
    ));
    drop(ctl3);

    server.stop().await;
}

#[tokio::test]
async fn pairing_attempts_are_limited() {
    let hub_dir = tempfile::tempdir().unwrap();
    let phone_dir = tempfile::tempdir().unwrap();
    let store = Arc::new(
        FsLibraryStore::open(hub_dir.path().join("lib"))
            .await
            .unwrap(),
    );
    let mut cfg = HubConfig::new(hub_dir.path().join("hub"), "Desk");
    cfg.bind_addr = IpAddr::V4(Ipv4Addr::LOCALHOST);
    cfg.advertise = false;
    cfg.pairing_max_attempts = 2;
    let server = HubServer::start(cfg, store, Arc::new(NullPadSink))
        .await
        .unwrap();
    let phone = HubClient::new(ClientConfig::new(phone_dir.path(), "Phone")).unwrap();
    let peer = server.local_peer();
    let code = server.new_pairing_code();
    let wrong = format!("{:06}", (code.code.parse::<u32>().unwrap() + 1) % 1_000_000);
    assert!(phone.pair(&peer, &wrong).await.is_err());
    assert!(phone.pair(&peer, &wrong).await.is_err());
    // 尝试次数用尽后，正确的码也不再可用（防止在线暴力猜测）
    let err = phone.pair(&peer, &code.code).await.unwrap_err();
    assert!(
        matches!(err, HubError::Pairing(ref m) if m.contains("pairing_closed")),
        "{err:?}"
    );
    assert!(!server.pairing_open());
    server.stop().await;
}

#[tokio::test]
async fn hub_and_client_share_identity_in_same_data_dir() {
    let dir = tempfile::tempdir().unwrap();
    let store = Arc::new(FsLibraryStore::open(dir.path().join("lib")).await.unwrap());
    let mut cfg = HubConfig::new(dir.path().join("hub"), "Desk");
    cfg.bind_addr = IpAddr::V4(Ipv4Addr::LOCALHOST);
    cfg.advertise = false;
    let server = HubServer::start(cfg, store, Arc::new(NullPadSink))
        .await
        .unwrap();
    let client = HubClient::new(ClientConfig::new(dir.path().join("hub"), "Desk")).unwrap();
    assert_eq!(client.device_id(), server.device_id());
    server.stop().await;
}

/// mDNS 在 CI 容器里通常没有组播，手动运行：
/// `cargo test -p up-hub --test end_to_end -- --ignored mdns`
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
#[ignore = "requires multicast-capable network interface"]
async fn mdns_discovery() {
    let hub_dir = tempfile::tempdir().unwrap();
    let phone_dir = tempfile::tempdir().unwrap();
    let store = Arc::new(
        FsLibraryStore::open(hub_dir.path().join("lib"))
            .await
            .unwrap(),
    );
    let cfg = HubConfig::new(hub_dir.path().join("hub"), "Desk mDNS");
    let server = HubServer::start(cfg, store, Arc::new(NullPadSink))
        .await
        .unwrap();
    assert!(server.is_advertising());
    let phone = HubClient::new(ClientConfig::new(phone_dir.path(), "Phone")).unwrap();
    let mut disc = phone.discover().unwrap();
    let found = tokio::time::timeout(Duration::from_secs(10), async {
        while let Some(ev) = disc.next_event().await {
            if let DiscoveryEvent::Found(p) = ev
                && p.id == server.device_id()
            {
                return p;
            }
        }
        panic!("discovery stream ended");
    })
    .await
    .expect("hub discovered within 10s");
    eprintln!("discovered: {found:?}");
    assert_eq!(found.name, "Desk mDNS");
    // 通过发现的地址真正连上并核对身份
    let (peer, _) = phone.probe(found.addr.clone()).await.unwrap();
    assert_eq!(peer.id, server.device_id());
    server.stop().await;
    let lost = tokio::time::timeout(Duration::from_secs(10), async {
        while let Some(ev) = disc.next_event().await {
            if let DiscoveryEvent::Lost(id) = ev {
                return id;
            }
        }
        panic!("discovery stream ended");
    })
    .await;
    eprintln!("lost event: {lost:?}");
}
