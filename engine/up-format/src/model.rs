//! [`KitDoc`]（格式层，完整表达 `.upkit`）↔ [`up_model::KitDoc`]（引擎/FFI/UI 使用的文档）的映射。
//!
//! `up_model::KitDoc` 每个 pad 只有一个采样、一个对称 choke 组，没有力度层/轮替/loop 点/
//! 非对称 choke 等字段；因此：
//! - 正向 [`to_model`]：取第一个采样层；`choke = choked_by.or(choke_group)`（开闭镲都落在同一组）
//! - 反向 [`apply_model`]：把编辑结果**合并**到原 `KitDoc` 上，保留模型表达不了的部分
//!   （其余采样层、轮替、非对称 choke、教程……）；`timeRatio`、`fadeInMs`、`fadeOutMs`
//!   存进 pad 的扩展字段（`ultrapads-kit.json`）
//!
//! 需要 up-model 补的字段见 crate 文档 / 报告。

use up_core::{Bank, ColorRole as MColor, KitId, PadId, PadMode, Quantize as MQuantize, SampleId};
use up_model::{
    JudgeWindow, LoopMeta, SampleRef, TimeSignature, TutorialAction, TutorialChart, TutorialEvent,
    TutorialLesson, TutorialTarget,
};

use crate::kit::{
    ColorRole, KitDoc, KitTempo, LaunchMode, LoopTempo, PadAddr, PadColor, PadDoc, PadKind,
    Quantize, SampleLayer, Stretch,
};
use crate::smf::Chart;
use crate::tutorial::{TutorialDoc, TutorialMode};

const EXT_TIME_RATIO: &str = "timeRatio";
const EXT_FADE_IN: &str = "fadeInMs";
const EXT_FADE_OUT: &str = "fadeOutMs";

pub fn db_to_linear(db: f32) -> f32 {
    10f32.powf(db / 20.0)
}

pub fn linear_to_db(g: f32) -> f32 {
    if g <= 1e-6 { -120.0 } else { 20.0 * g.log10() }
}

pub fn color_to_model(c: &PadColor) -> MColor {
    match c {
        PadColor::Role(r) => match r {
            ColorRole::Blue => MColor::Blue,
            ColorRole::Green | ColorRole::Lime => MColor::Green,
            ColorRole::Orange => MColor::Orange,
            ColorRole::Pink => MColor::Pink,
            ColorRole::Aqua => MColor::Cyan,
            ColorRole::Red => MColor::Red,
            ColorRole::Purple => MColor::Purple,
            ColorRole::Yellow => MColor::Yellow,
            ColorRole::Grey => MColor::Neutral,
        },
        PadColor::Hex(h) => nearest_role(h),
    }
}

pub fn color_from_model(c: MColor) -> PadColor {
    PadColor::Role(match c {
        MColor::Blue => ColorRole::Blue,
        MColor::Orange => ColorRole::Orange,
        MColor::Pink => ColorRole::Pink,
        MColor::Green => ColorRole::Green,
        MColor::Purple => ColorRole::Purple,
        MColor::Yellow => ColorRole::Yellow,
        MColor::Red => ColorRole::Red,
        MColor::Cyan => ColorRole::Aqua,
        MColor::Neutral => ColorRole::Grey,
    })
}

fn nearest_role(hex: &str) -> MColor {
    let rgb = |h: &str| -> Option<(i32, i32, i32)> {
        let h = h.trim_start_matches('#');
        Some((
            i32::from_str_radix(h.get(0..2)?, 16).ok()?,
            i32::from_str_radix(h.get(2..4)?, 16).ok()?,
            i32::from_str_radix(h.get(4..6)?, 16).ok()?,
        ))
    };
    let Some(c) = rgb(hex) else {
        return MColor::Blue;
    };
    ColorRole::ALL
        .into_iter()
        .filter(|r| *r != ColorRole::Grey)
        .min_by_key(|r| {
            let (r2, g2, b2) = rgb(r.reference_hex()).unwrap_or((0, 0, 0));
            (c.0 - r2).pow(2) + (c.1 - g2).pow(2) + (c.2 - b2).pow(2)
        })
        .map(|r| color_to_model(&PadColor::Role(r)))
        .unwrap_or(MColor::Blue)
}

fn mode_to_model(p: &PadDoc) -> PadMode {
    match (p.kind, p.launch.mode) {
        (PadKind::Loop, _) => PadMode::Loop,
        (PadKind::OneShot, LaunchMode::Gate) => PadMode::Gate,
        (PadKind::OneShot, _) => PadMode::OneShot,
    }
}

fn quantize_to_model(q: Quantize) -> Option<MQuantize> {
    match q {
        Quantize::None => Some(MQuantize::None),
        Quantize::Global => None,
        Quantize::Sixteenth | Quantize::Eighth | Quantize::Quarter | Quantize::Beat => {
            Some(MQuantize::Beat)
        }
        Quantize::Bar | Quantize::TwoBars | Quantize::FourBars => Some(MQuantize::Bar),
    }
}

fn quantize_from_model(q: Option<MQuantize>, kind: PadKind) -> Quantize {
    match q {
        Some(MQuantize::None) => Quantize::None,
        Some(MQuantize::Beat) => Quantize::Beat,
        Some(MQuantize::Bar) => Quantize::Bar,
        None if kind == PadKind::Loop => Quantize::Global,
        None => Quantize::None,
    }
}

fn ext_f32(p: &PadDoc, key: &str, default: f32) -> f32 {
    p.extra
        .get(key)
        .and_then(serde_json::Value::as_f64)
        .map(|v| v as f32)
        .unwrap_or(default)
}

/// 正向映射。`tutorial` 由调用方用 [`tutorial_chart`] 从包内教程构造。
pub fn to_model(doc: &KitDoc, tutorial: Option<TutorialChart>) -> up_model::KitDoc {
    let ts = doc.tempo.map(|t| t.time_signature).unwrap_or([4, 4]);
    let mut m = up_model::KitDoc {
        id: KitId::new(doc.id.clone()),
        name: doc.name.clone(),
        bpm: doc.tempo.map(|t| t.bpm),
        time_signature: TimeSignature {
            numerator: u32::from(ts[0]),
            denominator: u32::from(ts[1]),
        },
        tutorial,
        ..Default::default()
    };
    m.meta.author = (!doc.authors.is_empty()).then(|| doc.authors.join(", "));
    m.meta.genre = doc.genres.clone();
    m.meta.tags = doc.tags.clone();
    m.meta.cover = doc.cover.clone();
    m.meta.license = doc.license.clone();
    if let Some(src) = &doc.source {
        if let Some(i) = &src.inspired_by {
            let (artist, title) = match i.split_once(" — ") {
                Some((a, t)) => (Some(a.to_string()), Some(t.to_string())),
                None => (Some(i.clone()), None),
            };
            m.meta.inspired_by_artist = artist;
            m.meta.inspired_by_title = title;
        }
    }
    for p in &doc.pads {
        let Some(pad_id) = PadId::from_flat(usize::from(p.addr.flat())) else {
            continue;
        };
        let mut mp = up_model::PadDoc::new(pad_id);
        mp.note = p.note;
        mp.name = p
            .name
            .clone()
            .unwrap_or_else(|| format!("{}{}", p.addr.bank_letter(), p.addr.index + 1));
        mp.mode = mode_to_model(p);
        mp.gain = db_to_linear(p.gain_db);
        mp.pan = p.pan;
        mp.choke_group = p
            .choked_by
            .or(p.choke_group)
            .and_then(|g| u8::try_from(g).ok());
        mp.color = color_to_model(&p.color);
        mp.quantize = quantize_to_model(p.launch.quantize);
        mp.time_ratio = ext_f32(p, EXT_TIME_RATIO, 1.0).clamp(0.5, 2.0);
        mp.fade_in_ms = ext_f32(p, EXT_FADE_IN, 0.0);
        mp.fade_out_ms = ext_f32(p, EXT_FADE_OUT, 0.0);
        if let Some(l) = p.layers.first() {
            let id = l.sample_id.clone().unwrap_or_default();
            mp.sample = Some(SampleRef {
                id: SampleId::new(id.clone()),
                path: Some(l.sample.clone()),
                name: crate::path::file_stem(&l.sample).to_string(),
                blake3: l.sample_id.clone(),
                ..Default::default()
            });
            mp.start_frame = l.start_frame.unwrap_or(0);
            mp.end_frame = l.end_frame;
            mp.pitch_semitones =
                (l.transpose as f32 + l.tune_cents as f32 / 100.0).clamp(-12.0, 12.0);
        }
        if p.tempo.is_some() || p.layers.first().and_then(|l| l.root_key).is_some() {
            mp.loop_meta = Some(LoopMeta {
                bpm: p.tempo.map(|t| t.bpm),
                beats: p.tempo.and_then(|t| t.beats),
                root_note: p.layers.first().and_then(|l| l.root_key),
            });
        }
        m.pads.push(mp);
    }
    m.pads.sort_by_key(|p| p.pad);
    m
}

/// 反向映射：把模型上的编辑合并进 `base`。`base` 中不存在的 pad 会被新建；
/// 模型中没有的 pad 会被删除。
pub fn apply_model(base: &mut KitDoc, m: &up_model::KitDoc) {
    base.name = m.name.clone();
    let ts = [
        u8::try_from(m.time_signature.numerator).unwrap_or(4),
        u8::try_from(m.time_signature.denominator).unwrap_or(4),
    ];
    base.tempo = m.bpm.map(|bpm| KitTempo {
        bpm,
        time_signature: ts,
    });
    if !m.meta.genre.is_empty() || !base.genres.is_empty() {
        base.genres = m.meta.genre.clone();
    }
    base.tags = m.meta.tags.clone();
    if m.meta.license.is_some() {
        base.license = m.meta.license.clone();
    }
    if m.pads.iter().any(|p| p.pad.bank > 0) {
        base.pad_count = 24;
    }
    let keep: Vec<PadAddr> = m
        .pads
        .iter()
        .map(|p| PadAddr {
            bank: p.pad.bank,
            index: p.pad.index,
        })
        .collect();
    base.pads.retain(|p| keep.contains(&p.addr));
    for mp in &m.pads {
        let addr = PadAddr {
            bank: mp.pad.bank,
            index: mp.pad.index,
        };
        if base.pad(addr).is_none() {
            base.pads.push(PadDoc::new(addr));
        }
        let p = base
            .pads
            .iter_mut()
            .find(|p| p.addr == addr)
            .expect("刚插入");
        p.note = mp.note;
        p.name = (!mp.name.trim().is_empty()).then(|| mp.name.clone());
        let (kind, mode) = match mp.mode {
            PadMode::Loop => (PadKind::Loop, LaunchMode::Toggle),
            PadMode::Gate => (PadKind::OneShot, LaunchMode::Gate),
            PadMode::OneShot => (PadKind::OneShot, LaunchMode::Trigger),
        };
        p.kind = kind;
        p.launch.mode = mode;
        p.launch.quantize = quantize_from_model(mp.quantize, kind);
        p.gain_db = linear_to_db(mp.gain);
        p.pan = mp.pan.clamp(-1.0, 1.0);
        let new_group = mp.choke_group.map(u32::from);
        if p.choked_by.or(p.choke_group) != new_group {
            p.choke_group = new_group;
            p.choked_by = new_group;
        }
        p.color = color_from_model(mp.color);
        for (k, v, default) in [
            (EXT_TIME_RATIO, mp.time_ratio, 1.0),
            (EXT_FADE_IN, mp.fade_in_ms, 0.0),
            (EXT_FADE_OUT, mp.fade_out_ms, 0.0),
        ] {
            if (v - default).abs() > f32::EPSILON {
                p.extra
                    .insert(k.into(), serde_json::Value::from(f64::from(v)));
            } else {
                p.extra.remove(k);
            }
        }
        match &mp.sample {
            None => p.layers.clear(),
            Some(s) => {
                let hash = s
                    .blake3
                    .clone()
                    .or_else(|| (!s.id.as_str().is_empty()).then(|| s.id.as_str().to_string()));
                let path = s
                    .path
                    .clone()
                    .unwrap_or_else(|| format!("samples/{}.wav", crate::path::slug(&s.name)));
                let same = p.layers.first().is_some_and(|l| {
                    hash.is_some() && l.sample_id == hash || l.sample == path && hash.is_none()
                });
                if !same {
                    let mut l = SampleLayer::new(path);
                    l.sample_id = hash;
                    p.layers = vec![l];
                }
                let l = &mut p.layers[0];
                l.start_frame = (mp.start_frame > 0).then_some(mp.start_frame);
                l.end_frame = mp.end_frame;
                let semis = mp.pitch_semitones.clamp(-12.0, 12.0);
                l.transpose = semis.trunc() as i32;
                l.tune_cents = ((semis - semis.trunc()) * 100.0).round() as i32;
            }
        }
        if let Some(lm) = mp.loop_meta {
            if let Some(bpm) = lm.bpm {
                let prev = p.tempo;
                p.tempo = Some(LoopTempo {
                    bpm,
                    beats: lm.beats,
                    time_signature: prev.map(|t| t.time_signature).unwrap_or(ts),
                    stretch: prev.map(|t| t.stretch).unwrap_or(Stretch::None),
                });
            }
            if let (Some(root), Some(l)) = (lm.root_note, p.layers.first_mut()) {
                l.root_key = Some(root);
            }
        }
    }
    base.sort_pads();
}

fn note_to_target(doc: &KitDoc, key: u8) -> Option<(TutorialTarget, Option<MColor>)> {
    let pad = doc
        .pad_by_note(key)
        .map(|p| p.addr)
        .or_else(|| PadAddr::from_default_note(key))?;
    let id = PadId::from_flat(usize::from(pad.flat()))?;
    let color = doc.pad(pad).map(|p| color_to_model(&p.color));
    Some((TutorialTarget::Pad { pad: id }, color))
}

fn chart_events(doc: &KitDoc, chart: &Chart) -> Vec<TutorialEvent> {
    let secs_per_tick = 60.0 / chart.bpm.max(1.0) / f64::from(chart.ticks_per_quarter.max(1));
    let mut out = Vec::new();
    for mk in &chart.markers {
        let bank = match mk.text.as_str() {
            "Page A" => Bank::A,
            "Page B" => Bank::B,
            _ => continue,
        };
        out.push(TutorialEvent {
            time_secs: f64::from(mk.tick) * secs_per_tick,
            target: TutorialTarget::Page { bank },
            color: None,
            action: TutorialAction::Tap,
        });
    }
    for n in &chart.notes {
        let Some((target, color)) = note_to_target(doc, n.key) else {
            continue;
        };
        out.push(TutorialEvent {
            time_secs: f64::from(n.tick) * secs_per_tick,
            target,
            color,
            // 导入器约定：velocity 64 = 原 App 的 state 0（开启 loop）
            action: if n.velocity == 64 {
                TutorialAction::LoopToggle
            } else {
                TutorialAction::Tap
            },
        });
    }
    out.sort_by(|a, b| a.time_secs.total_cmp(&b.time_secs));
    out
}

/// 把包内教程（`tutorial.json` + 可选 `chart.mid`）合成为引擎的 [`TutorialChart`]。
/// 普通教程合并为整曲事件；`extra.lesson` 存在的教程成为分课。
pub fn tutorial_chart(
    doc: &KitDoc,
    tutorials: &[(TutorialDoc, Option<Chart>)],
) -> Option<TutorialChart> {
    let mut out = TutorialChart {
        timed: true,
        ..Default::default()
    };
    for (t, chart) in tutorials {
        if let Some(j) = t.judge {
            out.judge = JudgeWindow {
                perfect_ms: f64::from(j.perfect_ms),
                miss_ms: f64::from(j.good_ms) * 4.0,
            };
        }
        let events = match (t.mode, chart) {
            (TutorialMode::Timed, Some(c)) => {
                out.bpm = out.bpm.or(t.tempo.map(|x| x.target)).or(Some(c.bpm));
                chart_events(doc, c)
            }
            _ => {
                // 只规定顺序：每步间隔 1 秒
                let mut ev = Vec::new();
                for (i, s) in t.steps.iter().enumerate() {
                    let time = i as f64;
                    if let Some(b) = s.bank.as_deref() {
                        ev.push(TutorialEvent {
                            time_secs: time,
                            target: TutorialTarget::Page {
                                bank: if b == "B" { Bank::B } else { Bank::A },
                            },
                            color: None,
                            action: TutorialAction::Tap,
                        });
                    }
                    for k in &s.pads {
                        if let Some((target, color)) = note_to_target(doc, *k) {
                            ev.push(TutorialEvent {
                                time_secs: time,
                                target,
                                color,
                                action: TutorialAction::Tap,
                            });
                        }
                    }
                }
                if t.mode == TutorialMode::Sequence {
                    out.timed = false;
                }
                ev
            }
        };
        if t.extra.contains_key("lesson") {
            let get = |k: &str| {
                t.extra
                    .get(k)
                    .and_then(serde_json::Value::as_f64)
                    .unwrap_or(0.0)
            };
            out.lessons.push(TutorialLesson {
                events,
                duration_secs: get("duration"),
                song_start_secs: get("midStartTime"),
            });
        } else {
            out.events.extend(events);
        }
    }
    out.events
        .sort_by(|a, b| a.time_secs.total_cmp(&b.time_secs));
    (!out.is_empty()).then_some(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kit::ChokeMode;

    fn doc() -> KitDoc {
        let mut d = KitDoc::new("k", "Kit");
        d.tempo = Some(KitTempo {
            bpm: 92.0,
            time_signature: [4, 4],
        });
        let mut hh = PadDoc::new(PadAddr::from_flat(2));
        hh.choke_group = Some(4);
        hh.choked_by = Some(3);
        hh.choke_mode = ChokeMode::Time(0.03);
        let mut l1 = SampleLayer::new("samples/a.wav");
        l1.sample_id = Some("a".repeat(64));
        l1.hivel = 100;
        let mut l2 = SampleLayer::new("samples/b.wav");
        l2.sample_id = Some("b".repeat(64));
        l2.lovel = 101;
        hh.layers = vec![l1, l2];
        hh.gain_db = -6.0;
        hh.color = PadColor::Hex("#F09010".into());
        let mut lp = PadDoc::new(PadAddr::from_flat(12));
        lp.kind = PadKind::Loop;
        lp.launch.mode = LaunchMode::Toggle;
        lp.launch.quantize = Quantize::Bar;
        lp.tempo = Some(LoopTempo {
            bpm: 92.0,
            beats: Some(16.0),
            time_signature: [4, 4],
            stretch: Stretch::Beats,
        });
        d.pads = vec![hh, lp];
        d.pad_count = 24;
        d
    }

    #[test]
    fn forward_mapping() {
        let m = to_model(&doc(), None);
        assert_eq!(m.pads.len(), 2);
        let hh = &m.pads[0];
        assert_eq!(hh.choke_group, Some(3));
        assert!((hh.gain - 0.501).abs() < 0.01);
        assert_eq!(hh.color, MColor::Orange);
        assert_eq!(
            hh.sample.as_ref().unwrap().path.as_deref(),
            Some("samples/a.wav")
        );
        let lp = &m.pads[1];
        assert_eq!(lp.mode, PadMode::Loop);
        assert_eq!(lp.quantize, Some(MQuantize::Bar));
        assert_eq!(lp.loop_meta.unwrap().beats, Some(16.0));
        assert!(m.validate().is_ok());
    }

    #[test]
    fn identity_edit_preserves_extra_layers_and_choke() {
        let base = doc();
        let mut merged = base.clone();
        apply_model(&mut merged, &to_model(&base, None));
        let hh = merged.pad(PadAddr::from_flat(2)).unwrap();
        assert_eq!(hh.layers.len(), 2, "第二个力度层不能丢");
        assert_eq!((hh.choke_group, hh.choked_by), (Some(4), Some(3)));
        assert!((hh.gain_db + 6.0).abs() < 1e-3);
        assert_eq!(
            merged.pad(PadAddr::from_flat(12)).unwrap().tempo,
            base.pads[1].tempo
        );
    }

    #[test]
    fn edits_are_applied() {
        let base = doc();
        let mut m = to_model(&base, None);
        m.name = "Edited".into();
        m.pads[0].choke_group = Some(9);
        m.pads[0].time_ratio = 1.5;
        m.pads[0].pitch_semitones = -2.5;
        m.pads[0].sample = Some(SampleRef {
            id: SampleId::new("c".repeat(64)),
            name: "mic".into(),
            blake3: Some("c".repeat(64)),
            ..Default::default()
        });
        m.pads.remove(1);
        let mut np = up_model::PadDoc::new(PadId::from_flat(0).unwrap());
        np.mode = PadMode::Gate;
        m.pads.push(np);
        let mut merged = base.clone();
        apply_model(&mut merged, &m);
        assert_eq!(merged.name, "Edited");
        assert_eq!(merged.pads.len(), 2);
        let hh = merged.pad(PadAddr::from_flat(2)).unwrap();
        assert_eq!((hh.choke_group, hh.choked_by), (Some(9), Some(9)));
        assert_eq!(hh.layers.len(), 1);
        assert_eq!(hh.layers[0].sample, "samples/mic.wav");
        assert_eq!((hh.layers[0].transpose, hh.layers[0].tune_cents), (-2, -50));
        assert_eq!(hh.extra["timeRatio"], 1.5);
        let gate = merged.pad(PadAddr::from_flat(0)).unwrap();
        assert_eq!(gate.launch.mode, LaunchMode::Gate);
        assert!(gate.layers.is_empty());
    }

    #[test]
    fn tutorials_become_chart() {
        let d = doc();
        let chart = Chart {
            bpm: 120.0,
            markers: vec![crate::smf::Marker {
                tick: 0,
                text: "Page B".into(),
            }],
            notes: vec![crate::smf::NoteEvent {
                tick: 960,
                duration: 10,
                channel: 0,
                key: 48,
                velocity: 64,
            }],
            ..Chart::default()
        };
        let t = TutorialDoc {
            id: "t".into(),
            title: Default::default(),
            mode: TutorialMode::Timed,
            chart: Some("chart.mid".into()),
            tempo: None,
            judge: None,
            video_url: None,
            steps: vec![],
            extra: Default::default(),
        };
        let c = tutorial_chart(&d, &[(t, Some(chart))]).unwrap();
        assert!(c.timed);
        assert_eq!(c.events.len(), 2);
        assert_eq!(c.events[1].time_secs, 1.0);
        assert_eq!(c.events[1].action, TutorialAction::LoopToggle);
        assert!(matches!(c.events[1].target, TutorialTarget::Pad { pad } if pad.flat() == 12));
    }
}
