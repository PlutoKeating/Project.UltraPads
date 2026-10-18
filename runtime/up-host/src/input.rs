//! Microphone capture for sampling.

use crate::audio::find_device;
use cpal::traits::{DeviceTrait, StreamTrait};
use cpal::{FromSample, InputCallbackInfo, SampleFormat, SizedSample, StreamConfig};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::JoinHandle;
use std::time::Duration;
use up_codec::AudioBuffer;
use up_core::{ErrorCode, UpError, UpResult};
use up_recorder::{RecordWriter, TakeCollector, record_channel};

/// Running input capture. Call [`InputCapture::stop`] to get the audio.
pub struct InputCapture {
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<UpResult<AudioBuffer>>>,
    pub sample_rate: u32,
    pub channels: u16,
    pub device: String,
}

/// Longest capture accepted.
pub const MAX_CAPTURE_SECS: f32 = 120.0;

fn map_err(ctx: &str, e: impl std::fmt::Display) -> UpError {
    let msg = format!("{ctx}: {e}");
    let l = msg.to_ascii_lowercase();
    if l.contains("permission") || l.contains("denied") || l.contains("not allowed") {
        UpError::new(
            ErrorCode::PermissionDenied,
            format!("{msg} (is RECORD_AUDIO granted?)"),
        )
    } else {
        UpError::audio(msg)
    }
}

impl InputCapture {
    /// Start capturing from `device` (id or name; `None` = default input).
    pub fn start(device: Option<&str>, max_secs: f32) -> UpResult<Self> {
        if !crate::android::context_ready() {
            return Err(UpError::state("Android context not initialised"));
        }
        let stop = Arc::new(AtomicBool::new(false));
        let (ready_tx, ready_rx) = crossbeam_channel::bounded::<UpResult<(u32, u16, String)>>(1);
        let wanted = device.map(str::to_owned);
        let stop2 = Arc::clone(&stop);
        let max_secs = max_secs.clamp(0.5, MAX_CAPTURE_SECS);
        let thread = std::thread::Builder::new()
            .name("up-input-capture".into())
            .spawn(move || capture_thread(wanted, max_secs, stop2, ready_tx))
            .map_err(|e| UpError::internal(format!("spawn capture thread: {e}")))?;
        match ready_rx.recv() {
            Ok(Ok((sample_rate, channels, device))) => Ok(Self {
                stop,
                thread: Some(thread),
                sample_rate,
                channels,
                device,
            }),
            Ok(Err(e)) => {
                let _ = thread.join();
                Err(e)
            }
            Err(_) => Err(UpError::internal("capture thread exited")),
        }
    }

    /// Stop and return the captured audio (device rate / channels).
    pub fn stop(mut self) -> UpResult<AudioBuffer> {
        self.stop.store(true, Ordering::Release);
        match self.thread.take() {
            Some(t) => t
                .join()
                .map_err(|_| UpError::internal("capture thread panicked"))?,
            None => Err(UpError::state("capture already stopped")),
        }
    }
}

impl Drop for InputCapture {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        if let Some(t) = self.thread.take() {
            let _ = t.join();
        }
    }
}

fn capture_thread(
    wanted: Option<String>,
    max_secs: f32,
    stop: Arc<AtomicBool>,
    ready: crossbeam_channel::Sender<UpResult<(u32, u16, String)>>,
) -> UpResult<AudioBuffer> {
    let quiet = crate::audio::quiet_alsa();
    let host = cpal::default_host();
    let device = match find_device(&host, wanted.as_deref(), false) {
        Ok(d) => d,
        Err(e) => {
            let _ = ready.send(Err(e.clone()));
            return Err(e);
        }
    };
    let name = device
        .description()
        .map(|d| d.name().to_owned())
        .unwrap_or_else(|_| "input".into());
    let def = match device.default_input_config() {
        Ok(c) => c,
        Err(e) => {
            let err = map_err("default input config", e);
            let _ = ready.send(Err(err.clone()));
            return Err(err);
        }
    };
    let sr = def.sample_rate();
    let ch = def.channels();
    let config: StreamConfig = def.config();
    let (mut writer, reader) = record_channel(sr, ch, 4.0);
    writer.start();
    let mut collector = TakeCollector::new(reader);
    let stream = match def.sample_format() {
        SampleFormat::F32 => build::<f32>(&device, &config, writer),
        SampleFormat::I16 => build::<i16>(&device, &config, writer),
        SampleFormat::I32 => build::<i32>(&device, &config, writer),
        SampleFormat::U16 => build::<u16>(&device, &config, writer),
        other => Err(UpError::audio(format!(
            "unsupported input format {other:?}"
        ))),
    };
    let stream =
        match stream.and_then(|s| s.play().map(|_| s).map_err(|e| map_err("start input", e))) {
            Ok(s) => s,
            Err(e) => {
                let _ = ready.send(Err(e.clone()));
                return Err(e);
            }
        };
    let _ = ready.send(Ok((sr, ch, name)));
    drop(quiet);
    let max_frames = (max_secs * sr as f32) as usize;
    while !stop.load(Ordering::Acquire) && collector.collected_frames() < max_frames {
        collector.poll();
        std::thread::sleep(Duration::from_millis(15));
    }
    drop(stream);
    let mut take = collector.finish();
    let keep = max_frames.min(take.audio.frames()) * ch as usize;
    take.audio.data.truncate(keep);
    Ok(take.audio)
}

fn build<T: SizedSample + Send + 'static>(
    device: &cpal::Device,
    config: &StreamConfig,
    mut writer: RecordWriter,
) -> UpResult<cpal::Stream>
where
    f32: FromSample<T>,
{
    let mut scratch = vec![0.0f32; 16_384];
    device
        .build_input_stream(
            *config,
            move |data: &[T], _: &InputCallbackInfo| {
                for chunk in data.chunks(scratch.len()) {
                    let s = &mut scratch[..chunk.len()];
                    for (d, x) in s.iter_mut().zip(chunk) {
                        *d = <f32 as FromSample<T>>::from_sample_(*x);
                    }
                    writer.write_interleaved(s);
                }
            },
            |e| log::warn!("input stream error: {e}"),
            None,
        )
        .map_err(|e| map_err("build input stream", e))
}
