//! Ableton Link settings (the Link implementation itself is an optional,
//! default-off GPL feature; see ADR-0001 #5).

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct LinkSettings {
    pub enabled: bool,
    /// Sync start/stop with other Link peers.
    pub start_stop_sync: bool,
    /// Phase quantum in beats (usually one bar).
    pub quantum: f64,
}

impl Default for LinkSettings {
    fn default() -> Self {
        Self {
            enabled: false,
            start_stop_sync: false,
            quantum: 4.0,
        }
    }
}
