//! MIDI input mappings and clock settings.

use crate::mixer::ParamTarget;
use serde::{Deserialize, Serialize};
use up_core::{Bank, PadId};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum MidiMessageKind {
    Note { note: u8 },
    ControlChange { cc: u8 },
    ProgramChange { program: u8 },
    PitchBend,
    ChannelPressure,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MidiSource {
    /// Device name pattern; `None` = any device.
    #[serde(default)]
    pub device: Option<String>,
    /// MIDI channel 0..=15; `None` = omni.
    #[serde(default)]
    pub channel: Option<u8>,
    pub message: MidiMessageKind,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum MidiTarget {
    Pad {
        pad: PadId,
    },
    SwitchBank {
        bank: Bank,
    },
    StopAll,
    TransportPlay,
    TransportStop,
    Param {
        target: ParamTarget,
        min: f64,
        max: f64,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum VelocityCurve {
    #[default]
    Linear,
    Soft,
    Hard,
    /// Always full velocity.
    Fixed,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MidiBinding {
    pub source: MidiSource,
    pub target: MidiTarget,
    #[serde(default)]
    pub velocity_curve: VelocityCurve,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ClockSync {
    #[default]
    Internal,
    /// Follow incoming MIDI clock.
    External,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct MidiSettings {
    pub bindings: Vec<MidiBinding>,
    pub clock_sync: ClockSync,
    /// Send MIDI clock to these output devices.
    pub clock_outputs: Vec<String>,
    /// Map notes 36..=59 to pads automatically when no binding matches.
    pub default_pad_notes: bool,
}

impl MidiSettings {
    /// Resolve an incoming note to a pad, using bindings first and then the
    /// default `36 + flat` mapping when enabled.
    pub fn pad_for_note(&self, device: Option<&str>, channel: u8, note: u8) -> Option<PadId> {
        for b in &self.bindings {
            if let (MidiMessageKind::Note { note: n }, MidiTarget::Pad { pad }) =
                (b.source.message, &b.target)
                && n == note
                && b.source.channel.is_none_or(|c| c == channel)
                && b.source
                    .device
                    .as_deref()
                    .is_none_or(|d| device.is_some_and(|x| x.contains(d)))
            {
                return Some(*pad);
            }
        }
        if self.default_pad_notes && (36..60).contains(&note) {
            return PadId::from_flat((note - 36) as usize);
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn note_resolution() {
        let s = MidiSettings {
            bindings: vec![MidiBinding {
                source: MidiSource {
                    device: Some("Launchpad".into()),
                    channel: Some(9),
                    message: MidiMessageKind::Note { note: 60 },
                },
                target: MidiTarget::Pad {
                    pad: PadId { bank: 1, index: 5 },
                },
                velocity_curve: VelocityCurve::Linear,
            }],
            default_pad_notes: true,
            ..Default::default()
        };
        assert_eq!(
            s.pad_for_note(Some("Launchpad X"), 9, 60),
            Some(PadId { bank: 1, index: 5 })
        );
        assert_eq!(s.pad_for_note(Some("Other"), 9, 60), None);
        assert_eq!(
            s.pad_for_note(None, 0, 37),
            Some(PadId { bank: 0, index: 1 })
        );
        let j = serde_json::to_string(&s).unwrap();
        assert_eq!(serde_json::from_str::<MidiSettings>(&j).unwrap(), s);
    }
}
