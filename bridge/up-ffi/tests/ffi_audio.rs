//! FFI smoke test for "press a pad → sound": bundled-kit import from bytes
//! (`library_import_bytes`), load, `pad_down`, and `Meters` events with a
//! non-zero level. Uses the real output device when one is available
//! (`audio_start`); otherwise renders with the parked processor.
//!
//! `UP_REQUIRE_AUDIO=1 cargo test -p up_ffi --test ffi_audio -- --nocapture`
//! fails instead of falling back when no audio device can be opened.

use std::time::{Duration, Instant};
use up_ffi::api::{engine, library, types::*};

fn repo() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

#[test]
fn pad_press_produces_meter_levels() {
    let tmp = std::env::temp_dir().join(format!("up-ffi-audio-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&tmp);
    engine::init(AppDirs {
        data_dir: tmp.join("data").to_string_lossy().into(),
        cache_dir: tmp.join("cache").to_string_lossy().into(),
    })
    .unwrap();

    // Bundled CC0 kit, imported from memory like the app's first run.
    let bytes = std::fs::read(repo().join("content/kits/ultrapads-starter.upkit")).unwrap();
    let rep = library::library_import_bytes("ultrapads-starter.upkit".into(), bytes).unwrap();
    assert_eq!(rep.kind, "upkit");
    let kit = rep.kits[0].id.clone();

    let audio = engine::audio_start(AudioConfig {
        buffer_frames: None,
        sample_rate: None,
        output_device: None,
    });
    let real_device = match &audio {
        Ok(st) => {
            eprintln!(
                "audio: {} / {} @ {} Hz, {} ch, buffer {:?}, latency {:?} ms",
                st.host,
                st.device,
                st.sample_rate,
                st.channels,
                st.buffer_frames,
                st.output_latency_ms
            );
            st.running
        }
        Err(e) => {
            assert!(
                std::env::var("UP_REQUIRE_AUDIO").is_err(),
                "UP_REQUIRE_AUDIO set but audio_start failed: {e:?}"
            );
            eprintln!("audio: no output device ({e:?}); rendering offline");
            false
        }
    };
    if real_device {
        assert!(engine::audio_status().unwrap().running);
    }

    library::library_load_kit(kit).unwrap();
    let snap = engine::snapshot().unwrap();
    let pad = snap
        .pads
        .iter()
        .find(|p| p.params.sample.is_some() && p.params.mode == PadMode::OneShot)
        .expect("one-shot pad")
        .pad;

    let rx = up_ffi::testing::event_receiver().unwrap();
    engine::pad_down(pad.bank, pad.index, 1.0).unwrap();
    let deadline = Instant::now() + Duration::from_secs(3);
    let mut peak = 0.0f32;
    let mut pad_level = 0.0f32;
    while Instant::now() < deadline && peak <= 0.0 {
        if !real_device {
            up_ffi::testing::pump_audio(4).unwrap();
        }
        if let Ok(EngineEvent::Meters {
            master_peak,
            pad_levels,
            ..
        }) = rx.recv_timeout(Duration::from_millis(50))
        {
            peak = peak.max(master_peak[0].max(master_peak[1]));
            pad_level = pad_level.max(pad_levels[pad.bank as usize * 12 + pad.index as usize]);
        }
    }
    engine::pad_up(pad.bank, pad.index).unwrap();
    eprintln!(
        "pad {pad:?}: master peak {peak:.3}, pad level {pad_level:.3} (real device: {real_device})"
    );
    assert!(peak > 0.0, "Meters event with a non-zero master level");
    assert!(pad_level > 0.0, "the pressed pad's level is non-zero");

    // Speed + pitch reach the engine.
    engine::send(Command::SetSpeed { ratio: 0.7 }).unwrap();
    let mut params = snap
        .pads
        .iter()
        .find(|p| p.pad == pad)
        .unwrap()
        .params
        .clone();
    params.pitch = 5.0;
    engine::send(Command::SetPadParams { pad, params }).unwrap();
    std::thread::sleep(Duration::from_millis(50));
    let snap = engine::snapshot().unwrap();
    assert!((snap.transport.speed - 0.7).abs() < 1e-9);
    assert_eq!(
        snap.pads
            .iter()
            .find(|p| p.pad == pad)
            .unwrap()
            .params
            .pitch,
        5.0
    );

    // Audition without occupying a pad.
    let sample = snap
        .pads
        .iter()
        .find(|p| p.pad == pad)
        .unwrap()
        .params
        .sample
        .clone()
        .unwrap();
    engine::sample_preview(sample, 0, Some(4800)).unwrap();
    engine::sample_preview_stop().unwrap();

    if real_device {
        engine::audio_stop().unwrap();
    }
    let _ = std::fs::remove_dir_all(&tmp);
}
