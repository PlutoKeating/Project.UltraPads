//! [`AppCore`]: the runtime object behind the FFI and CLI.
//!
//! Owns the engine (rebuilt when the device sample rate changes), the
//! audio host, the current kit, microphone capture and track storage.
//! Hot-path calls (`pad_down`, `pad_up`, `send`, `snapshot`) only do a
//! lock-free `ArcSwap` load of the current engine handle.

use crate::audio::{AudioConfig, AudioDeviceInfo, AudioHost, AudioStatus, ProbeResult};
use crate::input::InputCapture;
use crate::kit_folder::{LoadedKit, apply_kit, load_folder_kit};
use crate::tracks::TrackStore;
use arc_swap::ArcSwapOption;
use crossbeam_channel::{Receiver, Sender, TrySendError};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard, RwLock};
use up_core::{KitId, PadId, SampleId, TrackId, UpError, UpResult};
use up_engine::{
    AudioProcessor, Command, Engine, EngineConfig, EngineEvent, EngineHandle, EngineSnapshot,
    GraphBackend, SampleData, TrackInfo,
};
use up_model::TutorialChart;

/// Stores a finished recording and returns its metadata (e.g. the
/// library's `track_add`). Runs on the engine control thread.
pub type TrackSink = Arc<dyn Fn(&up_engine::Take) -> UpResult<TrackInfo> + Send + Sync>;

/// Storage roots supplied by the platform shell.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppDirs {
    /// Persistent app data (tracks, samples, library).
    pub data_dir: String,
    /// Disposable cache.
    pub cache_dir: String,
}

/// Returned by `init`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct EngineInfo {
    pub version: String,
    pub sample_rate: u32,
    pub graph_backend: String,
    pub platform: String,
    pub data_dir: String,
}

#[derive(Default)]
struct EventBus {
    subs: Mutex<Vec<Sender<EngineEvent>>>,
}

impl EventBus {
    fn subscribe(&self) -> Receiver<EngineEvent> {
        let (tx, rx) = crossbeam_channel::bounded(4096);
        if let Ok(mut s) = self.subs.lock() {
            s.push(tx);
        }
        rx
    }

    fn broadcast(&self, ev: EngineEvent) {
        if let Ok(mut subs) = self.subs.lock() {
            subs.retain(|s| !matches!(s.try_send(ev.clone()), Err(TrySendError::Disconnected(_))));
        }
    }
}

struct State {
    host: AudioHost,
    /// Processor parked while no stream runs.
    processor: Option<AudioProcessor>,
    engine_cfg: EngineConfig,
    kit: Option<LoadedKit>,
    mic: Option<InputCapture>,
}

/// Application runtime core.
pub struct AppCore {
    dirs: AppDirs,
    tracks: TrackStore,
    samples_dir: PathBuf,
    handle: ArcSwapOption<EngineHandle>,
    bus: Arc<EventBus>,
    state: Mutex<State>,
    track_sink: Arc<RwLock<Option<TrackSink>>>,
}

impl AppCore {
    /// Create directories and an engine at the default sample rate (it is
    /// rebuilt on `audio_start` if the device uses another rate).
    pub fn new(dirs: AppDirs, engine_cfg: EngineConfig) -> UpResult<Self> {
        let data = PathBuf::from(&dirs.data_dir);
        if dirs.data_dir.is_empty() {
            return Err(UpError::invalid("data_dir must not be empty"));
        }
        std::fs::create_dir_all(&data)?;
        if !dirs.cache_dir.is_empty() {
            std::fs::create_dir_all(&dirs.cache_dir)?;
        }
        let samples_dir = data.join("samples");
        std::fs::create_dir_all(&samples_dir)?;
        let core = Self {
            tracks: TrackStore::new(data.join("tracks"))?,
            samples_dir,
            dirs,
            handle: ArcSwapOption::empty(),
            bus: Arc::new(EventBus::default()),
            track_sink: Arc::new(RwLock::new(None)),
            state: Mutex::new(State {
                host: AudioHost::new(),
                processor: None,
                engine_cfg,
                kit: None,
                mic: None,
            }),
        };
        {
            let mut st = core.lock()?;
            let sr = st.engine_cfg.sample_rate;
            core.rebuild_engine(&mut st, sr)?;
        }
        Ok(core)
    }

    fn lock(&self) -> UpResult<MutexGuard<'_, State>> {
        self.state
            .lock()
            .map_err(|_| UpError::internal("runtime state poisoned"))
    }

    /// Current engine handle (lock-free).
    pub fn handle(&self) -> UpResult<Arc<EngineHandle>> {
        self.handle.load_full().ok_or_else(|| {
            UpError::new(up_core::ErrorCode::NotInitialized, "engine not initialised")
        })
    }

    fn rebuild_engine(&self, st: &mut State, sample_rate: u32) -> UpResult<()> {
        let cfg = EngineConfig {
            sample_rate,
            ..st.engine_cfg.clone()
        };
        let (handle, processor) = Engine::new(cfg.clone())?;
        st.engine_cfg = cfg;
        // Forward this engine's events into the app-wide bus.
        let rx = handle.subscribe();
        let bus = Arc::clone(&self.bus);
        std::thread::Builder::new()
            .name("up-event-forward".into())
            .spawn(move || {
                for ev in rx {
                    bus.broadcast(ev);
                }
            })
            .map_err(|e| UpError::internal(format!("spawn forwarder: {e}")))?;
        let tracks = self.tracks.clone();
        let sink = Arc::clone(&self.track_sink);
        handle.set_take_handler(Some(Box::new(move |take| {
            let custom = sink.read().ok().and_then(|s| s.clone());
            let info = match custom {
                Some(f) => f(&take)?,
                None => tracks.save_take(&take)?,
            };
            Ok(Some(EngineEvent::TrackSaved { track: info }))
        })));
        // Re-apply the current kit at the new rate.
        if let Some(kit) = st.kit.take() {
            match kit
                .resampled(sample_rate)
                .and_then(|k| apply_kit(&handle, &k).map(|_| k))
            {
                Ok(k) => st.kit = Some(k),
                Err(e) => log::warn!("could not reload kit after engine rebuild: {e}"),
            }
        }
        st.processor = Some(processor);
        self.handle.store(Some(Arc::new(handle)));
        Ok(())
    }

    pub fn info(&self) -> EngineInfo {
        let sr = self.handle().map(|h| h.sample_rate()).unwrap_or(0);
        let backend = self
            .lock()
            .map(|s| format!("{:?}", s.engine_cfg.graph_backend))
            .unwrap_or_default();
        EngineInfo {
            version: env!("CARGO_PKG_VERSION").to_owned(),
            sample_rate: sr,
            graph_backend: backend,
            platform: format!("{}-{}", std::env::consts::OS, std::env::consts::ARCH),
            data_dir: self.dirs.data_dir.clone(),
        }
    }

    pub fn dirs(&self) -> &AppDirs {
        &self.dirs
    }

    // ---- hot path -------------------------------------------------------

    #[inline]
    pub fn pad_down(&self, pad: PadId, velocity: f32) -> UpResult<()> {
        self.handle()?.pad_down(pad, velocity)
    }

    #[inline]
    pub fn pad_up(&self, pad: PadId) -> UpResult<()> {
        self.handle()?.pad_up(pad)
    }

    pub fn send(&self, cmd: Command) -> UpResult<()> {
        self.handle()?.send(cmd)
    }

    pub fn transport_clock(&self) -> UpResult<up_engine::TransportClock> {
        Ok(self.handle()?.transport_clock())
    }

    pub fn snapshot(&self) -> UpResult<EngineSnapshot> {
        Ok(self.handle()?.snapshot())
    }

    /// App-wide event stream (survives engine rebuilds).
    pub fn subscribe(&self) -> Receiver<EngineEvent> {
        self.bus.subscribe()
    }

    /// Inject an event (library / hub / errors).
    pub fn emit(&self, ev: EngineEvent) {
        self.bus.broadcast(ev);
    }

    // ---- audio ----------------------------------------------------------

    pub fn audio_devices(&self) -> UpResult<Vec<AudioDeviceInfo>> {
        AudioHost::devices()
    }

    pub fn audio_start(&self, cfg: &AudioConfig) -> UpResult<AudioStatus> {
        let mut st = self.lock()?;
        if st.host.is_running()
            && let Some(p) = st.host.stop()
        {
            st.processor = Some(p);
        }
        let plan = AudioHost::plan_output(cfg)?;
        let current = self.handle()?.sample_rate();
        if plan.sample_rate != current || st.processor.is_none() {
            self.rebuild_engine(&mut st, plan.sample_rate)?;
        }
        let processor = st
            .processor
            .take()
            .ok_or_else(|| UpError::internal("audio processor missing"))?;
        match st.host.start(&plan, processor) {
            Ok(status) => Ok(status),
            Err((e, back)) => {
                st.processor = back;
                Err(e)
            }
        }
    }

    pub fn audio_stop(&self) -> UpResult<()> {
        let mut st = self.lock()?;
        if !st.host.is_running() {
            return Ok(());
        }
        let _ = self.handle()?.send(Command::StopAll);
        match st.host.stop() {
            Some(p) => st.processor = Some(p),
            None => {
                // Processor lost with the stream: rebuild at the same rate.
                let sr = self.handle()?.sample_rate();
                self.rebuild_engine(&mut st, sr)?;
            }
        }
        Ok(())
    }

    pub fn audio_status(&self) -> UpResult<AudioStatus> {
        Ok(self.lock()?.host.status())
    }

    /// Arm the output latency probe (see `up-cli latency-probe`).
    pub fn arm_latency_probe(&self) -> UpResult<()> {
        self.lock()?.host.stats().arm_probe();
        Ok(())
    }

    pub fn latency_probe_result(&self) -> UpResult<Option<ProbeResult>> {
        Ok(self.lock()?.host.stats().probe_result())
    }

    // ---- kits -----------------------------------------------------------

    /// Replace where recordings are stored (default: the built-in
    /// [`TrackStore`] under `data_dir/tracks`).
    pub fn set_track_sink(&self, sink: Option<TrackSink>) {
        if let Ok(mut s) = self.track_sink.write() {
            *s = sink;
        }
    }

    /// Load a folder of audio files as a kit (dev / CLI path).
    pub fn load_kit_folder(&self, dir: &Path) -> UpResult<up_engine::KitSummary> {
        let handle = self.handle()?;
        let kit = load_folder_kit(dir, handle.sample_rate())?;
        self.install_kit(&handle, kit)
    }

    /// Load a kit document with its original-rate audio (library path).
    /// Samples are resampled to the engine rate and kept for rebuilds.
    pub fn load_kit(
        &self,
        doc: up_model::KitDoc,
        audio: Vec<crate::KitAudio>,
    ) -> UpResult<up_engine::KitSummary> {
        doc.validate()?;
        let handle = self.handle()?;
        let kit = LoadedKit::from_audio(None, doc, audio, handle.sample_rate())?;
        self.install_kit(&handle, kit)
    }

    fn install_kit(
        &self,
        handle: &EngineHandle,
        kit: LoadedKit,
    ) -> UpResult<up_engine::KitSummary> {
        // Stop whatever the previous kit was playing (Ref behaviour).
        handle.send(Command::StopAll)?;
        apply_kit(handle, &kit)?;
        // Make `snapshot()` reflect the new kit as soon as this returns.
        handle.flush(std::time::Duration::from_secs(2))?;
        let summary = kit.doc.summary();
        self.lock()?.kit = Some(kit);
        Ok(summary)
    }

    /// Register decoded audio (original rate) as an engine sample.
    pub fn register_audio(
        &self,
        id: SampleId,
        name: &str,
        audio: &up_codec::AudioBuffer,
    ) -> UpResult<()> {
        let handle = self.handle()?;
        let rs = up_codec::resample(audio, handle.sample_rate())?;
        handle.register_sample(SampleData::new(
            id,
            name,
            handle.sample_rate(),
            rs.to_planar(),
        ));
        Ok(())
    }

    /// Play arbitrary audio (e.g. a library track) on the preview voice.
    pub fn play_audio(&self, track: &TrackId, audio: &up_codec::AudioBuffer) -> UpResult<()> {
        let handle = self.handle()?;
        let rs = up_codec::resample(audio, handle.sample_rate())?;
        let s = SampleData::new(
            SampleId::new(format!("track:{track}")),
            track.as_str(),
            handle.sample_rate(),
            rs.to_planar(),
        );
        handle.play_preview(track.clone(), Arc::new(s))
    }

    pub fn current_kit(&self) -> UpResult<Option<up_model::KitDoc>> {
        Ok(self.lock()?.kit.as_ref().map(|k| k.doc.clone()))
    }

    /// Tutorial for `kit` (current kit, or a folder kit's `tutorial.json`).
    pub fn tutorial(&self, kit: &KitId) -> UpResult<Option<TutorialChart>> {
        if let Some(k) = self.lock()?.kit.as_ref()
            && &k.doc.id == kit
        {
            return Ok(k.doc.tutorial.clone());
        }
        let dir = PathBuf::from(kit.as_str());
        for p in [
            dir.join("tutorial.json"),
            dir.join("Sounds").join("tutorial.json"),
        ] {
            if let Ok(text) = std::fs::read_to_string(&p) {
                return TutorialChart::from_json_any(&text).map(Some);
            }
        }
        Ok(None)
    }

    pub fn sample_waveform(&self, sample: &SampleId, buckets: u32) -> UpResult<Vec<f32>> {
        self.handle()?.waveform(sample, buckets.clamp(1, 16_384))
    }

    // ---- microphone sampling -------------------------------------------

    pub fn sampler_record_start(&self, input_device: Option<&str>) -> UpResult<()> {
        let mut st = self.lock()?;
        if st.mic.is_some() {
            return Err(UpError::state("microphone recording already running"));
        }
        st.mic = Some(InputCapture::start(input_device, 30.0)?);
        Ok(())
    }

    /// Stop the microphone and return the captured audio (device rate).
    pub fn sampler_record_stop_audio(&self) -> UpResult<up_codec::AudioBuffer> {
        let cap = self
            .lock()?
            .mic
            .take()
            .ok_or_else(|| UpError::state("microphone recording not running"))?;
        let audio = cap.stop()?;
        if audio.is_empty() {
            return Err(UpError::state("no audio captured"));
        }
        Ok(audio)
    }

    /// Stop the microphone, store the sample under `data_dir/samples` and
    /// register it with the engine. Returns its id (BLAKE3 of the PCM data).
    pub fn sampler_record_stop(&self) -> UpResult<SampleId> {
        let audio = self.sampler_record_stop_audio()?;
        let mut hasher = blake3::Hasher::new();
        for s in &audio.data {
            hasher.update(&s.to_le_bytes());
        }
        let id = SampleId::new(hasher.finalize().to_hex().to_string());
        let path = self.samples_dir.join(format!("{id}.wav"));
        {
            let f = std::fs::File::create(&path)?;
            up_codec::write_wav(
                std::io::BufWriter::new(f),
                &audio,
                up_codec::WavFormat::Pcm24,
            )?;
        }
        let handle = self.handle()?;
        let rs = up_codec::resample(&audio, handle.sample_rate())?;
        handle.register_sample(SampleData::new(
            id.clone(),
            "mic",
            handle.sample_rate(),
            rs.to_planar(),
        ));
        self.emit(EngineEvent::LibraryChanged);
        Ok(id)
    }

    // ---- tracks ---------------------------------------------------------

    pub fn tracks(&self) -> &TrackStore {
        &self.tracks
    }

    pub fn tracks_list(&self) -> UpResult<Vec<TrackInfo>> {
        self.tracks.list()
    }

    pub fn track_play(&self, id: &TrackId) -> UpResult<()> {
        let handle = self.handle()?;
        let s = self.tracks.load_sample(id, handle.sample_rate())?;
        handle.play_preview(id.clone(), Arc::new(s))
    }

    pub fn track_stop(&self) -> UpResult<()> {
        self.handle()?.stop_preview()
    }

    pub fn track_export(&self, id: &TrackId, path: &Path, format: &str) -> UpResult<()> {
        self.tracks.export(id, path, format)
    }

    pub fn track_delete(&self, id: &TrackId) -> UpResult<()> {
        self.tracks.delete(id)?;
        self.emit(EngineEvent::LibraryChanged);
        Ok(())
    }

    /// Graph backend used by new engines.
    pub fn graph_backend(&self) -> UpResult<GraphBackend> {
        Ok(self.lock()?.engine_cfg.graph_backend)
    }

    /// Take the parked processor (for offline rendering without a device).
    pub fn take_processor(&self) -> UpResult<Option<AudioProcessor>> {
        let mut st = self.lock()?;
        if st.host.is_running() {
            return Err(UpError::state("audio is running"));
        }
        Ok(st.processor.take())
    }

    pub fn return_processor(&self, p: AudioProcessor) -> UpResult<()> {
        self.lock()?.processor = Some(p);
        Ok(())
    }
}

impl Drop for AppCore {
    fn drop(&mut self) {
        if let Ok(mut st) = self.state.lock() {
            st.mic = None;
            let _ = st.host.stop();
        }
    }
}
