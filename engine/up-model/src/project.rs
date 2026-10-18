//! Project document.

use crate::arrangement::Arrangement;
use crate::link::LinkSettings;
use crate::midi::MidiSettings;
use crate::mixer::Mixer;
use crate::pattern::Pattern;
use crate::session::Session;
use crate::{KitDoc, TimeSignature};
use serde::{Deserialize, Serialize};
use up_core::{KitId, ProjectId};

/// Kit used by a project: embedded document or a library reference.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum KitRef {
    Library { id: KitId },
    Embedded { kit: Box<KitDoc> },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TempoSettings {
    pub bpm: f64,
    pub time_signature: TimeSignature,
    /// Metronome enabled.
    pub metronome: bool,
    pub count_in_bars: u32,
}

impl Default for TempoSettings {
    fn default() -> Self {
        Self {
            bpm: 120.0,
            time_signature: TimeSignature::default(),
            metronome: false,
            count_in_bars: 0,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Project {
    pub schema_version: u32,
    pub id: ProjectId,
    pub name: String,
    pub created_unix_ms: i64,
    pub modified_unix_ms: i64,
    pub tempo: TempoSettings,
    pub kits: Vec<KitRef>,
    pub session: Session,
    pub patterns: Vec<Pattern>,
    pub arrangement: Arrangement,
    pub mixer: Mixer,
    pub midi: MidiSettings,
    pub link: LinkSettings,
}

impl Default for Project {
    fn default() -> Self {
        Self {
            schema_version: crate::PROJECT_SCHEMA_VERSION,
            id: ProjectId::default(),
            name: String::new(),
            created_unix_ms: 0,
            modified_unix_ms: 0,
            tempo: TempoSettings::default(),
            kits: Vec::new(),
            session: Session::default(),
            patterns: Vec::new(),
            arrangement: Arrangement::default(),
            mixer: Mixer::default(),
            midi: MidiSettings::default(),
            link: LinkSettings::default(),
        }
    }
}

impl Project {
    pub fn to_json(&self) -> Result<String, up_core::UpError> {
        serde_json::to_string_pretty(self).map_err(|e| up_core::UpError::format(e.to_string()))
    }

    /// Parse and migrate to the current schema.
    pub fn from_json(s: &str) -> Result<Self, up_core::UpError> {
        crate::migrate::project_migrator().load(s)
    }
}
