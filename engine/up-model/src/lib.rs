//! UltraPads document model.
//!
//! * [`kit`] — kits, pads and sample references (used by the v0.0.1 runtime).
//! * [`tutorial`] — timed tutorial charts (song seconds) and judgement.
//! * [`project`] — top-level project tying everything together:
//!   [`session`] (clip launcher), [`pattern`] (step sequencer),
//!   [`arrangement`] (timeline, automation), [`mixer`] (channels, sends,
//!   buses, effect chains, plugin slots), [`midi`] mappings and [`link`]
//!   settings.
//! * [`migrate`] — schema versioning and migration hooks.
//!
//! All documents serialize as camelCase JSON and carry a `schemaVersion`.

#![forbid(unsafe_code)]

pub mod arrangement;
pub mod blob;
pub mod kit;
pub mod link;
pub mod midi;
pub mod migrate;
pub mod mixer;
pub mod pattern;
pub mod project;
pub mod session;
pub mod tutorial;

pub use kit::{
    ChokeRelease, KitDoc, KitMeta, KitSource, LoopMeta, PadDoc, SampleLayer, SampleRef, Stretch,
};
pub use migrate::{KIT_SCHEMA_VERSION, Migrator, PROJECT_SCHEMA_VERSION};
pub use project::Project;
pub use tutorial::{
    JudgeWindow, Judgement, TutorialAction, TutorialChart, TutorialEvent, TutorialLesson,
    TutorialTarget,
};

/// Musical time signature (shared by kit and project).
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
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
