//! Master output peak limiter (zero latency, instant attack, smooth release)
//! followed by a hard ceiling clamp, so the device never receives overs.

use crate::gain::db_to_linear;

#[derive(Debug, Clone, Copy)]
pub struct LimiterConfig {
    /// Output ceiling in dBFS.
    pub ceiling_db: f32,
    /// Release time constant in milliseconds.
    pub release_ms: f32,
}

impl Default for LimiterConfig {
    fn default() -> Self {
        Self {
            ceiling_db: -0.3,
            release_ms: 80.0,
        }
    }
}

/// Stereo-linked limiter.
#[derive(Debug, Clone)]
pub struct Limiter {
    ceiling: f32,
    release_coef: f32,
    /// Current gain reduction factor (≤ 1).
    gain: f32,
}

impl Limiter {
    pub fn new(sample_rate: u32, cfg: LimiterConfig) -> Self {
        let release_samples = (cfg.release_ms.max(1.0) / 1000.0) * sample_rate as f32;
        Self {
            ceiling: db_to_linear(cfg.ceiling_db),
            release_coef: (-1.0 / release_samples).exp(),
            gain: 1.0,
        }
    }

    /// Current gain reduction in linear units (1 = no reduction).
    pub fn gain_reduction(&self) -> f32 {
        self.gain
    }

    /// Process one stereo frame.
    #[inline]
    pub fn process_frame(&mut self, l: f32, r: f32) -> (f32, f32) {
        let peak = l.abs().max(r.abs());
        let wanted = if peak > self.ceiling {
            self.ceiling / peak
        } else {
            1.0
        };
        if wanted < self.gain {
            // Instant attack.
            self.gain = wanted;
        } else {
            // Exponential release towards `wanted`.
            self.gain = wanted + (self.gain - wanted) * self.release_coef;
        }
        let c = self.ceiling;
        ((l * self.gain).clamp(-c, c), (r * self.gain).clamp(-c, c))
    }

    /// Process interleaved stereo in place.
    pub fn process_interleaved(&mut self, buf: &mut [f32]) {
        for fr in buf.as_chunks_mut::<2>().0 {
            let (l, r) = self.process_frame(fr[0], fr[1]);
            fr[0] = l;
            fr[1] = r;
        }
    }

    /// Process planar stereo in place.
    pub fn process_planar(&mut self, left: &mut [f32], right: &mut [f32]) {
        for (l, r) in left.iter_mut().zip(right.iter_mut()) {
            let (a, b) = self.process_frame(*l, *r);
            *l = a;
            *r = b;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn never_exceeds_ceiling() {
        let mut lim = Limiter::new(48_000, LimiterConfig::default());
        let ceiling = db_to_linear(-0.3);
        for i in 0..48_000 {
            let x = 4.0 * ((i as f32) * 0.05).sin();
            let (l, r) = lim.process_frame(x, -x);
            assert!(l.abs() <= ceiling + 1e-6 && r.abs() <= ceiling + 1e-6);
        }
    }

    #[test]
    fn transparent_below_ceiling() {
        let mut lim = Limiter::new(48_000, LimiterConfig::default());
        for i in 0..1000 {
            let x = 0.5 * ((i as f32) * 0.05).sin();
            let (l, _) = lim.process_frame(x, x);
            assert!((l - x).abs() < 1e-6);
        }
    }

    #[test]
    fn releases_after_peak() {
        let mut lim = Limiter::new(48_000, LimiterConfig::default());
        lim.process_frame(2.0, 2.0);
        assert!(lim.gain_reduction() < 0.6);
        for _ in 0..48_000 {
            lim.process_frame(0.1, 0.1);
        }
        assert!(lim.gain_reduction() > 0.99);
    }
}
