//! [`KitDoc`]（格式层，完整表达 `.upkit`）↔ [`up_model::KitDoc`]（引擎/FFI/UI 使用的文档）的映射。
//!
//! up-model 现在覆盖了格式层的 pad 语义（多采样层/力度层/轮替、loop 点、非对称 choke 与释放方式、
//! 自截断、重触发方式、细粒度量化、拉伸策略、Kit 描述/主题色/来源），因此两边基本一一映射：
//! - 正向 [`to_model`]：直接映射；`gain_db` → 线性 `gain`；`up_model::PadDoc::sample` 镜像第一个采样层
//! - 反向 [`apply_model`]：把编辑结果合并到原 `KitDoc` 上；模型的 `layers` 为权威，若 UI 只改了
//!   主采样（`sample` 与 `layers[0]` 不一致）则替换为单层；`timeRatio`、`fadeInMs`、`fadeOutMs`
//!   存进 pad 的扩展字段（`ultrapads-kit.json`）

use up_core::{
    Bank, ColorRole as MColor, KitId, PadId, PadMode, Quantize as MQuantize,
    Retrigger as MRetrigger, SampleId,
};
use up_model::{
    ChokeRelease, JudgeWindow, KitSource as MKitSource, LoopMeta, SampleRef, Stretch as MStretch,
    TimeSignature, TutorialAction, TutorialChart, TutorialEvent, TutorialLesson, TutorialTarget,
};

use crate::kit::{
    ChokeMode, ColorRole, KitDoc, KitSource, KitTempo, LaunchMode, LoopTempo, PadAddr, PadColor,
    PadDoc, PadKind, Quantize, Retrigger, SampleLayer, Stretch,
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
            ColorRole::Green => MColor::Green,
            ColorRole::Lime => MColor::Lime,
            ColorRole::Orange => MColor::Orange,
            ColorRole::Pink => MColor::Pink,
            ColorRole::Aqua => MColor::Cyan,
            ColorRole::Red => MColor::Red,
            ColorRole::Purple => MColor::Purple,
            ColorRole::Yellow => MColor::Yellow,
            ColorRole::Grey => MColor::Grey,
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
        MColor::Lime => ColorRole::Lime,
        MColor::Grey | MColor::Neutral => ColorRole::Grey,
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
        Quantize::Sixteenth => Some(MQuantize::Sixteenth),
        Quantize::Eighth => Some(MQuantize::Eighth),
        // 拍 = 四分音符
        Quantize::Quarter | Quantize::Beat => Some(MQuantize::Beat),
        Quantize::Bar => Some(MQuantize::Bar),
        Quantize::TwoBars => Some(MQuantize::TwoBars),
        Quantize::FourBars => Some(MQuantize::FourBars),
    }
}

fn quantize_from_model(q: Option<MQuantize>, kind: PadKind, prev: Quantize) -> Quantize {
    match q {
        Some(MQuantize::None) => Quantize::None,
        Some(MQuantize::Sixteenth) => Quantize::Sixteenth,
        Some(MQuantize::Eighth) => Quantize::Eighth,
        // 保留原文件是 `1/4` 还是 `1beat` 的写法
        Some(MQuantize::Beat) if prev == Quantize::Quarter => Quantize::Quarter,
        Some(MQuantize::Beat) => Quantize::Beat,
        Some(MQuantize::Bar) => Quantize::Bar,
        Some(MQuantize::TwoBars) => Quantize::TwoBars,
        Some(MQuantize::FourBars) => Quantize::FourBars,
        None if kind == PadKind::Loop => Quantize::Global,
        None => Quantize::None,
    }
}

fn stretch_to_model(s: Stretch) -> MStretch {
    match s {
        Stretch::None => MStretch::None,
        Stretch::Beats => MStretch::Beats,
        Stretch::Repitch => MStretch::Repitch,
    }
}

fn stretch_from_model(s: MStretch) -> Stretch {
    match s {
        MStretch::None => Stretch::None,
        MStretch::Beats => Stretch::Beats,
        MStretch::Repitch => Stretch::Repitch,
    }
}

fn choke_to_model(m: ChokeMode) -> ChokeRelease {
    match m {
        ChokeMode::Fast => ChokeRelease::Fast,
        ChokeMode::Normal => ChokeRelease::Normal,
        ChokeMode::Time(secs) => ChokeRelease::Time { secs },
    }
}

fn choke_from_model(m: ChokeRelease) -> ChokeMode {
    match m {
        ChokeRelease::Fast => ChokeMode::Fast,
        ChokeRelease::Normal => ChokeMode::Normal,
        ChokeRelease::Time { secs } => ChokeMode::Time(secs),
    }
}

fn group_to_model(g: Option<u32>) -> Option<u8> {
    g.and_then(|g| u8::try_from(g).ok())
}

fn layer_to_model(l: &SampleLayer) -> up_model::SampleLayer {
    up_model::SampleLayer {
        sample: SampleRef {
            id: SampleId::new(l.sample_id.clone().unwrap_or_default()),
            path: Some(l.sample.clone()),
            name: crate::path::file_stem(&l.sample).to_string(),
            blake3: l.sample_id.clone(),
            ..Default::default()
        },
        lovel: l.lovel,
        hivel: l.hivel,
        seq_position: l.seq_position,
        rand_range: l.rand_range,
        root_key: l.root_key,
        start_frame: l.start_frame,
        end_frame: l.end_frame,
        loop_start: l.loop_start,
        loop_end: l.loop_end,
        transpose: l.transpose,
        tune_cents: l.tune_cents,
        volume_db: l.volume_db,
    }
}

fn layer_from_model(l: &up_model::SampleLayer) -> SampleLayer {
    let s = &l.sample;
    let hash = s
        .blake3
        .clone()
        .or_else(|| (!s.id.as_str().is_empty()).then(|| s.id.as_str().to_string()));
    let path = s
        .path
        .clone()
        .unwrap_or_else(|| format!("samples/{}.wav", crate::path::slug(&s.name)));
    let mut out = SampleLayer::new(path);
    out.sample_id = hash;
    out.lovel = l.lovel;
    out.hivel = l.hivel;
    out.seq_position = l.seq_position;
    out.rand_range = l.rand_range;
    out.root_key = l.root_key;
    out.start_frame = l.start_frame;
    out.end_frame = l.end_frame;
    out.loop_start = l.loop_start;
    out.loop_end = l.loop_end;
    out.transpose = l.transpose;
    out.tune_cents = l.tune_cents;
    out.volume_db = l.volume_db;
    out
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
        group_count: doc.pad_count.div_ceil(crate::kit::PADS_PER_BANK).max(1),
        ..Default::default()
    };
    m.meta.description = doc.description.clone();
    m.meta.theme_color = doc.theme_color.clone();
    m.meta.author = (!doc.authors.is_empty()).then(|| doc.authors.join(", "));
    m.meta.genre = doc.genres.clone();
    m.meta.tags = doc.tags.clone();
    m.meta.cover = doc.cover.clone();
    m.meta.license = doc.license.clone();
    if let Some(src) = &doc.source {
        m.meta.source = Some(MKitSource {
            kind: src.kind.clone(),
            original_id: src.original_id.clone(),
            original_name: src.original_name.clone(),
        });
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
        mp.choke_group = group_to_model(p.choke_group);
        mp.choked_by = group_to_model(p.choked_by);
        mp.choke_release = choke_to_model(p.choke_mode);
        mp.self_choke = p.self_choke;
        mp.retrigger = match p.launch.retrigger {
            Retrigger::Restart => MRetrigger::Restart,
            Retrigger::Continue => MRetrigger::Continue,
        };
        mp.exclusive = p.exclusive.clone();
        mp.color = color_to_model(&p.color);
        mp.quantize = quantize_to_model(p.launch.quantize);
        mp.seq_length = p.seq_length;
        mp.time_ratio = ext_f32(p, EXT_TIME_RATIO, 1.0).clamp(0.5, 2.0);
        mp.fade_in_ms = ext_f32(p, EXT_FADE_IN, 0.0);
        mp.fade_out_ms = ext_f32(p, EXT_FADE_OUT, 0.0);
        mp.layers = p.layers.iter().map(layer_to_model).collect();
        mp.normalize();
        if let Some(l) = p.layers.first() {
            mp.pitch_semitones =
                (l.transpose as f32 + l.tune_cents as f32 / 100.0).clamp(-12.0, 12.0);
        }
        if p.tempo.is_some() || p.layers.first().and_then(|l| l.root_key).is_some() {
            mp.loop_meta = Some(LoopMeta {
                bpm: p.tempo.map(|t| t.bpm),
                beats: p.tempo.and_then(|t| t.beats),
                root_note: p.layers.first().and_then(|l| l.root_key),
                time_signature: p.tempo.map(|t| TimeSignature {
                    numerator: u32::from(t.time_signature[0]),
                    denominator: u32::from(t.time_signature[1]),
                }),
                stretch: p
                    .tempo
                    .map(|t| stretch_to_model(t.stretch))
                    .unwrap_or_default(),
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
    if m.meta.description.is_some() {
        base.description = m.meta.description.clone();
    }
    if m.meta.theme_color.is_some() {
        base.theme_color = m.meta.theme_color.clone();
    }
    if let Some(src) = &m.meta.source {
        let inspired = base.source.as_ref().and_then(|s| s.inspired_by.clone());
        base.source = Some(KitSource {
            kind: src.kind.clone(),
            original_id: src.original_id.clone(),
            original_name: src.original_name.clone(),
            inspired_by: inspired,
        });
    }
    if !m.meta.genre.is_empty() || !base.genres.is_empty() {
        base.genres = m.meta.genre.clone();
    }
    base.tags = m.meta.tags.clone();
    if m.meta.license.is_some() {
        base.license = m.meta.license.clone();
    }
    base.pad_count = m.groups() * crate::kit::PADS_PER_BANK;
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
        p.launch.quantize = quantize_from_model(mp.quantize, kind, p.launch.quantize);
        p.launch.retrigger = match mp.retrigger {
            MRetrigger::Restart => Retrigger::Restart,
            MRetrigger::Continue => Retrigger::Continue,
        };
        p.gain_db = linear_to_db(mp.gain);
        p.pan = mp.pan.clamp(-1.0, 1.0);
        p.choke_group = mp.choke_group.map(u32::from);
        p.choked_by = mp.choked_by.map(u32::from);
        p.choke_mode = choke_from_model(mp.choke_release);
        p.self_choke = mp.self_choke;
        p.exclusive = mp.exclusive.clone();
        p.seq_length = mp.seq_length;
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
        // 采样层：`layers` 为权威；UI 只改了主采样时替换为单层。
        let primary_changed = match (&mp.sample, mp.layers.first()) {
            (Some(s), Some(l)) => s.id != l.sample.id,
            (None, Some(_)) => true,
            _ => false,
        };
        let mut layers: Vec<SampleLayer> = if mp.layers.is_empty() || primary_changed {
            match &mp.sample {
                None => Vec::new(),
                Some(s) => {
                    let mut l = up_model::SampleLayer::new(s.clone());
                    l.start_frame = (mp.start_frame > 0).then_some(mp.start_frame);
                    l.end_frame = mp.end_frame.map(|e| e.saturating_sub(1));
                    if let Some(old) = mp.layers.first() {
                        l.loop_start = old.loop_start;
                        l.loop_end = old.loop_end;
                    }
                    vec![layer_from_model(&l)]
                }
            }
        } else {
            mp.layers.iter().map(layer_from_model).collect()
        };
        if let Some(l) = layers.first_mut() {
            // 编辑器的主层修剪与音高
            l.start_frame = (mp.start_frame > 0).then_some(mp.start_frame);
            l.end_frame = mp.end_frame.map(|e| e.saturating_sub(1));
            let semis = mp.pitch_semitones.clamp(-12.0, 12.0);
            l.transpose = semis.trunc() as i32;
            l.tune_cents = ((semis - semis.trunc()) * 100.0).round() as i32;
        }
        p.layers = layers;
        if let Some(lm) = mp.loop_meta {
            if let Some(bpm) = lm.bpm {
                let prev = p.tempo;
                p.tempo = Some(LoopTempo {
                    bpm,
                    beats: lm.beats,
                    time_signature: lm
                        .time_signature
                        .and_then(|t| {
                            Some([
                                u8::try_from(t.numerator).ok()?,
                                u8::try_from(t.denominator).ok()?,
                            ])
                        })
                        .or(prev.map(|t| t.time_signature))
                        .unwrap_or(ts),
                    stretch: stretch_from_model(lm.stretch),
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
        assert_eq!((hh.choke_group, hh.choked_by), (Some(4), Some(3)));
        assert_eq!(hh.choke_release, ChokeRelease::Time { secs: 0.03 });
        assert_eq!(hh.layers.len(), 2, "力度层直接映射");
        assert_eq!(hh.layers[1].lovel, 101);
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
    fn sound_groups_roundtrip_and_editor_can_add_or_remove_groups() {
        let base = doc(); // 24 个 pad 的布局（A、B 两组）
        let mut m = to_model(&base, None);
        assert_eq!(m.group_count, 2);
        assert_eq!(m.groups(), 2);

        // 编辑器新增一个空的 C 组：布局扩到 36，kit.json 列出 A/B/C
        m.group_count = 3;
        let mut merged = base.clone();
        apply_model(&mut merged, &m);
        assert_eq!(merged.pad_count, 36);
        merged.validate().unwrap();
        assert_eq!(to_model(&merged, None).groups(), 3);
        let json = crate::kit_json::KitJson::new(merged.pad_count);
        assert_eq!(json.layout.banks, ["A", "B", "C"]);

        // 删除空的 C 组：回到 24
        m.group_count = 2;
        apply_model(&mut merged, &m);
        assert_eq!(merged.pad_count, 24);

        // 有声音的 pad 所在的组不会被删掉
        m.group_count = 1;
        apply_model(&mut merged, &m);
        assert_eq!(merged.pad_count, 24, "B 组还有 pad，组数至少为 2");
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
        assert_eq!((hh.choke_group, hh.choked_by), (Some(9), Some(3)));
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
