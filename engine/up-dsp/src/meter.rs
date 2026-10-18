//! Peak and RMS level meters.

/// Peak hold meter: `read_and_reset` returns the max |x| since last read.
#[derive(Debug, Clone, Copy, Default)]
pub struct PeakMeter {
    peak: f32,
}

impl PeakMeter {
    #[inline]
    pub fn push(&mut self, x: f32) {
        let a = x.abs();
        if a > self.peak {
            self.peak = a;
        }
    }

    #[inline]
    pub fn push_slice(&mut self, xs: &[f32]) {
        for &x in xs {
            self.push(x);
        }
    }

    #[inline]
    pub fn peek(&self) -> f32 {
        self.peak
    }

    #[inline]
    pub fn read_and_reset(&mut self) -> f32 {
        std::mem::take(&mut self.peak)
    }
}

/// Windowed RMS meter (mean of squares accumulated since last read).
#[derive(Debug, Clone, Copy, Default)]
pub struct RmsMeter {
    sum_sq: f64,
    n: u64,
}

impl RmsMeter {
    #[inline]
    pub fn push(&mut self, x: f32) {
        self.sum_sq += (x as f64) * (x as f64);
        self.n += 1;
    }

    #[inline]
    pub fn read_and_reset(&mut self) -> f32 {
        let r = if self.n == 0 {
            0.0
        } else {
            (self.sum_sq / self.n as f64).sqrt() as f32
        };
        self.sum_sq = 0.0;
        self.n = 0;
        r
    }
}

/// Stereo peak + RMS meter.
#[derive(Debug, Clone, Copy, Default)]
pub struct StereoMeter {
    pub peak: [PeakMeter; 2],
    pub rms: [RmsMeter; 2],
}

impl StereoMeter {
    #[inline]
    pub fn push(&mut self, l: f32, r: f32) {
        self.peak[0].push(l);
        self.peak[1].push(r);
        self.rms[0].push(l);
        self.rms[1].push(r);
    }

    /// Returns `(peak, rms)` and resets.
    pub fn read_and_reset(&mut self) -> ([f32; 2], [f32; 2]) {
        (
            [self.peak[0].read_and_reset(), self.peak[1].read_and_reset()],
            [self.rms[0].read_and_reset(), self.rms[1].read_and_reset()],
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rms_of_square_wave() {
        let mut m = RmsMeter::default();
        for i in 0..1000 {
            m.push(if i % 2 == 0 { 0.5 } else { -0.5 });
        }
        assert!((m.read_and_reset() - 0.5).abs() < 1e-6);
        assert_eq!(m.read_and_reset(), 0.0);
    }

    #[test]
    fn peak_hold() {
        let mut p = PeakMeter::default();
        p.push_slice(&[0.1, -0.9, 0.3]);
        assert_eq!(p.read_and_reset(), 0.9);
        assert_eq!(p.peek(), 0.0);
    }
}
