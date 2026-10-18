//! Exercises the FFI functions from Rust (no Dart, no audio device):
//! init → import example kits → list → load → snapshot → waveform →
//! tutorial → save edited kit → hub state.

use std::path::PathBuf;
use std::time::Duration;
use up_ffi::api::{engine, hub, library, tracks, types::*};

fn repo() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

#[test]
fn library_flow_through_ffi() {
    let tmp = std::env::temp_dir().join(format!("up-ffi-test-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    let info = engine::init(AppDirs {
        data_dir: tmp.join("data").to_string_lossy().into(),
        cache_dir: tmp.join("cache").to_string_lossy().into(),
    })
    .unwrap();
    assert_eq!(info.sample_rate, 48_000);
    // Idempotent.
    assert_eq!(
        engine::init(AppDirs {
            data_dir: "/nonexistent".into(),
            cache_dir: String::new()
        })
        .unwrap()
        .data_dir,
        info.data_dir
    );

    let rep = library::library_import(
        repo()
            .join("content/kits/ultrapads-starter.upkit")
            .to_string_lossy()
            .into(),
    )
    .unwrap();
    assert_eq!(rep.kind, "upkit");
    assert_eq!(rep.kits.len(), 1);
    library::library_import(
        repo()
            .join("content/kits/ultrapads-night-drive.upkit")
            .to_string_lossy()
            .into(),
    )
    .unwrap();
    let kits = library::library_list_kits().unwrap();
    assert_eq!(kits.len(), 2);
    let search =
        library::library_search_kits(Some("starter".into()), None, false, KitSort::Name, None)
            .unwrap();
    assert_eq!(search.len(), 1);

    let kit = &search[0];
    let loaded = library::library_load_kit(kit.id.clone()).unwrap();
    assert!(loaded.pad_count > 0);
    let snap = engine::snapshot().unwrap();
    let assigned: Vec<_> = snap
        .pads
        .iter()
        .filter(|p| p.params.sample.is_some())
        .collect();
    assert_eq!(assigned.len() as u32, loaded.pad_count);
    assert!(
        assigned.iter().all(|p| p.sample_secs > 0.0),
        "samples registered with the engine"
    );
    let sid = assigned[0].params.sample.clone().unwrap();
    let w = engine::sample_waveform(sid, 64).unwrap();
    assert_eq!(w.len(), 64);
    assert!(w.iter().any(|v| *v > 0.01));

    // Hot path through the FFI.
    engine::pad_down(assigned[0].pad.bank, assigned[0].pad.index, 1.0).unwrap();
    engine::pad_up(assigned[0].pad.bank, assigned[0].pad.index).unwrap();
    assert_eq!(
        engine::pad_down(up_core::BANK_COUNT as u8, 0, 1.0)
            .unwrap_err()
            .code,
        ErrorCode::InvalidArgument
    );
    engine::send(Command::SetQuantize {
        q: Quantize::TwoBars,
    })
    .unwrap();
    let clock = engine::transport_clock().unwrap();
    assert!(!clock.playing);
    assert_eq!(
        engine::tutorial_judge(1.0, 1.05, 1.0, 80.0, 600.0),
        Judgement::Perfect
    );

    // Tutorial from the library (starter kit ships one; any kit → Ok).
    let _ = engine::tutorial_get(kit.id.clone()).unwrap();

    // Edit and save the kit through the JSON model.
    let json = library::library_current_kit_json().unwrap().unwrap();
    let mut doc = up_model::KitDoc::from_json(&json).unwrap();
    doc.name = "Starter (edited)".into();
    let saved = library::library_save_kit(doc.to_json().unwrap()).unwrap();
    assert_eq!(saved.name, "Starter (edited)");

    let dir = tmp.join("export");
    let out =
        library::library_export_kit(kit.id.clone(), dir.to_string_lossy().into(), "sfz".into())
            .unwrap();
    assert!(std::path::Path::new(&out).exists());

    assert!(tracks::tracks_list().unwrap().is_empty());
    // Hub: no server until hub_start_server (full flow in ffi_hub.rs).
    assert!(hub::hub_server_info().unwrap().is_none());
    std::thread::sleep(Duration::from_millis(20));
    let _ = std::fs::remove_dir_all(&tmp);
}

/// Local-only check with the private asset pack (never committed):
/// `cargo test -p up_ffi -- --ignored private_assets`
#[test]
#[ignore = "needs private-assets/compat-ios (not in the repo)"]
fn private_assets_compat_ios() {
    let src = repo().join("private-assets/compat-ios");
    if !src.exists() {
        return;
    }
    let tmp = std::env::temp_dir().join(format!("up-ffi-private-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    engine::init(AppDirs {
        data_dir: tmp.join("data").to_string_lossy().into(),
        cache_dir: String::new(),
    })
    .unwrap();
    let rep = library::library_import(src.to_string_lossy().into()).unwrap();
    assert!(!rep.kits.is_empty());
    let kit = &rep.kits[0];
    let loaded = library::library_load_kit(kit.id.clone()).unwrap();
    let chart = engine::tutorial_get(kit.id.clone()).unwrap();
    eprintln!(
        "imported {} kits; loaded {:?} ({} pads); tutorial events: {}",
        rep.kits.len(),
        loaded.name,
        loaded.pad_count,
        chart.map(|c| c.events.len()).unwrap_or(0)
    );
    assert!(loaded.pad_count > 0);
    let _ = std::fs::remove_dir_all(&tmp);
}
