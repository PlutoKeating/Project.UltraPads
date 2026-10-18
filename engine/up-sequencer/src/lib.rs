//! Pattern scheduling core.
//!
//! [`PatternScheduler::schedule`] turns an [`up_model::pattern::Pattern`]
//! into pad hits for a beat window `[from, to)`, handling pattern looping,
//! swing, micro-timing, probability (deterministic seeded RNG), ratchets
//! and gate length. It writes into a caller-provided buffer so it can run
//! on the audio thread once the buffer has capacity.

#![forbid(unsafe_code)]

use up_core::PadId;
use up_model::pattern::Pattern;

/// A scheduled pad hit.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Hit {
    /// Absolute beat of the hit.
    pub beat: f64,
    pub pad: PadId,
    pub velocity: f32,
    /// Gate length in beats (for gate pads / note-off).
    pub length_beats: f64,
}

/// Small deterministic RNG (xorshift64*), seeded per step for reproducible
/// probability decisions regardless of window boundaries.
fn step_rand(seed: u64, cycle: u64, lane: usize, step: usize, repeat: u8) -> f32 {
    let mut x = seed
        ^ cycle.wrapping_mul(0x9E37_79B9_7F4A_7C15)
        ^ (lane as u64).wrapping_mul(0xC2B2_AE3D_27D4_EB4F)
        ^ (step as u64).wrapping_mul(0x1656_67B1_9E37_79F9)
        ^ (repeat as u64).wrapping_mul(0x27D4_EB2F_1656_67C5);
    if x == 0 {
        x = 0x2545_F491_4F6C_DD1D;
    }
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    let v = x.wrapping_mul(0x2545_F491_4F6C_DD1D);
    (v >> 40) as f32 / (1u64 << 24) as f32
}

/// Stateless scheduler with a probability seed.
#[derive(Debug, Clone, Copy)]
pub struct PatternScheduler {
    pub seed: u64,
}

impl Default for PatternScheduler {
    fn default() -> Self {
        Self { seed: 0x5EED }
    }
}

impl PatternScheduler {
    /// Beat offset of step `s` within one pattern cycle, including swing
    /// (delays odd steps) and micro-timing.
    pub fn step_time(pattern: &Pattern, step: usize, micro: f32) -> f64 {
        let step_len = 1.0 / pattern.steps_per_beat.max(1) as f64;
        let swing = if step % 2 == 1 {
            pattern.swing.clamp(0.0, 0.75) as f64 * step_len * 0.5
        } else {
            0.0
        };
        step as f64 * step_len + swing + micro.clamp(-0.5, 0.5) as f64 * step_len
    }

    /// Append hits falling in `[from, to)` (absolute beats; the pattern
    /// loops from beat 0) to `out`, sorted by time. Returns hits added.
    pub fn schedule(&self, pattern: &Pattern, from: f64, to: f64, out: &mut Vec<Hit>) -> usize {
        let len = pattern.length_beats();
        if len <= 0.0 || to <= from || pattern.length_steps == 0 {
            return 0;
        }
        let start_len = out.len();
        let step_len = 1.0 / pattern.steps_per_beat.max(1) as f64;
        // Micro-timing can pull a hit up to half a step earlier, so look one
        // cycle back as well.
        let first_cycle = ((from / len).floor() as i64 - 1).max(0) as u64;
        let last_cycle = (to / len).ceil() as u64;
        for cycle in first_cycle..=last_cycle {
            let base = cycle as f64 * len;
            for (li, lane) in pattern.lanes.iter().enumerate() {
                if lane.muted {
                    continue;
                }
                for (si, step) in lane
                    .steps
                    .iter()
                    .enumerate()
                    .take(pattern.length_steps as usize)
                {
                    if !step.active {
                        continue;
                    }
                    let t0 = base + Self::step_time(pattern, si, step.micro_offset);
                    let repeats = step.repeats.max(1);
                    let sub = step_len / repeats as f64;
                    for k in 0..repeats {
                        let t = t0 + k as f64 * sub;
                        if t < from || t >= to || t < 0.0 {
                            continue;
                        }
                        if step.probability < 1.0
                            && step_rand(self.seed, cycle, li, si, k) >= step.probability.max(0.0)
                        {
                            continue;
                        }
                        out.push(Hit {
                            beat: t,
                            pad: lane.pad,
                            velocity: step.velocity.clamp(0.0, 1.0),
                            length_beats: (step.length_steps.max(0.0) as f64 * step_len)
                                .min(sub * if repeats > 1 { 1.0 } else { f64::MAX }),
                        });
                    }
                }
            }
        }
        out[start_len..].sort_by(|a, b| a.beat.total_cmp(&b.beat));
        out.len() - start_len
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use up_model::pattern::{PatternLane, Step};

    fn four_on_floor() -> Pattern {
        let mut steps = vec![Step::default(); 16];
        for i in (0..16).step_by(4) {
            steps[i] = Step::on(1.0);
        }
        Pattern {
            lanes: vec![PatternLane {
                pad: PadId { bank: 0, index: 0 },
                steps,
                muted: false,
            }],
            ..Default::default()
        }
    }

    #[test]
    fn schedules_quarter_notes_and_loops() {
        let p = four_on_floor();
        let s = PatternScheduler::default();
        let mut out = Vec::new();
        s.schedule(&p, 0.0, 8.0, &mut out);
        let beats: Vec<f64> = out.iter().map(|h| h.beat).collect();
        assert_eq!(beats, vec![0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]);
        out.clear();
        // Window boundaries are half-open and windows tile without gaps.
        s.schedule(&p, 0.5, 2.0, &mut out);
        assert_eq!(out.iter().map(|h| h.beat).collect::<Vec<_>>(), vec![1.0]);
    }

    #[test]
    fn tiled_windows_equal_one_window() {
        let mut p = four_on_floor();
        p.swing = 0.5;
        p.lanes[0].steps[3] = Step {
            active: true,
            probability: 0.5,
            micro_offset: -0.4,
            repeats: 3,
            ..Default::default()
        };
        let s = PatternScheduler { seed: 42 };
        let mut whole = Vec::new();
        s.schedule(&p, 0.0, 16.0, &mut whole);
        let mut tiled = Vec::new();
        let mut t = 0.0;
        while t < 16.0 {
            let end = (t + 0.1f64).min(16.0);
            s.schedule(&p, t, end, &mut tiled);
            t = end;
        }
        assert_eq!(whole.len(), tiled.len());
        for (a, b) in whole.iter().zip(&tiled) {
            assert!((a.beat - b.beat).abs() < 1e-9);
        }
    }

    #[test]
    fn swing_delays_odd_steps() {
        let p = Pattern {
            swing: 0.5,
            ..Default::default()
        };
        assert_eq!(PatternScheduler::step_time(&p, 0, 0.0), 0.0);
        assert!((PatternScheduler::step_time(&p, 1, 0.0) - (0.25 + 0.0625)).abs() < 1e-12);
    }

    #[test]
    fn probability_zero_and_muted_lanes() {
        let mut p = four_on_floor();
        for st in &mut p.lanes[0].steps {
            st.probability = 0.0;
        }
        let mut out = Vec::new();
        PatternScheduler::default().schedule(&p, 0.0, 4.0, &mut out);
        assert!(out.is_empty());
        let mut p = four_on_floor();
        p.lanes[0].muted = true;
        PatternScheduler::default().schedule(&p, 0.0, 4.0, &mut out);
        assert!(out.is_empty());
    }
}
