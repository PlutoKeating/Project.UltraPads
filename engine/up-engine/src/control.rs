//! Control thread: owns the audio graph, drains audio-thread queues,
//! frees retired resources, coalesces events and maintains the snapshot.

use crate::handle::TakeHandler;
use crate::meters::{MeterBank, take_peak};
use crate::rt::RtEvent;
use arc_swap::ArcSwap;
use crossbeam_channel::{Receiver, Sender, TrySendError};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use up_core::{PAD_COUNT, PadId, TrackId};
use up_graph::AudioGraph;
use up_protocol::{Command, EngineEvent, EngineSnapshot, KitSummary, RecorderState};
use up_recorder::{Take, TakeCollector};
use up_rt::retire::Collector;
use up_rt::spsc::Consumer;
use up_sampler::SampleArc;

/// Messages from handles to the control thread.
pub(crate) enum ControlMsg {
    /// A command was accepted; update the snapshot.
    Applied(Command),
    Subscribe(Sender<EngineEvent>),
    Emit(EngineEvent),
    SetKit(Option<KitSummary>),
    SetTakeHandler(Option<TakeHandler>),
    /// Preview voice started: `Some` = track playback, `None` = audition.
    PreviewStarted(Option<TrackId>),
    /// Process everything pending, then acknowledge.
    Flush(Sender<()>),
}

/// Per-subscriber channel bound; slow subscribers lose events, never block.
pub(crate) const SUBSCRIBER_CAPACITY: usize = 4096;
const POLL: Duration = Duration::from_millis(4);

pub(crate) struct Control {
    pub graph: Box<dyn AudioGraph>,
    pub rx: Receiver<ControlMsg>,
    pub sampler_events: Consumer<RtEvent>,
    pub master_events: Consumer<RtEvent>,
    pub collector: Collector<SampleArc>,
    pub takes: TakeCollector,
    pub meters: Arc<MeterBank>,
    pub snapshot: Arc<ArcSwap<EngineSnapshot>>,
    pub last_take: Arc<Mutex<Option<Take>>>,
    pub last_pong: Arc<AtomicU64>,
    pub sample_rate: u32,
    pub meter_period: Duration,

    pub snap: EngineSnapshot,
    pub dirty: bool,
    pub subscribers: Vec<Sender<EngineEvent>>,
    pub take_handler: Option<TakeHandler>,
    pub recording: bool,
    pub preview: Option<TrackId>,
    pub meters_were_active: bool,
    pub tick: u64,
}

impl Control {
    pub fn run(mut self) {
        let mut next_tick = Instant::now() + self.meter_period;
        loop {
            let timeout = next_tick
                .saturating_duration_since(Instant::now())
                .min(POLL);
            match self.rx.recv_timeout(timeout) {
                Ok(msg) => {
                    if !self.handle_msg(msg) {
                        break;
                    }
                    while let Ok(m) = self.rx.try_recv() {
                        if !self.handle_msg(m) {
                            break;
                        }
                    }
                }
                Err(crossbeam_channel::RecvTimeoutError::Timeout) => {}
                Err(crossbeam_channel::RecvTimeoutError::Disconnected) => break,
            }
            self.pump();
            if Instant::now() >= next_tick {
                next_tick += self.meter_period;
                if next_tick < Instant::now() {
                    next_tick = Instant::now() + self.meter_period;
                }
                self.on_tick();
            }
            self.publish();
        }
        // Final cleanup: everything retired so far is freed here.
        self.collector.collect();
        log::debug!("engine control thread exiting");
    }

    /// Drain audio-thread queues.
    fn pump(&mut self) {
        self.collector.collect();
        while let Ok(ev) = self.sampler_events.pop() {
            self.on_rt_event(ev);
        }
        while let Ok(ev) = self.master_events.pop() {
            self.on_rt_event(ev);
        }
        if self.recording {
            self.takes.poll();
        }
    }

    fn publish(&mut self) {
        if std::mem::take(&mut self.dirty) {
            self.snapshot.store(Arc::new(self.snap.clone()));
        }
    }

    pub(crate) fn emit(&mut self, ev: EngineEvent) {
        self.subscribers.retain(|s| match s.try_send(ev.clone()) {
            Ok(()) => true,
            Err(TrySendError::Full(_)) => true,
            Err(TrySendError::Disconnected(_)) => false,
        });
    }

    fn handle_msg(&mut self, msg: ControlMsg) -> bool {
        match msg {
            ControlMsg::Applied(cmd) => self.apply(cmd),
            ControlMsg::Subscribe(tx) => self.subscribers.push(tx),
            ControlMsg::Emit(ev) => self.emit(ev),
            ControlMsg::SetKit(kit) => {
                self.snap.kit = kit.clone();
                self.dirty = true;
                if let Some(kit) = kit {
                    self.emit(EngineEvent::KitLoaded { kit });
                }
            }
            ControlMsg::SetTakeHandler(h) => self.take_handler = h,
            ControlMsg::PreviewStarted(Some(id)) => {
                self.preview = Some(id.clone());
                self.emit(EngineEvent::TrackPlayback { track: Some(id) });
            }
            ControlMsg::PreviewStarted(None) => {
                // An audition replaces a playing track.
                if self.preview.take().is_some() {
                    self.emit(EngineEvent::TrackPlayback { track: None });
                }
            }
            ControlMsg::Flush(ack) => {
                self.pump();
                self.publish();
                let _ = ack.send(());
            }
        }
        true
    }

    fn apply(&mut self, cmd: Command) {
        match cmd {
            Command::SetPadParams { pad, params } => {
                if let Some(p) = self.snap.pads.get_mut(pad.flat()) {
                    p.params = params;
                }
            }
            Command::SetTempo { bpm } => self.snap.transport.bpm = bpm,
            Command::SetSpeed { ratio } => self.snap.transport.speed = ratio,
            Command::SetQuantize { q } => self.snap.transport.quantize = q,
            Command::SetMasterGain { gain } => self.snap.master_gain = gain,
            _ => return,
        }
        self.dirty = true;
    }

    fn on_rt_event(&mut self, ev: RtEvent) {
        match ev {
            RtEvent::PadState { pad, state } => {
                if let Some(id) = PadId::from_flat(pad as usize) {
                    if let Some(p) = self.snap.pads.get_mut(pad as usize) {
                        p.state = state;
                    }
                    self.dirty = true;
                    self.emit(EngineEvent::PadState { pad: id, state });
                }
            }
            RtEvent::PreviewEnded => {
                if self.preview.take().is_some() {
                    self.emit(EngineEvent::TrackPlayback { track: None });
                }
            }
            RtEvent::Transport {
                playing,
                beat,
                bpm,
                bar_len_beats,
                song_secs,
            } => {
                self.snap.transport.playing = playing;
                self.snap.transport.beat = beat;
                self.snap.transport.song_secs = song_secs;
                self.dirty = true;
                self.emit(EngineEvent::Transport {
                    playing,
                    beat,
                    bpm,
                    bar_len_beats,
                    song_secs,
                });
            }
            RtEvent::RecorderStarted => {
                self.recording = true;
                self.snap.recorder = RecorderState::Recording;
                self.snap.recorder_elapsed_secs = 0.0;
                self.dirty = true;
                self.emit(EngineEvent::Recorder {
                    state: RecorderState::Recording,
                    elapsed_secs: 0.0,
                });
            }
            RtEvent::RecorderStopped { frames } => {
                self.recording = false;
                let elapsed = frames as f64 / self.sample_rate as f64;
                self.snap.recorder = RecorderState::Saving;
                self.snap.recorder_elapsed_secs = elapsed;
                self.dirty = true;
                self.emit(EngineEvent::Recorder {
                    state: RecorderState::Saving,
                    elapsed_secs: elapsed,
                });
                let take = self.takes.finish();
                if take.dropped_samples > 0 {
                    log::warn!("recorder dropped {} samples", take.dropped_samples);
                }
                match self.take_handler.as_mut() {
                    Some(h) => match h(take) {
                        Ok(Some(ev)) => self.emit(ev),
                        Ok(None) => {}
                        Err(e) => self.emit(EngineEvent::Error(e)),
                    },
                    None => {
                        if let Ok(mut slot) = self.last_take.lock() {
                            *slot = Some(take);
                        }
                    }
                }
                self.snap.recorder = RecorderState::Idle;
                self.emit(EngineEvent::Recorder {
                    state: RecorderState::Idle,
                    elapsed_secs: elapsed,
                });
            }
            RtEvent::Pong(n) => self.last_pong.store(n, Ordering::Release),
            RtEvent::Overflow => log::warn!("engine event ring overflow; some events were dropped"),
        }
    }

    fn on_tick(&mut self) {
        self.tick += 1;
        if let Err(e) = self.graph.update() {
            log::warn!("graph update failed: {e}");
        }
        let mut pad_levels = vec![0.0f32; PAD_COUNT];
        for (o, a) in pad_levels.iter_mut().zip(self.meters.pad_peaks.iter()) {
            *o = take_peak(a);
        }
        let master_peak = [
            take_peak(&self.meters.master_peak[0]),
            take_peak(&self.meters.master_peak[1]),
        ];
        let master_rms = [
            f32::from_bits(self.meters.master_rms[0].load(Ordering::Relaxed)),
            f32::from_bits(self.meters.master_rms[1].load(Ordering::Relaxed)),
        ];
        let voices = self.meters.active_voices.load(Ordering::Relaxed);
        if self.snap.active_voices != voices {
            self.snap.active_voices = voices;
            self.dirty = true;
        }
        let active = master_peak
            .iter()
            .chain(pad_levels.iter())
            .any(|v| *v > 1e-5);
        if active || self.meters_were_active {
            self.emit(EngineEvent::Meters {
                master_peak,
                master_rms,
                pad_levels,
            });
        }
        self.meters_were_active = active;

        if self.recording && self.tick.is_multiple_of(6) {
            let elapsed =
                self.takes.stats().frames.load(Ordering::Relaxed) as f64 / self.sample_rate as f64;
            self.snap.recorder_elapsed_secs = elapsed;
            self.dirty = true;
            self.emit(EngineEvent::Recorder {
                state: RecorderState::Recording,
                elapsed_secs: elapsed,
            });
        }
    }
}
