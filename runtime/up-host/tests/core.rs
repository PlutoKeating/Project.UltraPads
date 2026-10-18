use std::path::PathBuf;
use std::time::Duration;
use up_codec::{AudioBuffer, WavFormat, encode_wav};
use up_core::{PadId, PadMode, PadPlayState};
use up_engine::{
    Command, EngineConfig, EngineEvent, GraphBackend, RenderScript, TimedCommand, render_offline,
};
use up_host::{AppCore, AppDirs, load_folder_kit};

fn tmp(name: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("up-host-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn write_tone(path: &std::path::Path, rate: u32, secs: f32, hz: f32) {
    let n = (rate as f32 * secs) as usize;
    let data = (0..n)
        .map(|i| (i as f32 / rate as f32 * hz * std::f32::consts::TAU).sin() * 0.5)
        .collect();
    let bytes = encode_wav(&AudioBuffer::new(rate, 1, data), WavFormat::Pcm16).unwrap();
    std::fs::write(path, bytes).unwrap();
}

#[test]
fn compat_style_folder_kit() {
    let dir = tmp("sp");
    let sounds = dir.join("Sunset").join("Sounds");
    std::fs::create_dir_all(&sounds).unwrap();
    write_tone(&sounds.join("pad1_sunset.wav"), 44_100, 0.2, 440.0);
    write_tone(&sounds.join("pad2_sunset.wav"), 44_100, 0.2, 550.0);
    write_tone(&sounds.join("pad13_sunset.wav"), 44_100, 0.2, 660.0);
    std::fs::write(
        sounds.join("Sunset.txt"),
        r#"{"behaviour":{"pad1":200,"pad2":100,"pad13":300},"colors":{"pad1":"amarelo","pad2":"azul_loop"},"groups":{"pad1":1,"pad2":2},"preset":"sunset"}"#,
    )
    .unwrap();
    std::fs::write(sounds.join("tutorial.json"), r#"[{"time":0.0,"pad":100,"color":"page","state":1},{"time":1.5,"pad":2,"color":"blue","state":0}]"#).unwrap();
    let kit = load_folder_kit(&dir.join("Sunset"), 48_000).unwrap();
    assert_eq!(kit.doc.name, "Sunset");
    assert_eq!(kit.samples.len(), 3);
    let p0 = kit.doc.pad(PadId { bank: 0, index: 0 }).unwrap();
    assert_eq!(p0.mode, PadMode::OneShot);
    assert_eq!(p0.choke_group, Some(1));
    assert_eq!(p0.color, up_core::ColorRole::Orange);
    assert_eq!(
        kit.doc.pad(PadId { bank: 0, index: 1 }).unwrap().mode,
        PadMode::Loop
    );
    assert_eq!(
        kit.doc.pad(PadId { bank: 1, index: 0 }).unwrap().mode,
        PadMode::Gate
    );
    let t = kit.doc.tutorial.as_ref().unwrap();
    assert_eq!(t.events.len(), 2);
    assert!(kit.doc.summary().has_tutorial);
    assert!(kit.samples.iter().all(|s| s.sample_rate == 48_000));
    assert!((kit.samples[0].duration_secs() - 0.2).abs() < 0.01);
}

#[test]
fn app_core_end_to_end_offline() {
    let dir = tmp("core");
    let kit = dir.join("kit");
    std::fs::create_dir_all(&kit).unwrap();
    write_tone(&kit.join("01 kick.wav"), 48_000, 0.3, 100.0);
    write_tone(&kit.join("02 loop.wav"), 48_000, 0.5, 200.0);
    let core = AppCore::new(
        AppDirs {
            data_dir: dir.join("data").to_string_lossy().into(),
            cache_dir: dir.join("cache").to_string_lossy().into(),
        },
        EngineConfig {
            graph_backend: GraphBackend::Serial,
            ..Default::default()
        },
    )
    .unwrap();
    let rx = core.subscribe();
    let summary = core.load_kit_folder(&kit).unwrap();
    assert_eq!(summary.pad_count, 2);
    let handle = core.handle().unwrap();
    handle.flush(Duration::from_secs(2)).unwrap();
    let snap = core.snapshot().unwrap();
    assert_eq!(
        snap.pads[1].params.mode,
        PadMode::Loop,
        "name heuristic: 'loop' → Loop"
    );
    assert!(
        core.sample_waveform(snap.pads[0].params.sample.as_ref().unwrap(), 32)
            .unwrap()
            .iter()
            .any(|v| *v > 0.3)
    );

    // Offline render through the parked processor, with a recording.
    let mut p = core.take_processor().unwrap().unwrap();
    let script = RenderScript {
        duration_secs: 1.0,
        events: vec![
            TimedCommand {
                at_secs: 0.0,
                cmd: Command::StartRecording,
            },
            TimedCommand {
                at_secs: 0.1,
                cmd: Command::PadDown {
                    pad: PadId { bank: 0, index: 0 },
                    velocity: 1.0,
                },
            },
            TimedCommand {
                at_secs: 0.9,
                cmd: Command::StopRecording,
            },
        ],
    };
    let out = render_offline(&handle, &mut p, &script).unwrap();
    assert!(out.iter().any(|x| x.abs() > 0.3));
    core.return_processor(p).unwrap();

    // The take handler stores a track and broadcasts TrackSaved.
    let mut saved = None;
    for _ in 0..200 {
        handle.flush(Duration::from_secs(2)).unwrap();
        if let Some(t) = rx.try_iter().find_map(|e| match e {
            EngineEvent::TrackSaved { track } => Some(track),
            _ => None,
        }) {
            saved = Some(t);
            break;
        }
        std::thread::sleep(Duration::from_millis(10));
    }
    let track = saved.expect("track saved");
    assert!(
        (track.duration_secs - 0.9).abs() < 1e-6,
        "{}",
        track.duration_secs
    );
    let list = core.tracks_list().unwrap();
    assert_eq!(list.len(), 1);
    core.track_export(&track.id, &dir.join("out.wav"), "wav")
        .unwrap();
    core.track_play(&track.id).unwrap();
    core.track_delete(&track.id).unwrap();
    assert!(core.tracks_list().unwrap().is_empty());
    assert_eq!(core.tutorial(&summary.id).unwrap(), None);
    let states: Vec<_> = rx.try_iter().collect();
    let _ = states;
    assert_eq!(core.snapshot().unwrap().pads[0].state, PadPlayState::Idle);
}
