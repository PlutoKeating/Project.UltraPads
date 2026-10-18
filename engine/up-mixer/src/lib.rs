//! Minimal mixer: one stereo channel per pad (`PAD_COUNT`, every sound group)
//! plus the preview → stereo master.
//!
//! Channel gain/pan/mute live in [`MixerParams`] (atomics, written by the
//! control thread, read by the audio thread) and are smoothed per block to
//! avoid zipper noise. The mixer also measures per-pad peak levels.

#![forbid(unsafe_code)]

use std::sync::Arc;
use up_core::PAD_COUNT;
use up_dsp::gain::pan_gains_unity_centre;
use up_dsp::{PeakMeter, SmoothedValue};
use up_rt::param::{AtomicF32, AtomicFlag};

/// Number of mixer input channels (planar): stereo pads + stereo preview.
pub const MIXER_INPUTS: usize = PAD_COUNT * 2 + 2;

/// Shared channel parameters.
#[derive(Debug)]
pub struct ChannelParams {
    pub gain: AtomicF32,
    pub pan: AtomicF32,
    pub mute: AtomicFlag,
}

impl Default for ChannelParams {
    fn default() -> Self {
        Self {
            gain: AtomicF32::new(1.0),
            pan: AtomicF32::new(0.0),
            mute: AtomicFlag::new(false),
        }
    }
}

/// Parameters shared between control and audio threads.
#[derive(Debug)]
pub struct MixerParams {
    pub pads: [ChannelParams; PAD_COUNT],
    pub preview: ChannelParams,
}

impl Default for MixerParams {
    fn default() -> Self {
        Self {
            pads: std::array::from_fn(|_| ChannelParams::default()),
            preview: ChannelParams::default(),
        }
    }
}

struct Strip {
    gain_l: SmoothedValue,
    gain_r: SmoothedValue,
}

impl Strip {
    fn new(ramp: u32) -> Self {
        Self {
            gain_l: SmoothedValue::new(1.0, ramp),
            gain_r: SmoothedValue::new(1.0, ramp),
        }
    }

    fn update(&mut self, p: &ChannelParams) {
        let (pl, pr) = pan_gains_unity_centre(p.pan.get());
        let g = if p.mute.get() {
            0.0
        } else {
            p.gain.get().clamp(0.0, 4.0)
        };
        self.gain_l.set_target(g * pl);
        self.gain_r.set_target(g * pr);
    }
}

/// Audio-thread mixer.
pub struct Mixer {
    params: Arc<MixerParams>,
    strips: Vec<Strip>,
    preview: Strip,
    pad_meters: [PeakMeter; PAD_COUNT],
}

impl Mixer {
    pub fn new(sample_rate: u32, params: Arc<MixerParams>) -> Self {
        let ramp = (sample_rate / 200).max(1); // 5 ms
        Self {
            params,
            strips: (0..PAD_COUNT).map(|_| Strip::new(ramp)).collect(),
            preview: Strip::new(ramp),
            pad_meters: [PeakMeter::default(); PAD_COUNT],
        }
    }

    pub fn params(&self) -> &Arc<MixerParams> {
        &self.params
    }

    /// Sum planar `inputs` ([`MIXER_INPUTS`] channels) into `out_l`/`out_r`
    /// (overwritten). Missing inputs are treated as silence.
    pub fn process(&mut self, inputs: &[&[f32]], out_l: &mut [f32], out_r: &mut [f32]) {
        let frames = out_l.len().min(out_r.len());
        out_l[..frames].fill(0.0);
        out_r[..frames].fill(0.0);
        for pad in 0..PAD_COUNT {
            self.strips[pad].update(&self.params.pads[pad]);
            let (Some(l), Some(r)) = (inputs.get(pad * 2), inputs.get(pad * 2 + 1)) else {
                continue;
            };
            let strip = &mut self.strips[pad];
            let meter = &mut self.pad_meters[pad];
            let silent = !strip.gain_l.is_smoothing()
                && !strip.gain_r.is_smoothing()
                && strip.gain_l.target() == 0.0
                && strip.gain_r.target() == 0.0;
            for i in 0..frames.min(l.len()).min(r.len()) {
                let (a, b) = (l[i], r[i]);
                meter.push(a.abs().max(b.abs()));
                if !silent {
                    out_l[i] += a * strip.gain_l.next_value();
                    out_r[i] += b * strip.gain_r.next_value();
                }
            }
        }
        self.preview.update(&self.params.preview);
        if let (Some(l), Some(r)) = (inputs.get(PAD_COUNT * 2), inputs.get(PAD_COUNT * 2 + 1)) {
            for i in 0..frames.min(l.len()).min(r.len()) {
                out_l[i] += l[i] * self.preview.gain_l.next_value();
                out_r[i] += r[i] * self.preview.gain_r.next_value();
            }
        }
    }

    /// Per-pad peak levels since last call (pre-fader), then reset.
    pub fn take_pad_levels(&mut self, out: &mut [f32; PAD_COUNT]) {
        for (o, m) in out.iter_mut().zip(self.pad_meters.iter_mut()) {
            *o = m.read_and_reset();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sums_pads_and_meters() {
        let params = Arc::new(MixerParams::default());
        let mut m = Mixer::new(48_000, Arc::clone(&params));
        let ones = vec![0.25f32; 64];
        let zeros = vec![0.0f32; 64];
        let mut inputs: Vec<&[f32]> = vec![&zeros; MIXER_INPUTS];
        inputs[0] = &ones;
        inputs[1] = &ones;
        inputs[6] = &ones;
        inputs[7] = &ones;
        let mut l = vec![0.0; 64];
        let mut r = vec![0.0; 64];
        m.process(&inputs, &mut l, &mut r);
        assert!((l[10] - 0.5).abs() < 1e-6);
        let mut levels = [0.0; PAD_COUNT];
        m.take_pad_levels(&mut levels);
        assert_eq!(levels[0], 0.25);
        assert_eq!(levels[3], 0.25);
        assert_eq!(levels[1], 0.0);
    }

    #[test]
    fn mute_ramps_to_silence() {
        let params = Arc::new(MixerParams::default());
        let mut m = Mixer::new(48_000, Arc::clone(&params));
        params.pads[0].mute.set(true);
        let ones = vec![1.0f32; 512];
        let zeros = vec![0.0f32; 512];
        let mut inputs: Vec<&[f32]> = vec![&zeros; MIXER_INPUTS];
        inputs[0] = &ones;
        inputs[1] = &ones;
        let mut l = vec![0.0; 512];
        let mut r = vec![0.0; 512];
        m.process(&inputs, &mut l, &mut r);
        assert!(l[0] > 0.9 && l[511] == 0.0, "smoothed mute");
    }
}
