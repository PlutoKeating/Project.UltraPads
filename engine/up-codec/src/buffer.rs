/// Decoded audio: interleaved `f32` samples in `[-1, 1]`.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct AudioBuffer {
    pub sample_rate: u32,
    pub channels: u16,
    /// Interleaved samples, `frames × channels` long.
    pub data: Vec<f32>,
}

impl AudioBuffer {
    pub fn new(sample_rate: u32, channels: u16, data: Vec<f32>) -> Self {
        Self {
            sample_rate,
            channels,
            data,
        }
    }

    /// Number of frames.
    pub fn frames(&self) -> usize {
        if self.channels == 0 {
            0
        } else {
            self.data.len() / self.channels as usize
        }
    }

    pub fn duration_secs(&self) -> f64 {
        if self.sample_rate == 0 {
            0.0
        } else {
            self.frames() as f64 / self.sample_rate as f64
        }
    }

    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }

    /// Split into one `Vec` per channel.
    pub fn to_planar(&self) -> Vec<Vec<f32>> {
        let ch = self.channels.max(1) as usize;
        let frames = self.frames();
        let mut out = vec![Vec::with_capacity(frames); ch];
        for frame in self.data.chunks_exact(ch) {
            for (c, s) in frame.iter().enumerate() {
                out[c].push(*s);
            }
        }
        out
    }

    /// Build from planar channels (all channels must have equal length).
    pub fn from_planar(sample_rate: u32, planar: &[Vec<f32>]) -> Self {
        let ch = planar.len();
        let frames = planar.iter().map(Vec::len).min().unwrap_or(0);
        let mut data = Vec::with_capacity(frames * ch);
        for i in 0..frames {
            for c in planar {
                data.push(c[i]);
            }
        }
        Self::new(sample_rate, ch as u16, data)
    }

    /// Convert to stereo planar `(left, right)`. Mono is duplicated; more
    /// than two channels keep the first two.
    pub fn to_stereo_planar(&self) -> (Vec<f32>, Vec<f32>) {
        let mut planar = self.to_planar();
        match planar.len() {
            0 => (Vec::new(), Vec::new()),
            1 => {
                let l = planar.pop().unwrap_or_default();
                (l.clone(), l)
            }
            _ => {
                planar.truncate(2);
                let r = planar.pop().unwrap_or_default();
                let l = planar.pop().unwrap_or_default();
                (l, r)
            }
        }
    }

    /// Absolute peak over all samples.
    pub fn peak(&self) -> f32 {
        self.data.iter().fold(0.0f32, |m, s| m.max(s.abs()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn planar_roundtrip() {
        let b = AudioBuffer::new(48_000, 2, vec![1.0, -1.0, 2.0, -2.0]);
        assert_eq!(b.frames(), 2);
        let p = b.to_planar();
        assert_eq!(p, vec![vec![1.0, 2.0], vec![-1.0, -2.0]]);
        assert_eq!(AudioBuffer::from_planar(48_000, &p), b);
        let m = AudioBuffer::new(48_000, 1, vec![0.5, 0.25]);
        assert_eq!(m.to_stereo_planar(), (vec![0.5, 0.25], vec![0.5, 0.25]));
    }
}
