use std::time::Duration;
use up_core::{PadId, PadMode, PadPlayState, Quantize, SampleId};
use up_engine::*;
use up_rt::alloc_check::{CountingAlloc, count_allocs};

#[global_allocator]
static A: CountingAlloc = CountingAlloc;

const SR: u32 = 48_000;
const T: Duration = Duration::from_secs(2);

fn engine(backend: GraphBackend) -> (EngineHandle, AudioProcessor) {
    Engine::new(EngineConfig {
        sample_rate: SR,
        graph_backend: backend,
        ..Default::default()
    })
    .unwrap()
}

fn sine(id: &str, secs: f64, hz: f64, amp: f32) -> SampleData {
    let n = (SR as f64 * secs) as usize;
    let data = (0..n)
        .map(|i| amp * (2.0 * std::f64::consts::PI * hz * i as f64 / SR as f64).sin() as f32)
        .collect();
    SampleData::new(SampleId::new(id), id, SR, vec![data])
}

fn assign(h: &EngineHandle, pad: PadId, id: &str, mode: PadMode, choke: Option<u8>) {
    h.send(Command::SetPadParams {
        pad,
        params: PadParams {
            mode,
            choke_group: choke,
            sample: Some(SampleId::new(id)),
            ..Default::default()
        },
    })
    .unwrap();
}

fn a(i: u8) -> PadId {
    PadId { bank: 0, index: i }
}

fn down(at: f64, pad: PadId) -> TimedCommand {
    TimedCommand {
        at_secs: at,
        cmd: Command::PadDown { pad, velocity: 1.0 },
    }
}

#[test]
fn offline_render_is_sample_accurate_golden() {
    let (h, mut p) = engine(GraphBackend::Serial);
    let s = h.register_sample(sine("s", 0.5, 440.0, 0.5));
    assign(&h, a(0), "s", PadMode::OneShot, None);
    let script = RenderScript {
        duration_secs: 1.0,
        events: vec![down(0.1, a(0))],
    };
    let out = render_offline(&h, &mut p, &script).unwrap();
    assert_eq!(out.len(), SR as usize * 2);
    let start = 4800;
    assert!(
        out[..start * 2].iter().all(|x| *x == 0.0),
        "silent before the event"
    );
    for k in 0..s.frames() {
        let expect = s.left()[k];
        assert!((out[(start + k) * 2] - expect).abs() < 1e-6, "frame {k}");
        assert!(
            (out[(start + k) * 2 + 1] - expect).abs() < 1e-6,
            "frame {k} R"
        );
    }
    assert!(
        out[(start + s.frames()) * 2..].iter().all(|x| *x == 0.0),
        "silent after the one-shot"
    );
}

#[test]
fn firewheel_backend_matches_serial_golden() {
    let render = |backend| {
        let (h, mut p) = engine(backend);
        h.register_sample(sine("s", 0.3, 220.0, 0.4));
        h.register_sample(sine("l", 0.25, 330.0, 0.3));
        assign(&h, a(0), "s", PadMode::OneShot, Some(1));
        assign(&h, a(1), "l", PadMode::Loop, Some(1));
        let script = RenderScript {
            duration_secs: 1.5,
            events: vec![
                down(0.05, a(0)),
                down(0.2, a(1)),
                down(0.9, a(0)),
                TimedCommand {
                    at_secs: 1.2,
                    cmd: Command::StopAll,
                },
            ],
        };
        render_offline(&h, &mut p, &script).unwrap()
    };
    let fw = render(GraphBackend::Firewheel);
    let se = render(GraphBackend::Serial);
    let max = fw
        .iter()
        .zip(&se)
        .fold(0.0f32, |m, (x, y)| m.max((x - y).abs()));
    assert!(max < 1e-5, "max diff {max}");
    assert!(se.iter().any(|x| x.abs() > 0.1));
}

#[test]
fn quantized_loop_starts_on_bar_line_offline() {
    let (h, mut p) = engine(GraphBackend::Serial);
    h.register_sample(sine("l", 0.5, 200.0, 0.25));
    assign(&h, a(0), "l", PadMode::Loop, None);
    assign(&h, a(1), "l", PadMode::Loop, None);
    h.send(Command::SetQuantize { q: Quantize::Bar }).unwrap();
    // 120 bpm → bar = 2 s. Pad 0 starts the grid at 0.1 s, pad 1 pressed at
    // 0.7 s must start at 2.1 s.
    let script = RenderScript {
        duration_secs: 2.5,
        events: vec![down(0.1, a(0)), down(0.7, a(1))],
    };
    let out = render_offline(&h, &mut p, &script).unwrap();
    // Loop 0 alone between 0.1 and 2.1 s has |x| ≤ 0.25; both together → up to 0.5.
    let frame = |t: f64| (t * SR as f64) as usize;
    let peak = |from: f64, to: f64| {
        out[frame(from) * 2..frame(to) * 2]
            .iter()
            .fold(0.0f32, |m, x| m.max(x.abs()))
    };
    assert!(peak(0.2, 2.09) <= 0.2501);
    assert!(peak(2.11, 2.4) > 0.4, "second loop joined on the bar line");
    // Sample-exact: both loops in phase from 2.1 s → output = 2× loop 0.
    let k = frame(2.1) + 10;
    let solo = out[(k - frame(0.5) * 4) * 2]; // same phase 4 loop lengths earlier
    assert!((out[k * 2] - 2.0 * solo).abs() < 1e-4);
}

#[test]
fn events_and_snapshot() {
    let (h, mut p) = engine(GraphBackend::Serial);
    let rx = h.subscribe();
    h.register_sample(sine("s", 0.2, 440.0, 0.5));
    assign(&h, a(3), "s", PadMode::OneShot, None);
    h.set_kit(Some(KitSummary {
        name: "Test".into(),
        pad_count: 1,
        ..Default::default()
    }));
    h.flush(T).unwrap();
    h.pad_down(a(3), 1.0).unwrap();
    let mut buf = vec![0.0f32; 1024];
    p.process(&mut buf, 2);
    h.flush(T).unwrap();
    let snap = h.snapshot();
    assert_eq!(snap.pads[3].state, PadPlayState::Playing);
    assert_eq!(snap.pads[3].params.sample, Some(SampleId::new("s")));
    assert!((snap.pads[3].sample_secs - 0.2).abs() < 1e-6);
    assert_eq!(snap.kit.as_ref().unwrap().name, "Test");
    let evs: Vec<EngineEvent> = rx.try_iter().collect();
    assert!(
        evs.iter()
            .any(|e| matches!(e, EngineEvent::KitLoaded { .. }))
    );
    assert!(evs.contains(&EngineEvent::PadState {
        pad: a(3),
        state: PadPlayState::Playing
    }));
    // Meters arrive at ~60 Hz.
    std::thread::sleep(Duration::from_millis(60));
    let has_meters = rx
        .try_iter()
        .any(|e| matches!(e, EngineEvent::Meters { pad_levels, .. } if pad_levels[3] > 0.1));
    assert!(has_meters);
}

#[test]
fn invalid_commands_are_rejected() {
    let (h, _p) = engine(GraphBackend::Serial);
    let bad = PadId { bank: 2, index: 0 };
    assert_eq!(
        h.pad_down(bad, 1.0).unwrap_err().code,
        ErrorCode::InvalidArgument
    );
    let err = h
        .send(Command::SetPadParams {
            pad: a(0),
            params: PadParams {
                sample: Some(SampleId::new("missing")),
                ..Default::default()
            },
        })
        .unwrap_err();
    assert_eq!(err.code, ErrorCode::NotFound);
    assert!(h.send(Command::SetTempo { bpm: f64::NAN }).is_err());
}

#[test]
fn recording_captures_master_output() {
    let (h, mut p) = engine(GraphBackend::Serial);
    h.register_sample(sine("s", 1.0, 440.0, 0.5));
    assign(&h, a(0), "s", PadMode::OneShot, None);
    let script = RenderScript {
        duration_secs: 0.6,
        events: vec![
            TimedCommand {
                at_secs: 0.0,
                cmd: Command::StartRecording,
            },
            down(0.1, a(0)),
            TimedCommand {
                at_secs: 0.5,
                cmd: Command::StopRecording,
            },
        ],
    };
    let rx = h.subscribe();
    h.flush(T).unwrap();
    render_offline(&h, &mut p, &script).unwrap();
    // Let the control thread finalise the take.
    let mut take = None;
    for _ in 0..100 {
        h.flush(T).unwrap();
        if let Some(t) = h.take_last_take() {
            take = Some(t);
            break;
        }
        std::thread::sleep(Duration::from_millis(5));
    }
    let take = take.expect("take finalised");
    assert_eq!(take.audio.frames(), 24_000);
    assert!((take.duration_secs - 0.5).abs() < 1e-9);
    assert!(take.audio.peak() > 0.4);
    assert_eq!(take.waveform.len(), 128);
    let states: Vec<RecorderState> = rx
        .try_iter()
        .filter_map(|e| match e {
            EngineEvent::Recorder { state, .. } => Some(state),
            _ => None,
        })
        .collect();
    assert_eq!(states.first(), Some(&RecorderState::Recording));
    assert_eq!(states.last(), Some(&RecorderState::Idle));
}

#[test]
fn audio_processor_is_allocation_free() {
    for backend in [GraphBackend::Serial, GraphBackend::Firewheel] {
        let (h, mut p) = engine(backend);
        h.register_sample(sine("s", 0.05, 440.0, 0.5));
        h.register_sample(sine("l", 0.02, 440.0, 0.5));
        for i in 0..12 {
            let mode = [PadMode::OneShot, PadMode::Loop, PadMode::Gate][i % 3];
            assign(
                &h,
                a(i as u8),
                if i % 2 == 0 { "s" } else { "l" },
                mode,
                Some((i % 3) as u8),
            );
        }
        h.send(Command::SetQuantize { q: Quantize::Beat }).unwrap();
        let mut buf = vec![0.0f32; 256 * 2];
        let mut buf6 = vec![0.0f32; 256 * 6];
        for _ in 0..8 {
            p.process(&mut buf, 2);
        }
        let ((), n) = count_allocs(|| {
            for i in 0..600u32 {
                if i % 5 == 0 {
                    h.pad_down(a((i % 12) as u8), 0.9).unwrap();
                }
                if i % 9 == 0 {
                    h.pad_up(a((i % 12) as u8)).unwrap();
                }
                if i == 100 {
                    h.send(Command::StartRecording).unwrap();
                }
                if i == 400 {
                    h.send(Command::StopRecording).unwrap();
                }
                if i == 500 {
                    h.send(Command::StopAll).unwrap();
                }
                if i % 2 == 0 {
                    p.process(&mut buf, 2);
                } else {
                    p.process(&mut buf6, 6);
                }
            }
        });
        assert_eq!(
            n, 0,
            "{backend:?}: audio path performed {n} heap operations"
        );
    }
}

#[test]
fn render_script_from_json() {
    let (h, mut p) = engine(GraphBackend::Serial);
    h.register_sample(sine("s", 0.1, 440.0, 0.5));
    assign(&h, a(0), "s", PadMode::OneShot, None);
    let script: RenderScript = serde_json::from_str(
        r#"{"duration_secs":0.3,"events":[{"at_secs":0.0,"cmd":{"PadDown":{"pad":{"bank":0,"index":0},"velocity":1.0}}}]}"#,
    )
    .unwrap();
    let out = render_offline(&h, &mut p, &script).unwrap();
    assert!(out.iter().any(|x| x.abs() > 0.4));
}

#[test]
fn transport_clock_tracks_song_time_with_speed() {
    let (h, mut p) = engine(GraphBackend::Serial);
    h.send(Command::SetSpeed { ratio: 0.5 }).unwrap();
    h.send(Command::Transport(TransportCmd::Play)).unwrap();
    let mut buf = vec![0.0f32; 480 * 2];
    for _ in 0..100 {
        p.process(&mut buf, 2); // 1 s of audio
    }
    let c = h.transport_clock();
    assert!(c.playing);
    assert_eq!(c.speed, 0.5);
    // 1 s at half speed = 0.5 song seconds (plus ≤ a few ms extrapolation).
    assert!((c.song_secs - 0.5).abs() < 0.02, "{}", c.song_secs);
    h.send(Command::Transport(TransportCmd::Stop)).unwrap();
    p.process(&mut buf, 2);
    let c = h.transport_clock();
    assert!(!c.playing);
    assert_eq!(c.song_secs, 0.0);
}
