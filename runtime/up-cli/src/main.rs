//! `up-cli` — headless UltraPads tool.
//!
//! ```text
//! up-cli devices
//! up-cli render --kit-dir ./kit --events script.json --out out.wav
//! up-cli play --kit-dir ./kit --pad A0 [--pad B3] [--duration 2]
//! up-cli latency-probe [--kit-dir ./kit] [--iterations 20]
//! up-cli inspect out.wav
//! ```

use clap::{Parser, Subcommand, ValueEnum};
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::Arc;
use std::time::{Duration, Instant};
use up_core::{PadId, SampleId, UpError, UpResult};
use up_engine::{
    AudioProcessor, Command, Engine, EngineConfig, EngineHandle, GraphBackend, PadParams,
    RenderScript, SampleData, render_offline,
};
use up_host::{AudioConfig, AudioHost, apply_kit, load_folder_kit};

#[derive(Parser)]
#[command(name = "up-cli", version, about = "UltraPads headless tool")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Clone, Copy, ValueEnum)]
enum Backend {
    Firewheel,
    Serial,
}

impl From<Backend> for GraphBackend {
    fn from(b: Backend) -> Self {
        match b {
            Backend::Firewheel => GraphBackend::Firewheel,
            Backend::Serial => GraphBackend::Serial,
        }
    }
}

#[derive(Clone, Copy, ValueEnum)]
enum Format {
    Wav16,
    Wav24,
    Wav32f,
}

#[derive(Subcommand)]
enum Cmd {
    /// List audio devices.
    Devices {
        /// Print JSON instead of a table.
        #[arg(long)]
        json: bool,
    },
    /// Render an event script offline to a WAV file.
    Render {
        /// Folder of audio files (sorted by name → pads A0..B11).
        #[arg(long)]
        kit_dir: PathBuf,
        /// JSON `RenderScript` ({"duration_secs":…, "events":[{"at_secs":…, "cmd":…}]}).
        #[arg(long)]
        events: PathBuf,
        #[arg(long)]
        out: PathBuf,
        #[arg(long, default_value_t = 48_000)]
        sample_rate: u32,
        #[arg(long, value_enum, default_value_t = Backend::Firewheel)]
        backend: Backend,
        #[arg(long, value_enum, default_value_t = Format::Wav24)]
        format: Format,
    },
    /// Play pads on the default output device.
    Play {
        #[arg(long)]
        kit_dir: PathBuf,
        /// Pad label (A0..A11, B0..B11, or 0..23). Repeat for several pads.
        #[arg(long, required = true)]
        pad: Vec<String>,
        /// Seconds to hold before releasing.
        #[arg(long, default_value_t = 2.0)]
        duration: f64,
        #[arg(long, default_value_t = 1.0)]
        velocity: f32,
        #[arg(long)]
        device: Option<String>,
        #[arg(long)]
        buffer: Option<u32>,
    },
    /// Measure command enqueue → first non-zero output sample.
    LatencyProbe {
        /// Optional kit; without it a synthetic click is used.
        #[arg(long)]
        kit_dir: Option<PathBuf>,
        #[arg(long, default_value = "A0")]
        pad: String,
        #[arg(long, default_value_t = 20)]
        iterations: u32,
        #[arg(long)]
        device: Option<String>,
        #[arg(long)]
        buffer: Option<u32>,
    },
    /// Print duration, peak and RMS of a WAV file (read back with hound).
    Inspect { file: PathBuf },
}

fn main() -> ExitCode {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn")).init();
    let cli = Cli::parse();
    let res = match cli.cmd {
        Cmd::Devices { json } => devices(json),
        Cmd::Render {
            kit_dir,
            events,
            out,
            sample_rate,
            backend,
            format,
        } => render(&kit_dir, &events, &out, sample_rate, backend.into(), format),
        Cmd::Play {
            kit_dir,
            pad,
            duration,
            velocity,
            device,
            buffer,
        } => play(&kit_dir, &pad, duration, velocity, device, buffer),
        Cmd::LatencyProbe {
            kit_dir,
            pad,
            iterations,
            device,
            buffer,
        } => latency_probe(kit_dir.as_deref(), &pad, iterations, device, buffer),
        Cmd::Inspect { file } => inspect(&file),
    };
    match res {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::FAILURE
        }
    }
}

fn devices(json: bool) -> UpResult<()> {
    let list = AudioHost::devices()?;
    if json {
        println!(
            "{}",
            serde_json::to_string_pretty(&list).map_err(|e| UpError::internal(e.to_string()))?
        );
        return Ok(());
    }
    println!(
        "{:<4} {:<3} {:<3} {:>7} {:>4} {:>4}  name / id",
        "", "in", "out", "rate", "ch↓", "ch↑"
    );
    for d in list {
        let def = match (d.is_default_output, d.is_default_input) {
            (true, true) => "*io",
            (true, false) => "*o",
            (false, true) => "*i",
            _ => "",
        };
        println!(
            "{:<4} {:<3} {:<3} {:>7} {:>4} {:>4}  {} [{}]",
            def,
            if d.is_input { "y" } else { "-" },
            if d.is_output { "y" } else { "-" },
            d.default_sample_rate
                .map(|r| r.to_string())
                .unwrap_or_else(|| "?".into()),
            d.max_output_channels,
            d.max_input_channels,
            d.name,
            d.id
        );
    }
    Ok(())
}

fn engine(sample_rate: u32, backend: GraphBackend) -> UpResult<(EngineHandle, AudioProcessor)> {
    Engine::new(EngineConfig {
        sample_rate,
        graph_backend: backend,
        ..Default::default()
    })
}

fn render(
    kit_dir: &Path,
    events: &Path,
    out: &Path,
    sr: u32,
    backend: GraphBackend,
    format: Format,
) -> UpResult<()> {
    let text = std::fs::read_to_string(events)?;
    let script: RenderScript = serde_json::from_str(&text)
        .map_err(|e| UpError::format(format!("{}: {e}", events.display())))?;
    let (handle, mut processor) = engine(sr, backend)?;
    let kit = load_folder_kit(kit_dir, sr)?;
    for (p, e) in &kit.skipped {
        eprintln!("warning: skipped {}: {e}", p.display());
    }
    apply_kit(&handle, &kit)?;
    let t0 = Instant::now();
    let data = render_offline(&handle, &mut processor, &script)?;
    let elapsed = t0.elapsed();
    let buf = up_codec::AudioBuffer::new(sr, 2, data);
    let fmt = match format {
        Format::Wav16 => up_codec::WavFormat::Pcm16,
        Format::Wav24 => up_codec::WavFormat::Pcm24,
        Format::Wav32f => up_codec::WavFormat::Float32,
    };
    if let Some(parent) = out.parent().filter(|p| !p.as_os_str().is_empty()) {
        std::fs::create_dir_all(parent)?;
    }
    up_codec::write_wav(
        std::io::BufWriter::new(std::fs::File::create(out)?),
        &buf,
        fmt,
    )?;
    println!(
        "rendered {:.3}s ({} pads, {} events) in {:.1} ms → {} (peak {:.3})",
        buf.duration_secs(),
        kit.doc.summary().pad_count,
        script.events.len(),
        elapsed.as_secs_f64() * 1000.0,
        out.display(),
        buf.peak()
    );
    Ok(())
}

/// Start the default output with a fresh engine at the device rate.
fn start_audio(device: Option<String>, buffer: Option<u32>) -> UpResult<(AudioHost, EngineHandle)> {
    let cfg = AudioConfig {
        buffer_frames: buffer,
        sample_rate: None,
        output_device: device,
    };
    let plan = AudioHost::plan_output(&cfg)?;
    let (handle, processor) = engine(plan.sample_rate, GraphBackend::default())?;
    let mut host = AudioHost::new();
    let status = host.start(&plan, processor).map_err(|(e, _)| e)?;
    println!(
        "audio: {} / {} @ {} Hz, {} ch, buffer {}, {}",
        status.host,
        status.device,
        status.sample_rate,
        status.channels,
        status
            .buffer_frames
            .map(|b| b.to_string())
            .unwrap_or_else(|| "default".into()),
        status.sample_format
    );
    Ok((host, handle))
}

fn play(
    kit_dir: &Path,
    pads: &[String],
    duration: f64,
    velocity: f32,
    device: Option<String>,
    buffer: Option<u32>,
) -> UpResult<()> {
    let pads: Vec<PadId> = pads
        .iter()
        .map(|p| PadId::parse(p))
        .collect::<UpResult<_>>()?;
    let (mut host, handle) = start_audio(device, buffer)?;
    let kit = load_folder_kit(kit_dir, handle.sample_rate())?;
    apply_kit(&handle, &kit)?;
    for p in &pads {
        if kit.doc.pad(*p).is_none() {
            eprintln!("warning: pad {p} has no sample in this kit");
        }
        handle.pad_down(*p, velocity)?;
    }
    std::thread::sleep(Duration::from_secs_f64(duration.clamp(0.0, 600.0)));
    for p in &pads {
        handle.pad_up(*p)?;
    }
    handle.send(Command::StopAll)?;
    std::thread::sleep(Duration::from_millis(100));
    let stats = Arc::clone(host.stats());
    let status = host.status();
    host.stop();
    let callbacks = stats.callbacks.load(std::sync::atomic::Ordering::Relaxed);
    let errors = stats.errors.load(std::sync::atomic::Ordering::Relaxed);
    println!(
        "played {} pad(s); {} callbacks, max {} frames/callback, {} stream errors, output latency {}",
        pads.len(),
        callbacks,
        stats
            .max_callback_frames
            .load(std::sync::atomic::Ordering::Relaxed),
        errors,
        status
            .output_latency_ms
            .map(|ms| format!("{ms:.2} ms"))
            .unwrap_or_else(|| "n/a".into())
    );
    if let Some(e) = stats.last_error() {
        eprintln!("last stream error: {e}");
    }
    if callbacks == 0 {
        return Err(UpError::audio("the output callback never ran"));
    }
    Ok(())
}

fn latency_probe(
    kit_dir: Option<&Path>,
    pad: &str,
    iterations: u32,
    device: Option<String>,
    buffer: Option<u32>,
) -> UpResult<()> {
    let pad = PadId::parse(pad)?;
    let (mut host, handle) = start_audio(device, buffer)?;
    if let Some(dir) = kit_dir {
        let kit = load_folder_kit(dir, handle.sample_rate())?;
        apply_kit(&handle, &kit)?;
    } else {
        // Synthetic click: 5 ms full-scale burst.
        let n = (handle.sample_rate() / 200) as usize;
        handle.register_sample(SampleData::new(
            SampleId::new("probe-click"),
            "click",
            handle.sample_rate(),
            vec![vec![0.9; n]],
        ));
        handle.send(Command::SetPadParams {
            pad,
            params: PadParams {
                sample: Some(SampleId::new("probe-click")),
                ..Default::default()
            },
        })?;
    }
    std::thread::sleep(Duration::from_millis(300)); // let the stream settle
    let stats = Arc::clone(host.stats());
    let mut samples = Vec::new();
    for _ in 0..iterations.max(1) {
        stats.arm_probe();
        handle.pad_down(pad, 1.0)?;
        let deadline = Instant::now() + Duration::from_millis(500);
        let r = loop {
            if let Some(r) = stats.probe_result() {
                break Some(r);
            }
            if Instant::now() > deadline {
                break None;
            }
            std::thread::sleep(Duration::from_micros(200));
        };
        handle.pad_up(pad)?;
        handle.send(Command::StopAll)?;
        match r {
            Some(r) => samples.push(r),
            None => eprintln!("probe timed out (silent pad?)"),
        }
        std::thread::sleep(Duration::from_millis(120));
    }
    host.stop();
    if samples.is_empty() {
        return Err(UpError::audio("no probe measurement succeeded"));
    }
    let mut enq: Vec<f64> = samples
        .iter()
        .map(|r| r.enqueue_to_output.as_secs_f64() * 1000.0)
        .collect();
    enq.sort_by(f64::total_cmp);
    let out_lat = samples
        .iter()
        .map(|r| r.callback_to_playback.as_secs_f64() * 1000.0)
        .sum::<f64>()
        / samples.len() as f64;
    let med = enq[enq.len() / 2];
    println!("latency-probe: {} measurements", enq.len());
    println!(
        "  enqueue → first non-zero sample rendered: min {:.2} ms, median {:.2} ms, max {:.2} ms",
        enq[0],
        med,
        enq[enq.len() - 1]
    );
    println!("  backend callback → playback estimate:     {out_lat:.2} ms");
    println!(
        "  estimated command → sound at DAC:          {:.2} ms (median)",
        med + out_lat
    );
    Ok(())
}

fn inspect(file: &Path) -> UpResult<()> {
    let mut r = hound::WavReader::open(file).map_err(|e| UpError::codec(e.to_string()))?;
    let spec = r.spec();
    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => r.samples::<f32>().collect::<Result<_, _>>(),
        hound::SampleFormat::Int => {
            let scale = 1.0 / (1i64 << (spec.bits_per_sample - 1)) as f32;
            r.samples::<i32>()
                .map(|s| s.map(|v| v as f32 * scale))
                .collect()
        }
    }
    .map_err(|e| UpError::codec(e.to_string()))?;
    let frames = samples.len() / spec.channels.max(1) as usize;
    let peak = samples.iter().fold(0.0f32, |m, s| m.max(s.abs()));
    let rms = (samples.iter().map(|s| (*s as f64).powi(2)).sum::<f64>()
        / samples.len().max(1) as f64)
        .sqrt();
    let nonzero = samples.iter().filter(|s| s.abs() > 1e-4).count();
    println!(
        "{}: {} Hz, {} ch, {}-bit {:?}, {:.3} s, peak {:.4}, rms {:.4}, non-silent samples {}",
        file.display(),
        spec.sample_rate,
        spec.channels,
        spec.bits_per_sample,
        spec.sample_format,
        frames as f64 / spec.sample_rate as f64,
        peak,
        rms,
        nonzero
    );
    if nonzero == 0 {
        return Err(UpError::codec("file is silent"));
    }
    Ok(())
}
