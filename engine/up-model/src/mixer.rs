//! Mixer: channels, sends, buses, effect chains and plugin slots.

use crate::blob::Blob;
use serde::{Deserialize, Serialize};

/// Addressable automatable parameter.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum ParamTarget {
    Tempo,
    MasterGain,
    ChannelGain {
        channel: String,
    },
    ChannelPan {
        channel: String,
    },
    ChannelMute {
        channel: String,
    },
    SendLevel {
        channel: String,
        send: String,
    },
    PluginParam {
        channel: String,
        slot: String,
        param: u32,
    },
    PadGain {
        pad: up_core::PadId,
    },
    PadPan {
        pad: up_core::PadId,
    },
}

/// Which plugin implementation a slot hosts.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "format")]
pub enum PluginKind {
    /// Built-in UltraPads effect (e.g. `"eq3"`, `"compressor"`, `"reverb"`).
    Builtin { name: String },
    /// CLAP plugin identified by its reverse-DNS id.
    Clap { id: String, version: Option<String> },
    /// VST3 plugin identified by its class UID (32 hex chars).
    Vst3 {
        uid: String,
        version: Option<String>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ParamValue {
    pub id: u32,
    pub value: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PluginSlot {
    pub id: String,
    pub kind: PluginKind,
    #[serde(default = "yes")]
    pub enabled: bool,
    /// Dry/wet `0..=1`.
    #[serde(default = "one")]
    pub mix: f32,
    #[serde(default)]
    pub params: Vec<ParamValue>,
    /// Opaque plugin state (CLAP state / VST3 component+controller state).
    #[serde(default)]
    pub state: Option<Blob>,
    #[serde(default)]
    pub display_name: Option<String>,
}

fn yes() -> bool {
    true
}
fn one() -> f32 {
    1.0
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct EffectChain {
    pub slots: Vec<PluginSlot>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SendDoc {
    pub id: String,
    /// Destination bus id.
    pub bus: String,
    pub level_db: f32,
    #[serde(default)]
    pub pre_fader: bool,
}

/// Where a channel gets its audio from.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum ChannelInput {
    #[default]
    None,
    /// A single pad.
    Pad { pad: up_core::PadId },
    /// All pads of a kit.
    Kit { kit: up_core::KitId },
    /// A track (session/arrangement) id.
    Track { track: String },
    /// Hardware input channel(s).
    HardwareInput { channels: Vec<u16> },
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum OutputTarget {
    #[default]
    Master,
    Bus {
        bus: String,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Channel {
    pub id: String,
    pub name: String,
    pub input: ChannelInput,
    pub gain_db: f32,
    pub pan: f32,
    pub mute: bool,
    pub solo: bool,
    pub phase_invert: bool,
    pub sends: Vec<SendDoc>,
    pub effects: EffectChain,
    pub output: OutputTarget,
    pub color: Option<up_core::ColorRole>,
}

impl Default for Channel {
    fn default() -> Self {
        Self {
            id: String::new(),
            name: String::new(),
            input: ChannelInput::None,
            gain_db: 0.0,
            pan: 0.0,
            mute: false,
            solo: false,
            phase_invert: false,
            sends: Vec::new(),
            effects: EffectChain::default(),
            output: OutputTarget::Master,
            color: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Bus {
    pub id: String,
    pub name: String,
    pub gain_db: f32,
    pub pan: f32,
    pub mute: bool,
    pub effects: EffectChain,
    pub output: OutputTarget,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct MasterChannel {
    pub gain_db: f32,
    pub effects: EffectChain,
    pub limiter: bool,
    pub limiter_ceiling_db: f32,
}

impl Default for MasterChannel {
    fn default() -> Self {
        Self {
            gain_db: 0.0,
            effects: EffectChain::default(),
            limiter: true,
            limiter_ceiling_db: -0.3,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Mixer {
    pub channels: Vec<Channel>,
    pub buses: Vec<Bus>,
    pub master: MasterChannel,
}

impl Mixer {
    /// Check that sends/outputs reference existing buses and that bus
    /// routing has no cycles.
    pub fn validate(&self) -> Result<(), up_core::UpError> {
        let has_bus = |id: &str| self.buses.iter().any(|b| b.id == id);
        for c in &self.channels {
            for s in &c.sends {
                if !has_bus(&s.bus) {
                    return Err(up_core::UpError::format(format!(
                        "channel {} sends to unknown bus {}",
                        c.id, s.bus
                    )));
                }
            }
            if let OutputTarget::Bus { bus } = &c.output
                && !has_bus(bus)
            {
                return Err(up_core::UpError::format(format!(
                    "channel {} outputs to unknown bus {bus}",
                    c.id
                )));
            }
        }
        // Bus → bus cycle detection.
        for start in &self.buses {
            let mut cur = &start.output;
            let mut hops = 0;
            while let OutputTarget::Bus { bus } = cur {
                hops += 1;
                if bus == &start.id || hops > self.buses.len() {
                    return Err(up_core::UpError::format(format!(
                        "bus routing cycle through {}",
                        start.id
                    )));
                }
                match self.buses.iter().find(|b| &b.id == bus) {
                    Some(b) => cur = &b.output,
                    None => {
                        return Err(up_core::UpError::format(format!("unknown bus {bus}")));
                    }
                }
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cycle_detection() {
        let mut m = Mixer {
            buses: vec![
                Bus {
                    id: "a".into(),
                    output: OutputTarget::Bus { bus: "b".into() },
                    ..Default::default()
                },
                Bus {
                    id: "b".into(),
                    output: OutputTarget::Master,
                    ..Default::default()
                },
            ],
            ..Default::default()
        };
        assert!(m.validate().is_ok());
        m.buses[1].output = OutputTarget::Bus { bus: "a".into() };
        assert!(m.validate().is_err());
    }

    #[test]
    fn plugin_slot_json() {
        let slot = PluginSlot {
            id: "fx1".into(),
            kind: PluginKind::Vst3 {
                uid: "0123456789ABCDEF0123456789ABCDEF".into(),
                version: None,
            },
            enabled: true,
            mix: 1.0,
            params: vec![ParamValue { id: 3, value: 0.5 }],
            state: Some(Blob(vec![0xde, 0xad])),
            display_name: None,
        };
        let j = serde_json::to_string(&slot).unwrap();
        assert!(j.contains("\"format\":\"vst3\""), "{j}");
        assert_eq!(serde_json::from_str::<PluginSlot>(&j).unwrap(), slot);
    }
}
