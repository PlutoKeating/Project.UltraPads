use crate::SampleArc;
use up_dsp::Fade;
use up_dsp::interp::read_hermite;

/// Pad index used for the track preview voice.
pub(crate) const PREVIEW_PAD: u8 = u8::MAX;

#[derive(Debug, Default)]
pub(crate) struct Voice {
    pub active: bool,
    pub pad: u8,
    pub sample: Option<SampleArc>,
    /// Read position in sample frames.
    pub pos: f64,
    pub start: usize,
    pub end: usize,
    /// Loop region (within `start..end`) used when `looping`.
    pub loop_start: usize,
    pub loop_end: usize,
    pub looping: bool,
    pub gain_l: f32,
    pub gain_r: f32,
    /// Velocity part of the gain (kept for live pad gain/pan changes).
    pub vel_gain: f32,
    pub fade: Fade,
    /// Frames to wait inside the current block before producing output.
    pub start_delay: u32,
    /// Start a fade-out this many frames into the current block.
    pub fade_out_at: Option<u32>,
    /// Trigger order (monotonic), used for stealing.
    pub age: u64,
    /// `pos` increment per output frame at speed 1.0 (source/engine rate).
    pub rate: f64,
}

/// Result of rendering a voice for one block.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum VoiceEnd {
    Running,
    /// Reached the end of a non-looping region.
    Finished,
    /// Fade-out completed.
    FadedOut,
}

pub(crate) const FADE_OUT_FRAMES_MS: f32 = 5.0;

impl Voice {
    pub fn is_releasing(&self) -> bool {
        self.fade.is_fading_out() || self.fade_out_at.is_some()
    }

    /// Render into `out_l`/`out_r` (additive). `speed` multiplies the rate.
    pub fn render(
        &mut self,
        out_l: &mut [f32],
        out_r: &mut [f32],
        speed: f64,
        fade_out_frames: u32,
    ) -> VoiceEnd {
        let Some(sample) = self.sample.as_ref() else {
            return VoiceEnd::Finished;
        };
        let frames = out_l.len();
        let left = sample.left();
        let right = sample.right();
        let stereo = sample.is_stereo();
        let inc = self.rate * speed;
        let wrap = if self.looping {
            Some((self.start, self.end))
        } else {
            None
        };
        let mut i = self.start_delay.min(frames as u32) as usize;
        self.start_delay -= i as u32;
        while i < frames {
            if let Some(at) = self.fade_out_at
                && i as u32 >= at
            {
                self.fade.start_fade_out(fade_out_frames);
                self.fade_out_at = None;
            }
            if !self.looping && self.pos >= self.end as f64 {
                return VoiceEnd::Finished;
            }
            let g = self.fade.next_gain();
            if self.fade.is_silent() {
                return VoiceEnd::FadedOut;
            }
            let l = read_hermite(left, self.pos, wrap);
            let r = if stereo {
                read_hermite(right, self.pos, wrap)
            } else {
                l
            };
            out_l[i] += l * self.gain_l * g;
            out_r[i] += r * self.gain_r * g;
            self.pos += inc;
            if self.looping && self.pos >= self.loop_end as f64 {
                let len = (self.loop_end - self.loop_start) as f64;
                if len <= 0.0 {
                    return VoiceEnd::Finished;
                }
                self.pos = self.loop_start as f64 + (self.pos - self.loop_start as f64) % len;
            }
            i += 1;
        }
        // Fade scheduled exactly at block end carries into the next block.
        if let Some(at) = self.fade_out_at {
            self.fade_out_at = Some(at.saturating_sub(frames as u32));
        }
        VoiceEnd::Running
    }
}
