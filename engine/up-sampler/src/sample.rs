use std::sync::Arc;
use up_core::SampleId;

/// Decoded, engine-rate sample in planar layout (1 or 2 channels).
#[derive(Debug, Clone, PartialEq, Default)]
pub struct SampleData {
    pub id: SampleId,
    pub name: String,
    pub sample_rate: u32,
    /// One `Vec` per channel (1 = mono, 2 = stereo); equal lengths.
    pub channels: Vec<Vec<f32>>,
}

/// Shared handle used across threads.
pub type SampleArc = Arc<SampleData>;

impl SampleData {
    /// Build from planar data; channels beyond two are dropped and
    /// mismatched lengths are truncated to the shortest.
    pub fn new(
        id: SampleId,
        name: impl Into<String>,
        sample_rate: u32,
        mut channels: Vec<Vec<f32>>,
    ) -> Self {
        channels.truncate(2);
        let n = channels.iter().map(Vec::len).min().unwrap_or(0);
        for c in &mut channels {
            c.truncate(n);
            c.shrink_to_fit();
        }
        Self {
            id,
            name: name.into(),
            sample_rate,
            channels,
        }
    }

    pub fn frames(&self) -> usize {
        self.channels.first().map_or(0, Vec::len)
    }

    pub fn duration_secs(&self) -> f64 {
        if self.sample_rate == 0 {
            0.0
        } else {
            self.frames() as f64 / self.sample_rate as f64
        }
    }

    pub fn is_stereo(&self) -> bool {
        self.channels.len() >= 2
    }

    pub fn left(&self) -> &[f32] {
        self.channels.first().map_or(&[], Vec::as_slice)
    }

    pub fn right(&self) -> &[f32] {
        self.channels.get(1).map_or(self.left(), Vec::as_slice)
    }
}
