//! `ultrapads-kit.json`：SFZ 表达不了的交互/布局/外观扩展。
//!
//! 字段与 `docs/research/kit-and-project-formats.md` §6.2 一致；JSON Schema 见
//! `content/schema/ultrapads-kit-1.schema.json`。未知字段保存在 `extra` 中，回写时原样保留（前向兼容）。

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

use crate::kit::{Launch, LoopTempo, PadColor, PadKind, TutorialRef};
use crate::{FormatError, Result};

pub const FILE_NAME: &str = "ultrapads-kit.json";
pub const SCHEMA_ID: &str = "https://ultrapads.dev/schema/kit-1.json";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KitJson {
    #[serde(rename = "$schema", default, skip_serializing_if = "Option::is_none")]
    pub schema: Option<String>,
    pub format_version: String,
    /// SFZ 文件的包内路径（默认 `kit.sfz`）。
    #[serde(default = "default_sfz")]
    pub sfz: String,
    #[serde(default)]
    pub layout: Layout,
    #[serde(default)]
    pub pads: Vec<PadJson>,
    #[serde(default, skip_serializing_if = "Defaults::is_empty")]
    pub defaults: Defaults,
    /// Kit 级速度。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tempo: Option<KitTempoJson>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tutorials: Vec<TutorialRef>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub skin: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cover: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub theme_color: Option<String>,
    #[serde(flatten)]
    pub extra: Map<String, Value>,
}

fn default_sfz() -> String {
    "kit.sfz".into()
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Layout {
    pub pad_count: u8,
    #[serde(default = "default_grid")]
    pub grid: [u8; 2],
    #[serde(default = "default_banks")]
    pub banks: Vec<String>,
}

fn default_grid() -> [u8; 2] {
    [4, 3]
}
fn default_banks() -> Vec<String> {
    vec!["A".into(), "B".into()]
}

impl Default for Layout {
    fn default() -> Self {
        Self {
            pad_count: 12,
            grid: default_grid(),
            banks: default_banks(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KitTempoJson {
    pub bpm: f64,
    #[serde(default = "default_ts")]
    pub time_signature: [u8; 2],
}

fn default_ts() -> [u8; 2] {
    [4, 4]
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PadJson {
    /// 关联 SFZ 中的音符。
    pub note: u8,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub bank: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub index: Option<u8>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub color: Option<PadColor>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<PadKind>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub launch: Option<Launch>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tempo: Option<LoopTempo>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exclusive: Option<String>,
    #[serde(flatten)]
    pub extra: Map<String, Value>,
}

impl PadJson {
    pub fn new(note: u8) -> Self {
        Self {
            note,
            bank: None,
            index: None,
            name: None,
            color: None,
            icon: None,
            kind: None,
            launch: None,
            tempo: None,
            exclusive: None,
            extra: Map::new(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Defaults {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub one_shot: Option<KindDefaults>,
    #[serde(rename = "loop", default, skip_serializing_if = "Option::is_none")]
    pub loop_: Option<KindDefaults>,
}

impl Defaults {
    pub fn is_empty(&self) -> bool {
        self.one_shot.is_none() && self.loop_.is_none()
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KindDefaults {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub launch: Option<Launch>,
}

impl KitJson {
    pub fn new(pad_count: u8) -> Self {
        Self {
            schema: Some(SCHEMA_ID.into()),
            format_version: crate::FORMAT_VERSION.into(),
            sfz: default_sfz(),
            layout: Layout {
                pad_count,
                ..Layout::default()
            },
            pads: Vec::new(),
            defaults: Defaults::default(),
            tempo: None,
            tutorials: Vec::new(),
            skin: None,
            cover: None,
            theme_color: None,
            extra: Map::new(),
        }
    }

    pub fn from_slice(bytes: &[u8]) -> Result<Self> {
        let v: Self = serde_json::from_slice(bytes).map_err(|e| FormatError::json(FILE_NAME, e))?;
        crate::check_format_version(&v.format_version)?;
        Ok(v)
    }

    pub fn to_vec_pretty(&self) -> Vec<u8> {
        let mut v = serde_json::to_vec_pretty(self).expect("KitJson 序列化不会失败");
        v.push(b'\n');
        v
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 规格文档 §6.2 中的示例必须能被解析。
    pub(crate) const SPEC_EXAMPLE: &str = r##"{
  "$schema": "https://ultrapads.dev/schema/kit-1.json",
  "formatVersion": "1.0.0",
  "sfz": "kit.sfz",
  "layout": { "padCount": 24, "grid": [4, 3], "banks": ["A", "B"] },
  "pads": [
    { "note": 36, "bank": "A", "index": 0, "name": "Kick",   "color": "#FF5A36", "icon": "kick" },
    { "note": 42, "bank": "A", "index": 1, "name": "HH Cl",  "color": "#F7C948" },
    { "note": 46, "bank": "A", "index": 2, "name": "HH Op",  "color": "#F7C948" },
    {
      "note": 48, "bank": "B", "index": 0, "name": "Groove", "color": "#3FA7FF",
      "kind": "loop",
      "launch": { "mode": "toggle", "quantize": "1bar", "retrigger": "restart" },
      "tempo": { "bpm": 92.0, "beats": 16, "timeSignature": [4, 4], "stretch": "beats" },
      "exclusive": "loops-B"
    }
  ],
  "defaults": { "oneShot": { "launch": { "mode": "trigger", "quantize": "none" } } },
  "tutorials": [ { "id": "first-beat", "path": "tutorials/first-beat/tutorial.json" } ],
  "skin": "skin/theme.json",
  "futureField": { "keep": true }
}"##;

    #[test]
    fn parses_spec_example_and_keeps_unknown_fields() {
        let k = KitJson::from_slice(SPEC_EXAMPLE.as_bytes()).unwrap();
        assert_eq!(k.layout.pad_count, 24);
        assert_eq!(k.pads.len(), 4);
        assert_eq!(k.pads[3].kind, Some(PadKind::Loop));
        assert_eq!(k.pads[3].tempo.unwrap().beats, Some(16.0));
        assert!(k.extra.contains_key("futureField"));
        let back = KitJson::from_slice(&k.to_vec_pretty()).unwrap();
        assert_eq!(back, k);
    }

    #[test]
    fn rejects_future_major() {
        let src = r#"{"formatVersion":"2.0.0"}"#;
        assert!(KitJson::from_slice(src.as_bytes()).is_err());
    }
}
