//! Timeline arrangement: tracks with clips and automation lanes.

use crate::mixer::ParamTarget;
use crate::session::ClipContent;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ArrangementClip {
    pub id: String,
    pub start_beats: f64,
    pub length_beats: f64,
    /// Offset into the source content.
    #[serde(default)]
    pub offset_beats: f64,
    pub content: ClipContent,
    #[serde(default)]
    pub muted: bool,
    #[serde(default)]
    pub gain: Option<f32>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CurveKind {
    #[default]
    Linear,
    Hold,
    /// Exponential-ish curve; tension in the point.
    Curve,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AutomationPoint {
    pub beat: f64,
    pub value: f64,
    #[serde(default)]
    pub curve: CurveKind,
    #[serde(default)]
    pub tension: f32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AutomationLane {
    pub id: String,
    pub target: ParamTarget,
    pub points: Vec<AutomationPoint>,
    #[serde(default = "default_true")]
    pub enabled: bool,
}

fn default_true() -> bool {
    true
}

impl AutomationLane {
    /// Value at `beat` (linear/hold interpolation, clamped at the ends).
    pub fn value_at(&self, beat: f64) -> Option<f64> {
        let pts = &self.points;
        let first = pts.first()?;
        if beat <= first.beat {
            return Some(first.value);
        }
        for w in pts.windows(2) {
            let (a, b) = (w[0], w[1]);
            if beat < b.beat {
                return Some(match a.curve {
                    CurveKind::Hold => a.value,
                    _ => {
                        let t = (beat - a.beat) / (b.beat - a.beat).max(f64::EPSILON);
                        a.value + (b.value - a.value) * t
                    }
                });
            }
        }
        pts.last().map(|p| p.value)
    }
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ArrangementTrack {
    pub id: String,
    pub name: String,
    /// Mixer channel id.
    pub channel: Option<String>,
    pub clips: Vec<ArrangementClip>,
    pub automation: Vec<AutomationLane>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Marker {
    pub beat: f64,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Arrangement {
    pub tracks: Vec<ArrangementTrack>,
    /// Tempo automation (`ParamTarget::Tempo`) lives here too.
    pub master_automation: Vec<AutomationLane>,
    pub loop_region: Option<(f64, f64)>,
    pub markers: Vec<Marker>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn automation_interpolation() {
        let lane = AutomationLane {
            id: "a".into(),
            target: ParamTarget::MasterGain,
            points: vec![
                AutomationPoint {
                    beat: 0.0,
                    value: 0.0,
                    curve: CurveKind::Linear,
                    tension: 0.0,
                },
                AutomationPoint {
                    beat: 4.0,
                    value: 1.0,
                    curve: CurveKind::Hold,
                    tension: 0.0,
                },
                AutomationPoint {
                    beat: 8.0,
                    value: 0.5,
                    curve: CurveKind::Linear,
                    tension: 0.0,
                },
            ],
            enabled: true,
        };
        assert_eq!(lane.value_at(-1.0), Some(0.0));
        assert_eq!(lane.value_at(2.0), Some(0.5));
        assert_eq!(lane.value_at(6.0), Some(1.0));
        assert_eq!(lane.value_at(9.0), Some(0.5));
    }
}
