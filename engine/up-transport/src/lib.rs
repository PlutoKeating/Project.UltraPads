//! Musical transport running on the audio thread.
//!
//! Positions are tracked in beats (`f64`). The effective tempo is
//! `bpm × speed`, so changing the speed ratio keeps loops on the grid.

#![forbid(unsafe_code)]

use up_core::{Beats, Quantize};

/// Time signature.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TimeSignature {
    pub numerator: u32,
    pub denominator: u32,
}

impl Default for TimeSignature {
    fn default() -> Self {
        Self {
            numerator: 4,
            denominator: 4,
        }
    }
}

impl TimeSignature {
    /// Bar length in beats, where one beat is a quarter note.
    /// 4/4 → 4, 3/4 → 3, 6/8 → 3, 7/8 → 3.5.
    pub fn bar_len_beats(&self) -> f64 {
        self.numerator.max(1) as f64 * 4.0 / self.denominator.max(1) as f64
    }
}

/// Tolerance used to decide that a position is "on" a boundary.
pub const BOUNDARY_EPS_BEATS: f64 = 1e-9;

/// Length of a quantize grid cell in beats, or `None` for no quantization.
pub fn quantize_len_beats(q: Quantize, ts: TimeSignature) -> Option<f64> {
    q.grid_beats(ts.bar_len_beats())
}

/// Next grid boundary at or after `beat` (a position exactly on the grid is
/// returned unchanged).
pub fn next_boundary(beat: Beats, grid: f64) -> Beats {
    debug_assert!(grid > 0.0);
    let cells = beat / grid;
    let nearest = cells.round();
    if (cells - nearest).abs() * grid <= BOUNDARY_EPS_BEATS.max(beat.abs() * 1e-12) {
        return nearest * grid;
    }
    cells.ceil() * grid
}

/// Frames from position `beat` until the next `grid` boundary.
pub fn frames_until_boundary(beat: Beats, grid: f64, frames_per_beat: f64) -> f64 {
    (next_boundary(beat, grid) - beat).max(0.0) * frames_per_beat
}

/// Realtime transport state.
#[derive(Debug, Clone)]
pub struct Transport {
    sample_rate: u32,
    bpm: f64,
    speed: f64,
    signature: TimeSignature,
    playing: bool,
    beat: Beats,
    /// Total frames rendered while playing (sample clock).
    frames_played: u64,
}

impl Transport {
    pub fn new(sample_rate: u32, bpm: f64) -> Self {
        Self {
            sample_rate: sample_rate.max(1),
            bpm,
            speed: 1.0,
            signature: TimeSignature::default(),
            playing: false,
            beat: 0.0,
            frames_played: 0,
        }
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }
    pub fn bpm(&self) -> f64 {
        self.bpm
    }
    pub fn speed(&self) -> f64 {
        self.speed
    }
    /// `bpm × speed`.
    pub fn effective_bpm(&self) -> f64 {
        self.bpm * self.speed
    }
    pub fn signature(&self) -> TimeSignature {
        self.signature
    }
    pub fn is_playing(&self) -> bool {
        self.playing
    }
    pub fn beat(&self) -> Beats {
        self.beat
    }
    pub fn frames_played(&self) -> u64 {
        self.frames_played
    }
    pub fn bar_len_beats(&self) -> f64 {
        self.signature.bar_len_beats()
    }

    pub fn set_bpm(&mut self, bpm: f64) {
        if bpm.is_finite() && bpm > 0.0 {
            self.bpm = bpm;
        }
    }
    pub fn set_speed(&mut self, speed: f64) {
        if speed.is_finite() && speed > 0.0 {
            self.speed = speed;
        }
    }
    pub fn set_signature(&mut self, ts: TimeSignature) {
        self.signature = ts;
    }

    /// Start playing from the current position.
    pub fn play(&mut self) {
        self.playing = true;
    }
    /// Stop and rewind to beat 0.
    pub fn stop(&mut self) {
        self.playing = false;
        self.beat = 0.0;
        self.frames_played = 0;
    }
    pub fn seek(&mut self, beat: Beats) {
        if beat.is_finite() {
            self.beat = beat.max(0.0);
        }
    }

    /// Frames per beat at the effective tempo.
    #[inline]
    pub fn frames_per_beat(&self) -> f64 {
        self.sample_rate as f64 * 60.0 / self.effective_bpm()
    }

    /// Beats advanced per frame at the effective tempo.
    #[inline]
    pub fn beats_per_frame(&self) -> f64 {
        1.0 / self.frames_per_beat()
    }

    /// Beat position `frames` into the current block.
    #[inline]
    pub fn beat_at_offset(&self, frames: u32) -> Beats {
        self.beat + frames as f64 * self.beats_per_frame()
    }

    /// Advance the transport by a rendered block.
    #[inline]
    pub fn advance(&mut self, frames: u32) {
        if self.playing {
            self.beat += frames as f64 * self.beats_per_frame();
            self.frames_played += frames as u64;
        }
    }

    /// Frame offset within a block of `block_frames` at which the next
    /// boundary for `q` occurs, if it falls inside this block. Returns
    /// `Some(0)` for `Quantize::None` or when the transport is stopped
    /// (immediate start).
    pub fn boundary_in_block(&self, q: Quantize, block_frames: u32) -> Option<u32> {
        let Some(grid) = quantize_len_beats(q, self.signature) else {
            return Some(0);
        };
        if !self.playing {
            return Some(0);
        }
        let f = frames_until_boundary(self.beat, grid, self.frames_per_beat());
        // Accumulated float error can leave `f` a hair above an integer
        // frame; snap within 1e-6 frames instead of rounding up a whole frame.
        let r = f.round();
        let off = if (f - r).abs() < 1e-6 { r } else { f.ceil() };
        if off < block_frames as f64 {
            Some(off as u32)
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bar_lengths() {
        assert_eq!(TimeSignature::default().bar_len_beats(), 4.0);
        assert_eq!(
            TimeSignature {
                numerator: 6,
                denominator: 8
            }
            .bar_len_beats(),
            3.0
        );
        assert_eq!(
            TimeSignature {
                numerator: 3,
                denominator: 4
            }
            .bar_len_beats(),
            3.0
        );
    }

    #[test]
    fn next_boundary_math() {
        assert_eq!(next_boundary(0.0, 4.0), 0.0);
        assert_eq!(next_boundary(0.1, 4.0), 4.0);
        assert_eq!(next_boundary(4.0, 4.0), 4.0);
        assert_eq!(next_boundary(4.0000000000001, 4.0), 4.0);
        assert_eq!(next_boundary(5.5, 1.0), 6.0);
        assert_eq!(next_boundary(7.999, 4.0), 8.0);
    }

    #[test]
    fn frames_until_boundary_at_120bpm() {
        // 120 bpm @ 48k → 24000 frames/beat.
        let t = Transport::new(48_000, 120.0);
        assert_eq!(t.frames_per_beat(), 24_000.0);
        assert_eq!(frames_until_boundary(3.5, 4.0, 24_000.0), 12_000.0);
        assert_eq!(frames_until_boundary(1.0, 1.0, 24_000.0), 0.0);
    }

    #[test]
    fn boundary_in_block() {
        let mut t = Transport::new(48_000, 120.0);
        // Stopped → immediate.
        assert_eq!(t.boundary_in_block(Quantize::Bar, 512), Some(0));
        t.play();
        t.seek(3.99);
        // 0.01 beat = 240 frames.
        assert_eq!(t.boundary_in_block(Quantize::Bar, 512), Some(240));
        assert_eq!(t.boundary_in_block(Quantize::Bar, 128), None);
        assert_eq!(t.boundary_in_block(Quantize::None, 128), Some(0));
        t.seek(4.0);
        assert_eq!(t.boundary_in_block(Quantize::Bar, 64), Some(0));
    }

    #[test]
    fn fine_grids() {
        let ts = TimeSignature::default();
        assert_eq!(quantize_len_beats(Quantize::Sixteenth, ts), Some(0.25));
        assert_eq!(quantize_len_beats(Quantize::FourBars, ts), Some(16.0));
        let t34 = TimeSignature {
            numerator: 3,
            denominator: 4,
        };
        assert_eq!(quantize_len_beats(Quantize::TwoBars, t34), Some(6.0));
    }

    #[test]
    fn speed_scales_tempo() {
        let mut t = Transport::new(48_000, 120.0);
        t.set_speed(2.0);
        assert_eq!(t.effective_bpm(), 240.0);
        assert_eq!(t.frames_per_beat(), 12_000.0);
        t.play();
        t.advance(12_000);
        assert!((t.beat() - 1.0).abs() < 1e-12);
        t.stop();
        assert_eq!(t.beat(), 0.0);
        assert!(!t.is_playing());
    }
}
