//! Engine, audio, events, sampling and tutorial functions.

use super::types::*;
use crate::frb_generated::StreamSink;
use crate::state;
use flutter_rust_bridge::frb;

type R<T> = Result<T, UpError>;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Initialise storage roots, the engine and the library
/// (`<data_dir>/library`). Idempotent: a second call (e.g. after a Flutter
/// hot restart) returns the running engine.
pub fn init(app_dirs: AppDirs) -> R<EngineInfo> {
    if let Some(core) = state::installed() {
        return Ok(core.info().into());
    }
    let lib_root = std::path::Path::new(&app_dirs.data_dir).join("library");
    let core = up_host::AppCore::new(
        up_host::AppDirs {
            data_dir: app_dirs.data_dir,
            cache_dir: app_dirs.cache_dir,
        },
        up_engine::EngineConfig::default(),
    )?;
    let library =
        state::install_library(up_library::Library::open(&lib_root).map_err(state::lib_err)?);
    // Recordings go into the library.
    let lib = std::sync::Arc::clone(&library);
    core.set_track_sink(Some(std::sync::Arc::new(move |take: &up_engine::Take| {
        let bytes = up_codec::encode_wav(&take.audio, up_codec::WavFormat::Pcm24)?;
        let n = lib.tracks_list().len() + 1;
        let kit = state::current_kit();
        let t = lib
            .track_add(&bytes, &format!("TRACK {n}"), kit.as_deref(), None)
            .map_err(|e| up_core::UpError::io(e.to_string()))?;
        if let Ok(mut c) = state::waveform_cache().lock() {
            c.insert(t.id.clone(), take.waveform.clone());
        }
        Ok(up_engine::TrackInfo {
            id: up_core::TrackId(t.id),
            name: t.name,
            created_unix_ms: t.created_at_ms,
            duration_secs: t.duration_secs,
            sample_rate: t.sample_rate,
            channels: t.channels,
            waveform: take.waveform.clone(),
        })
    })));
    let core = state::install(core);
    Ok(core.info().into())
}

/// Open the output device and start rendering. Rebuilds the engine (and
/// reloads the current kit) if the device sample rate differs.
pub fn audio_start(cfg: AudioConfig) -> R<AudioStatus> {
    let core = state::core()?;
    let st = core.audio_start(&up_host::AudioConfig {
        buffer_frames: cfg.buffer_frames,
        sample_rate: cfg.sample_rate,
        output_device: cfg.output_device,
    })?;
    Ok(st.into())
}

pub fn audio_stop() -> R<()> {
    Ok(state::core()?.audio_stop()?)
}

pub fn audio_status() -> R<AudioStatus> {
    Ok(state::core()?.audio_status()?.into())
}

pub fn audio_devices() -> R<Vec<AudioDeviceInfo>> {
    Ok(up_host::AudioHost::devices()?
        .into_iter()
        .map(Into::into)
        .collect())
}

/// Engine event stream (~60 Hz meters; pad/transport/recorder changes
/// immediately). Each call creates an independent subscription.
pub fn events(sink: StreamSink<EngineEvent>) -> R<()> {
    let rx = state::core()?.subscribe();
    std::thread::Builder::new()
        .name("up-ffi-events".into())
        .spawn(move || {
            for ev in rx {
                if sink.add(ev.into()).is_err() {
                    break; // Dart side closed the stream.
                }
            }
        })
        .map_err(|e| UpError {
            code: ErrorCode::Internal,
            message: e.to_string(),
        })?;
    Ok(())
}

/// Full state snapshot (lock-free read).
#[frb(sync)]
pub fn snapshot() -> R<EngineSnapshot> {
    Ok(state::core()?.snapshot()?.into())
}

/// Hot path: press a pad (lock-free queue push, microseconds).
#[frb(sync)]
pub fn pad_down(bank: u8, index: u8, velocity: f32) -> R<()> {
    Ok(state::core()?.pad_down(up_core::PadId { bank, index }, velocity)?)
}

/// Hot path: release a pad.
#[frb(sync)]
pub fn pad_up(bank: u8, index: u8) -> R<()> {
    Ok(state::core()?.pad_up(up_core::PadId { bank, index })?)
}

/// Generic command (lock-free).
#[frb(sync)]
pub fn send(cmd: Command) -> R<()> {
    Ok(state::core()?.send(cmd.into())?)
}

/// Precise transport clock extrapolated to now (tutorial judgement).
#[frb(sync)]
pub fn transport_clock() -> R<TransportClock> {
    Ok(state::core()?.transport_clock()?.into())
}

/// Judge a tutorial press: `expected_secs`/`actual_secs` are song seconds,
/// `speed` the current speed ratio, windows in real-time ms.
#[frb(sync)]
pub fn tutorial_judge(
    expected_secs: f64,
    actual_secs: f64,
    speed: f64,
    perfect_ms: f64,
    miss_ms: f64,
) -> Judgement {
    up_model::JudgeWindow {
        perfect_ms,
        miss_ms,
    }
    .judge(expected_secs, actual_secs, speed)
    .into()
}

/// Peak overview (`buckets` values in 0..=1) of a sample (engine-loaded
/// samples first, then the library).
pub fn sample_waveform(sample: String, buckets: u32) -> R<Vec<f32>> {
    match state::core()?.sample_waveform(&up_core::SampleId(sample.clone()), buckets) {
        Ok(w) => Ok(w),
        Err(e) if e.code == up_core::ErrorCode::NotFound => state::library()?
            .sample_waveform(&sample, buckets.clamp(1, 16_384))
            .map_err(state::lib_err),
        Err(e) => Err(e.into()),
    }
}

/// Start microphone sampling. On Android, request RECORD_AUDIO first via
/// the `dev.ultrapads/permissions` MethodChannel (`requestRecordAudio`).
pub fn sampler_record_start(input_device: Option<String>) -> R<()> {
    Ok(state::core()?.sampler_record_start(input_device.as_deref())?)
}

/// Stop microphone sampling, store the take in the library (as a
/// `Microphone` sample) and register it with the engine. Returns the new
/// sample id (BLAKE3) to assign with `SetPadParams`.
pub fn sampler_record_stop() -> R<String> {
    let core = state::core()?;
    let audio = core.sampler_record_stop_audio()?;
    let bytes = up_codec::encode_wav(&audio, up_codec::WavFormat::Pcm24)?;
    let lib = state::library()?;
    let n = lib.list_samples().len() + 1;
    let rec = lib
        .add_sample(
            &bytes,
            &format!("MIC {n}"),
            up_library::SampleOrigin::Microphone,
        )
        .map_err(state::lib_err)?;
    core.register_audio(up_core::SampleId::new(rec.id.clone()), &rec.name, &audio)?;
    core.emit(up_engine::EngineEvent::LibraryChanged);
    Ok(rec.id)
}

/// Tutorial chart for a kit (from the library's tutorials, or a folder
/// kit's `tutorial.json`).
pub fn tutorial_get(kit: String) -> R<Option<TutorialChart>> {
    if let Ok(lib) = state::library() {
        match lib.kit_model(&kit) {
            Ok(m) => return Ok(m.tutorial.map(Into::into)),
            Err(up_library::LibraryError::NotFound { .. }) => {}
            Err(e) => return Err(state::lib_err(e)),
        }
    }
    Ok(state::core()?
        .tutorial(&up_core::KitId(kit))?
        .map(Into::into))
}

/// Arm the output latency probe; the next non-zero output sample is timed.
#[frb(sync)]
pub fn latency_probe_arm() -> R<()> {
    Ok(state::core()?.arm_latency_probe()?)
}

/// Milliseconds from `latency_probe_arm` to the first non-zero sample
/// rendered, plus the backend's callback→playback estimate.
#[frb(sync)]
pub fn latency_probe_result() -> R<Option<Vec<f64>>> {
    Ok(state::core()?.latency_probe_result()?.map(|r| {
        vec![
            r.enqueue_to_output.as_secs_f64() * 1000.0,
            r.callback_to_playback.as_secs_f64() * 1000.0,
        ]
    }))
}
