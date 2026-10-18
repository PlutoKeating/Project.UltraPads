use crate::SampleArc;
use crate::voice::{FADE_OUT_FRAMES_MS, PREVIEW_PAD, Voice, VoiceEnd};
use up_core::{PAD_COUNT, PadMode, PadPlayState, Quantize, Retrigger};
use up_dsp::gain::{pan_gains_unity_centre, velocity_to_gain};
use up_rt::retire::Retirer;
use up_transport::Transport;

/// Number of extra output channels used by the track preview voice.
pub const PREVIEW_OUTPUTS: usize = 2;

/// Planar output channels the sampler writes: one stereo bus per pad
/// ([`PAD_COUNT`]) followed by one stereo preview bus.
pub const fn outputs_needed() -> usize {
    PAD_COUNT * 2 + PREVIEW_OUTPUTS
}

/// [`outputs_needed`] as a constant (for fixed-size bus arrays on the audio thread).
pub const BUS_COUNT: usize = outputs_needed();

/// Allocation-free per-pad parameters.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RtPadParams {
    pub mode: PadMode,
    pub gain: f32,
    pub pan: f32,
    /// Group this pad belongs to; triggering it chokes pads `choked_by` it.
    pub choke_group: Option<u8>,
    /// Group that chokes this pad (`None` = `choke_group`, symmetric).
    pub choked_by: Option<u8>,
    /// Fade-out when choked (ms; `None` = sampler default).
    pub choke_release_ms: Option<f32>,
    /// Re-trigger cuts the pad's own previous voice.
    pub self_choke: bool,
    pub retrigger: Retrigger,
    pub start_frame: u64,
    pub end_frame: Option<u64>,
    pub loop_start: Option<u64>,
    pub loop_end: Option<u64>,
    pub quantize_override: Option<Quantize>,
    /// Pitch in semitones (`-12..=12`), applied as a rate multiplier.
    pub pitch: f32,
}

/// Playback-rate multiplier for `semitones` (clamped to ±12).
#[inline]
pub fn pitch_ratio(semitones: f32) -> f64 {
    let s = if semitones.is_finite() {
        semitones.clamp(-12.0, 12.0)
    } else {
        0.0
    };
    2f64.powf(f64::from(s) / 12.0)
}

impl Default for RtPadParams {
    fn default() -> Self {
        Self {
            mode: PadMode::OneShot,
            gain: 1.0,
            pan: 0.0,
            choke_group: None,
            choked_by: None,
            choke_release_ms: None,
            self_choke: true,
            retrigger: Retrigger::Restart,
            start_frame: 0,
            end_frame: None,
            loop_start: None,
            loop_end: None,
            quantize_override: None,
            pitch: 0.0,
        }
    }
}

/// What to do with a pad's sample in [`SamplerCmd::SetPad`].
#[derive(Debug)]
pub enum SampleUpdate {
    Keep,
    Clear,
    Set(SampleArc),
}

/// Realtime sampler command (no owned heap data besides `Arc`s).
#[derive(Debug)]
pub enum SamplerCmd {
    PadDown {
        pad: u8,
        velocity: f32,
    },
    PadUp {
        pad: u8,
    },
    StopAll,
    SetPad {
        pad: u8,
        params: RtPadParams,
        sample: SampleUpdate,
    },
    SetQuantize(Quantize),
    SetSpeed(f64),
    /// Play a sample on the preview voice (track playback, editor audition).
    PlayPreview {
        sample: SampleArc,
        start: u64,
        /// Exclusive end frame (`None` = sample end).
        end: Option<u64>,
        looping: bool,
    },
    StopPreview,
}

/// Events emitted by the sampler.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SamplerEvent {
    PadState { pad: u8, state: PadPlayState },
    PreviewEnded,
}

/// Event sink implemented by the engine (must be realtime-safe).
pub trait SamplerEvents {
    fn emit(&mut self, ev: SamplerEvent);
}

impl SamplerEvents for Vec<SamplerEvent> {
    fn emit(&mut self, ev: SamplerEvent) {
        self.push(ev);
    }
}

/// Sampler construction parameters.
#[derive(Debug, Clone, Copy)]
pub struct SamplerConfig {
    pub sample_rate: u32,
    /// Maximum simultaneously *sounding* (non-releasing) voices.
    pub max_voices: usize,
    /// Extra slots for voices that are fading out after being stolen,
    /// choked or retriggered.
    pub tail_voices: usize,
    /// Fade-out length used for stop/choke/steal (ms).
    pub fade_out_ms: f32,
    /// Fade-in for trimmed starts (ms; samples starting at frame 0 start
    /// without fade to keep transients sharp).
    pub fade_in_ms: f32,
}

impl Default for SamplerConfig {
    fn default() -> Self {
        Self {
            sample_rate: up_core::DEFAULT_SAMPLE_RATE,
            max_voices: 32,
            tail_voices: 16,
            fade_out_ms: FADE_OUT_FRAMES_MS,
            fade_in_ms: 1.0,
        }
    }
}

/// Per-pad state.
#[derive(Debug, Default)]
pub struct PadState {
    pub params: RtPadParams,
    pub sample: Option<SampleArc>,
    pub state: PadPlayState,
    /// Index of the pad's current (non-releasing) voice.
    voice: Option<usize>,
    /// Pending launch velocity (when `state == Pending`).
    pending_velocity: f32,
    /// Loop stop is waiting for a quantize boundary.
    stop_pending: bool,
    held: bool,
}

/// 24-pad sampler engine.
pub struct Sampler {
    cfg: SamplerConfig,
    pads: [PadState; PAD_COUNT],
    voices: Vec<Voice>,
    preview: Voice,
    quantize: Quantize,
    speed: f64,
    age: u64,
    fade_out_frames: u32,
    fade_in_frames: u32,
    retirer: Retirer<SampleArc>,
    /// Transport was started by a quantized loop and should stop when the
    /// last loop ends.
    auto_transport: bool,
}

impl Sampler {
    /// Create a sampler. Allocates all voices up front.
    pub fn new(cfg: SamplerConfig, retirer: Retirer<SampleArc>) -> Self {
        let max = cfg.max_voices.max(1);
        let total = max + cfg.tail_voices.max(1);
        let ms = |ms: f32| ((ms.max(0.0) / 1000.0) * cfg.sample_rate as f32).round() as u32;
        Self {
            cfg: SamplerConfig {
                max_voices: max,
                ..cfg
            },
            pads: std::array::from_fn(|_| PadState::default()),
            voices: (0..total).map(|_| Voice::default()).collect(),
            preview: Voice::default(),
            quantize: Quantize::None,
            speed: 1.0,
            age: 0,
            fade_out_frames: ms(cfg.fade_out_ms).max(1),
            fade_in_frames: ms(cfg.fade_in_ms),
            retirer,
            auto_transport: false,
        }
    }

    pub fn config(&self) -> &SamplerConfig {
        &self.cfg
    }
    pub fn quantize(&self) -> Quantize {
        self.quantize
    }
    pub fn speed(&self) -> f64 {
        self.speed
    }
    pub fn pad(&self, flat: usize) -> Option<&PadState> {
        self.pads.get(flat)
    }
    pub fn pad_state(&self, flat: usize) -> PadPlayState {
        self.pads.get(flat).map_or(PadPlayState::Idle, |p| p.state)
    }
    /// Number of voices currently producing sound (including fading tails).
    pub fn active_voices(&self) -> usize {
        self.voices.iter().filter(|v| v.active).count() + usize::from(self.preview.active)
    }
    pub fn preview_active(&self) -> bool {
        self.preview.active
    }

    fn set_state(&mut self, pad: usize, state: PadPlayState, ev: &mut impl SamplerEvents) {
        if self.pads[pad].state != state {
            self.pads[pad].state = state;
            ev.emit(SamplerEvent::PadState {
                pad: pad as u8,
                state,
            });
        }
    }

    fn effective_quantize(&self, pad: usize) -> Quantize {
        let p = &self.pads[pad].params;
        match (p.mode, p.quantize_override) {
            (_, Some(q)) => q,
            (PadMode::Loop, None) => self.quantize,
            _ => Quantize::None,
        }
    }

    /// Apply one command (call at block start, before [`Sampler::process`]).
    pub fn handle(
        &mut self,
        cmd: SamplerCmd,
        transport: &mut Transport,
        ev: &mut impl SamplerEvents,
    ) {
        match cmd {
            SamplerCmd::PadDown { pad, velocity } => {
                self.pad_down(pad as usize, velocity, transport, ev)
            }
            SamplerCmd::PadUp { pad } => self.pad_up(pad as usize, ev),
            SamplerCmd::StopAll => self.stop_all(transport, ev),
            SamplerCmd::SetPad {
                pad,
                params,
                sample,
            } => self.set_pad(pad as usize, params, sample, ev),
            SamplerCmd::SetQuantize(q) => self.quantize = q,
            SamplerCmd::SetSpeed(r) => {
                if r.is_finite() {
                    self.speed = r.clamp(0.5, 2.0);
                    transport.set_speed(self.speed);
                }
            }
            SamplerCmd::PlayPreview {
                sample,
                start,
                end,
                looping,
            } => self.play_preview(sample, start, end, looping, ev),
            SamplerCmd::StopPreview => {
                if self.preview.active && !self.preview.fade.is_fading_out() {
                    self.preview.fade.start_fade_out(self.fade_out_frames);
                }
            }
        }
    }

    fn set_pad(
        &mut self,
        pad: usize,
        params: RtPadParams,
        sample: SampleUpdate,
        ev: &mut impl SamplerEvents,
    ) {
        if pad >= PAD_COUNT {
            if let SampleUpdate::Set(s) = sample {
                self.retirer.retire(s);
            }
            return;
        }
        let replaced = !matches!(sample, SampleUpdate::Keep);
        let mode_changed = self.pads[pad].params.mode != params.mode;
        if replaced || mode_changed {
            // The playing voice keeps its own Arc; just release it.
            self.release_pad(pad, ev);
            self.pads[pad].stop_pending = false;
            if self.pads[pad].state == PadPlayState::Pending {
                self.set_state(pad, PadPlayState::Idle, ev);
            }
        }
        self.pads[pad].params = params;
        // Live gain/pan/pitch update for a voice that keeps playing.
        if let Some(vi) = self.pads[pad].voice {
            let v = &mut self.voices[vi];
            if let Some(s) = v.sample.as_ref() {
                v.rate =
                    s.sample_rate as f64 / self.cfg.sample_rate as f64 * pitch_ratio(params.pitch);
            }
            let (pl, pr) = pan_gains_unity_centre(params.pan);
            let g = params.gain.clamp(0.0, 4.0) * v.vel_gain;
            v.gain_l = g * pl;
            v.gain_r = g * pr;
        }
        match sample {
            SampleUpdate::Keep => {}
            SampleUpdate::Clear => {
                if let Some(old) = self.pads[pad].sample.take() {
                    self.retirer.retire(old);
                }
            }
            SampleUpdate::Set(s) => {
                if let Some(old) = self.pads[pad].sample.replace(s) {
                    self.retirer.retire(old);
                }
            }
        }
    }

    fn pad_down(
        &mut self,
        pad: usize,
        velocity: f32,
        transport: &mut Transport,
        ev: &mut impl SamplerEvents,
    ) {
        if pad >= PAD_COUNT || self.pads[pad].sample.is_none() {
            return;
        }
        let mode = self.pads[pad].params.mode;
        self.pads[pad].held = true;

        if mode == PadMode::Loop {
            match self.pads[pad].state {
                PadPlayState::Pending => {
                    self.set_state(pad, PadPlayState::Idle, ev);
                    self.stop_transport_if_idle(transport);
                    return;
                }
                PadPlayState::Playing => {
                    self.request_loop_stop(pad, transport, ev);
                    return;
                }
                PadPlayState::Stopping if self.pads[pad].stop_pending => {
                    // Cancel a stop that is still waiting for its boundary.
                    self.pads[pad].stop_pending = false;
                    self.set_state(pad, PadPlayState::Playing, ev);
                    return;
                }
                _ => {}
            }
        }

        if mode != PadMode::Loop
            && self.pads[pad].params.retrigger == Retrigger::Continue
            && self.pads[pad].state == PadPlayState::Playing
        {
            return;
        }

        self.choke_group_of(pad, ev);

        let q = self.effective_quantize(pad);
        if q != Quantize::None && mode == PadMode::Loop && !transport.is_playing() {
            // First quantized loop starts the grid at beat 0.
            transport.seek(0.0);
            transport.play();
            self.auto_transport = true;
        }
        match transport.boundary_in_block(q, 1) {
            Some(0) => self.start_voice(pad, velocity, 0, ev),
            _ => {
                self.pads[pad].pending_velocity = velocity;
                self.set_state(pad, PadPlayState::Pending, ev);
            }
        }
    }

    fn pad_up(&mut self, pad: usize, ev: &mut impl SamplerEvents) {
        if pad >= PAD_COUNT {
            return;
        }
        self.pads[pad].held = false;
        if self.pads[pad].params.mode != PadMode::Gate {
            return;
        }
        match self.pads[pad].state {
            PadPlayState::Pending => self.set_state(pad, PadPlayState::Idle, ev),
            PadPlayState::Playing => self.release_pad(pad, ev),
            _ => {}
        }
    }

    fn request_loop_stop(
        &mut self,
        pad: usize,
        transport: &Transport,
        ev: &mut impl SamplerEvents,
    ) {
        let q = self.effective_quantize(pad);
        if q == Quantize::None || !transport.is_playing() {
            self.release_pad(pad, ev);
        } else {
            self.pads[pad].stop_pending = true;
            self.set_state(pad, PadPlayState::Stopping, ev);
        }
    }

    /// Fade out the pad's voice (if any) and move it to the tail pool.
    fn release_pad(&mut self, pad: usize, ev: &mut impl SamplerEvents) {
        self.release_pad_with(pad, self.fade_out_frames, ev);
    }

    fn release_pad_with(&mut self, pad: usize, fade_frames: u32, ev: &mut impl SamplerEvents) {
        if let Some(vi) = self.pads[pad].voice.take() {
            let v = &mut self.voices[vi];
            if v.active {
                v.fade.start_fade_out(fade_frames);
                self.set_state(pad, PadPlayState::Stopping, ev);
                return;
            }
        }
        if self.pads[pad].state != PadPlayState::Idle {
            self.set_state(pad, PadPlayState::Idle, ev);
        }
    }

    fn choke_group_of(&mut self, pad: usize, ev: &mut impl SamplerEvents) {
        let Some(g) = self.pads[pad].params.choke_group else {
            return;
        };
        for other in 0..PAD_COUNT {
            let op = &self.pads[other].params;
            if other != pad && op.choked_by.or(op.choke_group) == Some(g) {
                let fade = op
                    .choke_release_ms
                    .map(|ms| self.ms_to_frames(ms).max(1))
                    .unwrap_or(self.fade_out_frames);
                self.pads[other].stop_pending = false;
                match self.pads[other].state {
                    PadPlayState::Idle => {}
                    PadPlayState::Pending => self.set_state(other, PadPlayState::Idle, ev),
                    _ => self.release_pad_with(other, fade, ev),
                }
            }
        }
    }

    fn ms_to_frames(&self, ms: f32) -> u32 {
        ((ms.clamp(0.0, 10_000.0) / 1000.0) * self.cfg.sample_rate as f32).round() as u32
    }

    fn stop_all(&mut self, transport: &mut Transport, ev: &mut impl SamplerEvents) {
        for pad in 0..PAD_COUNT {
            self.pads[pad].stop_pending = false;
            if self.pads[pad].state == PadPlayState::Pending {
                self.set_state(pad, PadPlayState::Idle, ev);
            }
            self.release_pad(pad, ev);
        }
        // Tails / unowned voices too.
        for v in &mut self.voices {
            if v.active && !v.fade.is_fading_out() {
                v.fade.start_fade_out(self.fade_out_frames);
            }
        }
        if self.auto_transport {
            transport.stop();
            self.auto_transport = false;
        }
    }

    fn play_preview(
        &mut self,
        sample: SampleArc,
        start: u64,
        end: Option<u64>,
        looping: bool,
        ev: &mut impl SamplerEvents,
    ) {
        if let Some(old) = self.preview.sample.take() {
            self.retirer.retire(old);
            ev.emit(SamplerEvent::PreviewEnded);
        }
        let frames = sample.frames();
        let start = (start as usize).min(frames);
        let end = end.map_or(frames, |e| (e as usize).clamp(start, frames));
        let rate = sample.sample_rate as f64 / self.cfg.sample_rate as f64;
        self.preview = Voice {
            active: end > start,
            pad: PREVIEW_PAD,
            sample: Some(sample),
            pos: start as f64,
            start,
            end,
            loop_start: start,
            loop_end: end,
            looping,
            gain_l: 1.0,
            gain_r: 1.0,
            vel_gain: 1.0,
            fade: up_dsp::Fade::steady(),
            start_delay: 0,
            fade_out_at: None,
            age: 0,
            rate,
        };
    }

    /// Pick a voice slot, stealing if needed. Returns `None` only if every
    /// slot is in use and nothing could be reclaimed.
    fn alloc_voice(&mut self, ev: &mut impl SamplerEvents) -> Option<usize> {
        let sounding = self
            .voices
            .iter()
            .filter(|v| v.active && !v.is_releasing())
            .count();
        if sounding >= self.cfg.max_voices {
            // Steal the oldest sounding voice: prefer one-shot/gate voices
            // over loops, then oldest first.
            let victim = self
                .voices
                .iter()
                .enumerate()
                .filter(|(_, v)| v.active && !v.is_releasing())
                .min_by_key(|(_, v)| (v.looping, v.age))
                .map(|(i, _)| i);
            if let Some(vi) = victim {
                let pad = self.voices[vi].pad as usize;
                if pad < PAD_COUNT && self.pads[pad].voice == Some(vi) {
                    self.pads[pad].voice = None;
                    self.pads[pad].stop_pending = false;
                    self.set_state(pad, PadPlayState::Stopping, ev);
                }
                self.voices[vi].fade.start_fade_out(self.fade_out_frames);
            }
        }
        if let Some(i) = self.voices.iter().position(|v| !v.active) {
            return Some(i);
        }
        // No free slot: hard-cut the oldest releasing voice.
        let vi = self
            .voices
            .iter()
            .enumerate()
            .filter(|(_, v)| v.active && v.is_releasing())
            .min_by_key(|(_, v)| v.age)
            .map(|(i, _)| i)?;
        self.free_voice(vi, ev);
        Some(vi)
    }

    fn free_voice(&mut self, vi: usize, ev: &mut impl SamplerEvents) {
        let v = &mut self.voices[vi];
        v.active = false;
        let pad = v.pad as usize;
        if let Some(s) = v.sample.take() {
            self.retirer.retire(s);
        }
        if pad < PAD_COUNT {
            if self.pads[pad].voice == Some(vi) {
                self.pads[pad].voice = None;
            }
            if self.pads[pad].voice.is_none() && self.pads[pad].state != PadPlayState::Pending {
                // Only report Idle when no other voice of this pad is still
                // owned (a retriggered one-shot keeps its new voice).
                self.set_state(pad, PadPlayState::Idle, ev);
            }
        }
    }

    fn start_voice(&mut self, pad: usize, velocity: f32, offset: u32, ev: &mut impl SamplerEvents) {
        let Some(sample) = self.pads[pad].sample.clone() else {
            self.set_state(pad, PadPlayState::Idle, ev);
            return;
        };
        // With self-choke the previous voice becomes a fading tail;
        // without it, it keeps playing unowned (overlapping one-shots).
        let self_choke =
            self.pads[pad].params.self_choke || self.pads[pad].params.mode != PadMode::OneShot;
        if let Some(prev) = self.pads[pad].voice.take()
            && self.voices[prev].active
            && self_choke
        {
            if offset == 0 {
                self.voices[prev].fade.start_fade_out(self.fade_out_frames);
            } else {
                self.voices[prev].fade_out_at = Some(offset);
            }
        }
        let Some(vi) = self.alloc_voice(ev) else {
            self.retirer.retire(sample);
            self.set_state(pad, PadPlayState::Idle, ev);
            return;
        };
        let p = self.pads[pad].params;
        let frames = sample.frames();
        let start = (p.start_frame as usize).min(frames);
        let end = p
            .end_frame
            .map_or(frames, |e| (e as usize).clamp(start, frames));
        let loop_start = p
            .loop_start
            .map_or(start, |s| (s as usize).clamp(start, end));
        let loop_end = p
            .loop_end
            .map_or(end, |e| (e as usize).clamp(loop_start, end));
        let (loop_start, loop_end) = if loop_end > loop_start {
            (loop_start, loop_end)
        } else {
            (start, end)
        };
        if end <= start {
            self.retirer.retire(sample);
            self.set_state(pad, PadPlayState::Idle, ev);
            return;
        }
        let vel_gain = velocity_to_gain(velocity);
        let gain = p.gain.clamp(0.0, 4.0) * vel_gain;
        let (pl, pr) = pan_gains_unity_centre(p.pan);
        let fade = if start > 0 {
            up_dsp::Fade::fade_in(self.fade_in_frames)
        } else {
            up_dsp::Fade::steady()
        };
        self.age += 1;
        let rate = sample.sample_rate as f64 / self.cfg.sample_rate as f64 * pitch_ratio(p.pitch);
        let old = std::mem::replace(
            &mut self.voices[vi],
            Voice {
                active: true,
                pad: pad as u8,
                sample: Some(sample),
                pos: start as f64,
                start,
                end,
                loop_start,
                loop_end,
                looping: p.mode == PadMode::Loop,
                gain_l: gain * pl,
                gain_r: gain * pr,
                vel_gain,
                fade,
                start_delay: offset,
                fade_out_at: None,
                age: self.age,
                rate,
            },
        );
        if let Some(s) = old.sample {
            self.retirer.retire(s);
        }
        self.pads[pad].voice = Some(vi);
        self.pads[pad].stop_pending = false;
        self.set_state(pad, PadPlayState::Playing, ev);
    }

    fn stop_transport_if_idle(&mut self, transport: &mut Transport) {
        if !self.auto_transport {
            return;
        }
        let busy = self
            .pads
            .iter()
            .any(|p| p.params.mode == PadMode::Loop && p.state != PadPlayState::Idle);
        if !busy {
            transport.stop();
            self.auto_transport = false;
        }
    }

    /// Render one block of `frames` frames into planar `outputs`
    /// (see [`outputs_needed`]; extra channels are ignored, missing ones
    /// are skipped). Outputs are overwritten. Does not advance the
    /// transport — the caller does that after processing.
    pub fn process(
        &mut self,
        transport: &mut Transport,
        outputs: &mut [&mut [f32]],
        frames: usize,
        ev: &mut impl SamplerEvents,
    ) {
        self.retirer.flush();
        for o in outputs.iter_mut() {
            let n = frames.min(o.len());
            o[..n].fill(0.0);
        }

        // 1. Quantized launches and stops whose boundary falls in this block.
        for pad in 0..PAD_COUNT {
            let st = self.pads[pad].state;
            let stop_pending = self.pads[pad].stop_pending;
            if st != PadPlayState::Pending && !stop_pending {
                continue;
            }
            let q = self.effective_quantize(pad);
            let Some(off) = transport.boundary_in_block(q, frames as u32) else {
                continue;
            };
            if st == PadPlayState::Pending {
                let vel = self.pads[pad].pending_velocity;
                self.start_voice(pad, vel, off, ev);
            } else if let Some(vi) = self.pads[pad].voice.take() {
                self.pads[pad].stop_pending = false;
                if off == 0 {
                    self.voices[vi].fade.start_fade_out(self.fade_out_frames);
                } else {
                    self.voices[vi].fade_out_at = Some(off);
                }
            } else {
                self.pads[pad].stop_pending = false;
                self.set_state(pad, PadPlayState::Idle, ev);
            }
        }

        // 2. Render voices into their pad buses.
        let speed = self.speed;
        let fade_out = self.fade_out_frames;
        for vi in 0..self.voices.len() {
            if !self.voices[vi].active {
                continue;
            }
            let pad = self.voices[vi].pad as usize;
            let li = pad * 2;
            let end = if li + 1 < outputs.len() {
                let (a, b) = outputs.split_at_mut(li + 1);
                let l = &mut a[li][..frames];
                let r = &mut b[0][..frames];
                self.voices[vi].render(l, r, speed, fade_out)
            } else {
                // No bus for this pad: still advance silently.
                let mut dummy_l = [0.0f32; 0];
                let mut dummy_r = [0.0f32; 0];
                self.voices[vi].render(&mut dummy_l, &mut dummy_r, speed, fade_out)
            };
            if end != VoiceEnd::Running {
                self.free_voice(vi, ev);
            }
        }

        // 3. Preview voice.
        if self.preview.active {
            let base = PAD_COUNT * 2;
            let end = if base + 1 < outputs.len() {
                let (a, b) = outputs.split_at_mut(base + 1);
                self.preview
                    .render(&mut a[base][..frames], &mut b[0][..frames], 1.0, fade_out)
            } else {
                VoiceEnd::Finished
            };
            if end != VoiceEnd::Running {
                self.preview.active = false;
                if let Some(s) = self.preview.sample.take() {
                    self.retirer.retire(s);
                }
                ev.emit(SamplerEvent::PreviewEnded);
            }
        }

        self.stop_transport_if_idle(transport);
    }
}
