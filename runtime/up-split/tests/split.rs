//! 端到端：合成一首 24 小节的歌 → 用假分轨后端拆分 → 校验排布（每组一个段落、组内一个乐器）并能打成合法的 .upkit。

use std::collections::BTreeMap;

use up_codec::AudioBuffer;
use up_format::upkit::{BuildOptions, UpkitPackage};
use up_split::{Progress, Result, Separator, SplitOptions, StemKind, Stereo, split_song};

const SR: u32 = 44_100;

/// 鼓：每拍一个噪声脉冲 + 每小节第 1 拍底鼓；贝斯：低频正弦。返回立体声交错数据。
fn song(bpm: f64, bars: usize, offset: f64) -> Vec<f32> {
    let sr = f64::from(SR);
    let n = ((bars as f64 * 240.0 / bpm + offset) * sr) as usize;
    let mut m = vec![0.0f32; n];
    let mut seed = 7u32;
    let beat = 60.0 / bpm;
    for i in 0.. {
        let a = ((offset + i as f64 * beat) * sr) as usize;
        if a + 3000 >= n {
            break;
        }
        for j in 0..600 {
            seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
            let noise = (seed >> 16) as f32 / 32768.0 - 1.0;
            m[a + j] += noise * 0.4 * (-(j as f32) / 150.0).exp();
        }
        if i % 4 == 0 {
            for j in 0..3000 {
                let ph = std::f32::consts::TAU * 55.0 * j as f32 / SR as f32;
                m[a + j] += 0.6 * ph.sin() * (-(j as f32) / 900.0).exp();
            }
        }
    }
    // 后半首加一层和弦，让段落之间有差别
    for (i, v) in m.iter_mut().enumerate().skip(n / 2) {
        *v += 0.1 * (std::f32::consts::TAU * 220.0 * i as f32 / SR as f32).sin();
    }
    m.iter().flat_map(|v| [*v, *v]).collect()
}

/// 假的分轨后端：鼓 = 输入，贝斯 = 输入的一半，证明 `Separator` 是可插拔的。
struct Fake;

impl Separator for Fake {
    fn name(&self) -> &str {
        "fake"
    }
    fn stems(&self) -> &[StemKind] {
        &[StemKind::Drums, StemKind::Bass]
    }
    fn memory_mb(&self, _: usize) -> u64 {
        1
    }
    fn separate(&self, input: &Stereo, progress: Progress<'_>) -> Result<Vec<Stereo>> {
        progress(1.0);
        let half = Stereo {
            l: input.l.iter().map(|v| v * 0.5).collect(),
            r: input.r.iter().map(|v| v * 0.5).collect(),
        };
        Ok(vec![input.clone(), half])
    }
}

fn pack(out: &up_split::SplitOutcome) {
    let pkg = UpkitPackage::build(
        &out.kit.doc,
        out.kit.assets.clone(),
        &BuildOptions::default(),
    )
    .expect("打包");
    let loaded = pkg.read(&Default::default()).expect("读取");
    assert!(loaded.warnings.is_empty(), "{:?}", loaded.warnings);
}

#[test]
fn stems_become_pads_and_sections_become_groups() {
    let buf = AudioBuffer::new(SR, 2, song(100.0, 24, 0.4));
    let opts = SplitOptions {
        title: "Test",
        separator: Some(&Fake),
        ..Default::default()
    };
    let out = split_song(&buf, &opts, &mut |_, _| true).expect("拆分");
    assert!((out.grid.bpm - 100.0).abs() < 0.5, "{:?}", out.grid);
    assert!(out.separated);
    assert!(!out.sections.is_empty() && out.sections.len() <= 6);
    let pads = &out.kit.doc.pads;
    let groups: BTreeMap<u8, Vec<_>> = pads.iter().fold(BTreeMap::new(), |mut m, p| {
        m.entry(p.addr.bank).or_default().push(p);
        m
    });
    assert_eq!(groups.len(), out.sections.len());
    for g in groups.values() {
        assert_eq!(g.len(), 2, "每组一个段落：鼓 + 贝斯各一个 pad");
        assert_eq!(g[0].addr.index, 0);
        assert_eq!(g[1].addr.index, 1);
        assert_ne!(g[0].exclusive, g[1].exclusive, "同组乐器之间不互斥");
    }
    // 同一乐器跨组互斥
    assert_eq!(groups[&0][0].exclusive, groups[&1][0].exclusive);
    pack(&out);
}

#[test]
fn mix_only_gets_whole_section_plus_fragments() {
    let buf = AudioBuffer::new(SR, 2, song(120.0, 16, 0.0));
    let out = split_song(&buf, &SplitOptions::default(), &mut |_, _| true).expect("拆分");
    assert!(!out.separated);
    let per_group = 1 + 6;
    assert_eq!(out.kit.doc.pads.len(), out.sections.len() * per_group);
    pack(&out);
}

#[test]
fn cancel_stops_the_split() {
    let buf = AudioBuffer::new(SR, 2, song(100.0, 24, 0.0));
    let err = split_song(&buf, &SplitOptions::default(), &mut |_, _| false)
        .err()
        .expect("应取消");
    assert!(matches!(err, up_split::SplitError::Cancelled));
}

#[test]
fn too_short_is_reported() {
    let buf = AudioBuffer::new(SR, 2, song(100.0, 2, 0.0));
    assert!(split_song(&buf, &SplitOptions::default(), &mut |_, _| true).is_err());
}
