//! `up-catalog-pack` — 曲库入库管线的 Rust 侧工具（Python 管线调用）。
//!
//! ```text
//! up-catalog-pack pack   --dir <kit 目录> --out <x.upkit> [--timestamp 2026-10-18T00:00:00Z]
//! up-catalog-pack verify <x.upkit>          # 导入临时曲库并逐个解码样本，输出 JSON 摘要
//! up-catalog-pack render --sf2 <x.sf2> --jobs jobs.json [--threads 4] [--sample-rate 44100]
//! ```
//!
//! `pack` 的 `<kit 目录>` 里 `kit.json` 是 `up_format::kit::KitDoc`（camelCase），其余文件按相对路径原样进包。
//! `render` 的 jobs 是 `[{ "midi": "a.mid", "out": "a.f32", "secs": 12.5 }]`，输出为交错立体声 f32le 原始样本。

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::Arc;

use clap::{Parser, Subcommand};
use rustysynth::{MidiFile, MidiFileSequencer, SoundFont, Synthesizer, SynthesizerSettings};
use serde::Deserialize;
use up_format::kit::KitDoc;
use up_format::upkit::{BuildOptions, UpkitPackage};

type Res<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

#[derive(Parser)]
#[command(
    name = "up-catalog-pack",
    version,
    about = "UltraPads catalog pipeline helper"
)]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// 把 kit 目录打成 .upkit。
    Pack {
        #[arg(long)]
        dir: PathBuf,
        #[arg(long)]
        out: PathBuf,
        /// 写入 manifest 的 created/updated（缺省为固定值，保证产物可复现）。
        #[arg(long, default_value = "2026-10-18T00:00:00Z")]
        timestamp: String,
    },
    /// 导入 .upkit 到临时曲库并解码全部样本，输出 JSON 摘要。
    Verify { file: PathBuf },
    /// 列出 SoundFont 的预设（bank patch name）。
    Presets {
        #[arg(long)]
        sf2: PathBuf,
    },
    /// 用 SoundFont 批量渲染 MIDI 为 f32le 原始立体声样本。
    Render {
        #[arg(long)]
        sf2: PathBuf,
        #[arg(long)]
        jobs: PathBuf,
        #[arg(long, default_value_t = 4)]
        threads: usize,
        #[arg(long, default_value_t = 44_100)]
        sample_rate: i32,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let res = match cli.cmd {
        Cmd::Pack {
            dir,
            out,
            timestamp,
        } => pack(&dir, &out, &timestamp),
        Cmd::Verify { file } => verify(&file),
        Cmd::Presets { sf2 } => presets(&sf2),
        Cmd::Render {
            sf2,
            jobs,
            threads,
            sample_rate,
        } => render(&sf2, &jobs, threads, sample_rate),
    };
    match res {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::FAILURE
        }
    }
}

// ---------------------------------------------------------------- pack

fn collect(dir: &Path, base: &Path, out: &mut BTreeMap<String, Vec<u8>>) -> Res<()> {
    let mut entries: Vec<_> = std::fs::read_dir(dir)?.collect::<Result<_, _>>()?;
    entries.sort_by_key(|e| e.file_name());
    for e in entries {
        let path = e.path();
        if e.file_type()?.is_dir() {
            collect(&path, base, out)?;
        } else {
            let rel = path
                .strip_prefix(base)?
                .to_string_lossy()
                .replace('\\', "/");
            if rel == "kit.json" {
                continue;
            }
            out.insert(rel, std::fs::read(&path)?);
        }
    }
    Ok(())
}

/// 把 `dir` 打成 `.upkit` 字节。
pub fn pack_dir(dir: &Path, timestamp: &str) -> Res<Vec<u8>> {
    let doc: KitDoc = serde_json::from_slice(&std::fs::read(dir.join("kit.json"))?)?;
    let mut assets = BTreeMap::new();
    collect(dir, dir, &mut assets)?;
    let opts = BuildOptions {
        created: Some(timestamp.into()),
        updated: Some(timestamp.into()),
        generator: Some("UltraPads catalog pipeline".into()),
    };
    let pkg = UpkitPackage::build(&doc, assets, &opts)?;
    let loaded = pkg.read(&Default::default())?;
    if !loaded.warnings.is_empty() {
        return Err(format!("包有警告：{:?}", loaded.warnings).into());
    }
    Ok(up_library::archive::zip_to_vec(&pkg.zip_entries())?)
}

fn pack(dir: &Path, out: &Path, timestamp: &str) -> Res<()> {
    let bytes = pack_dir(dir, timestamp)?;
    if let Some(parent) = out.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(out, &bytes)?;
    println!("{}  {} bytes", out.display(), bytes.len());
    Ok(())
}

// ---------------------------------------------------------------- verify

/// 导入 `.upkit` 字节到临时曲库，解码所有样本，返回摘要。
pub fn verify_bytes(name: &str, bytes: &[u8]) -> Res<serde_json::Value> {
    let tmp = std::env::temp_dir().join(format!(
        "up-catalog-verify-{}-{}",
        std::process::id(),
        bytes.len()
    ));
    let _ = std::fs::remove_dir_all(&tmp);
    let lib = up_library::Library::open(&tmp)?;
    let report = lib.import_zip_bytes(name, bytes)?;
    let kit = report.kits.first().ok_or("导入后没有 Kit")?;
    let loaded = lib.load_kit_assets_with(
        &kit.kit_id,
        &up_library::LoadOptions {
            decode: true,
            mark_used: false,
        },
    )?;
    let mut samples = 0usize;
    let mut total_secs = 0f64;
    for (path, s) in &loaded.samples {
        // 引擎按内容嗅探 blob（无扩展名）：这里同样不给扩展名提示
        let blob = std::fs::read(&s.file)?;
        let buf =
            up_codec::decode_bytes(blob, None).map_err(|e| format!("{path}：引擎无法解码：{e}"))?;
        let frames = buf.data.len() / usize::from(buf.channels.max(1));
        if frames == 0 {
            return Err(format!("{path}：解码后为空").into());
        }
        total_secs += frames as f64 / f64::from(buf.sample_rate);
        samples += 1;
    }
    let pads_with_sound = loaded
        .model
        .pads
        .iter()
        .filter(|p| p.sample.is_some())
        .count();
    let summary = serde_json::json!({
        "kit_id": kit.kit_id,
        "name": kit.name,
        "pad_count": pads_with_sound,
        "group_count": loaded.model.groups(),
        "samples": samples,
        "audio_secs": total_secs,
        "bytes": bytes.len(),
        "warnings": loaded.warnings.len() + report.warnings.len(),
    });
    let _ = std::fs::remove_dir_all(&tmp);
    Ok(summary)
}

fn verify(file: &Path) -> Res<()> {
    let bytes = std::fs::read(file)?;
    let name = file
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "kit.upkit".into());
    println!("{}", serde_json::to_string(&verify_bytes(&name, &bytes)?)?);
    Ok(())
}

// ---------------------------------------------------------------- render

fn presets(sf2: &Path) -> Res<()> {
    let mut f = std::fs::File::open(sf2)?;
    let font = SoundFont::new(&mut f)?;
    for p in font.get_presets() {
        println!(
            "{} {} {}",
            p.get_bank_number(),
            p.get_patch_number(),
            p.get_name()
        );
    }
    Ok(())
}

#[derive(Deserialize)]
struct Job {
    midi: PathBuf,
    out: PathBuf,
    secs: f64,
}

fn render_one(font: &Arc<SoundFont>, rate: i32, job: &Job) -> Res<()> {
    let mut f = std::fs::File::open(&job.midi)?;
    let midi = Arc::new(MidiFile::new(&mut f)?);
    let settings = SynthesizerSettings::new(rate);
    let synth = Synthesizer::new(font, &settings)?;
    let mut seq = MidiFileSequencer::new(synth);
    seq.play(&midi, false);
    let n = (job.secs * f64::from(rate)).round() as usize;
    let mut left = vec![0f32; n];
    let mut right = vec![0f32; n];
    seq.render(&mut left, &mut right);
    let mut raw = Vec::with_capacity(n * 8);
    for i in 0..n {
        raw.extend_from_slice(&left[i].to_le_bytes());
        raw.extend_from_slice(&right[i].to_le_bytes());
    }
    if let Some(parent) = job.out.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(&job.out, raw)?;
    Ok(())
}

fn render(sf2: &Path, jobs: &Path, threads: usize, rate: i32) -> Res<()> {
    let mut f = std::fs::File::open(sf2)?;
    let font = Arc::new(SoundFont::new(&mut f)?);
    let jobs: Vec<Job> = serde_json::from_slice(&std::fs::read(jobs)?)?;
    let jobs = Arc::new(jobs);
    let next = Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let mut handles = Vec::new();
    for _ in 0..threads.max(1) {
        let (font, jobs, next) = (font.clone(), jobs.clone(), next.clone());
        handles.push(std::thread::spawn(move || -> Res<()> {
            loop {
                let i = next.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                let Some(job) = jobs.get(i) else {
                    return Ok(());
                };
                render_one(&font, rate, job).map_err(|e| format!("{}：{e}", job.midi.display()))?;
            }
        }));
    }
    for h in handles {
        h.join().map_err(|_| "渲染线程崩溃")??;
    }
    println!("rendered {} jobs", jobs.len());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use up_format::kit::{
        ColorRole, Launch, LaunchMode, LoopTempo, PadAddr, PadColor, PadDoc, PadKind, Quantize,
        Retrigger, SampleLayer, Stretch,
    };

    /// 手写一个最小 FLAC（16 位单声道，固定预测器 0 的 verbatim 子帧），避免依赖外部编码器。
    pub(crate) fn tiny_flac(rate: u32, samples: &[i16]) -> Vec<u8> {
        struct Bits {
            out: Vec<u8>,
            acc: u64,
            n: u32,
        }
        impl Bits {
            fn put(&mut self, v: u64, bits: u32) {
                if bits > 32 {
                    self.put(v >> 32, bits - 32);
                    self.put(v, 32);
                    return;
                }
                self.acc = (self.acc << bits) | (v & ((1u64 << bits) - 1));
                self.n += bits;
                while self.n >= 8 {
                    self.n -= 8;
                    self.out.push((self.acc >> self.n) as u8);
                }
                self.acc &= (1u64 << self.n) - 1;
            }
            fn align(&mut self) {
                if self.n > 0 {
                    self.put(0, 8 - self.n);
                }
            }
        }
        fn crc8(d: &[u8]) -> u8 {
            let mut c = 0u8;
            for &b in d {
                c ^= b;
                for _ in 0..8 {
                    c = if c & 0x80 != 0 {
                        (c << 1) ^ 0x07
                    } else {
                        c << 1
                    };
                }
            }
            c
        }
        fn crc16(d: &[u8]) -> u16 {
            let mut c = 0u16;
            for &b in d {
                c ^= u16::from(b) << 8;
                for _ in 0..8 {
                    c = if c & 0x8000 != 0 {
                        (c << 1) ^ 0x8005
                    } else {
                        c << 1
                    };
                }
            }
            c
        }
        let n = samples.len() as u64;
        let mut f = b"fLaC".to_vec();
        let mut b = Bits {
            out: vec![],
            acc: 0,
            n: 0,
        };
        b.put(1, 1); // last metadata block
        b.put(0, 7); // STREAMINFO
        b.put(34, 24);
        b.put(n, 16);
        b.put(n, 16);
        b.put(0, 24);
        b.put(0, 24);
        b.put(u64::from(rate), 20);
        b.put(0, 3); // 1 声道
        b.put(15, 5); // 16 位
        b.put(n, 36);
        b.put(0, 64);
        b.put(0, 64);
        f.extend(b.out);
        // 单个帧：块大小 = n（blocksize code 7 = 16 位 n-1）
        let mut hdr = Bits {
            out: vec![],
            acc: 0,
            n: 0,
        };
        hdr.put(0x3FFE, 14);
        hdr.put(0, 1);
        hdr.put(0, 1);
        hdr.put(7, 4); // 块大小 16 位
        hdr.put(0, 4); // 采样率取自 STREAMINFO
        hdr.put(0, 4); // 1 声道独立
        hdr.put(4, 3); // 16 位
        hdr.put(0, 1);
        hdr.put(0, 8); // 帧号 0
        hdr.put(n - 1, 16);
        hdr.align();
        let mut frame = hdr.out;
        frame.push(crc8(&frame));
        let mut body = Bits {
            out: vec![],
            acc: 0,
            n: 0,
        };
        body.put(0, 1);
        body.put(1, 6); // verbatim
        body.put(0, 1);
        for &s in samples {
            body.put(s as u16 as u64, 16);
        }
        body.align();
        frame.extend(body.out);
        let c = crc16(&frame);
        frame.extend(c.to_be_bytes());
        f.extend(frame);
        f
    }

    fn sine(frames: usize, hz: f32) -> Vec<i16> {
        (0..frames)
            .map(|i| ((i as f32 * hz * std::f32::consts::TAU / 44_100.0).sin() * 12_000.0) as i16)
            .collect()
    }

    fn kit_dir(dir: &Path, bpm: f64) {
        std::fs::create_dir_all(dir.join("samples")).unwrap();
        let mut doc = KitDoc::new("urn:uuid:00000000-0000-8000-8000-0000000000a1", "Test Song");
        doc.authors = vec!["Tester".into()];
        doc.license = Some("CC0-1.0".into());
        doc.pad_count = 24;
        for (i, hz) in [220.0f32, 330.0].into_iter().enumerate() {
            let file = format!("samples/loop{i}.flac");
            std::fs::write(dir.join(&file), tiny_flac(44_100, &sine(44_100, hz))).unwrap();
            let mut pad = PadDoc::new(PadAddr::from_flat(i as u8 * 12));
            pad.name = Some(format!("Loop {i}"));
            pad.color = PadColor::Role(ColorRole::Blue);
            pad.kind = PadKind::Loop;
            pad.launch = Launch {
                mode: LaunchMode::Toggle,
                quantize: Quantize::Bar,
                retrigger: Retrigger::Restart,
            };
            pad.tempo = Some(LoopTempo {
                bpm,
                beats: Some(4.0),
                time_signature: [4, 4],
                stretch: Stretch::Beats,
            });
            pad.layers.push(SampleLayer::new(file));
            doc.pads.push(pad);
        }
        std::fs::write(dir.join("kit.json"), serde_json::to_vec(&doc).unwrap()).unwrap();
    }

    /// 回归：.upkit 内放 FLAC 样本，`library_import` 之后样本仍可被引擎（按内容嗅探）解码，且 Kit 结构完整。
    #[test]
    fn flac_samples_survive_import() {
        let tmp = tempfile::tempdir().unwrap();
        kit_dir(tmp.path(), 120.0);
        let bytes = pack_dir(tmp.path(), "2026-10-18T00:00:00Z").unwrap();
        let summary = verify_bytes("test.upkit", &bytes).unwrap();
        assert_eq!(summary["samples"], 2);
        assert_eq!(summary["pad_count"], 2);
        assert_eq!(summary["group_count"], 2);
        assert!((summary["audio_secs"].as_f64().unwrap() - 2.0).abs() < 0.01);
    }

    #[test]
    fn pack_is_deterministic() {
        let tmp = tempfile::tempdir().unwrap();
        kit_dir(tmp.path(), 100.0);
        let a = pack_dir(tmp.path(), "2026-10-18T00:00:00Z").unwrap();
        let b = pack_dir(tmp.path(), "2026-10-18T00:00:00Z").unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn pack_rejects_missing_sample() {
        let tmp = tempfile::tempdir().unwrap();
        kit_dir(tmp.path(), 100.0);
        std::fs::remove_file(tmp.path().join("samples/loop1.flac")).unwrap();
        assert!(pack_dir(tmp.path(), "2026-10-18T00:00:00Z").is_err());
    }
}
