//! Graph nodes: Sampler (pads + mixer) → Master.
//!
//! The sampler renders every pad (all sound groups) into its own stereo bus
//! and mixes them to stereo inside the node, so the graph's port count does
//! not grow with the number of pads (Firewheel nodes have ≤ 64 ports).

use crate::meters::{MeterBank, push_peak};
use crate::rt::{MasterCmd, RtCommand, RtEvent};
use std::sync::Arc;
use std::sync::atomic::Ordering;
use up_core::PAD_COUNT;
use up_dsp::{Limiter, LimiterConfig, SmoothedValue, StereoMeter};
use up_graph::{NodeProcessor, ProcessInfo};
use up_mixer::Mixer;
use up_protocol::TransportCmd;
use up_recorder::RecordWriter;
use up_rt::mpsc::CommandQueue;
use up_rt::param::AtomicF32;
use up_rt::spsc::Producer;
use up_sampler::{BUS_COUNT, Sampler, SamplerEvent, SamplerEvents};
use up_transport::Transport;

/// Maximum commands applied per block (bounds worst-case block time).
const MAX_COMMANDS_PER_BLOCK: usize = 256;

struct EventSink<'a> {
    tx: &'a mut Producer<RtEvent>,
    overflow: &'a mut bool,
}

impl EventSink<'_> {
    fn push(&mut self, ev: RtEvent) {
        if self.tx.push(ev).is_err() {
            *self.overflow = true;
        }
    }
}

impl SamplerEvents for EventSink<'_> {
    fn emit(&mut self, ev: SamplerEvent) {
        let e = match ev {
            SamplerEvent::PadState { pad, state } => RtEvent::PadState { pad, state },
            SamplerEvent::PreviewEnded => RtEvent::PreviewEnded,
        };
        self.push(e);
    }
}

pub(crate) struct SamplerNode {
    pub sampler: Sampler,
    pub transport: Transport,
    pub commands: CommandQueue<RtCommand>,
    pub events: Producer<RtEvent>,
    pub meters: Arc<MeterBank>,
    /// Frames between transport position events while playing.
    pub transport_interval: u32,
    pub since_transport: u32,
    pub last_playing: bool,
    pub overflow: bool,
    /// Pad / preview buses, planar: `BUS_COUNT` × `bus_len` frames (preallocated).
    pub buses: Vec<f32>,
    pub bus_len: usize,
    pub mixer: Mixer,
    pub levels: [f32; PAD_COUNT],
}

impl SamplerNode {
    fn transport_event(&self) -> RtEvent {
        RtEvent::Transport {
            playing: self.transport.is_playing(),
            beat: self.transport.beat(),
            bpm: self.transport.effective_bpm(),
            bar_len_beats: self.transport.bar_len_beats(),
            song_secs: self.transport.beat() * 60.0 / self.transport.bpm(),
        }
    }
}

impl NodeProcessor for SamplerNode {
    fn process(&mut self, info: &ProcessInfo, _inputs: &[&[f32]], outputs: &mut [&mut [f32]]) {
        let mut transport_changed = false;
        for _ in 0..MAX_COMMANDS_PER_BLOCK {
            let Some(cmd) = self.commands.pop() else {
                break;
            };
            let mut sink = EventSink {
                tx: &mut self.events,
                overflow: &mut self.overflow,
            };
            match cmd {
                RtCommand::Sampler(c) => self.sampler.handle(c, &mut self.transport, &mut sink),
                RtCommand::SetTempo(bpm) => {
                    self.transport.set_bpm(bpm);
                    transport_changed = true;
                }
                RtCommand::Transport(t) => {
                    match t {
                        TransportCmd::Play => self.transport.play(),
                        TransportCmd::Stop => self.transport.stop(),
                        TransportCmd::Seek(b) => self.transport.seek(b),
                    }
                    transport_changed = true;
                }
                RtCommand::Ping(n) => sink.push(RtEvent::Pong(n)),
            }
        }
        let mut sink = EventSink {
            tx: &mut self.events,
            overflow: &mut self.overflow,
        };
        let frames = info.frames.min(self.bus_len);
        {
            let mut chunks = self.buses.chunks_exact_mut(self.bus_len);
            let mut buses: [&mut [f32]; BUS_COUNT] =
                std::array::from_fn(|_| chunks.next().unwrap_or_default());
            self.sampler
                .process(&mut self.transport, &mut buses, frames, &mut sink);
        }
        // Mix every pad bus (+ preview) to the stereo output; also per-pad levels.
        if let [l, r, ..] = outputs {
            let mut chunks = self.buses.chunks_exact(self.bus_len);
            let ins: [&[f32]; BUS_COUNT] =
                std::array::from_fn(|_| chunks.next().map_or(&[][..], |c| &c[..frames]));
            let n = frames.min(l.len()).min(r.len());
            self.mixer.process(&ins, &mut l[..n], &mut r[..n]);
            self.mixer.take_pad_levels(&mut self.levels);
            for (a, v) in self.meters.pad_peaks.iter().zip(self.levels.iter()) {
                push_peak(a, *v);
            }
        }
        self.transport.advance(info.frames as u32);

        let playing = self.transport.is_playing();
        self.since_transport = self.since_transport.saturating_add(info.frames as u32);
        if transport_changed
            || playing != self.last_playing
            || (playing && self.since_transport >= self.transport_interval)
        {
            self.since_transport = 0;
            self.last_playing = playing;
            let ev = self.transport_event();
            if self.events.push(ev).is_err() {
                self.overflow = true;
            }
        }
        if std::mem::take(&mut self.overflow) {
            let _ = self.events.push(RtEvent::Overflow);
        }
        self.meters
            .active_voices
            .store(self.sampler.active_voices() as u32, Ordering::Relaxed);
        self.meters.clock.publish(
            playing,
            self.transport.beat(),
            self.transport.bpm(),
            self.transport.speed(),
        );
    }
}

pub(crate) struct MasterNode {
    pub gain_param: Arc<AtomicF32>,
    pub gain: SmoothedValue,
    pub limiter: Limiter,
    pub meter: StereoMeter,
    pub meter_window: u32,
    pub meter_count: u32,
    pub meters: Arc<MeterBank>,
    pub recorder: RecordWriter,
    pub commands: CommandQueue<MasterCmd>,
    pub events: Producer<RtEvent>,
}

impl MasterNode {
    pub fn new(
        sample_rate: u32,
        meter_hz: f64,
        gain_param: Arc<AtomicF32>,
        meters: Arc<MeterBank>,
        recorder: RecordWriter,
        commands: CommandQueue<MasterCmd>,
        events: Producer<RtEvent>,
    ) -> Self {
        Self {
            gain: SmoothedValue::new(gain_param.get(), (sample_rate / 100).max(1)),
            gain_param,
            limiter: Limiter::new(sample_rate, LimiterConfig::default()),
            meter: StereoMeter::default(),
            meter_window: ((sample_rate as f64 / meter_hz.max(1.0)) as u32).max(64),
            meter_count: 0,
            meters,
            recorder,
            commands,
            events,
        }
    }
}

impl NodeProcessor for MasterNode {
    fn process(&mut self, info: &ProcessInfo, inputs: &[&[f32]], outputs: &mut [&mut [f32]]) {
        while let Some(cmd) = self.commands.pop() {
            let ev = match cmd {
                MasterCmd::StartRecording if !self.recorder.is_recording() => {
                    self.recorder.start();
                    Some(RtEvent::RecorderStarted)
                }
                MasterCmd::StopRecording if self.recorder.is_recording() => {
                    let frames = self.recorder.stop();
                    Some(RtEvent::RecorderStopped { frames })
                }
                _ => None,
            };
            if let Some(ev) = ev {
                let _ = self.events.push(ev);
            }
        }
        if outputs.len() < 2 {
            return;
        }
        self.gain.set_target(self.gain_param.get().clamp(0.0, 4.0));
        let frames = info.frames;
        let (l, r) = outputs.split_at_mut(1);
        let (out_l, out_r) = (&mut l[0][..frames], &mut r[0][..frames]);
        let zero: &[f32] = &[];
        let in_l = inputs.first().copied().unwrap_or(zero);
        let in_r = inputs.get(1).copied().unwrap_or(zero);
        for i in 0..frames {
            let g = self.gain.next_value();
            let mut a = in_l.get(i).copied().unwrap_or(0.0) * g;
            let mut b = in_r.get(i).copied().unwrap_or(0.0) * g;
            if !a.is_finite() {
                a = 0.0;
            }
            if !b.is_finite() {
                b = 0.0;
            }
            let (x, y) = self.limiter.process_frame(a, b);
            out_l[i] = x;
            out_r[i] = y;
            self.meter.push(x, y);
        }
        self.recorder.write_stereo(out_l, out_r);

        self.meter_count += frames as u32;
        if self.meter_count >= self.meter_window {
            self.meter_count = 0;
            let (peak, rms) = self.meter.read_and_reset();
            for c in 0..2 {
                push_peak(&self.meters.master_peak[c], peak[c]);
                self.meters.master_rms[c].store(rms[c].to_bits(), Ordering::Relaxed);
            }
        }
    }
}
