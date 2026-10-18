//! `tutorials/<id>/tutorial.json`：教程说明，配合 `chart.mid`。
//!
//! 两种模式：
//! - `timed`：按小节/时间的教程（规格 §6.2），谱面时刻来自 `chart.mid`
//! - `sequence`：只规定按键顺序、不计时（私有素材包的教程），每一步列出要同时按下的 pad 音符
//!
//! JSON Schema 见 `content/schema/tutorial-1.schema.json`。

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

use crate::{FormatError, Result};

pub const FILE_NAME: &str = "tutorial.json";

/// 多语言文本：BCP 47 语言标签 → 文本。
pub type LocalizedText = BTreeMap<String, String>;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TutorialMode {
    #[default]
    Timed,
    Sequence,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TutorialTempo {
    pub start: f64,
    pub target: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Judge {
    pub perfect_ms: u32,
    pub good_ms: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TutorialStep {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub from_bar: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub to_bar: Option<u32>,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub hint: LocalizedText,
    /// 本步要按的 pad 音符。
    #[serde(default)]
    pub pads: Vec<u8>,
    /// 本步要求所在的 bank（`A`/`B`）；切页步骤只有 bank 没有 pads。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub bank: Option<String>,
    #[serde(default, rename = "loop", skip_serializing_if = "std::ops::Not::not")]
    pub loop_: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TutorialDoc {
    pub id: String,
    #[serde(default)]
    pub title: LocalizedText,
    #[serde(default)]
    pub mode: TutorialMode,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub chart: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tempo: Option<TutorialTempo>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub judge: Option<Judge>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub video_url: Option<String>,
    #[serde(default)]
    pub steps: Vec<TutorialStep>,
    #[serde(flatten)]
    pub extra: Map<String, Value>,
}

impl TutorialDoc {
    pub fn from_slice(bytes: &[u8]) -> Result<Self> {
        serde_json::from_slice(bytes).map_err(|e| FormatError::json(FILE_NAME, e))
    }
    pub fn to_vec_pretty(&self) -> Vec<u8> {
        let mut v = serde_json::to_vec_pretty(self).expect("TutorialDoc 序列化不会失败");
        v.push(b'\n');
        v
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    pub(crate) const SPEC_EXAMPLE: &str = r#"{
  "id": "first-beat",
  "title": { "zh-CN": "你的第一个节拍", "en": "Your first beat" },
  "chart": "chart.mid",
  "tempo": { "start": 80, "target": 92 },
  "judge": { "perfectMs": 30, "goodMs": 80 },
  "steps": [
    { "fromBar": 1, "toBar": 2, "hint": { "zh-CN": "只按 Kick，跟着节拍器" }, "pads": [36] },
    { "fromBar": 3, "toBar": 4, "hint": { "zh-CN": "加入闭镲" }, "pads": [36, 42], "loop": true }
  ]
}"#;

    #[test]
    fn parses_spec_example() {
        let t = TutorialDoc::from_slice(SPEC_EXAMPLE.as_bytes()).unwrap();
        assert_eq!(t.mode, TutorialMode::Timed);
        assert_eq!(t.steps[1].pads, vec![36, 42]);
        assert!(t.steps[1].loop_);
        let back = TutorialDoc::from_slice(&t.to_vec_pretty()).unwrap();
        assert_eq!(back, t);
    }
}
