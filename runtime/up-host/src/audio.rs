//! Output streams (cpal) driving the engine's `AudioProcessor`.
//!
//! cpal streams are not `Send` on every platform, so each stream lives on
//! a dedicated host thread. Stopping hands the processor back from the
//! audio callback through a wait-free SPSC slot, so the engine survives a
//! stop/start cycle without being rebuilt.

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{
    BufferSize, Device, FromSample, OutputCallbackInfo, SampleFormat, SizedSample, StreamConfig,
    SupportedBufferSize,
};
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};
use up_core::{ErrorCode, UpError, UpResult};
use up_engine::AudioProcessor;

/// Requested output configuration (`docs/API.md` §3 `AudioConfig`).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct AudioConfig {
    /// Desired buffer size in frames (`None` = low-latency default,
    /// [`DEFAULT_BUFFER_FRAMES`]). Ignored on Android (AAudio picks the burst).
    pub buffer_frames: Option<u32>,
    /// Desired sample rate (`None` = device default).
    pub sample_rate: Option<u32>,
    /// Output device id or name (`None` = default device).
    pub output_device: Option<String>,
}

/// Running stream description.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AudioStatus {
    pub running: bool,
    pub host: String,
    pub device: String,
    pub sample_rate: u32,
    pub channels: u16,
    /// Fixed buffer size if one could be configured.
    pub buffer_frames: Option<u32>,
    pub sample_format: String,
    /// Output latency estimate (callback → playback) in ms, once known.
    pub output_latency_ms: Option<f64>,
}

/// Device listing entry.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct AudioDeviceInfo {
    pub id: String,
    pub name: String,
    pub is_input: bool,
    pub is_output: bool,
    pub is_default_output: bool,
    pub is_default_input: bool,
    pub default_sample_rate: Option<u32>,
    pub max_output_channels: u16,
    pub max_input_channels: u16,
    pub min_buffer_frames: Option<u32>,
    pub max_buffer_frames: Option<u32>,
}

/// Default buffer request when the caller does not specify one: 128 frames
/// (2.7 ms at 48 kHz per period; ALSA double-buffers, so ~10 ms command →
/// DAC on PipeWire instead of ~18 ms at 256).
pub const DEFAULT_BUFFER_FRAMES: u32 = 128;
/// Largest callback chunk handled in one go (bigger callbacks are split).
const SCRATCH_FRAMES: usize = 4096;

/// Live counters shared with the audio callback (lock-free).
#[derive(Debug)]
pub struct StreamStats {
    base: Instant,
    pub callbacks: AtomicU64,
    pub frames: AtomicU64,
    pub errors: AtomicU64,
    /// Callback → playback delay reported by the backend (ns).
    pub output_latency_ns: AtomicU64,
    /// Largest callback size seen (frames).
    pub max_callback_frames: AtomicU64,
    probe_armed: AtomicBool,
    probe_armed_at_ns: AtomicU64,
    probe_result_ns: AtomicU64,
    probe_callback_latency_ns: AtomicU64,
    last_error: Mutex<Option<String>>,
}

impl Default for StreamStats {
    fn default() -> Self {
        Self {
            base: Instant::now(),
            callbacks: AtomicU64::new(0),
            frames: AtomicU64::new(0),
            errors: AtomicU64::new(0),
            output_latency_ns: AtomicU64::new(0),
            max_callback_frames: AtomicU64::new(0),
            probe_armed: AtomicBool::new(false),
            probe_armed_at_ns: AtomicU64::new(0),
            probe_result_ns: AtomicU64::new(0),
            probe_callback_latency_ns: AtomicU64::new(0),
            last_error: Mutex::new(None),
        }
    }
}

/// Result of a latency probe measurement.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ProbeResult {
    /// From `arm_probe()` to the end of the first callback that produced a
    /// non-zero sample.
    pub enqueue_to_output: Duration,
    /// Backend-reported callback → playback delay for that callback.
    pub callback_to_playback: Duration,
}

impl StreamStats {
    fn now_ns(&self) -> u64 {
        self.base.elapsed().as_nanos() as u64
    }

    /// Arm the probe right before sending a command.
    pub fn arm_probe(&self) {
        self.probe_result_ns.store(0, Ordering::Relaxed);
        self.probe_armed_at_ns
            .store(self.now_ns(), Ordering::Relaxed);
        self.probe_armed.store(true, Ordering::Release);
    }

    pub fn probe_result(&self) -> Option<ProbeResult> {
        let r = self.probe_result_ns.load(Ordering::Acquire);
        if r == 0 {
            return None;
        }
        Some(ProbeResult {
            enqueue_to_output: Duration::from_nanos(r),
            callback_to_playback: Duration::from_nanos(
                self.probe_callback_latency_ns.load(Ordering::Relaxed),
            ),
        })
    }

    pub fn last_error(&self) -> Option<String> {
        self.last_error.lock().ok().and_then(|e| e.clone())
    }

    #[inline]
    fn on_callback_done(&self, frames: usize) {
        self.callbacks.fetch_add(1, Ordering::Relaxed);
        self.frames.fetch_add(frames as u64, Ordering::Relaxed);
        self.max_callback_frames
            .fetch_max(frames as u64, Ordering::Relaxed);
    }

    #[inline]
    fn on_chunk(&self, out: &[f32], info: &OutputCallbackInfo) {
        let ts = info.timestamp();
        let lat = ts
            .playback
            .saturating_duration_since(ts.callback)
            .as_nanos() as u64;
        self.output_latency_ns.store(lat, Ordering::Relaxed);
        if self.probe_armed.load(Ordering::Acquire) && out.iter().any(|s| *s != 0.0) {
            let armed = self.probe_armed_at_ns.load(Ordering::Relaxed);
            let dt = self.now_ns().saturating_sub(armed).max(1);
            self.probe_callback_latency_ns.store(lat, Ordering::Relaxed);
            self.probe_result_ns.store(dt, Ordering::Release);
            self.probe_armed.store(false, Ordering::Release);
        }
    }

    fn on_error(&self, e: &cpal::Error) {
        self.errors.fetch_add(1, Ordering::Relaxed);
        if let Ok(mut g) = self.last_error.try_lock() {
            *g = Some(e.to_string());
        }
    }
}

/// A resolved output configuration.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutputPlan {
    pub device_id: Option<String>,
    pub device_name: String,
    pub host: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub buffer_frames: Option<u32>,
    pub sample_format: String,
}

/// Route ALSA's library error messages (printed to stderr while probing
/// devices that cannot be opened) into a thread-local buffer while the
/// returned guard lives.
pub(crate) fn quiet_alsa() -> impl Drop {
    struct Guard(#[allow(dead_code)] Option<Box<dyn std::any::Any>>);
    impl Drop for Guard {
        fn drop(&mut self) {}
    }
    #[cfg(target_os = "linux")]
    {
        Guard(
            alsa::Output::local_error_handler()
                .ok()
                .map(|g| Box::new(g) as Box<dyn std::any::Any>),
        )
    }
    #[cfg(not(target_os = "linux"))]
    {
        Guard(None)
    }
}

fn audio_err(ctx: &str, e: impl std::fmt::Display) -> UpError {
    let msg = format!("{ctx}: {e}");
    let lower = msg.to_ascii_lowercase();
    if lower.contains("permission") || lower.contains("denied") {
        UpError::new(ErrorCode::PermissionDenied, msg)
    } else {
        UpError::audio(msg)
    }
}

fn device_name(d: &Device) -> String {
    d.description()
        .map(|desc| desc.name().to_owned())
        .or_else(|_| d.id().map(|id| id.to_string()))
        .unwrap_or_else(|_| "unknown".into())
}

fn device_id(d: &Device) -> Option<String> {
    d.id().ok().map(|id| id.to_string())
}

/// Find a device by id or (case-insensitive) name.
pub(crate) fn find_device(
    host: &cpal::Host,
    wanted: Option<&str>,
    output: bool,
) -> UpResult<Device> {
    let default = if output {
        host.default_output_device()
    } else {
        host.default_input_device()
    };
    let Some(w) = wanted.filter(|w| !w.is_empty()) else {
        return default.ok_or_else(|| {
            UpError::not_found(if output {
                "no default output device"
            } else {
                "no default input device"
            })
        });
    };
    // The default device is not always part of the enumeration (AAudio's
    // default is the pseudo device `aaudio:-1`), so match it first.
    if let Some(d) = default
        && (device_id(&d).as_deref() == Some(w) || device_name(&d).eq_ignore_ascii_case(w))
    {
        return Ok(d);
    }
    let devices = host
        .devices()
        .map_err(|e| audio_err("enumerate devices", e))?;
    for d in devices {
        let matches_dir = if output {
            d.supports_output()
        } else {
            d.supports_input()
        };
        if !matches_dir {
            continue;
        }
        if device_id(&d).as_deref() == Some(w) || device_name(&d).eq_ignore_ascii_case(w) {
            return Ok(d);
        }
    }
    Err(UpError::not_found(format!("audio device {w:?}")))
}

fn format_rank(f: SampleFormat) -> u8 {
    match f {
        SampleFormat::F32 => 0,
        SampleFormat::I16 => 1,
        SampleFormat::I32 => 2,
        SampleFormat::I24 => 3,
        SampleFormat::U16 => 4,
        SampleFormat::F64 => 5,
        _ => 9,
    }
}

fn supported_format(f: SampleFormat) -> bool {
    matches!(
        f,
        SampleFormat::F32
            | SampleFormat::I16
            | SampleFormat::I32
            | SampleFormat::U16
            | SampleFormat::F64
    )
}

/// Owns the current output stream.
pub struct AudioHost {
    stats: Arc<StreamStats>,
    running: Option<Running>,
}

struct Running {
    stop: Arc<AtomicBool>,
    thread: JoinHandle<Option<AudioProcessor>>,
    status: AudioStatus,
}

impl Default for AudioHost {
    fn default() -> Self {
        Self::new()
    }
}

impl AudioHost {
    pub fn new() -> Self {
        Self {
            stats: Arc::new(StreamStats::default()),
            running: None,
        }
    }

    pub fn stats(&self) -> &Arc<StreamStats> {
        &self.stats
    }

    pub fn is_running(&self) -> bool {
        self.running.is_some()
    }

    pub fn status(&self) -> AudioStatus {
        match &self.running {
            Some(r) => {
                let mut s = r.status.clone();
                let ns = self.stats.output_latency_ns.load(Ordering::Relaxed);
                if ns > 0 {
                    s.output_latency_ms = Some(ns as f64 / 1e6);
                }
                s
            }
            None => AudioStatus::default(),
        }
    }

    /// Enumerate devices of the default host.
    pub fn devices() -> UpResult<Vec<AudioDeviceInfo>> {
        crate::android::context_ready()
            .then_some(())
            .ok_or_else(|| {
                UpError::state("Android context not initialised (MainActivity.nativeInit)")
            })?;
        let _quiet = quiet_alsa();
        let host = cpal::default_host();
        let def_out = host.default_output_device().and_then(|d| device_id(&d));
        let def_in = host.default_input_device().and_then(|d| device_id(&d));
        let mut out = Vec::new();
        for d in host
            .devices()
            .map_err(|e| audio_err("enumerate devices", e))?
        {
            let id = device_id(&d).unwrap_or_default();
            let mut info = AudioDeviceInfo {
                name: device_name(&d),
                is_input: d.supports_input(),
                is_output: d.supports_output(),
                is_default_output: def_out.as_deref() == Some(id.as_str()),
                is_default_input: def_in.as_deref() == Some(id.as_str()),
                id,
                ..Default::default()
            };
            if let Ok(c) = d.default_output_config() {
                info.default_sample_rate = Some(c.sample_rate());
                if let SupportedBufferSize::Range { min, max } = c.buffer_size() {
                    info.min_buffer_frames = Some(*min);
                    info.max_buffer_frames = Some(*max);
                }
            } else if let Ok(c) = d.default_input_config() {
                info.default_sample_rate = Some(c.sample_rate());
            }
            if let Ok(cfgs) = d.supported_output_configs() {
                info.max_output_channels = cfgs.map(|c| c.channels()).max().unwrap_or(0);
            }
            if let Ok(cfgs) = d.supported_input_configs() {
                info.max_input_channels = cfgs.map(|c| c.channels()).max().unwrap_or(0);
            }
            out.push(info);
        }
        Ok(out)
    }

    /// Resolve device, sample rate, channel count and buffer size without
    /// opening a stream. Create the engine with `plan.sample_rate`.
    pub fn plan_output(cfg: &AudioConfig) -> UpResult<OutputPlan> {
        if !crate::android::context_ready() {
            return Err(UpError::state(
                "Android context not initialised (MainActivity.nativeInit)",
            ));
        }
        let _quiet = quiet_alsa();
        let host = cpal::default_host();
        let device = find_device(&host, cfg.output_device.as_deref(), true)?;
        let default = device
            .default_output_config()
            .map_err(|e| audio_err("default output config", e))?;
        let rate = cfg.sample_rate.unwrap_or(default.sample_rate());
        // Pick the best supported config containing the requested rate.
        let mut candidates: Vec<_> = device
            .supported_output_configs()
            .map_err(|e| audio_err("supported output configs", e))?
            .filter(|c| supported_format(c.sample_format()))
            .filter(|c| c.min_sample_rate() <= rate && rate <= c.max_sample_rate())
            .collect();
        candidates.sort_by_key(|c| {
            (
                format_rank(c.sample_format()),
                c.channels() != 2,
                c.channels(),
            )
        });
        let chosen = match candidates.into_iter().next() {
            Some(c) => c.with_sample_rate(rate),
            None if cfg.sample_rate.is_none() && supported_format(default.sample_format()) => {
                default
            }
            None => {
                return Err(UpError::audio(format!(
                    "device does not support {rate} Hz with a usable sample format"
                )));
            }
        };
        let want = cfg.buffer_frames.unwrap_or(DEFAULT_BUFFER_FRAMES);
        let buffer_frames = match chosen.buffer_size() {
            // AAudio: a fixed request forces `frames_per_data_callback` and a
            // 2× capacity, which bypasses the burst-aligned fast path. The
            // default lets AAudio call back once per burst and tune the
            // buffer on underruns (Oboe's low-latency recipe).
            _ if cfg!(target_os = "android") => None,
            SupportedBufferSize::Range { min, max } => Some(want.clamp(*min, *max)),
            SupportedBufferSize::Unknown => cfg.buffer_frames,
        };
        // AAudio converts channel counts itself. Some devices report mono only
        // (e.g. a phone's built-in speaker) and some vendors refuse a mono FAST
        // track (AAUDIO_ERROR_INTERNAL), so always ask for stereo on Android.
        let channels = if cfg!(target_os = "android") {
            2
        } else {
            chosen.channels()
        };
        Ok(OutputPlan {
            device_id: device_id(&device),
            device_name: device_name(&device),
            host: host.id().name().to_owned(),
            sample_rate: chosen.sample_rate(),
            channels,
            buffer_frames,
            sample_format: format!("{:?}", chosen.sample_format()),
        })
    }

    /// Open and start the output stream for `plan`, driving `processor`.
    /// `processor.sample_rate()` must equal `plan.sample_rate`.
    pub fn start(
        &mut self,
        plan: &OutputPlan,
        processor: AudioProcessor,
    ) -> Result<AudioStatus, (UpError, Option<AudioProcessor>)> {
        if self.running.is_some() {
            return Err((UpError::state("audio already running"), Some(processor)));
        }
        if processor.sample_rate() != plan.sample_rate {
            return Err((
                UpError::invalid(format!(
                    "processor runs at {} Hz but stream is {} Hz",
                    processor.sample_rate(),
                    plan.sample_rate
                )),
                Some(processor),
            ));
        }
        let stop = Arc::new(AtomicBool::new(false));
        let (ready_tx, ready_rx) =
            crossbeam_channel::bounded::<Result<Option<u32>, (UpError, Option<AudioProcessor>)>>(1);
        let plan2 = plan.clone();
        let stats = Arc::clone(&self.stats);
        let stop2 = Arc::clone(&stop);
        let thread = std::thread::Builder::new()
            .name("up-audio-host".into())
            .spawn(move || stream_thread(plan2, processor, stats, stop2, ready_tx))
            .map_err(|e| (UpError::internal(format!("spawn audio thread: {e}")), None))?;
        match ready_rx.recv() {
            Ok(Ok(buffer)) => {
                let status = AudioStatus {
                    running: true,
                    host: plan.host.clone(),
                    device: plan.device_name.clone(),
                    sample_rate: plan.sample_rate,
                    channels: plan.channels,
                    buffer_frames: buffer,
                    sample_format: plan.sample_format.clone(),
                    output_latency_ms: None,
                };
                self.running = Some(Running {
                    stop,
                    thread,
                    status: status.clone(),
                });
                Ok(status)
            }
            Ok(Err(e)) => {
                let _ = thread.join();
                Err(e)
            }
            Err(_) => Err((UpError::internal("audio thread exited during start"), None)),
        }
    }

    /// Stop the stream and get the processor back (if the callback was
    /// still running).
    pub fn stop(&mut self) -> Option<AudioProcessor> {
        let r = self.running.take()?;
        r.stop.store(true, Ordering::Release);
        r.thread.join().ok().flatten()
    }
}

impl Drop for AudioHost {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

type Ready = crossbeam_channel::Sender<Result<Option<u32>, (UpError, Option<AudioProcessor>)>>;

fn stream_thread(
    plan: OutputPlan,
    processor: AudioProcessor,
    stats: Arc<StreamStats>,
    stop: Arc<AtomicBool>,
    ready: Ready,
) -> Option<AudioProcessor> {
    let quiet = quiet_alsa();
    let host = cpal::default_host();
    let device = match find_device(&host, plan.device_id.as_deref(), true) {
        Ok(d) => d,
        Err(e) => {
            let _ = ready.send(Err((e, Some(processor))));
            return None;
        }
    };
    let format = match device
        .supported_output_configs()
        .ok()
        .and_then(|mut it| {
            it.find(|c| {
                format!("{:?}", c.sample_format()) == plan.sample_format
                    && c.channels() == plan.channels
                    && c.min_sample_rate() <= plan.sample_rate
                    && plan.sample_rate <= c.max_sample_rate()
            })
        })
        .map(|c| c.sample_format())
    {
        Some(f) => f,
        None => device
            .default_output_config()
            .map(|c| c.sample_format())
            .unwrap_or(SampleFormat::F32),
    };

    // Hand-back slot for the processor.
    let (back_tx, mut back_rx) = rtrb::RingBuffer::<AudioProcessor>::new(1);
    let mut attempt_buffers = vec![
        plan.buffer_frames.map(BufferSize::Fixed),
        Some(BufferSize::Default),
    ];
    attempt_buffers.dedup();
    let mut slot = Some((processor, back_tx));
    let mut last_err = None;
    let mut stream_and_buf = None;
    for buf in attempt_buffers.into_iter().flatten() {
        let Some((p, tx)) = slot.take() else { break };
        let config = StreamConfig {
            channels: plan.channels,
            sample_rate: plan.sample_rate,
            buffer_size: buf,
        };
        let fixed = match buf {
            BufferSize::Fixed(n) => Some(n),
            BufferSize::Default => None,
        };
        let shared = CallbackShared::new(
            p,
            tx,
            Arc::clone(&stats),
            Arc::clone(&stop),
            plan.channels as usize,
        );
        let res = match format {
            SampleFormat::F32 => build::<f32>(&device, &config, shared),
            SampleFormat::I16 => build::<i16>(&device, &config, shared),
            SampleFormat::I32 => build::<i32>(&device, &config, shared),
            SampleFormat::U16 => build::<u16>(&device, &config, shared),
            SampleFormat::F64 => build::<f64>(&device, &config, shared),
            other => Err((
                audio_err("sample format", format!("{other:?} unsupported")),
                None,
            )),
        };
        match res {
            Ok((stream, cell)) => {
                stream_and_buf = Some((stream, fixed, cell));
                break;
            }
            Err((e, back)) => {
                log::warn!("output stream with {buf:?} failed: {e}");
                last_err = Some(e);
                slot = back;
            }
        }
    }
    let Some((stream, fixed, cell)) = stream_and_buf else {
        let e = last_err.unwrap_or_else(|| UpError::audio("could not open output stream"));
        let _ = ready.send(Err((e, slot.map(|(p, _)| p))));
        return None;
    };
    if let Err(e) = stream.play() {
        let _ = ready.send(Err((audio_err("start stream", e), None)));
        return None;
    }
    let _ = ready.send(Ok(fixed));
    drop(quiet);

    // Park until asked to stop.
    while !stop.load(Ordering::Acquire) {
        std::thread::sleep(Duration::from_millis(20));
    }
    // The callback moves the processor into the slot on its next run.
    let deadline = Instant::now() + Duration::from_millis(500);
    let processor = loop {
        if let Ok(p) = back_rx.pop() {
            break Some(p);
        }
        if Instant::now() > deadline {
            // The callback never ran (or stalled): recover from the cell.
            let parked = cell
                .lock()
                .ok()
                .and_then(|mut g| g.take())
                .and_then(|s| s.processor);
            if parked.is_none() {
                log::warn!("audio callback did not return the processor in time");
            }
            break parked;
        }
        std::thread::sleep(Duration::from_millis(2));
    };
    drop(stream);
    processor
}

/// State owned by the realtime callback.
struct CallbackShared {
    processor: Option<AudioProcessor>,
    back: rtrb::Producer<AudioProcessor>,
    stats: Arc<StreamStats>,
    stop: Arc<AtomicBool>,
    channels: usize,
    scratch: Vec<f32>,
}

impl CallbackShared {
    fn new(
        p: AudioProcessor,
        back: rtrb::Producer<AudioProcessor>,
        stats: Arc<StreamStats>,
        stop: Arc<AtomicBool>,
        channels: usize,
    ) -> Self {
        Self {
            processor: Some(p),
            back,
            stats,
            stop,
            channels: channels.max(1),
            scratch: vec![0.0; SCRATCH_FRAMES * channels.max(1)],
        }
    }

    #[inline]
    fn render<T: SizedSample + FromSample<f32>>(
        &mut self,
        data: &mut [T],
        info: &OutputCallbackInfo,
    ) {
        if self.stop.load(Ordering::Acquire) {
            if let Some(p) = self.processor.take()
                && let Err(rtrb::PushError::Full(p)) = self.back.push(p)
            {
                // Slot full (should never happen): keep it.
                self.processor = Some(p);
            }
            data.fill(T::EQUILIBRIUM);
            return;
        }
        let Some(p) = self.processor.as_mut() else {
            data.fill(T::EQUILIBRIUM);
            return;
        };
        let ch = self.channels;
        let total_frames = data.len() / ch;
        for chunk in data.chunks_mut(self.scratch.len()) {
            let n = chunk.len();
            let s = &mut self.scratch[..n];
            p.process(s, ch);
            for (d, x) in chunk.iter_mut().zip(s.iter()) {
                *d = T::from_sample(*x);
            }
            self.stats.on_chunk(s, info);
        }
        self.stats.on_callback_done(total_frames);
    }
}

type Cell = Arc<Mutex<Option<CallbackShared>>>;
type BuildErr = (
    UpError,
    Option<(AudioProcessor, rtrb::Producer<AudioProcessor>)>,
);

/// Build a stream. The callback state is parked in a cell that the
/// callback empties on its first run, so the processor can be recovered if
/// building fails or the stream never runs.
fn build<T: SizedSample + FromSample<f32>>(
    device: &Device,
    config: &StreamConfig,
    shared: CallbackShared,
) -> Result<(cpal::Stream, Cell), BuildErr> {
    let stats = Arc::clone(&shared.stats);
    let cell: Cell = Arc::new(Mutex::new(None));
    let cell2 = Arc::clone(&cell);
    *cell
        .lock()
        .map_err(|_| (UpError::internal("poisoned"), None))? = Some(shared);
    // Move the state out of the cell into the callback on first run
    // (`try_lock` only — the control side never holds this lock while the
    // stream is running).
    let mut local: Option<CallbackShared> = None;
    let result = device.build_output_stream(
        *config,
        move |data: &mut [T], info: &OutputCallbackInfo| {
            if local.is_none()
                && let Ok(mut g) = cell2.try_lock()
            {
                local = g.take();
            }
            match local.as_mut() {
                Some(s) => s.render(data, info),
                None => data.fill(T::EQUILIBRIUM),
            }
        },
        move |e| stats.on_error(&e),
        None,
    );
    match result {
        Ok(stream) => Ok((stream, cell)),
        Err(e) => {
            let back = cell
                .lock()
                .ok()
                .and_then(|mut g| g.take())
                .and_then(|s| s.processor.map(|p| (p, s.back)));
            Err((audio_err("build output stream", e), back))
        }
    }
}
