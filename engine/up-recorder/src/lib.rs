//! Recording: the audio thread writes interleaved frames into a lock-free
//! SPSC ring ([`RecordWriter`]); the control thread drains it
//! ([`RecordReader`]) into memory and finalises a [`Take`]. Writing the
//! take to disk is done by the runtime (engine crates do no I/O), using
//! `up_codec::write_wav`.

#![forbid(unsafe_code)]

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use up_codec::AudioBuffer;
use up_rt::spsc::{self, Consumer, Producer};

/// Shared counters.
#[derive(Debug, Default)]
pub struct RecordStats {
    /// Frames written while recording.
    pub frames: AtomicU64,
    /// Samples dropped because the ring was full.
    pub dropped: AtomicU64,
    pub recording: AtomicBool,
}

/// Audio-thread half.
pub struct RecordWriter {
    tx: Producer<f32>,
    channels: usize,
    stats: Arc<RecordStats>,
    active: bool,
}

/// Control-thread half.
pub struct RecordReader {
    rx: Consumer<f32>,
    channels: u16,
    sample_rate: u32,
    stats: Arc<RecordStats>,
}

/// Create a recording ring for `seconds` of audio.
pub fn record_channel(
    sample_rate: u32,
    channels: u16,
    seconds: f32,
) -> (RecordWriter, RecordReader) {
    let cap =
        ((sample_rate as f32 * seconds.max(0.1)) as usize).max(1024) * channels.max(1) as usize;
    let (tx, rx) = spsc::channel(cap);
    let stats = Arc::new(RecordStats::default());
    (
        RecordWriter {
            tx,
            channels: channels.max(1) as usize,
            stats: Arc::clone(&stats),
            active: false,
        },
        RecordReader {
            rx,
            channels: channels.max(1),
            sample_rate,
            stats,
        },
    )
}

impl RecordWriter {
    pub fn is_recording(&self) -> bool {
        self.active
    }

    pub fn start(&mut self) {
        self.active = true;
        self.stats.frames.store(0, Ordering::Relaxed);
        self.stats.dropped.store(0, Ordering::Relaxed);
        self.stats.recording.store(true, Ordering::Release);
    }

    /// Stop; returns total frames recorded.
    pub fn stop(&mut self) -> u64 {
        self.active = false;
        self.stats.recording.store(false, Ordering::Release);
        self.stats.frames.load(Ordering::Relaxed)
    }

    pub fn frames(&self) -> u64 {
        self.stats.frames.load(Ordering::Relaxed)
    }

    /// Write interleaved samples (no-op when not recording). Lock-free,
    /// allocation-free; drops samples if the ring is full.
    pub fn write_interleaved(&mut self, data: &[f32]) {
        if !self.active {
            return;
        }
        let whole = data.len() - data.len() % self.channels;
        let (pushed, rest) = self.tx.push_partial_slice(&data[..whole]);
        // Keep frames aligned: if a partial frame got in, the reader trims it.
        if !rest.is_empty() {
            self.stats
                .dropped
                .fetch_add(rest.len() as u64, Ordering::Relaxed);
        }
        self.stats
            .frames
            .fetch_add((pushed.len() / self.channels) as u64, Ordering::Relaxed);
    }

    /// Write planar stereo.
    pub fn write_stereo(&mut self, left: &[f32], right: &[f32]) {
        if !self.active {
            return;
        }
        let n = left.len().min(right.len());
        let mut written = 0u64;
        for i in 0..n {
            if self.tx.slots() < 2 {
                self.stats
                    .dropped
                    .fetch_add(((n - i) * 2) as u64, Ordering::Relaxed);
                break;
            }
            let _ = self.tx.push(left[i]);
            let _ = self.tx.push(right[i]);
            written += 1;
        }
        self.stats.frames.fetch_add(written, Ordering::Relaxed);
    }
}

impl RecordReader {
    pub fn stats(&self) -> &Arc<RecordStats> {
        &self.stats
    }
    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }
    pub fn channels(&self) -> u16 {
        self.channels
    }

    /// Move everything currently in the ring into `out`. Returns samples moved.
    pub fn drain_into(&mut self, out: &mut Vec<f32>) -> usize {
        let n = self.rx.slots();
        if n == 0 {
            return 0;
        }
        match self.rx.read_chunk(n) {
            Ok(chunk) => {
                let (a, b) = chunk.as_slices();
                out.extend_from_slice(a);
                out.extend_from_slice(b);
                chunk.commit_all();
                n
            }
            Err(_) => 0,
        }
    }

    /// Discard whatever is in the ring.
    pub fn clear(&mut self) {
        let n = self.rx.slots();
        if let Ok(c) = self.rx.read_chunk(n) {
            c.commit_all();
        }
    }
}

/// A finished recording.
#[derive(Debug, Clone, PartialEq)]
pub struct Take {
    pub audio: AudioBuffer,
    pub duration_secs: f64,
    pub waveform: Vec<f32>,
    pub dropped_samples: u64,
}

/// Number of buckets in a take's waveform overview.
pub const TAKE_WAVEFORM_BUCKETS: u32 = 128;

impl Take {
    /// Finalise collected interleaved samples into a take (trims any
    /// trailing partial frame).
    pub fn finalize(mut data: Vec<f32>, sample_rate: u32, channels: u16, dropped: u64) -> Self {
        let ch = channels.max(1) as usize;
        data.truncate(data.len() - data.len() % ch);
        let audio = AudioBuffer::new(sample_rate, channels.max(1), data);
        let waveform = up_codec::waveform(&audio.data, audio.channels, TAKE_WAVEFORM_BUCKETS);
        Self {
            duration_secs: audio.duration_secs(),
            audio,
            waveform,
            dropped_samples: dropped,
        }
    }
}

/// Control-side accumulator: drain periodically while recording, then
/// [`TakeCollector::finish`].
pub struct TakeCollector {
    reader: RecordReader,
    buf: Vec<f32>,
}

impl TakeCollector {
    pub fn new(reader: RecordReader) -> Self {
        Self {
            reader,
            buf: Vec::new(),
        }
    }

    pub fn stats(&self) -> &Arc<RecordStats> {
        self.reader.stats()
    }

    /// Discard previous data (call when a new recording starts).
    pub fn reset(&mut self) {
        self.reader.clear();
        self.buf.clear();
    }

    /// Pull pending samples from the ring.
    pub fn poll(&mut self) -> usize {
        self.reader.drain_into(&mut self.buf)
    }

    pub fn collected_frames(&self) -> usize {
        self.buf.len() / self.reader.channels() as usize
    }

    /// Finish the current take.
    pub fn finish(&mut self) -> Take {
        self.poll();
        let data = std::mem::take(&mut self.buf);
        let dropped = self.reader.stats().dropped.load(Ordering::Relaxed);
        Take::finalize(
            data,
            self.reader.sample_rate(),
            self.reader.channels(),
            dropped,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn records_and_finalizes() {
        let (mut w, r) = record_channel(48_000, 2, 1.0);
        let mut col = TakeCollector::new(r);
        w.write_stereo(&[0.5; 100], &[0.25; 100]); // ignored: not recording
        w.start();
        for _ in 0..10 {
            w.write_stereo(&[0.5; 480], &[-0.25; 480]);
            col.poll();
        }
        assert_eq!(w.stop(), 4800);
        let take = col.finish();
        assert_eq!(take.audio.frames(), 4800);
        assert!((take.duration_secs - 0.1).abs() < 1e-9);
        assert_eq!(take.waveform.len(), TAKE_WAVEFORM_BUCKETS as usize);
        assert_eq!(take.waveform[3], 0.5);
        assert_eq!(take.dropped_samples, 0);
    }

    #[test]
    fn overflow_counts_drops() {
        let (mut w, r) = record_channel(1000, 2, 0.1); // min 1024 frames
        let mut col = TakeCollector::new(r);
        w.start();
        w.write_interleaved(&vec![0.1; 4096]);
        w.write_stereo(&[0.1; 2000], &[0.1; 2000]);
        assert!(col.stats().dropped.load(Ordering::Relaxed) > 0);
        let take = col.finish();
        assert_eq!(take.audio.frames(), 1024);
    }
}
