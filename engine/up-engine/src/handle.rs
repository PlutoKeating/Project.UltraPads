use crate::EngineConfig;
use crate::control::{Control, ControlMsg, SUBSCRIBER_CAPACITY};
use crate::meters::MeterBank;
use crate::nodes::{MasterNode, MixerNode, SamplerNode};
use crate::processor::AudioProcessor;
use crate::rt::{MasterCmd, RtCommand};
use arc_swap::{ArcSwap, ArcSwapOption};
use crossbeam_channel::{Receiver, Sender};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use up_core::{ErrorCode, PAD_COUNT, PadId, SampleId, TrackId, UpError, UpResult};
use up_graph::{DescNode, GraphDesc, NodeSpec, StreamConfig};
use up_mixer::{MIXER_INPUTS, Mixer, MixerParams};
use up_protocol::{
    BPM_MAX, BPM_MIN, Command, EngineEvent, EngineSnapshot, KitSummary, PadParams, PadSnapshot,
    SPEED_MAX, SPEED_MIN, TransportState,
};
use up_recorder::{Take, TakeCollector, record_channel};
use up_rt::mpsc::CommandQueue;
use up_rt::param::AtomicF32;
use up_rt::retire::retire_channel;
use up_rt::spsc;
use up_sampler::{
    RtPadParams, SampleArc, SampleData, SampleUpdate, Sampler, SamplerCmd, SamplerConfig,
    outputs_needed,
};
use up_transport::Transport;

/// Called on the control thread with each finished recording. Return an
/// event to broadcast (e.g. `TrackSaved`) or an error.
pub type TakeHandler = Box<dyn FnMut(Take) -> UpResult<Option<EngineEvent>> + Send>;

struct Shared {
    sample_rate: u32,
    commands: CommandQueue<RtCommand>,
    master_cmds: CommandQueue<crate::rt::MasterCmd>,
    registry: ArcSwap<HashMap<SampleId, SampleArc>>,
    pad_samples: Vec<ArcSwapOption<SampleId>>,
    snapshot: Arc<ArcSwap<EngineSnapshot>>,
    ctl: Sender<ControlMsg>,
    master_gain: Arc<AtomicF32>,
    meters: Arc<MeterBank>,
    last_take: Arc<Mutex<Option<Take>>>,
    last_pong: Arc<AtomicU64>,
    dropped: AtomicU64,
}

/// Thread-safe, cloneable control handle. All methods are callable from any
/// thread; [`EngineHandle::send`] and the pad helpers are lock-free.
#[derive(Clone)]
pub struct EngineHandle {
    shared: Arc<Shared>,
}

/// Engine statistics.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EngineStats {
    pub frames_processed: u64,
    pub callbacks: u64,
    pub dropped_commands: u64,
    pub queued_commands: usize,
}

pub(crate) fn build(cfg: EngineConfig) -> UpResult<(EngineHandle, AudioProcessor)> {
    let sr = cfg.sample_rate;
    let commands = CommandQueue::new(cfg.command_capacity);
    let master_cmds = CommandQueue::new(64);
    let (sampler_ev_tx, sampler_ev_rx) = spsc::channel(cfg.event_capacity);
    let (master_ev_tx, master_ev_rx) = spsc::channel(256);
    let (retirer, collector) = retire_channel(1024);
    let (rec_writer, rec_reader) = record_channel(sr, 2, cfg.record_ring_seconds);
    let meters = Arc::new(MeterBank::default());
    let master_gain = Arc::new(AtomicF32::new(1.0));

    let mut transport = Transport::new(sr, cfg.bpm);
    transport.set_speed(1.0);
    let sampler = Sampler::new(
        SamplerConfig {
            sample_rate: sr,
            max_voices: cfg.max_voices,
            ..Default::default()
        },
        retirer,
    );
    let sampler_node = SamplerNode {
        sampler,
        transport,
        commands: commands.clone(),
        events: sampler_ev_tx,
        meters: Arc::clone(&meters),
        transport_interval: (sr as f64 / cfg.meter_hz.max(1.0)) as u32,
        since_transport: 0,
        last_playing: false,
        overflow: false,
    };
    let mixer_node = MixerNode {
        mixer: Mixer::new(sr, Arc::new(MixerParams::default())),
        meters: Arc::clone(&meters),
        levels: [0.0; PAD_COUNT],
    };
    let master_node = MasterNode::new(
        sr,
        cfg.meter_hz,
        Arc::clone(&master_gain),
        Arc::clone(&meters),
        rec_writer,
        master_cmds.clone(),
        master_ev_tx,
    );

    let mut desc = GraphDesc::new(2);
    let n_sampler = desc.add_node(
        NodeSpec {
            name: "pad_sampler",
            inputs: 0,
            outputs: outputs_needed(),
        },
        Box::new(sampler_node),
    );
    let n_mixer = desc.add_node(
        NodeSpec {
            name: "mixer",
            inputs: MIXER_INPUTS,
            outputs: 2,
        },
        Box::new(mixer_node),
    );
    let n_master = desc.add_node(
        NodeSpec {
            name: "master",
            inputs: 2,
            outputs: 2,
        },
        Box::new(master_node),
    );
    desc.connect_ports(n_sampler, 0, n_mixer, 0, outputs_needed().min(MIXER_INPUTS));
    desc.connect_ports(n_mixer, 0, n_master, 0, 2);
    desc.connect_ports(n_master, 0, DescNode::OUTPUT, 0, 2);

    let snapshot = Arc::new(ArcSwap::from_pointee(initial_snapshot(&cfg)));
    let last_take = Arc::new(Mutex::new(None));
    let last_pong = Arc::new(AtomicU64::new(0));
    let (ctl_tx, ctl_rx) = crossbeam_channel::unbounded();
    let (ready_tx, ready_rx) = crossbeam_channel::bounded(1);

    let stream = StreamConfig {
        sample_rate: sr,
        max_block_frames: cfg.max_block_frames,
        output_channels: 2,
    };
    let backend = cfg.graph_backend;
    let ctl_parts = (
        Arc::clone(&meters),
        Arc::clone(&snapshot),
        Arc::clone(&last_take),
        Arc::clone(&last_pong),
        initial_snapshot(&cfg),
    );
    let meter_period = Duration::from_secs_f64(1.0 / cfg.meter_hz.clamp(1.0, 1000.0));
    std::thread::Builder::new()
        .name("up-engine-control".into())
        .spawn(move || {
            // The graph is created and lives on this thread (Firewheel's
            // context is not `Send`).
            let built = desc.instantiate(backend).and_then(|mut g| {
                let p = g.activate(stream)?;
                Ok((g, p))
            });
            let (graph, processor) = match built {
                Ok(x) => x,
                Err(e) => {
                    let _ = ready_tx.send(Err(e));
                    return;
                }
            };
            if ready_tx.send(Ok(processor)).is_err() {
                return;
            }
            let (meters, snapshot, last_take, last_pong, snap) = ctl_parts;
            Control {
                graph,
                rx: ctl_rx,
                sampler_events: sampler_ev_rx,
                master_events: master_ev_rx,
                collector,
                takes: TakeCollector::new(rec_reader),
                meters,
                snapshot,
                last_take,
                last_pong,
                sample_rate: sr,
                meter_period,
                snap,
                dirty: false,
                subscribers: Vec::new(),
                take_handler: None,
                recording: false,
                preview: None,
                meters_were_active: false,
                tick: 0,
            }
            .run();
        })
        .map_err(|e| UpError::internal(format!("spawn control thread: {e}")))?;

    let graph_processor = ready_rx
        .recv()
        .map_err(|_| UpError::internal("control thread died during startup"))??;
    let processor = AudioProcessor::new(
        graph_processor,
        cfg.max_block_frames,
        Arc::clone(&meters),
        sr,
    );
    let handle = EngineHandle {
        shared: Arc::new(Shared {
            sample_rate: sr,
            commands,
            master_cmds,
            registry: ArcSwap::from_pointee(HashMap::new()),
            pad_samples: (0..PAD_COUNT).map(|_| ArcSwapOption::empty()).collect(),
            snapshot,
            ctl: ctl_tx,
            master_gain,
            meters,
            last_take,
            last_pong,
            dropped: AtomicU64::new(0),
        }),
    };
    Ok((handle, processor))
}

fn initial_snapshot(cfg: &EngineConfig) -> EngineSnapshot {
    EngineSnapshot {
        pads: PadId::all()
            .map(|pad| PadSnapshot {
                pad,
                ..Default::default()
            })
            .collect(),
        transport: TransportState {
            bpm: cfg.bpm,
            ..Default::default()
        },
        kit: None,
        master_gain: 1.0,
        sample_rate: cfg.sample_rate,
        ..Default::default()
    }
}

fn check_pad(pad: PadId) -> UpResult<u8> {
    if pad.is_valid() {
        Ok(pad.flat() as u8)
    } else {
        Err(UpError::invalid(format!("pad out of range: {pad:?}")))
    }
}

fn finite(v: f64, what: &str) -> UpResult<f64> {
    if v.is_finite() {
        Ok(v)
    } else {
        Err(UpError::invalid(format!("{what} must be finite")))
    }
}

impl EngineHandle {
    pub fn sample_rate(&self) -> u32 {
        self.shared.sample_rate
    }

    fn push(&self, cmd: RtCommand) -> UpResult<()> {
        self.shared.commands.push(cmd).map_err(|_| {
            self.shared.dropped.fetch_add(1, Ordering::Relaxed);
            UpError::new(ErrorCode::QueueFull, "engine command queue is full")
        })
    }

    fn notify(&self, cmd: Command) {
        let _ = self.shared.ctl.send(ControlMsg::Applied(cmd));
    }

    /// Hot path: press a pad. Lock-free, allocation-free.
    #[inline]
    pub fn pad_down(&self, pad: PadId, velocity: f32) -> UpResult<()> {
        let pad = check_pad(pad)?;
        let velocity = if velocity.is_finite() {
            velocity.clamp(0.0, 1.0)
        } else {
            1.0
        };
        self.push(RtCommand::Sampler(SamplerCmd::PadDown { pad, velocity }))
    }

    /// Hot path: release a pad. Lock-free, allocation-free.
    #[inline]
    pub fn pad_up(&self, pad: PadId) -> UpResult<()> {
        let pad = check_pad(pad)?;
        self.push(RtCommand::Sampler(SamplerCmd::PadUp { pad }))
    }

    /// Send any [`Command`]. Lock-free (the command queue is a bounded
    /// lock-free queue; sample lookups use an `ArcSwap` registry).
    pub fn send(&self, cmd: Command) -> UpResult<()> {
        match cmd {
            Command::PadDown { pad, velocity } => self.pad_down(pad, velocity),
            Command::PadUp { pad } => self.pad_up(pad),
            Command::StopAll => self.push(RtCommand::Sampler(SamplerCmd::StopAll)),
            Command::SetTempo { bpm } => {
                let bpm = finite(bpm, "bpm")?.clamp(BPM_MIN, BPM_MAX);
                self.push(RtCommand::SetTempo(bpm))?;
                self.notify(Command::SetTempo { bpm });
                Ok(())
            }
            Command::SetSpeed { ratio } => {
                let ratio = finite(ratio, "speed")?.clamp(SPEED_MIN, SPEED_MAX);
                self.push(RtCommand::Sampler(SamplerCmd::SetSpeed(ratio)))?;
                self.notify(Command::SetSpeed { ratio });
                Ok(())
            }
            Command::SetQuantize { q } => {
                self.push(RtCommand::Sampler(SamplerCmd::SetQuantize(q)))?;
                self.notify(Command::SetQuantize { q });
                Ok(())
            }
            Command::SetPadParams { pad, params } => self.set_pad_params(pad, params),
            Command::SetMasterGain { gain } => {
                if !gain.is_finite() {
                    return Err(UpError::invalid("gain must be finite"));
                }
                let gain = gain.clamp(0.0, 4.0);
                self.shared.master_gain.set(gain);
                self.notify(Command::SetMasterGain { gain });
                Ok(())
            }
            Command::StartRecording => self.push_master(MasterCmd::StartRecording),
            Command::StopRecording => self.push_master(MasterCmd::StopRecording),
            Command::Transport(t) => {
                if let up_protocol::TransportCmd::Seek(b) = t {
                    finite(b, "seek position")?;
                }
                self.push(RtCommand::Transport(t))
            }
        }
    }

    fn push_master(&self, cmd: MasterCmd) -> UpResult<()> {
        self.shared
            .master_cmds
            .push(cmd)
            .map_err(|_| UpError::new(ErrorCode::QueueFull, "master command queue is full"))
    }

    fn set_pad_params(&self, pad: PadId, mut params: PadParams) -> UpResult<()> {
        let flat = check_pad(pad)?;
        if !params.gain.is_finite() || !params.pan.is_finite() {
            return Err(UpError::invalid("gain/pan must be finite"));
        }
        params.gain = params.gain.clamp(0.0, 4.0);
        params.pan = params.pan.clamp(-1.0, 1.0);
        let slot = &self.shared.pad_samples[flat as usize];
        let current = slot.load_full();
        let update = match (&params.sample, current.as_deref()) {
            (None, None) => SampleUpdate::Keep,
            (None, Some(_)) => SampleUpdate::Clear,
            (Some(id), Some(cur)) if id == cur => SampleUpdate::Keep,
            (Some(id), _) => match self.sample(id) {
                Some(arc) => SampleUpdate::Set(arc),
                None => return Err(UpError::not_found(format!("sample {id} is not registered"))),
            },
        };
        let rt = RtPadParams {
            mode: params.mode,
            gain: params.gain,
            pan: params.pan,
            choke_group: params.choke_group,
            choked_by: params.choked_by,
            choke_release_ms: params.choke_release_ms.filter(|ms| ms.is_finite()),
            self_choke: params.self_choke,
            retrigger: params.retrigger,
            start_frame: params.start_frame,
            end_frame: params.end_frame,
            loop_start: params.loop_start,
            loop_end: params.loop_end,
            quantize_override: params.quantize_override,
        };
        self.push(RtCommand::Sampler(SamplerCmd::SetPad {
            pad: flat,
            params: rt,
            sample: update,
        }))?;
        slot.store(params.sample.clone().map(Arc::new));
        self.notify(Command::SetPadParams { pad, params });
        Ok(())
    }

    /// Register a decoded sample (must already be at the engine sample
    /// rate for correct pitch; see `up_codec::resample`). Replaces any
    /// sample with the same id.
    pub fn register_sample(&self, data: SampleData) -> SampleArc {
        let arc = Arc::new(data);
        let id = arc.id.clone();
        let ins = Arc::clone(&arc);
        self.shared.registry.rcu(move |m| {
            let mut m = HashMap::clone(m);
            m.insert(id.clone(), Arc::clone(&ins));
            m
        });
        arc
    }

    /// Remove a sample from the registry (pads keep playing their copy).
    pub fn unregister_sample(&self, id: &SampleId) {
        self.shared.registry.rcu(|m| {
            let mut m = HashMap::clone(m);
            m.remove(id);
            m
        });
    }

    pub fn sample(&self, id: &SampleId) -> Option<SampleArc> {
        self.shared.registry.load().get(id).cloned()
    }

    pub fn sample_ids(&self) -> Vec<SampleId> {
        self.shared.registry.load().keys().cloned().collect()
    }

    /// Peak overview of a registered sample.
    pub fn waveform(&self, id: &SampleId, buckets: u32) -> UpResult<Vec<f32>> {
        let s = self
            .sample(id)
            .ok_or_else(|| UpError::not_found(format!("sample {id}")))?;
        let chans: Vec<&[f32]> = s.channels.iter().map(Vec::as_slice).collect();
        Ok(up_codec::waveform_planar(&chans, buckets))
    }

    /// Play a recorded track (or any sample) on the preview voice.
    pub fn play_preview(&self, track: TrackId, sample: SampleArc) -> UpResult<()> {
        self.push(RtCommand::Sampler(SamplerCmd::PlayPreview(sample)))?;
        let _ = self.shared.ctl.send(ControlMsg::PreviewStarted(track));
        Ok(())
    }

    pub fn stop_preview(&self) -> UpResult<()> {
        self.push(RtCommand::Sampler(SamplerCmd::StopPreview))
    }

    /// Subscribe to the event stream.
    pub fn subscribe(&self) -> Receiver<EngineEvent> {
        let (tx, rx) = crossbeam_channel::bounded(SUBSCRIBER_CAPACITY);
        let _ = self.shared.ctl.send(ControlMsg::Subscribe(tx));
        rx
    }

    /// Latest full snapshot (lock-free read).
    pub fn snapshot(&self) -> EngineSnapshot {
        let mut s = EngineSnapshot::clone(&self.shared.snapshot.load());
        for p in &mut s.pads {
            p.sample_secs = p
                .params
                .sample
                .as_ref()
                .and_then(|id| self.sample(id))
                .map_or(0.0, |s| s.duration_secs());
        }
        s
    }

    /// Set the current kit summary (broadcasts `KitLoaded`).
    pub fn set_kit(&self, kit: Option<KitSummary>) {
        let _ = self.shared.ctl.send(ControlMsg::SetKit(kit));
    }

    /// Inject an event into the stream (runtime: library/hub/errors).
    pub fn emit(&self, ev: EngineEvent) {
        let _ = self.shared.ctl.send(ControlMsg::Emit(ev));
    }

    /// Install the recording handler (runs on the control thread).
    pub fn set_take_handler(&self, handler: Option<TakeHandler>) {
        let _ = self.shared.ctl.send(ControlMsg::SetTakeHandler(handler));
    }

    /// Take the last finished recording (only when no handler is set).
    pub fn take_last_take(&self) -> Option<Take> {
        self.shared.last_take.lock().ok().and_then(|mut t| t.take())
    }

    /// Wait until the control thread has processed everything sent so far
    /// and drained the audio-thread queues.
    pub fn flush(&self, timeout: Duration) -> UpResult<()> {
        let (tx, rx) = crossbeam_channel::bounded(1);
        self.shared
            .ctl
            .send(ControlMsg::Flush(tx))
            .map_err(|_| UpError::state("control thread stopped"))?;
        rx.recv_timeout(timeout)
            .map_err(|_| UpError::state("control thread did not respond"))
    }

    /// Precise transport clock (lock-free, extrapolated to now). Use for
    /// tutorial judgement: compare `song_secs` at the press with the chart.
    pub fn transport_clock(&self) -> up_protocol::TransportClock {
        self.shared.meters.clock.read()
    }

    /// Latency probe helper: enqueue a marker that the audio thread echoes.
    pub fn ping(&self, n: u64) -> UpResult<()> {
        self.push(RtCommand::Ping(n))
    }

    /// Last marker echoed by the audio thread.
    pub fn last_pong(&self) -> u64 {
        self.shared.last_pong.load(Ordering::Acquire)
    }

    pub fn stats(&self) -> EngineStats {
        EngineStats {
            frames_processed: self.shared.meters.frames.load(Ordering::Relaxed),
            callbacks: self.shared.meters.callbacks.load(Ordering::Relaxed),
            dropped_commands: self.shared.dropped.load(Ordering::Relaxed),
            queued_commands: self.shared.commands.len(),
        }
    }
}

impl std::fmt::Debug for EngineHandle {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EngineHandle")
            .field("sample_rate", &self.shared.sample_rate)
            .finish_non_exhaustive()
    }
}
