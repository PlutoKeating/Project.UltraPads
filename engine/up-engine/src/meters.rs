//! Lock-free meter bank written by the audio thread, read by the control
//! thread. Peaks use `fetch_max` on the IEEE bits (valid for non-negative
//! floats), so the control thread sees the max since its last read.

use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use up_core::PAD_COUNT;

#[derive(Debug, Default)]
pub(crate) struct MeterBank {
    pub clock: ClockCell,
    pub pad_peaks: [AtomicU32; PAD_COUNT],
    pub master_peak: [AtomicU32; 2],
    /// Latest RMS (bits), published once per window.
    pub master_rms: [AtomicU32; 2],
    pub active_voices: AtomicU32,
    /// Frames processed since start (sample clock).
    pub frames: AtomicU64,
    /// Number of `process` calls.
    pub callbacks: AtomicU64,
}

#[inline]
pub(crate) fn push_peak(a: &AtomicU32, v: f32) {
    let v = v.abs();
    if v > 0.0 && v.is_finite() {
        a.fetch_max(v.to_bits(), Ordering::Relaxed);
    }
}

#[inline]
pub(crate) fn take_peak(a: &AtomicU32) -> f32 {
    f32::from_bits(a.swap(0, Ordering::Relaxed))
}

/// Seqlock-protected transport clock written once per block by the audio
/// thread (wait-free for the writer), read by any thread.
#[derive(Debug)]
pub(crate) struct ClockCell {
    base: std::time::Instant,
    seq: AtomicU64,
    playing: AtomicU64,
    beat: AtomicU64,
    bpm: AtomicU64,
    speed: AtomicU64,
    at_ns: AtomicU64,
}

impl Default for ClockCell {
    fn default() -> Self {
        Self {
            base: std::time::Instant::now(),
            seq: AtomicU64::new(0),
            playing: AtomicU64::new(0),
            beat: AtomicU64::new(0),
            bpm: AtomicU64::new(120f64.to_bits()),
            speed: AtomicU64::new(1f64.to_bits()),
            at_ns: AtomicU64::new(0),
        }
    }
}

impl ClockCell {
    fn now_ns(&self) -> u64 {
        self.base.elapsed().as_nanos() as u64
    }

    /// Publish the transport state at the *end* of a block.
    pub fn publish(&self, playing: bool, beat: f64, bpm: f64, speed: f64) {
        let now = self.now_ns();
        self.seq.fetch_add(1, Ordering::AcqRel); // odd: writing
        self.playing.store(playing as u64, Ordering::Relaxed);
        self.beat.store(beat.to_bits(), Ordering::Relaxed);
        self.bpm.store(bpm.to_bits(), Ordering::Relaxed);
        self.speed.store(speed.to_bits(), Ordering::Relaxed);
        self.at_ns.store(now, Ordering::Relaxed);
        self.seq.fetch_add(1, Ordering::AcqRel); // even: done
    }

    /// Read a consistent clock extrapolated to now.
    pub fn read(&self) -> up_protocol::TransportClock {
        loop {
            let s1 = self.seq.load(Ordering::Acquire);
            if s1 % 2 == 1 {
                std::hint::spin_loop();
                continue;
            }
            let playing = self.playing.load(Ordering::Relaxed) != 0;
            let beat = f64::from_bits(self.beat.load(Ordering::Relaxed));
            let bpm = f64::from_bits(self.bpm.load(Ordering::Relaxed));
            let speed = f64::from_bits(self.speed.load(Ordering::Relaxed));
            let at = self.at_ns.load(Ordering::Relaxed);
            if self.seq.load(Ordering::Acquire) != s1 {
                continue;
            }
            let mut beat_now = beat;
            if playing {
                // Extrapolate at most 100 ms (guards against a stalled stream).
                let dt = (self.now_ns().saturating_sub(at) as f64 / 1e9).min(0.1);
                beat_now += dt * bpm * speed / 60.0;
            }
            let song_secs = if bpm > 0.0 {
                beat_now * 60.0 / bpm
            } else {
                0.0
            };
            return up_protocol::TransportClock {
                playing,
                beat: beat_now,
                song_secs,
                bpm,
                speed,
            };
        }
    }
}
