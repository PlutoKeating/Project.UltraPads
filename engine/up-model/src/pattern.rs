//! Step-sequencer patterns.

use serde::{Deserialize, Serialize};
use up_core::PadId;

/// A parameter lock on a step (overrides a parameter for that step only).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ParamLock {
    pub target: crate::mixer::ParamTarget,
    pub value: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Step {
    pub active: bool,
    /// `0..=1`.
    pub velocity: f32,
    /// Trigger probability `0..=1`.
    pub probability: f32,
    /// Micro-timing offset as a fraction of a step (`-0.5..=0.5`).
    pub micro_offset: f32,
    /// Gate length in steps.
    pub length_steps: f32,
    /// Ratchet count (1 = single hit).
    pub repeats: u8,
    pub param_locks: Vec<ParamLock>,
}

impl Default for Step {
    fn default() -> Self {
        Self {
            active: false,
            velocity: 1.0,
            probability: 1.0,
            micro_offset: 0.0,
            length_steps: 1.0,
            repeats: 1,
            param_locks: Vec::new(),
        }
    }
}

impl Step {
    pub fn on(velocity: f32) -> Self {
        Self {
            active: true,
            velocity,
            ..Default::default()
        }
    }
}

/// One row of a pattern, triggering a pad.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct PatternLane {
    pub pad: PadId,
    pub steps: Vec<Step>,
    pub muted: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Pattern {
    pub id: String,
    pub name: String,
    /// Steps per beat (4 = sixteenth notes).
    pub steps_per_beat: u32,
    /// Pattern length in steps.
    pub length_steps: u32,
    /// Swing amount `0..=0.75` applied to every second step.
    pub swing: f32,
    pub lanes: Vec<PatternLane>,
}

impl Default for Pattern {
    fn default() -> Self {
        Self {
            id: String::new(),
            name: String::new(),
            steps_per_beat: 4,
            length_steps: 16,
            swing: 0.0,
            lanes: Vec::new(),
        }
    }
}

impl Pattern {
    pub fn length_beats(&self) -> f64 {
        self.length_steps as f64 / self.steps_per_beat.max(1) as f64
    }
}
