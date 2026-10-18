use std::sync::Arc;
use up_core::{PadMode, PadPlayState, Quantize, SampleId};
use up_rt::alloc_check::{CountingAlloc, count_allocs};
use up_rt::retire::{Collector, retire_channel};
use up_sampler::*;
use up_transport::Transport;

#[global_allocator]
static A: CountingAlloc = CountingAlloc;

const SR: u32 = 48_000;
const BLOCK: usize = 64;

struct Rig {
    s: Sampler,
    t: Transport,
    ev: Vec<SamplerEvent>,
    bufs: Vec<Vec<f32>>,
    collector: Collector<SampleArc>,
}

fn dc_sample(frames: usize, value: f32) -> SampleArc {
    Arc::new(SampleData::new(
        SampleId::new("dc"),
        "dc",
        SR,
        vec![vec![value; frames]],
    ))
}

impl Rig {
    fn new(cfg: SamplerConfig) -> Self {
        let (r, c) = retire_channel(256);
        let ev = Vec::with_capacity(4096);
        Self {
            s: Sampler::new(cfg, r),
            t: Transport::new(SR, 120.0),
            ev,
            bufs: vec![vec![0.0; BLOCK]; outputs_needed()],
            collector: c,
        }
    }

    fn default() -> Self {
        Self::new(SamplerConfig {
            sample_rate: SR,
            ..Default::default()
        })
    }

    fn set(&mut self, pad: u8, mode: PadMode, choke: Option<u8>, sample: SampleArc) {
        let params = RtPadParams {
            mode,
            choke_group: choke,
            ..Default::default()
        };
        self.s.handle(
            SamplerCmd::SetPad {
                pad,
                params,
                sample: SampleUpdate::Set(sample),
            },
            &mut self.t,
            &mut self.ev,
        );
    }

    fn cmd(&mut self, c: SamplerCmd) {
        self.s.handle(c, &mut self.t, &mut self.ev);
    }

    fn down(&mut self, pad: u8) {
        self.cmd(SamplerCmd::PadDown { pad, velocity: 1.0 });
    }

    /// Process one block (allocation-free harness).
    fn block(&mut self) {
        const N: usize = outputs_needed();
        let mut it = self.bufs.iter_mut();
        let mut outs: [&mut [f32]; N] = std::array::from_fn(|_| it.next().unwrap().as_mut_slice());
        self.s.process(&mut self.t, &mut outs, BLOCK, &mut self.ev);
        self.t.advance(BLOCK as u32);
    }

    fn blocks(&mut self, n: usize) {
        for _ in 0..n {
            self.block();
        }
    }

    fn state(&self, pad: usize) -> PadPlayState {
        self.s.pad_state(pad)
    }

    fn pad_out(&self, pad: usize) -> &[f32] {
        &self.bufs[pad * 2]
    }
}

#[test]
fn one_shot_plays_to_end_then_idle() {
    let mut r = Rig::default();
    r.set(0, PadMode::OneShot, None, dc_sample(BLOCK * 3, 0.5));
    r.down(0);
    assert_eq!(r.state(0), PadPlayState::Playing);
    r.block();
    assert!(
        r.pad_out(0).iter().all(|s| (*s - 0.5).abs() < 1e-6),
        "unity gain at centre pan, velocity 1"
    );
    r.blocks(3);
    assert_eq!(r.state(0), PadPlayState::Idle);
    assert!(r.pad_out(0).iter().all(|s| *s == 0.0));
    assert!(
        r.collector.collect() >= 1,
        "finished voice's Arc retired to control thread"
    );
}

#[test]
fn one_shot_retrigger_restarts_with_crossfade() {
    let mut r = Rig::default();
    r.set(0, PadMode::OneShot, None, dc_sample(SR as usize, 0.5));
    r.down(0);
    r.blocks(2);
    r.down(0);
    r.block();
    // Old voice fading + new voice → sum stays bounded by 2× and ≥ 1×.
    let first = r.pad_out(0)[0];
    assert!(first > 0.5 && first <= 1.0 + 1e-6, "{first}");
    r.blocks(10);
    assert!(
        (r.pad_out(0)[BLOCK - 1] - 0.5).abs() < 1e-6,
        "only one voice left"
    );
    assert_eq!(r.state(0), PadPlayState::Playing);
}

#[test]
fn gate_stops_on_release_with_fade() {
    let mut r = Rig::default();
    r.set(1, PadMode::Gate, None, dc_sample(SR as usize, 0.5));
    r.down(1);
    r.block();
    r.cmd(SamplerCmd::PadUp { pad: 1 });
    assert_eq!(r.state(1), PadPlayState::Stopping);
    r.block();
    let out = r.pad_out(1);
    assert!(out[0] > out[BLOCK - 1], "fading out");
    r.blocks(10); // 5 ms = 240 frames < 11 blocks
    assert_eq!(r.state(1), PadPlayState::Idle);
}

#[test]
fn loop_toggles_without_quantize() {
    let mut r = Rig::default();
    r.set(2, PadMode::Loop, None, dc_sample(100, 0.25));
    r.down(2);
    assert_eq!(r.state(2), PadPlayState::Playing);
    r.blocks(20); // far beyond sample length: still looping
    assert_eq!(r.state(2), PadPlayState::Playing);
    assert!(r.pad_out(2).iter().all(|s| (*s - 0.25).abs() < 1e-6));
    r.down(2);
    assert_eq!(r.state(2), PadPlayState::Stopping);
    r.blocks(10);
    assert_eq!(r.state(2), PadPlayState::Idle);
}

#[test]
fn quantized_loop_state_machine() {
    let mut r = Rig::default();
    r.cmd(SamplerCmd::SetQuantize(Quantize::Bar));
    r.set(0, PadMode::Loop, None, dc_sample(SR as usize, 0.5));
    r.set(1, PadMode::Loop, None, dc_sample(SR as usize, 0.5));

    // First loop: starts the transport at beat 0 → plays immediately.
    r.down(0);
    assert_eq!(r.state(0), PadPlayState::Playing);
    assert!(r.t.is_playing());
    r.block();

    // Second loop mid-bar → Pending until the next bar (beat 4).
    r.down(1);
    assert_eq!(r.state(1), PadPlayState::Pending);
    // 120 bpm @ 48k: bar = 96000 frames = 1500 blocks of 64.
    let bar_frames = 96_000usize;
    let mut started_at = None;
    for b in 1..2000 {
        r.block();
        if r.state(1) == PadPlayState::Playing && started_at.is_none() {
            started_at = Some(b);
            // Sample-accurate start: the bar boundary is inside this block.
            let out = r.pad_out(1);
            let first_nz = out.iter().position(|s| *s != 0.0).unwrap();
            let abs = b * BLOCK + first_nz;
            assert_eq!(abs, bar_frames, "loop must start exactly on the bar line");
            break;
        }
    }
    assert!(started_at.is_some());

    // Press while playing → Stopping (waits for the next bar), press again cancels.
    r.down(1);
    assert_eq!(r.state(1), PadPlayState::Stopping);
    r.down(1);
    assert_eq!(r.state(1), PadPlayState::Playing);

    // Pending can be cancelled.
    r.set(2, PadMode::Loop, None, dc_sample(SR as usize, 0.5));
    r.down(2);
    assert_eq!(r.state(2), PadPlayState::Pending);
    r.down(2);
    assert_eq!(r.state(2), PadPlayState::Idle);

    // Stop at boundary then idle.
    r.down(0);
    assert_eq!(r.state(0), PadPlayState::Stopping);
    r.blocks(1600);
    assert_eq!(r.state(0), PadPlayState::Idle);
}

#[test]
fn transport_auto_stops_after_last_quantized_loop() {
    let mut r = Rig::default();
    r.cmd(SamplerCmd::SetQuantize(Quantize::Beat));
    r.set(0, PadMode::Loop, None, dc_sample(1000, 0.5));
    r.down(0);
    assert!(r.t.is_playing());
    r.blocks(10);
    r.cmd(SamplerCmd::StopAll);
    r.blocks(10);
    assert!(!r.t.is_playing());
    assert_eq!(r.t.beat(), 0.0);
}

#[test]
fn choke_group_stops_other_pads() {
    let mut r = Rig::default();
    r.set(0, PadMode::Loop, Some(1), dc_sample(SR as usize, 0.5));
    r.set(1, PadMode::OneShot, Some(1), dc_sample(SR as usize, 0.5));
    r.set(2, PadMode::OneShot, Some(2), dc_sample(SR as usize, 0.5));
    r.down(0);
    r.down(2);
    r.block();
    r.down(1);
    assert_eq!(
        r.state(0),
        PadPlayState::Stopping,
        "loop in same group choked"
    );
    assert_eq!(r.state(1), PadPlayState::Playing);
    assert_eq!(r.state(2), PadPlayState::Playing, "other group unaffected");
    r.blocks(10);
    assert_eq!(r.state(0), PadPlayState::Idle);
    assert!(r.pad_out(0).iter().all(|s| *s == 0.0));
}

#[test]
fn asymmetric_choke_open_closed_hihat() {
    let mut r = Rig::default();
    // Closed hat (pad 0) is in group 3; open hat (pad 1) is in group 4 but
    // choked by group 3 — closed chokes open, not vice versa.
    let closed = RtPadParams {
        choke_group: Some(3),
        ..Default::default()
    };
    let open = RtPadParams {
        choke_group: Some(4),
        choked_by: Some(3),
        choke_release_ms: Some(30.0),
        ..Default::default()
    };
    r.cmd(SamplerCmd::SetPad {
        pad: 0,
        params: closed,
        sample: SampleUpdate::Set(dc_sample(SR as usize, 0.5)),
    });
    r.cmd(SamplerCmd::SetPad {
        pad: 1,
        params: open,
        sample: SampleUpdate::Set(dc_sample(SR as usize, 0.5)),
    });
    r.down(0);
    r.down(1);
    assert_eq!(
        r.state(0),
        PadPlayState::Playing,
        "open hat does not choke closed hat"
    );
    r.down(0);
    assert_eq!(r.state(1), PadPlayState::Stopping);
    r.blocks(10); // 30 ms = 1440 frames > 10 blocks of 64
    assert_eq!(
        r.state(1),
        PadPlayState::Stopping,
        "custom choke release is longer"
    );
    r.blocks(20);
    assert_eq!(r.state(1), PadPlayState::Idle);
}

#[test]
fn overlapping_one_shots_and_continue_retrigger() {
    let mut r = Rig::default();
    let poly = RtPadParams {
        self_choke: false,
        ..Default::default()
    };
    r.cmd(SamplerCmd::SetPad {
        pad: 0,
        params: poly,
        sample: SampleUpdate::Set(dc_sample(SR as usize, 0.25)),
    });
    r.down(0);
    r.block();
    r.down(0);
    r.blocks(10);
    assert!(
        (r.pad_out(0)[5] - 0.5).abs() < 1e-6,
        "two overlapping voices"
    );
    let cont = RtPadParams {
        retrigger: up_core::Retrigger::Continue,
        ..Default::default()
    };
    r.cmd(SamplerCmd::SetPad {
        pad: 1,
        params: cont,
        sample: SampleUpdate::Set(dc_sample(BLOCK * 4, 0.5)),
    });
    r.down(1);
    r.blocks(2);
    r.down(1); // ignored
    r.blocks(3);
    assert_eq!(r.state(1), PadPlayState::Idle, "re-press did not restart");
}

#[test]
fn loop_points_wrap_inside_region() {
    let mut r = Rig::default();
    // Sample: 100 frames of 0.1 then 100 frames of 0.9; loop only the second half.
    let mut data = vec![0.1f32; 100];
    data.extend(std::iter::repeat_n(0.9f32, 100));
    let s = Arc::new(SampleData::new(SampleId::new("lp"), "lp", SR, vec![data]));
    let params = RtPadParams {
        mode: PadMode::Loop,
        loop_start: Some(100),
        ..Default::default()
    };
    r.cmd(SamplerCmd::SetPad {
        pad: 0,
        params,
        sample: SampleUpdate::Set(s),
    });
    r.down(0);
    r.blocks(10);
    assert!(
        r.pad_out(0).iter().all(|x| (*x - 0.9).abs() < 1e-6),
        "after the intro only the loop region plays"
    );
}

#[test]
fn voice_limit_steals_oldest_one_shot_before_loops() {
    let mut r = Rig::new(SamplerConfig {
        sample_rate: SR,
        max_voices: 3,
        tail_voices: 2,
        ..Default::default()
    });
    r.set(0, PadMode::Loop, None, dc_sample(SR as usize, 0.1));
    for p in 1..5u8 {
        r.set(p, PadMode::OneShot, None, dc_sample(SR as usize, 0.1));
    }
    r.down(0);
    r.down(1);
    r.down(2);
    r.block();
    r.down(3); // steals pad 1 (oldest one-shot), not the loop
    assert_eq!(r.state(1), PadPlayState::Stopping);
    assert_eq!(r.state(0), PadPlayState::Playing);
    r.down(4); // steals pad 2
    assert_eq!(r.state(2), PadPlayState::Stopping);
    r.blocks(10);
    assert_eq!(r.state(1), PadPlayState::Idle);
    assert_eq!(r.state(2), PadPlayState::Idle);
    assert_eq!(r.state(0), PadPlayState::Playing);
    assert_eq!(r.s.active_voices(), 3);
}

#[test]
fn velocity_and_pan_shape_gain() {
    let mut r = Rig::default();
    let params = RtPadParams {
        pan: -1.0,
        gain: 0.5,
        ..Default::default()
    };
    r.cmd(SamplerCmd::SetPad {
        pad: 0,
        params,
        sample: SampleUpdate::Set(dc_sample(SR as usize, 1.0)),
    });
    r.cmd(SamplerCmd::PadDown {
        pad: 0,
        velocity: 0.5,
    });
    r.block();
    let l = r.bufs[0][10];
    let rr = r.bufs[1][10];
    assert!(
        (l - 0.5 * 0.25 * std::f32::consts::SQRT_2).abs() < 1e-5,
        "{l}"
    );
    assert!(rr.abs() < 1e-6);
}

#[test]
fn live_gain_change_applies_to_playing_loop() {
    let mut r = Rig::default();
    r.set(0, PadMode::Loop, None, dc_sample(1000, 1.0));
    r.down(0);
    r.block();
    let params = RtPadParams {
        mode: PadMode::Loop,
        gain: 0.5,
        ..Default::default()
    };
    r.cmd(SamplerCmd::SetPad {
        pad: 0,
        params,
        sample: SampleUpdate::Keep,
    });
    r.block();
    assert_eq!(r.state(0), PadPlayState::Playing);
    assert!((r.pad_out(0)[10] - 0.5).abs() < 1e-6);
}

#[test]
fn speed_changes_playback_rate() {
    let mut r = Rig::default();
    r.set(0, PadMode::OneShot, None, dc_sample(BLOCK * 4, 0.5));
    r.cmd(SamplerCmd::SetSpeed(2.0));
    r.down(0);
    r.blocks(2); // 128 frames at 2× consume 256 source frames
    r.block();
    assert_eq!(
        r.state(0),
        PadPlayState::Idle,
        "sample exhausted twice as fast"
    );
    r.cmd(SamplerCmd::SetSpeed(10.0));
    assert_eq!(r.s.speed(), 2.0, "clamped");
}

#[test]
fn sample_replacement_retires_old_arc() {
    let mut r = Rig::default();
    let a = dc_sample(1000, 0.5);
    let weak = Arc::downgrade(&a);
    r.set(0, PadMode::OneShot, None, a);
    r.set(0, PadMode::OneShot, None, dc_sample(1000, 0.5));
    assert!(weak.upgrade().is_some(), "not freed on the audio thread");
    r.collector.collect();
    assert!(weak.upgrade().is_none());
}

#[test]
fn preview_plays_and_ends() {
    let mut r = Rig::default();
    r.cmd(SamplerCmd::PlayPreview {
        sample: dc_sample(BLOCK * 2, 0.3),
        start: 0,
        end: None,
        looping: false,
    });
    r.block();
    assert!((r.bufs[48][5] - 0.3).abs() < 1e-6);
    r.blocks(3);
    assert!(!r.s.preview_active());
    assert!(r.ev.contains(&SamplerEvent::PreviewEnded));
}

#[test]
fn preview_region_loops_without_a_pad() {
    let mut r = Rig::default();
    r.cmd(SamplerCmd::PlayPreview {
        sample: dc_sample(BLOCK * 4, 0.3),
        start: 10,
        end: Some(30),
        looping: true,
    });
    r.blocks(20);
    assert!(r.s.preview_active(), "looping preview keeps playing");
    assert!((r.bufs[48][5] - 0.3).abs() < 1e-6);
    for pad in 0..24 {
        assert_eq!(r.state(pad), PadPlayState::Idle, "no pad is occupied");
    }
    r.cmd(SamplerCmd::StopPreview);
    r.blocks(10);
    assert!(!r.s.preview_active());
}

/// Ramp sample: value = frame index; reading position reveals the rate.
fn ramp_sample(frames: usize) -> SampleArc {
    Arc::new(SampleData::new(
        SampleId::new("ramp"),
        "ramp",
        SR,
        vec![(0..frames).map(|i| i as f32).collect()],
    ))
}

#[test]
fn pitch_scales_playback_rate_and_multiplies_with_speed() {
    let rate_after_block = |pitch: f32, speed: f64| {
        let mut r = Rig::default();
        r.cmd(SamplerCmd::SetSpeed(speed));
        let params = RtPadParams {
            pitch,
            ..Default::default()
        };
        r.cmd(SamplerCmd::SetPad {
            pad: 0,
            params,
            sample: SampleUpdate::Set(ramp_sample(BLOCK * 8)),
        });
        r.down(0);
        r.block();
        // Sample value at output frame 32 = read position at frame 32.
        f64::from(r.pad_out(0)[32]) / 32.0
    };
    assert!((rate_after_block(0.0, 1.0) - 1.0).abs() < 1e-3);
    assert!(
        (rate_after_block(12.0, 1.0) - 2.0).abs() < 1e-3,
        "+12 = octave up"
    );
    assert!((rate_after_block(-12.0, 1.0) - 0.5).abs() < 1e-3);
    assert!(
        (rate_after_block(12.0, 0.5) - 1.0).abs() < 1e-3,
        "pitch × speed"
    );
    assert!(
        (rate_after_block(24.0, 1.0) - 2.0).abs() < 1e-3,
        "clamped to ±12"
    );
    assert!((pitch_ratio(7.0) - 1.4983).abs() < 1e-3);
}

#[test]
fn audio_path_is_allocation_free() {
    let mut r = Rig::new(SamplerConfig {
        sample_rate: SR,
        max_voices: 4,
        tail_voices: 2,
        ..Default::default()
    });
    r.cmd(SamplerCmd::SetQuantize(Quantize::Beat));
    let samples: Vec<SampleArc> = (0..6).map(|_| dc_sample(5000, 0.2)).collect();
    for (i, s) in samples.iter().enumerate() {
        let mode = [PadMode::OneShot, PadMode::Loop, PadMode::Gate][i % 3];
        r.set(i as u8, mode, Some((i % 2) as u8), Arc::clone(s));
    }
    r.blocks(2);
    let replacement = dc_sample(5000, 0.1);
    let ((), n) = count_allocs(|| {
        for i in 0..400u32 {
            let pad = (i % 6) as u8;
            if i % 7 == 0 {
                r.cmd(SamplerCmd::PadDown { pad, velocity: 0.8 });
            }
            if i % 11 == 0 {
                r.cmd(SamplerCmd::PadUp { pad });
            }
            if i % 97 == 0 {
                r.cmd(SamplerCmd::SetSpeed(0.5 + (i % 4) as f64 * 0.5));
            }
            if i == 200 {
                r.cmd(SamplerCmd::SetPad {
                    pad: 0,
                    params: RtPadParams::default(),
                    sample: SampleUpdate::Set(Arc::clone(&replacement)),
                });
            }
            if i == 300 {
                r.cmd(SamplerCmd::StopAll);
            }
            r.block();
            r.ev.clear(); // keeps capacity
        }
    });
    assert_eq!(
        n, 0,
        "sampler performed {n} heap operations on the audio path"
    );
    r.collector.collect();
}
