//! Hub integration through the FFI functions (one process, loopback, no
//! audio device; the parked audio processor is pumped by hand):
//!
//! A. FFI = hub, raw `up_hub::HubClient` = phone:
//!    start → pairing code → pair → sync (LibraryChanged) → controller pad
//!    events reach the engine (PadState Playing).
//! B. FFI = client of a raw `up_hub::HubServer`:
//!    probe → wrong code → pair → sync (progress, LibraryChanged, sample
//!    arrives) → controller: `pad_down` is forwarded and silent locally,
//!    local echo plays locally, disconnect restores local playback.

use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crossbeam_channel::Receiver;
use up_ffi::api::{engine, hub, library, types::*};
use up_hub::{ClientConfig, DeviceId, HubClient, HubConfig, HubServer, PadSink, PeerAddr};
use up_library::hub_store::LibraryHubStore;

fn repo() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

struct Events {
    rx: Receiver<EngineEvent>,
    seen: Vec<EngineEvent>,
}

impl Events {
    fn drain(&mut self) {
        while let Ok(ev) = self.rx.try_recv() {
            if !matches!(
                ev,
                EngineEvent::Meters { .. } | EngineEvent::Transport { .. }
            ) {
                self.seen.push(ev);
            }
        }
    }

    /// Wait until an event matching `pred` arrives (consumes it and everything
    /// before it). `tick` runs between polls (e.g. pumping audio).
    fn wait(
        &mut self,
        what: &str,
        mut tick: impl FnMut(),
        pred: impl Fn(&EngineEvent) -> bool,
    ) -> EngineEvent {
        let deadline = Instant::now() + Duration::from_secs(10);
        loop {
            self.drain();
            if let Some(i) = self.seen.iter().position(&pred) {
                let ev = self.seen[i].clone();
                self.seen.drain(..=i);
                return ev;
            }
            assert!(
                Instant::now() < deadline,
                "timed out waiting for {what}; seen: {:?}",
                self.seen
            );
            tick();
            std::thread::sleep(Duration::from_millis(5));
        }
    }

    fn any(&mut self, pred: impl Fn(&EngineEvent) -> bool) -> bool {
        self.drain();
        self.seen.iter().any(pred)
    }

    fn clear(&mut self) {
        self.drain();
        self.seen.clear();
    }
}

fn pump() {
    up_ffi::testing::pump_audio(2).unwrap();
}

fn playing(pad: PadId) -> impl Fn(&EngineEvent) -> bool {
    move |e| matches!(e, EngineEvent::PadState { pad: p, state: PadPlayState::Playing } if *p == pad)
}

/// Pump until every pad is idle, then forget old events.
fn settle(ev: &mut Events) {
    engine::send(Command::StopAll).unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        pump();
        std::thread::sleep(Duration::from_millis(5));
        let snap = engine::snapshot().unwrap();
        if snap.pads.iter().all(|p| p.state == PadPlayState::Idle) {
            break;
        }
        assert!(Instant::now() < deadline, "pads did not go idle");
    }
    std::thread::sleep(Duration::from_millis(30));
    ev.clear();
}

/// 0.25 s of a 440 Hz sine, 16-bit mono 48 kHz WAV.
fn sine_wav() -> Vec<u8> {
    let frames = 12_000u32;
    let mut pcm = Vec::with_capacity(frames as usize * 2);
    for i in 0..frames {
        let s = (i as f32 / 48_000.0 * 440.0 * std::f32::consts::TAU).sin() * 0.5;
        pcm.extend_from_slice(&((s * i16::MAX as f32) as i16).to_le_bytes());
    }
    let mut w = Vec::new();
    w.extend_from_slice(b"RIFF");
    w.extend_from_slice(&(36 + pcm.len() as u32).to_le_bytes());
    w.extend_from_slice(b"WAVEfmt ");
    w.extend_from_slice(&16u32.to_le_bytes());
    w.extend_from_slice(&1u16.to_le_bytes()); // PCM
    w.extend_from_slice(&1u16.to_le_bytes()); // mono
    w.extend_from_slice(&48_000u32.to_le_bytes());
    w.extend_from_slice(&96_000u32.to_le_bytes());
    w.extend_from_slice(&2u16.to_le_bytes());
    w.extend_from_slice(&16u16.to_le_bytes());
    w.extend_from_slice(b"data");
    w.extend_from_slice(&(pcm.len() as u32).to_le_bytes());
    w.extend_from_slice(&pcm);
    w
}

#[derive(Default)]
struct RecordingSink(Mutex<Vec<String>>);

impl PadSink for RecordingSink {
    fn pad_down(&self, _: &DeviceId, bank: u8, index: u8, velocity: u8) {
        self.0
            .lock()
            .unwrap()
            .push(format!("down {bank}/{index} {velocity}"));
    }
    fn pad_up(&self, _: &DeviceId, bank: u8, index: u8) {
        self.0.lock().unwrap().push(format!("up {bank}/{index}"));
    }
    fn stop_all(&self, _: &DeviceId) {
        self.0.lock().unwrap().push("stop".into());
    }
}

impl RecordingSink {
    fn wait_for(&self, what: &str) {
        let deadline = Instant::now() + Duration::from_secs(5);
        while !self.0.lock().unwrap().iter().any(|e| e == what) {
            assert!(
                Instant::now() < deadline,
                "remote hub never received {what:?}: {:?}",
                self.0.lock().unwrap()
            );
            std::thread::sleep(Duration::from_millis(5));
        }
    }
}

#[test]
fn hub_flow_through_ffi() {
    let tmp = std::env::temp_dir().join(format!("up-ffi-hub-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let trt = tokio::runtime::Runtime::new().unwrap();

    engine::init(AppDirs {
        data_dir: tmp.join("data").to_string_lossy().into(),
        cache_dir: String::new(),
    })
    .unwrap();
    library::library_import(
        repo()
            .join("content/kits/ultrapads-starter.upkit")
            .to_string_lossy()
            .into(),
    )
    .unwrap();
    let kit = library::library_list_kits().unwrap().remove(0);
    library::library_load_kit(kit.id.clone()).unwrap();
    let snap = engine::snapshot().unwrap();
    let pad = snap
        .pads
        .iter()
        .find(|p| p.params.sample.is_some() && p.params.mode == PadMode::OneShot)
        .or_else(|| snap.pads.iter().find(|p| p.params.sample.is_some()))
        .expect("a pad with a sample")
        .pad;
    let mut ev = Events {
        rx: up_ffi::testing::event_receiver().unwrap(),
        seen: Vec::new(),
    };
    assert!(hub::hub_server_info().unwrap().is_none());
    let my_id = hub::hub_device_id().unwrap();
    assert!(
        tmp.join("data/hub/identity.key").exists(),
        "identity under <data>/hub"
    );

    // ------------------------------------------------ A: FFI is the hub
    let info = trt.block_on(hub::hub_start_server("Desk".into())).unwrap();
    assert_eq!(info.id, my_id);
    assert!(info.port > 0 && info.udp_port > 0);
    assert!(!info.addresses.is_empty());
    ev.wait(
        "ServerStarted",
        || {},
        |e| matches!(e, EngineEvent::Hub(HubEvent::ServerStarted { port }) if *port == info.port),
    );
    // Same name again → same server.
    assert_eq!(
        trt.block_on(hub::hub_start_server("Desk".into()))
            .unwrap()
            .port,
        info.port
    );
    let code = hub::hub_new_pairing_code().unwrap();
    assert_eq!(code.code.len(), 6);
    assert!(code.ttl_secs > 0 && code.expires_unix_ms > 0);

    let phone_lib = Arc::new(up_library::Library::open(tmp.join("phone/library")).unwrap());
    phone_lib
        .import(repo().join("content/kits/ultrapads-night-drive.upkit"))
        .unwrap();
    let phone = HubClient::new(ClientConfig::new(tmp.join("phone/hub"), "Phone")).unwrap();
    let phone_store = LibraryHubStore::new(Arc::clone(&phone_lib), phone.device_id());
    let desk = up_hub::HubPeer {
        id: DeviceId::parse(&info.id).unwrap(),
        name: info.name.clone(),
        addr: PeerAddr::lan(format!("127.0.0.1:{}", info.port).parse().unwrap()),
    };
    trt.block_on(phone.pair(&desk, &code.code)).unwrap();
    let phone_id = phone.device_id().to_b32();
    ev.wait("Paired (hub side)", || {}, |e| {
        matches!(e, EngineEvent::Hub(HubEvent::Paired { id, name }) if *id == phone_id && name == "Phone")
    });
    assert!(
        hub::hub_trusted_devices()
            .unwrap()
            .iter()
            .any(|d| d.id == phone_id)
    );

    let report = trt.block_on(phone.sync(&desk, &phone_store)).unwrap();
    assert!(report.uploaded_blobs > 0, "{report:?}");
    assert!(report.downloaded_blobs > 0, "{report:?}");
    ev.wait(
        "LibraryChanged (hub side)",
        || {},
        |e| matches!(e, EngineEvent::LibraryChanged),
    );
    let kits = library::library_list_kits().unwrap();
    assert_eq!(kits.len(), 2, "night-drive arrived on the hub: {kits:?}");
    assert_eq!(
        phone_lib.list_kits(&Default::default()).len(),
        2,
        "starter arrived on the phone"
    );

    settle(&mut ev);
    let ctl = trt.block_on(phone.controller_connect(&desk)).unwrap();
    ev.wait("RemoteControllerConnected", || {}, |e| {
        matches!(e, EngineEvent::Hub(HubEvent::RemoteControllerConnected { device, .. }) if *device == phone_id)
    });
    ctl.pad_down(pad.bank, pad.index, 127).unwrap();
    ev.wait(
        "remote PadDown → engine PadState Playing",
        pump,
        playing(pad),
    );
    ctl.pad_up(pad.bank, pad.index).unwrap();
    let stats = hub::hub_controller_stats().unwrap();
    assert_eq!(stats.len(), 1);
    assert_eq!(stats[0].device_id, phone_id);
    assert!(stats[0].accepted_events >= 1, "{stats:?}");
    trt.block_on(ctl.close()).unwrap();
    ev.wait("RemoteControllerDisconnected", pump, |e| {
        matches!(e, EngineEvent::Hub(HubEvent::RemoteControllerDisconnected { device }) if *device == phone_id)
    });

    // ------------------------------------------------ B: FFI is a client
    let desk2_lib = Arc::new(up_library::Library::open(tmp.join("desk2/library")).unwrap());
    let sample = desk2_lib
        .add_sample(&sine_wav(), "Sine", up_library::SampleOrigin::Import)
        .unwrap();
    let desk2_dir = tmp.join("desk2/hub");
    let desk2_id = HubClient::new(ClientConfig::new(&desk2_dir, "x"))
        .unwrap()
        .device_id();
    let sink = Arc::new(RecordingSink::default());
    let mut cfg = HubConfig::new(&desk2_dir, "Desk 2");
    cfg.bind_addr = "127.0.0.1".parse().unwrap();
    cfg.advertise = false;
    let server = trt
        .block_on(HubServer::start(
            cfg,
            Arc::new(LibraryHubStore::new(Arc::clone(&desk2_lib), desk2_id)),
            sink.clone(),
        ))
        .unwrap();

    hub::hub_set_device_name("FFI Phone".into()).unwrap();
    let peer = trt
        .block_on(hub::hub_probe(server.local_addr().to_string()))
        .unwrap();
    assert_eq!(peer.id, desk2_id.to_b32());
    assert_eq!(peer.name, "Desk 2");
    assert!(!peer.paired);
    let code = server.new_pairing_code();
    let wrong = if code.code == "000000" {
        "111111"
    } else {
        "000000"
    };
    let err = trt
        .block_on(hub::hub_pair(peer.id.clone(), wrong.into()))
        .unwrap_err();
    assert_eq!(err.code, ErrorCode::PermissionDenied);
    assert!(err.message.starts_with("[pairing_failed]"), "{err:?}");
    let dev = trt
        .block_on(hub::hub_pair(peer.id.clone(), code.code.clone()))
        .unwrap();
    assert_eq!(dev.id, peer.id);
    assert!(
        server
            .trusted_devices()
            .iter()
            .any(|d| d.name == "FFI Phone")
    );
    ev.wait(
        "Paired (client side)",
        || {},
        |e| matches!(e, EngineEvent::Hub(HubEvent::Paired { id, .. }) if *id == peer.id),
    );
    assert!(
        hub::hub_known_peers()
            .unwrap()
            .iter()
            .any(|p| p.id == peer.id && p.paired)
    );
    assert!(tmp.join("data/hub/peers.json").exists());

    let rep = trt.block_on(hub::hub_sync(peer.id.clone())).unwrap();
    assert!(rep.downloaded_blobs >= 1, "{rep:?}");
    assert!(rep.uploaded_blobs >= 1, "{rep:?}");
    assert!(rep.pulled >= 1 && rep.pushed >= 1, "{rep:?}");
    ev.wait(
        "SyncStarted",
        || {},
        |e| matches!(e, EngineEvent::Hub(HubEvent::SyncStarted { peer: p }) if *p == peer.id),
    );
    ev.wait("SyncProgress", || {}, |e| {
        matches!(e, EngineEvent::Hub(HubEvent::SyncProgress { done, total, .. }) if *total > 0 && done == total)
    });
    ev.wait(
        "SyncFinished",
        || {},
        |e| matches!(e, EngineEvent::Hub(HubEvent::SyncFinished { report, .. }) if report == &rep),
    );
    ev.wait(
        "LibraryChanged (client side)",
        || {},
        |e| matches!(e, EngineEvent::LibraryChanged),
    );
    assert!(
        library::library_list_samples()
            .unwrap()
            .iter()
            .any(|s| s.id == sample.id),
        "sample synced from the hub"
    );
    assert_eq!(
        desk2_lib.list_kits(&Default::default()).len(),
        2,
        "kits pushed to the hub"
    );

    // Controller: forwarded and silent locally.
    settle(&mut ev);
    let st = trt
        .block_on(hub::hub_controller_connect(peer.id.clone()))
        .unwrap();
    assert!(st.connected && !st.local_echo);
    assert_eq!(st.peer.as_deref(), Some(peer.id.as_str()));
    ev.wait("ControllerConnected", || {}, |e| {
        matches!(e, EngineEvent::Hub(HubEvent::ControllerConnected { peer: p }) if *p == peer.id)
    });
    engine::pad_down(pad.bank, pad.index, 1.0).unwrap();
    sink.wait_for(&format!("down {}/{} 127", pad.bank, pad.index));
    engine::pad_up(pad.bank, pad.index).unwrap();
    sink.wait_for(&format!("up {}/{}", pad.bank, pad.index));
    for _ in 0..20 {
        pump();
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(
        !ev.any(playing(pad)),
        "forwarded pad must not sound locally"
    );
    // Out-of-range pads are still rejected.
    assert_eq!(
        engine::pad_down(5, 0, 1.0).unwrap_err().code,
        ErrorCode::InvalidArgument
    );

    // Local echo: forwarded and played locally.
    hub::hub_controller_set_local_echo(true);
    assert!(hub::hub_controller_status().local_echo);
    engine::send(Command::PadDown { pad, velocity: 0.5 }).unwrap();
    sink.wait_for(&format!("down {}/{} 64", pad.bank, pad.index));
    ev.wait("local echo PadState Playing", pump, playing(pad));
    engine::pad_up(pad.bank, pad.index).unwrap();
    hub::hub_controller_set_local_echo(false);

    // Latency stats arrive with the background pings.
    let deadline = Instant::now() + Duration::from_secs(5);
    while hub::hub_controller_status()
        .latency
        .is_none_or(|l| l.pongs_received == 0)
    {
        assert!(Instant::now() < deadline, "no pong from the hub");
        std::thread::sleep(Duration::from_millis(20));
    }

    trt.block_on(hub::hub_controller_disconnect()).unwrap();
    assert!(!hub::hub_controller_status().connected);
    ev.wait(
        "ControllerDisconnected",
        || {},
        |e| matches!(e, EngineEvent::Hub(HubEvent::ControllerDisconnected)),
    );
    settle(&mut ev);
    let before = sink.0.lock().unwrap().len();
    engine::pad_down(pad.bank, pad.index, 1.0).unwrap();
    ev.wait("local playback after disconnect", pump, playing(pad));
    std::thread::sleep(Duration::from_millis(50));
    assert_eq!(sink.0.lock().unwrap().len(), before, "nothing forwarded");

    // Revoke on our side.
    assert!(hub::hub_revoke(peer.id.clone()).unwrap());
    assert!(
        !hub::hub_trusted_devices()
            .unwrap()
            .iter()
            .any(|d| d.id == peer.id)
    );

    trt.block_on(server.stop());
    trt.block_on(hub::hub_stop_server()).unwrap();
    ev.wait(
        "ServerStopped",
        || {},
        |e| matches!(e, EngineEvent::Hub(HubEvent::ServerStopped)),
    );
    assert!(hub::hub_server_info().unwrap().is_none());
    let _ = std::fs::remove_dir_all(&tmp);
}
