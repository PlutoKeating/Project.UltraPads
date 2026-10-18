use crate::meters::MeterBank;
use std::sync::Arc;
use std::sync::atomic::Ordering;
use up_graph::GraphProcessor;

/// Realtime half of the engine. Owned by the audio callback.
pub struct AudioProcessor {
    graph: Box<dyn GraphProcessor>,
    scratch: Vec<f32>,
    meters: Arc<MeterBank>,
    sample_rate: u32,
}

impl AudioProcessor {
    pub(crate) fn new(
        graph: Box<dyn GraphProcessor>,
        max_block: usize,
        meters: Arc<MeterBank>,
        sample_rate: u32,
    ) -> Self {
        Self {
            graph,
            scratch: vec![0.0; max_block * 2],
            meters,
            sample_rate,
        }
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    /// Render interleaved output for a device with `channels` channels.
    /// Stereo is written to the first two channels (mono devices get the
    /// average, extra channels are silent). Never allocates or locks.
    pub fn process(&mut self, out: &mut [f32], channels: usize) {
        let channels = channels.max(1);
        let frames = out.len() / channels;
        if channels == 2 {
            self.graph.process_interleaved(&mut out[..frames * 2], 2);
        } else {
            let chunk = self.scratch.len() / 2;
            let mut done = 0;
            while done < frames {
                let n = (frames - done).min(chunk);
                let s = &mut self.scratch[..n * 2];
                self.graph.process_interleaved(s, 2);
                for f in 0..n {
                    let (l, r) = (s[f * 2], s[f * 2 + 1]);
                    let frame = &mut out[(done + f) * channels..(done + f + 1) * channels];
                    if channels == 1 {
                        frame[0] = 0.5 * (l + r);
                    } else {
                        frame[0] = l;
                        frame[1] = r;
                        frame[2..].fill(0.0);
                    }
                }
                done += n;
            }
        }
        self.meters
            .frames
            .fetch_add(frames as u64, Ordering::Relaxed);
        self.meters.callbacks.fetch_add(1, Ordering::Relaxed);
    }
}
