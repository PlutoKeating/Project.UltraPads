//! 原创示例 Kit 生成器：所有声音都由代码合成（确定性伪随机数），素材 100% 原创，按 CC0-1.0 公开。
//!
//! 生成脚本：`cargo run -p up-library --example kitgen -- content/kits`
//! 产物：`content/kits/ultrapads-starter.upkit`、`content/kits/ultrapads-night-drive.upkit`。

use std::collections::BTreeMap;
use std::f32::consts::TAU;

use up_format::kit::{
    ChokeMode, ColorRole, KitDoc, KitSource, KitTempo, Launch, LaunchMode, LoopTempo, PadAddr,
    PadColor, PadDoc, PadKind, Quantize, Retrigger, SampleLayer, Stretch, TutorialRef,
};
use up_format::smf::{Chart, NoteEvent};
use up_format::tutorial::{Judge, TutorialDoc, TutorialMode, TutorialStep, TutorialTempo};
use up_format::upkit::{BuildOptions, UpkitPackage};
use up_format::wav;

pub const SR: u32 = 44_100;
const LICENSE_TEXT: &str = "UltraPads example kit\n\nAll sounds in this kit were synthesized from scratch by\nruntime/up-library/src/kitgen.rs (deterministic code, no recorded or third-party audio).\n\nTo the extent possible under law, the UltraPads authors have waived all copyright and\nrelated or neighboring rights to these sounds: CC0 1.0 Universal\nhttps://creativecommons.org/publicdomain/zero/1.0/\n";

/// xorshift32，确定性噪声。
struct Rng(u32);

impl Rng {
    fn next(&mut self) -> f32 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.0 = x;
        (x as f32 / u32::MAX as f32) * 2.0 - 1.0
    }
}

fn frames(secs: f32) -> usize {
    (secs * SR as f32) as usize
}

fn env(t: f32, decay: f32) -> f32 {
    (-t / decay.max(1e-4)).exp()
}

fn normalize(buf: &mut [f32], peak: f32) {
    let m = buf.iter().fold(0f32, |a, s| a.max(s.abs()));
    if m > 0.0 {
        for s in buf.iter_mut() {
            *s *= peak / m;
        }
    }
    // 结尾 5 ms 淡出，避免爆音
    let fade = frames(0.005).min(buf.len());
    let n = buf.len();
    for i in 0..fade {
        buf[n - 1 - i] *= i as f32 / fade as f32;
    }
}

/// 单极点低通。
fn lowpass(buf: &mut [f32], cutoff: f32) {
    let a = (-TAU * cutoff / SR as f32).exp();
    let mut y = 0.0;
    for s in buf.iter_mut() {
        y = (1.0 - a) * *s + a * y;
        *s = y;
    }
}

/// 一阶高通。
fn highpass(buf: &mut [f32], cutoff: f32) {
    let rc = 1.0 / (TAU * cutoff);
    let dt = 1.0 / SR as f32;
    let a = rc / (rc + dt);
    let (mut px, mut py) = (0.0, 0.0);
    for s in buf.iter_mut() {
        let y = a * (py + *s - px);
        px = *s;
        py = y;
        *s = y;
    }
}

pub fn kick(start_hz: f32, end_hz: f32, decay: f32) -> Vec<f32> {
    let n = frames(decay * 5.0);
    let mut phase = 0.0f32;
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let t = i as f32 / SR as f32;
        let f = end_hz + (start_hz - end_hz) * env(t, 0.04);
        phase += TAU * f / SR as f32;
        let click = if t < 0.004 {
            (1.0 - t / 0.004) * 0.6
        } else {
            0.0
        };
        out.push(phase.sin() * env(t, decay) + click);
    }
    normalize(&mut out, 0.95);
    out
}

pub fn snare(seed: u32, tone_hz: f32, decay: f32) -> Vec<f32> {
    let mut r = Rng(seed);
    let n = frames(decay * 4.0);
    let mut noise: Vec<f32> = (0..n).map(|_| r.next()).collect();
    highpass(&mut noise, 1200.0);
    let mut out = Vec::with_capacity(n);
    for (i, nz) in noise.iter().enumerate() {
        let t = i as f32 / SR as f32;
        let tone = (TAU * tone_hz * t).sin() * env(t, 0.05) * 0.7;
        out.push(nz * env(t, decay) + tone);
    }
    normalize(&mut out, 0.9);
    out
}

pub fn hat(seed: u32, decay: f32) -> Vec<f32> {
    let mut r = Rng(seed);
    let n = frames(decay * 5.0).max(frames(0.05));
    let mut out: Vec<f32> = (0..n).map(|_| r.next()).collect();
    highpass(&mut out, 7000.0);
    highpass(&mut out, 7000.0);
    for (i, s) in out.iter_mut().enumerate() {
        *s *= env(i as f32 / SR as f32, decay);
    }
    normalize(&mut out, 0.7);
    out
}

pub fn clap(seed: u32) -> Vec<f32> {
    let mut r = Rng(seed);
    let n = frames(0.5);
    let mut noise: Vec<f32> = (0..n).map(|_| r.next()).collect();
    highpass(&mut noise, 900.0);
    lowpass(&mut noise, 6000.0);
    let mut out = Vec::with_capacity(n);
    for (i, nz) in noise.iter().enumerate() {
        let t = i as f32 / SR as f32;
        let bursts: f32 = [0.0f32, 0.011, 0.023]
            .iter()
            .map(|&b| if t >= b { env(t - b, 0.006) } else { 0.0 })
            .sum();
        let tail = if t >= 0.03 {
            env(t - 0.03, 0.12) * 0.8
        } else {
            0.0
        };
        out.push(nz * (bursts + tail));
    }
    normalize(&mut out, 0.9);
    out
}

pub fn tom(hz: f32) -> Vec<f32> {
    let n = frames(0.9);
    let mut phase = 0.0f32;
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let t = i as f32 / SR as f32;
        let f = hz * (1.0 + 0.6 * env(t, 0.05));
        phase += TAU * f / SR as f32;
        out.push(phase.sin() * env(t, 0.22));
    }
    normalize(&mut out, 0.9);
    out
}

pub fn blip(hz: f32, decay: f32) -> Vec<f32> {
    let n = frames(decay * 5.0);
    let mut out: Vec<f32> = (0..n)
        .map(|i| {
            let t = i as f32 / SR as f32;
            ((TAU * hz * t).sin() + 0.4 * (TAU * hz * 1.5 * t).sin()) * env(t, decay)
        })
        .collect();
    normalize(&mut out, 0.8);
    out
}

fn midi_hz(n: f32) -> f32 {
    440.0 * 2f32.powf((n - 69.0) / 12.0)
}

/// 带限近似的锯齿波（前 8 个谐波）。
fn saw(phase: f32) -> f32 {
    (1..=8)
        .map(|k| (phase * k as f32).sin() / k as f32)
        .sum::<f32>()
        * 0.6
}

fn mix_at(dst: &mut [f32], src: &[f32], at: usize, gain: f32) {
    for (i, s) in src.iter().enumerate() {
        if let Some(d) = dst.get_mut(at + i) {
            *d += s * gain;
        }
    }
}

/// 一个 loop：`bars` 小节，4/4。
pub struct LoopSpec {
    pub bpm: f32,
    pub bars: u32,
}

impl LoopSpec {
    fn beat_frames(&self) -> usize {
        (60.0 / self.bpm * SR as f32) as usize
    }
    fn total(&self) -> usize {
        self.beat_frames() * 4 * self.bars as usize
    }
}

/// 鼓 loop：kick/snare/hat 按 16 分音符步进。
pub fn drum_loop(spec: &LoopSpec, pattern: &[(&[f32], &str, f32)]) -> Vec<f32> {
    let mut out = vec![0.0; spec.total()];
    let step = spec.beat_frames() / 4;
    for bar in 0..spec.bars as usize {
        for (sound, steps, gain) in pattern {
            for (i, c) in steps.chars().filter(|c| *c != ' ').enumerate() {
                if c == 'x' {
                    mix_at(&mut out, sound, (bar * 16 + i) * step, *gain);
                }
            }
        }
    }
    normalize(&mut out, 0.9);
    // 去掉结尾淡出外的部分：loop 必须严格等长
    out.truncate(spec.total());
    out
}

/// 低音 loop：每拍一个音符（MIDI 音高，None = 休止）。
pub fn bass_loop(spec: &LoopSpec, notes: &[Option<f32>], cutoff: f32) -> Vec<f32> {
    let mut out = vec![0.0; spec.total()];
    let beat = spec.beat_frames();
    let per = beat / 2;
    let steps = spec.total() / per;
    for s in 0..steps {
        let Some(n) = notes[s % notes.len()] else {
            continue;
        };
        let hz = midi_hz(n);
        let mut phase = 0.0f32;
        for i in 0..per {
            let t = i as f32 / SR as f32;
            phase += TAU * hz / SR as f32;
            let a = env(t, 0.18) * (1.0 - (i as f32 / per as f32).powi(8));
            out[s * per + i] += saw(phase) * a;
        }
    }
    lowpass(&mut out, cutoff);
    lowpass(&mut out, cutoff * 1.5);
    normalize(&mut out, 0.85);
    out
}

/// 和弦 pad loop：每小节一个和弦。
pub fn chord_loop(spec: &LoopSpec, chords: &[[f32; 3]], cutoff: f32) -> Vec<f32> {
    let mut out = vec![0.0; spec.total()];
    let bar = spec.beat_frames() * 4;
    for b in 0..spec.bars as usize {
        let chord = chords[b % chords.len()];
        for n in chord {
            let hz = midi_hz(n);
            for i in 0..bar {
                let t = i as f32 / SR as f32;
                let attack = (t / 0.08).min(1.0);
                let release = ((bar - i) as f32 / (SR as f32 * 0.05)).min(1.0);
                let ph = TAU * hz * t;
                out[b * bar + i] += (saw(ph) + saw(ph * 1.003)) * 0.5 * attack * release;
            }
        }
    }
    lowpass(&mut out, cutoff);
    normalize(&mut out, 0.7);
    out
}

/// 琶音 loop：16 分音符。
pub fn arp_loop(spec: &LoopSpec, notes: &[f32]) -> Vec<f32> {
    let mut out = vec![0.0; spec.total()];
    let step = spec.beat_frames() / 4;
    let steps = spec.total() / step;
    for s in 0..steps {
        let hz = midi_hz(notes[s % notes.len()]);
        for i in 0..step {
            let t = i as f32 / SR as f32;
            let sq = if (TAU * hz * t).sin() >= 0.0 {
                1.0
            } else {
                -1.0
            };
            out[s * step + i] += sq * env(t, 0.06) * 0.5;
        }
    }
    lowpass(&mut out, 3500.0);
    normalize(&mut out, 0.6);
    out
}

fn one_shot_wav(samples: &[f32]) -> Vec<u8> {
    wav::encode_pcm16(1, SR, samples)
}

/// loop WAV：内嵌 `acid`（BPM/拍数）+ `smpl`（整段 loop），脱离 UltraPads 也能被识别。
fn loop_wav(samples: &[f32], spec: &LoopSpec, root: u8) -> Vec<u8> {
    let base = wav::encode_pcm16(1, SR, samples);
    let mut smpl = wav::SmplChunk::new(SR, root);
    smpl.loops.push(wav::SampleLoop {
        cue_id: 0,
        kind: wav::LoopType::Forward,
        start: 0,
        end: samples.len() as u32 - 1,
        fraction: 0,
        play_count: 0,
    });
    let meta = wav::WavMetadata {
        smpl: Some(smpl),
        acid: Some(wav::AcidChunk::looped(
            spec.bpm,
            spec.bars * 4,
            root,
            [4, 4],
        )),
        ..Default::default()
    };
    wav::write_metadata(&base, &meta).expect("刚编码的 WAV 一定合法")
}

struct PadBuild<'a> {
    flat: u8,
    name: &'a str,
    file: &'a str,
    color: ColorRole,
    wav: Vec<u8>,
    loop_spec: Option<&'a LoopSpec>,
    choke: Option<(u32, u32)>,
    exclusive: Option<&'a str>,
}

fn assemble(
    id: &str,
    name: &str,
    description: &str,
    genres: &[&str],
    tags: &[&str],
    bpm: f32,
    pads: Vec<PadBuild<'_>>,
) -> (KitDoc, BTreeMap<String, Vec<u8>>) {
    let mut doc = KitDoc::new(id, name);
    doc.description = Some(description.into());
    doc.authors = vec!["UltraPads".into()];
    doc.license = Some("CC0-1.0".into());
    doc.genres = genres.iter().map(|s| s.to_string()).collect();
    doc.tags = tags.iter().map(|s| s.to_string()).collect();
    doc.tempo = Some(KitTempo {
        bpm: f64::from(bpm),
        time_signature: [4, 4],
    });
    doc.source = Some(KitSource {
        kind: "generated".into(),
        original_name: Some("runtime/up-library/src/kitgen.rs".into()),
        ..KitSource::default()
    });
    let mut assets = BTreeMap::new();
    let mut max_flat = 0;
    for p in pads {
        max_flat = max_flat.max(p.flat);
        let path = format!("samples/{}", p.file);
        let mut pad = PadDoc::new(PadAddr::from_flat(p.flat));
        pad.name = Some(p.name.into());
        pad.color = PadColor::Role(p.color);
        if let Some(spec) = p.loop_spec {
            pad.kind = PadKind::Loop;
            pad.launch = Launch {
                mode: LaunchMode::Toggle,
                quantize: Quantize::Bar,
                retrigger: Retrigger::Restart,
            };
            pad.tempo = Some(LoopTempo {
                bpm: f64::from(spec.bpm),
                beats: Some(f64::from(spec.bars * 4)),
                time_signature: [4, 4],
                stretch: Stretch::Beats,
            });
        } else {
            pad.self_choke = true;
        }
        if let Some((g, off)) = p.choke {
            pad.choke_group = Some(g);
            pad.choked_by = Some(off);
            pad.choke_mode = ChokeMode::Time(0.03);
        }
        pad.exclusive = p.exclusive.map(str::to_string);
        pad.layers.push(SampleLayer::new(path.clone()));
        assets.insert(path, p.wav);
        doc.pads.push(pad);
    }
    doc.pad_count = if max_flat >= 12 { 24 } else { 12 };
    assets.insert("LICENSE.txt".into(), LICENSE_TEXT.as_bytes().to_vec());
    (doc, assets)
}

/// 12 pad 的入门 Kit（120 BPM）：8 个鼓 one-shot + 4 个 1 小节 loop。
pub fn starter_kit() -> (KitDoc, BTreeMap<String, Vec<u8>>) {
    let spec = LoopSpec {
        bpm: 120.0,
        bars: 1,
    };
    let k = kick(160.0, 48.0, 0.12);
    let s = snare(7, 190.0, 0.09);
    let ch = hat(11, 0.025);
    let oh = hat(13, 0.18);
    let drums = drum_loop(
        &spec,
        &[
            (&k, "x... .... x.x. ....", 1.0),
            (&s, ".... x... .... x...", 0.8),
            (&ch, "x.x. x.x. x.x. x.xx", 0.45),
        ],
    );
    let bass = bass_loop(
        &spec,
        &[
            Some(33.0),
            None,
            Some(33.0),
            Some(45.0),
            Some(36.0),
            None,
            Some(31.0),
            Some(43.0),
        ],
        900.0,
    );
    let chords = chord_loop(&spec, &[[57.0, 60.0, 64.0]], 1800.0);
    let arp = arp_loop(&spec, &[69.0, 72.0, 76.0, 81.0, 76.0, 72.0]);
    let pads = vec![
        PadBuild {
            flat: 0,
            name: "Kick",
            file: "kick.wav",
            color: ColorRole::Orange,
            wav: one_shot_wav(&k),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 1,
            name: "Snare",
            file: "snare.wav",
            color: ColorRole::Pink,
            wav: one_shot_wav(&s),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 2,
            name: "Clap",
            file: "clap.wav",
            color: ColorRole::Pink,
            wav: one_shot_wav(&clap(5)),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 3,
            name: "Hat Closed",
            file: "hat-closed.wav",
            color: ColorRole::Green,
            wav: one_shot_wav(&ch),
            loop_spec: None,
            choke: Some((3, 3)),
            exclusive: None,
        },
        PadBuild {
            flat: 4,
            name: "Hat Open",
            file: "hat-open.wav",
            color: ColorRole::Green,
            wav: one_shot_wav(&oh),
            loop_spec: None,
            choke: Some((3, 3)),
            exclusive: None,
        },
        PadBuild {
            flat: 5,
            name: "Tom Low",
            file: "tom-low.wav",
            color: ColorRole::Orange,
            wav: one_shot_wav(&tom(95.0)),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 6,
            name: "Tom High",
            file: "tom-high.wav",
            color: ColorRole::Orange,
            wav: one_shot_wav(&tom(150.0)),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 7,
            name: "Blip",
            file: "blip.wav",
            color: ColorRole::Purple,
            wav: one_shot_wav(&blip(880.0, 0.05)),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 8,
            name: "Drums",
            file: "loop-drums-120bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&drums, &spec, 36),
            loop_spec: Some(&spec),
            choke: Some((10, 10)),
            exclusive: Some("drums"),
        },
        PadBuild {
            flat: 9,
            name: "Bass",
            file: "loop-bass-120bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&bass, &spec, 33),
            loop_spec: Some(&spec),
            choke: Some((11, 11)),
            exclusive: Some("bass"),
        },
        PadBuild {
            flat: 10,
            name: "Chords",
            file: "loop-chords-120bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&chords, &spec, 57),
            loop_spec: Some(&spec),
            choke: Some((12, 12)),
            exclusive: Some("chords"),
        },
        PadBuild {
            flat: 11,
            name: "Arp",
            file: "loop-arp-120bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&arp, &spec, 69),
            loop_spec: Some(&spec),
            choke: Some((13, 13)),
            exclusive: Some("arp"),
        },
    ];
    let (mut doc, mut assets) = assemble(
        "0192f0c0-5a17-7000-8000-00000000c0de",
        "UltraPads Starter",
        "原创合成鼓组：8 个 one-shot + 4 个 120 BPM loop（鼓、低音、和弦、琶音）。",
        &["Electronic", "Hip Hop"],
        &["starter", "synth", "drums"],
        120.0,
        pads,
    );
    add_first_beat_tutorial(&mut doc, &mut assets);
    (doc, assets)
}

fn add_first_beat_tutorial(doc: &mut KitDoc, assets: &mut BTreeMap<String, Vec<u8>>) {
    let tpq = 480u32;
    let mut notes = Vec::new();
    for bar in 0..4u32 {
        for beat in 0..4u32 {
            let tick = (bar * 4 + beat) * tpq;
            let key = if beat % 2 == 0 { 36 } else { 37 };
            notes.push(NoteEvent {
                tick,
                duration: tpq / 4,
                channel: 0,
                key,
                velocity: 100,
            });
            if bar >= 2 {
                notes.push(NoteEvent {
                    tick: tick + tpq / 2,
                    duration: tpq / 4,
                    channel: 0,
                    key: 39,
                    velocity: 80,
                });
            }
        }
    }
    let chart = Chart {
        ticks_per_quarter: tpq as u16,
        bpm: 120.0,
        time_signature: [4, 4],
        track_name: Some("First beat".into()),
        markers: Vec::new(),
        notes,
    };
    let t = TutorialDoc {
        id: "first-beat".into(),
        title: BTreeMap::from([
            ("en".into(), "Your first beat".into()),
            ("zh-CN".into(), "你的第一个节拍".into()),
        ]),
        mode: TutorialMode::Timed,
        chart: Some("chart.mid".into()),
        tempo: Some(TutorialTempo {
            start: 90.0,
            target: 120.0,
        }),
        judge: Some(Judge {
            perfect_ms: 30,
            good_ms: 80,
        }),
        video_url: None,
        steps: vec![
            TutorialStep {
                from_bar: Some(1),
                to_bar: Some(2),
                hint: BTreeMap::from([
                    ("en".into(), "Kick and snare on the beat".into()),
                    ("zh-CN".into(), "跟着节拍交替按 Kick 和 Snare".into()),
                ]),
                pads: vec![36, 37],
                bank: Some("A".into()),
                loop_: false,
            },
            TutorialStep {
                from_bar: Some(3),
                to_bar: Some(4),
                hint: BTreeMap::from([
                    ("en".into(), "Add the closed hat on the off-beats".into()),
                    ("zh-CN".into(), "在反拍加入闭镲".into()),
                ]),
                pads: vec![36, 37, 39],
                bank: None,
                loop_: true,
            },
        ],
        extra: Default::default(),
    };
    assets.insert(
        "tutorials/first-beat/tutorial.json".into(),
        t.to_vec_pretty(),
    );
    assets.insert("tutorials/first-beat/chart.mid".into(), chart.to_smf());
    doc.tutorials.push(TutorialRef {
        id: "first-beat".into(),
        path: "tutorials/first-beat/tutorial.json".into(),
    });
}

/// 8 pad 的 Lo-Fi 小 Kit（90 BPM，较暗的音色）。
pub fn night_drive_kit() -> (KitDoc, BTreeMap<String, Vec<u8>>) {
    let spec = LoopSpec { bpm: 90.0, bars: 1 };
    let k = kick(110.0, 42.0, 0.18);
    let s = snare(23, 160.0, 0.14);
    let ch = hat(29, 0.03);
    let mut drums = drum_loop(
        &spec,
        &[
            (&k, "x... ...x ..x. ....", 1.0),
            (&s, ".... x... .... x...", 0.7),
            (&ch, "x.x. x.x. x.x. x.x.", 0.35),
        ],
    );
    lowpass(&mut drums, 5000.0);
    normalize(&mut drums, 0.9);
    let chords = chord_loop(&spec, &[[50.0, 53.0, 57.0]], 900.0);
    let bass = bass_loop(
        &spec,
        &[
            Some(26.0),
            None,
            None,
            Some(26.0),
            Some(29.0),
            None,
            Some(24.0),
            None,
        ],
        500.0,
    );
    let pads = vec![
        PadBuild {
            flat: 0,
            name: "Dusty Kick",
            file: "kick.wav",
            color: ColorRole::Orange,
            wav: one_shot_wav(&k),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 1,
            name: "Soft Snare",
            file: "snare.wav",
            color: ColorRole::Pink,
            wav: one_shot_wav(&s),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
        PadBuild {
            flat: 2,
            name: "Hat",
            file: "hat.wav",
            color: ColorRole::Green,
            wav: one_shot_wav(&ch),
            loop_spec: None,
            choke: Some((2, 2)),
            exclusive: None,
        },
        PadBuild {
            flat: 3,
            name: "Rim",
            file: "rim.wav",
            color: ColorRole::Yellow,
            wav: one_shot_wav(&blip(620.0, 0.02)),
            loop_spec: None,
            choke: Some((2, 2)),
            exclusive: None,
        },
        PadBuild {
            flat: 4,
            name: "Beat",
            file: "loop-beat-90bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&drums, &spec, 36),
            loop_spec: Some(&spec),
            choke: Some((10, 10)),
            exclusive: Some("beat"),
        },
        PadBuild {
            flat: 5,
            name: "Keys",
            file: "loop-keys-90bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&chords, &spec, 50),
            loop_spec: Some(&spec),
            choke: Some((11, 11)),
            exclusive: Some("keys"),
        },
        PadBuild {
            flat: 6,
            name: "Sub",
            file: "loop-sub-90bpm-1bar.wav",
            color: ColorRole::Blue,
            wav: loop_wav(&bass, &spec, 26),
            loop_spec: Some(&spec),
            choke: Some((12, 12)),
            exclusive: Some("sub"),
        },
        PadBuild {
            flat: 7,
            name: "Tom",
            file: "tom.wav",
            color: ColorRole::Purple,
            wav: one_shot_wav(&tom(80.0)),
            loop_spec: None,
            choke: None,
            exclusive: None,
        },
    ];
    assemble(
        "0192f0c0-5a17-7000-8000-0000000d21e0",
        "UltraPads Night Drive",
        "原创合成 Lo-Fi 小鼓组：90 BPM，5 个 one-shot + 3 个 loop。",
        &["Lo-Fi"],
        &["chill", "synth"],
        90.0,
        pads,
    )
}

/// 生成所有示例包：`(文件名, 包)`。输出是确定性的（固定 ID、固定时间戳）。
pub fn example_packages() -> up_format::Result<Vec<(String, UpkitPackage)>> {
    let opts = BuildOptions {
        created: Some("2026-10-18T00:00:00Z".into()),
        updated: Some("2026-10-18T00:00:00Z".into()),
        generator: Some("UltraPads kitgen".into()),
    };
    let mut out = Vec::new();
    for (file, (doc, assets)) in [
        ("ultrapads-starter.upkit", starter_kit()),
        ("ultrapads-night-drive.upkit", night_drive_kit()),
    ] {
        out.push((file.to_string(), UpkitPackage::build(&doc, assets, &opts)?));
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_and_valid() {
        let a = example_packages().unwrap();
        let b = example_packages().unwrap();
        assert_eq!(a, b);
        for (_, pkg) in &a {
            let loaded = pkg.read(&Default::default()).unwrap();
            assert!(loaded.warnings.is_empty(), "{:?}", loaded.warnings);
        }
    }
}
