//! DAWproject 1.0 的 serde 模型骨架（`project.xml` / `metadata.xml`）与最小导出。
//!
//! 只覆盖 v0.0.1 需要的子集：Application、Transport（Tempo/TimeSignature）、Structure（Track/Channel，
//! 含 BuiltinDevice/ClapPlugin/Vst3Plugin 与 State 文件引用、Mute/Pan/Volume）、Arrangement（Lanes/Clips/
//! Clip/Notes/Note/Audio）、Scenes（Scene + Lanes）、MetaData。元素顺序严格按 `Project.xsd` 的 sequence。
//! 官方 XSD 存放在 `content/schema/dawproject/`，测试中用 `xmllint --schema` 校验导出结果。

use serde::{Deserialize, Serialize};

use crate::kit::KitDoc;
use crate::{FormatError, Result};

pub const DAWPROJECT_VERSION: &str = "1.0";

fn xml_err(e: impl std::fmt::Display) -> FormatError {
    FormatError::Xml(e.to_string())
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename = "Project")]
pub struct Project {
    #[serde(rename = "@version")]
    pub version: String,
    #[serde(rename = "Application")]
    pub application: Application,
    #[serde(rename = "Transport", default, skip_serializing_if = "Option::is_none")]
    pub transport: Option<Transport>,
    #[serde(rename = "Structure", default, skip_serializing_if = "Option::is_none")]
    pub structure: Option<Structure>,
    #[serde(
        rename = "Arrangement",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub arrangement: Option<Arrangement>,
    #[serde(rename = "Scenes", default, skip_serializing_if = "Option::is_none")]
    pub scenes: Option<Scenes>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Application {
    #[serde(rename = "@name")]
    pub name: String,
    #[serde(rename = "@version")]
    pub version: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Transport {
    #[serde(rename = "Tempo", default, skip_serializing_if = "Option::is_none")]
    pub tempo: Option<RealParameter>,
    #[serde(
        rename = "TimeSignature",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub time_signature: Option<TimeSignatureParameter>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RealParameter {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "@max", default, skip_serializing_if = "Option::is_none")]
    pub max: Option<f64>,
    #[serde(rename = "@min", default, skip_serializing_if = "Option::is_none")]
    pub min: Option<f64>,
    /// `linear` | `normalized` | `percent` | `decibel` | `hertz` | `semitones` | `seconds` | `beats` | `bpm`
    #[serde(rename = "@unit")]
    pub unit: String,
    #[serde(rename = "@value", default, skip_serializing_if = "Option::is_none")]
    pub value: Option<f64>,
}

impl RealParameter {
    pub fn new(id: &str, unit: &str, value: f64) -> Self {
        Self {
            id: Some(id.into()),
            name: None,
            max: None,
            min: None,
            unit: unit.into(),
            value: Some(value),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BoolParameter {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "@value", default, skip_serializing_if = "Option::is_none")]
    pub value: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TimeSignatureParameter {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@denominator")]
    pub denominator: u32,
    #[serde(rename = "@numerator")]
    pub numerator: u32,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct Structure {
    #[serde(rename = "$value", default)]
    pub items: Vec<StructureItem>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum StructureItem {
    Track(Track),
    Channel(Channel),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Track {
    #[serde(rename = "@id")]
    pub id: String,
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "@color", default, skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    /// 空格分隔的 contentType 列表（audio/automation/notes/video/markers/tracks）。
    #[serde(
        rename = "@contentType",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub content_type: Option<String>,
    #[serde(rename = "@loaded", default, skip_serializing_if = "Option::is_none")]
    pub loaded: Option<bool>,
    #[serde(rename = "Channel", default, skip_serializing_if = "Option::is_none")]
    pub channel: Option<Channel>,
    #[serde(rename = "Track", default, skip_serializing_if = "Vec::is_empty")]
    pub tracks: Vec<Track>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Channel {
    #[serde(rename = "@id")]
    pub id: String,
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(
        rename = "@audioChannels",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub audio_channels: Option<u32>,
    #[serde(
        rename = "@destination",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub destination: Option<String>,
    /// `regular` | `master` | `effect` | `submix` | `vca`
    #[serde(rename = "@role", default, skip_serializing_if = "Option::is_none")]
    pub role: Option<String>,
    #[serde(rename = "@solo", default, skip_serializing_if = "Option::is_none")]
    pub solo: Option<bool>,
    #[serde(rename = "Devices", default, skip_serializing_if = "Option::is_none")]
    pub devices: Option<Devices>,
    #[serde(rename = "Mute", default, skip_serializing_if = "Option::is_none")]
    pub mute: Option<BoolParameter>,
    #[serde(rename = "Pan", default, skip_serializing_if = "Option::is_none")]
    pub pan: Option<RealParameter>,
    #[serde(rename = "Volume", default, skip_serializing_if = "Option::is_none")]
    pub volume: Option<RealParameter>,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct Devices {
    #[serde(rename = "$value", default)]
    pub items: Vec<DeviceItem>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum DeviceItem {
    BuiltinDevice(Device),
    ClapPlugin(Device),
    Vst3Plugin(Device),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Device {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "@deviceID", default, skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
    #[serde(rename = "@deviceName")]
    pub device_name: String,
    /// `instrument` | `noteFX` | `audioFX` | `analyzer`
    #[serde(rename = "@deviceRole")]
    pub device_role: String,
    #[serde(
        rename = "@deviceVendor",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub device_vendor: Option<String>,
    #[serde(rename = "@loaded", default, skip_serializing_if = "Option::is_none")]
    pub loaded: Option<bool>,
    /// 仅插件（ClapPlugin/Vst3Plugin）可用。
    #[serde(
        rename = "@pluginVersion",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub plugin_version: Option<String>,
    #[serde(rename = "Enabled", default, skip_serializing_if = "Option::is_none")]
    pub enabled: Option<BoolParameter>,
    #[serde(rename = "State", default, skip_serializing_if = "Option::is_none")]
    pub state: Option<FileReference>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FileReference {
    #[serde(rename = "@path")]
    pub path: String,
    #[serde(rename = "@external", default, skip_serializing_if = "Option::is_none")]
    pub external: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Arrangement {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "Lanes", default, skip_serializing_if = "Option::is_none")]
    pub lanes: Option<Lanes>,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct Lanes {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@timeUnit", default, skip_serializing_if = "Option::is_none")]
    pub time_unit: Option<String>,
    #[serde(rename = "@track", default, skip_serializing_if = "Option::is_none")]
    pub track: Option<String>,
    #[serde(rename = "$value", default)]
    pub items: Vec<LaneItem>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum LaneItem {
    Lanes(Lanes),
    Notes(Notes),
    Clips(Clips),
    ClipSlot(Box<ClipSlot>),
    Audio(Audio),
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct Clips {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@track", default, skip_serializing_if = "Option::is_none")]
    pub track: Option<String>,
    #[serde(rename = "Clip", default)]
    pub clips: Vec<Clip>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Clip {
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "@color", default, skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    #[serde(rename = "@time")]
    pub time: f64,
    #[serde(rename = "@duration", default, skip_serializing_if = "Option::is_none")]
    pub duration: Option<f64>,
    #[serde(
        rename = "@contentTimeUnit",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub content_time_unit: Option<String>,
    #[serde(
        rename = "@playStart",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub play_start: Option<f64>,
    #[serde(
        rename = "@loopStart",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub loop_start: Option<f64>,
    #[serde(rename = "@loopEnd", default, skip_serializing_if = "Option::is_none")]
    pub loop_end: Option<f64>,
    #[serde(
        rename = "@reference",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub reference: Option<String>,
    #[serde(rename = "$value", default, skip_serializing_if = "Option::is_none")]
    pub content: Option<ClipContent>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ClipContent {
    Notes(Notes),
    Audio(Audio),
    Lanes(Lanes),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ClipSlot {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@track", default, skip_serializing_if = "Option::is_none")]
    pub track: Option<String>,
    #[serde(rename = "@hasStop", default, skip_serializing_if = "Option::is_none")]
    pub has_stop: Option<bool>,
    #[serde(rename = "Clip", default, skip_serializing_if = "Option::is_none")]
    pub clip: Option<Clip>,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct Notes {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@track", default, skip_serializing_if = "Option::is_none")]
    pub track: Option<String>,
    #[serde(rename = "Note", default)]
    pub notes: Vec<Note>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Note {
    #[serde(rename = "@time")]
    pub time: f64,
    #[serde(rename = "@duration")]
    pub duration: f64,
    #[serde(rename = "@channel")]
    pub channel: u8,
    #[serde(rename = "@key")]
    pub key: u8,
    /// 0..=1
    #[serde(rename = "@vel", default, skip_serializing_if = "Option::is_none")]
    pub vel: Option<f64>,
    #[serde(rename = "@rel", default, skip_serializing_if = "Option::is_none")]
    pub rel: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Audio {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@duration")]
    pub duration: f64,
    #[serde(
        rename = "@algorithm",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub algorithm: Option<String>,
    #[serde(rename = "@channels")]
    pub channels: u32,
    #[serde(rename = "@sampleRate")]
    pub sample_rate: u32,
    #[serde(rename = "File")]
    pub file: FileReference,
}

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct Scenes {
    #[serde(rename = "Scene", default)]
    pub scenes: Vec<Scene>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Scene {
    #[serde(rename = "@id", default, skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(rename = "@name", default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(rename = "Lanes")]
    pub lanes: Lanes,
}

/// `metadata.xml`。
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename = "MetaData")]
pub struct MetaData {
    #[serde(rename = "Title", default, skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(rename = "Artist", default, skip_serializing_if = "Option::is_none")]
    pub artist: Option<String>,
    #[serde(rename = "Album", default, skip_serializing_if = "Option::is_none")]
    pub album: Option<String>,
    #[serde(
        rename = "OriginalArtist",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub original_artist: Option<String>,
    #[serde(rename = "Composer", default, skip_serializing_if = "Option::is_none")]
    pub composer: Option<String>,
    #[serde(
        rename = "Songwriter",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub songwriter: Option<String>,
    #[serde(rename = "Producer", default, skip_serializing_if = "Option::is_none")]
    pub producer: Option<String>,
    #[serde(rename = "Arranger", default, skip_serializing_if = "Option::is_none")]
    pub arranger: Option<String>,
    #[serde(rename = "Year", default, skip_serializing_if = "Option::is_none")]
    pub year: Option<String>,
    #[serde(rename = "Genre", default, skip_serializing_if = "Option::is_none")]
    pub genre: Option<String>,
    #[serde(rename = "Copyright", default, skip_serializing_if = "Option::is_none")]
    pub copyright: Option<String>,
    #[serde(rename = "Website", default, skip_serializing_if = "Option::is_none")]
    pub website: Option<String>,
    #[serde(rename = "Comment", default, skip_serializing_if = "Option::is_none")]
    pub comment: Option<String>,
}

const XML_DECL: &str = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

fn to_xml<T: Serialize>(value: &T) -> Result<String> {
    let mut body = String::new();
    let mut ser = quick_xml::se::Serializer::new(&mut body);
    ser.indent(' ', 2);
    value.serialize(ser).map_err(xml_err)?;
    let mut out = String::with_capacity(body.len() + XML_DECL.len() + 1);
    out.push_str(XML_DECL);
    out.push_str(&body);
    out.push('\n');
    Ok(out)
}

impl Project {
    pub fn to_xml(&self) -> Result<String> {
        to_xml(self)
    }
    pub fn from_xml(xml: &str) -> Result<Self> {
        quick_xml::de::from_str(xml).map_err(xml_err)
    }
}

impl MetaData {
    pub fn to_xml(&self) -> Result<String> {
        to_xml(self)
    }
    pub fn from_xml(xml: &str) -> Result<Self> {
        quick_xml::de::from_str(xml).map_err(xml_err)
    }
}

/// 导出的两份 XML。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DawProjectXml {
    pub project_xml: String,
    pub metadata_xml: String,
}

/// pattern 中的一个音符（以拍为单位）。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PatternNote {
    pub beat: f64,
    pub duration: f64,
    pub key: u8,
    /// 0..=1
    pub velocity: f64,
}

/// Kit 导出选项。
#[derive(Debug, Clone)]
pub struct KitExportOptions {
    /// Kit 在 `.dawproject` ZIP 中的路径（`BuiltinDevice/State@path`），如 `kits/808-street.upkit`。
    pub kit_state_path: String,
    pub application_version: String,
    /// 可选 pattern：导出为 Arrangement 中的一个 note clip。
    pub pattern: Vec<PatternNote>,
    /// pattern clip 的长度（拍）；为 0 时按音符末尾向上取整到小节。
    pub pattern_length_beats: f64,
}

impl Default for KitExportOptions {
    fn default() -> Self {
        Self {
            kit_state_path: "kits/kit.upkit".into(),
            application_version: env!("CARGO_PKG_VERSION").into(),
            pattern: Vec::new(),
            pattern_length_beats: 0.0,
        }
    }
}

fn transport(bpm: f64, ts: [u8; 2]) -> Transport {
    Transport {
        tempo: Some(RealParameter {
            min: Some(20.0),
            max: Some(999.0),
            ..RealParameter::new("tempo", "bpm", bpm)
        }),
        time_signature: Some(TimeSignatureParameter {
            id: Some("ts".into()),
            numerator: u32::from(ts[0]),
            denominator: u32::from(ts[1]),
        }),
    }
}

fn master_track() -> Track {
    Track {
        id: "trk_master".into(),
        name: Some("Master".into()),
        color: None,
        content_type: Some("audio notes".into()),
        loaded: Some(true),
        channel: Some(Channel {
            id: "ch_master".into(),
            name: Some("Master".into()),
            audio_channels: Some(2),
            destination: None,
            role: Some("master".into()),
            solo: None,
            devices: None,
            mute: Some(BoolParameter {
                id: Some("mute_master".into()),
                name: None,
                value: Some(false),
            }),
            pan: Some(RealParameter::new("pan_master", "normalized", 0.5)),
            volume: Some(RealParameter::new("vol_master", "linear", 1.0)),
        }),
        tracks: Vec::new(),
    }
}

/// 把 Kit 导出为最小可用的 DAWproject：一条 notes 轨（BuiltinDevice 引用嵌入的 `.upkit`）+ Master，
/// 可选一个 pattern clip。
pub fn export_kit_project(doc: &KitDoc, options: &KitExportOptions) -> Result<DawProjectXml> {
    let tempo = doc.tempo.map(|t| t.bpm).unwrap_or(120.0);
    let ts = doc.tempo.map(|t| t.time_signature).unwrap_or([4, 4]);
    let kit_track = Track {
        id: "trk_kit".into(),
        name: Some(doc.name.clone()),
        color: doc.pads.first().map(|p| p.color.to_hex()),
        content_type: Some("notes".into()),
        loaded: Some(true),
        channel: Some(Channel {
            id: "ch_kit".into(),
            name: Some(doc.name.clone()),
            audio_channels: Some(2),
            destination: Some("ch_master".into()),
            role: Some("regular".into()),
            solo: None,
            devices: Some(Devices {
                items: vec![DeviceItem::BuiltinDevice(Device {
                    id: Some("dev_kit".into()),
                    name: Some(doc.name.clone()),
                    device_id: Some("dev.ultrapads.kit".into()),
                    device_name: "UltraPads Kit".into(),
                    device_role: "instrument".into(),
                    device_vendor: Some("UltraPads".into()),
                    loaded: Some(true),
                    plugin_version: None,
                    enabled: None,
                    state: Some(FileReference {
                        path: options.kit_state_path.clone(),
                        external: None,
                    }),
                })],
            }),
            mute: Some(BoolParameter {
                id: Some("mute_kit".into()),
                name: None,
                value: Some(false),
            }),
            pan: Some(RealParameter::new("pan_kit", "normalized", 0.5)),
            volume: Some(RealParameter::new("vol_kit", "linear", 1.0)),
        }),
        tracks: Vec::new(),
    };
    let mut track_lanes = Lanes {
        id: Some("lane_kit".into()),
        time_unit: None,
        track: Some("trk_kit".into()),
        items: Vec::new(),
    };
    if !options.pattern.is_empty() {
        let bar = f64::from(ts[0].max(1));
        let end = options
            .pattern
            .iter()
            .map(|n| n.beat + n.duration)
            .fold(0.0, f64::max);
        let len = if options.pattern_length_beats > 0.0 {
            options.pattern_length_beats
        } else {
            (end / bar).ceil().max(1.0) * bar
        };
        track_lanes.items.push(LaneItem::Clips(Clips {
            id: Some("clips_kit".into()),
            track: None,
            clips: vec![Clip {
                name: Some("Pattern 1".into()),
                color: None,
                time: 0.0,
                duration: Some(len),
                content_time_unit: None,
                play_start: Some(0.0),
                loop_start: None,
                loop_end: None,
                reference: None,
                content: Some(ClipContent::Notes(Notes {
                    id: Some("notes_p1".into()),
                    track: None,
                    notes: options
                        .pattern
                        .iter()
                        .map(|n| Note {
                            time: n.beat,
                            duration: n.duration,
                            channel: 0,
                            key: n.key,
                            vel: Some(n.velocity.clamp(0.0, 1.0)),
                            rel: None,
                        })
                        .collect(),
                })),
            }],
        }));
    }
    let project = Project {
        version: DAWPROJECT_VERSION.into(),
        application: Application {
            name: "UltraPads".into(),
            version: options.application_version.clone(),
        },
        transport: Some(transport(tempo, ts)),
        structure: Some(Structure {
            items: vec![
                StructureItem::Track(kit_track),
                StructureItem::Track(master_track()),
            ],
        }),
        arrangement: Some(Arrangement {
            id: Some("arr".into()),
            lanes: Some(Lanes {
                id: Some("arr_lanes".into()),
                time_unit: Some("beats".into()),
                track: None,
                items: vec![LaneItem::Lanes(track_lanes)],
            }),
        }),
        scenes: None,
    };
    let meta = MetaData {
        title: Some(doc.name.clone()),
        artist: (!doc.authors.is_empty()).then(|| doc.authors.join(", ")),
        genre: doc.genres.first().cloned(),
        copyright: doc.license.clone(),
        comment: doc.description.clone(),
        ..MetaData::default()
    };
    Ok(DawProjectXml {
        project_xml: project.to_xml()?,
        metadata_xml: meta.to_xml()?,
    })
}

/// 录音作品导出选项。
#[derive(Debug, Clone)]
pub struct AudioTrackExport {
    pub name: String,
    /// 音频在 `.dawproject` ZIP 中的路径，如 `audio/take-1.wav`。
    pub audio_path: String,
    pub duration_secs: f64,
    pub sample_rate: u32,
    pub channels: u32,
    pub bpm: f64,
    pub application_version: String,
}

/// 把一条录音作品导出为 DAWproject：一条 audio 轨 + 一个引用音频文件的 clip。
pub fn export_audio_track_project(t: &AudioTrackExport) -> Result<DawProjectXml> {
    let track = Track {
        id: "trk_audio".into(),
        name: Some(t.name.clone()),
        color: None,
        content_type: Some("audio".into()),
        loaded: Some(true),
        channel: Some(Channel {
            id: "ch_audio".into(),
            name: Some(t.name.clone()),
            audio_channels: Some(t.channels),
            destination: Some("ch_master".into()),
            role: Some("regular".into()),
            solo: None,
            devices: None,
            mute: None,
            pan: Some(RealParameter::new("pan_audio", "normalized", 0.5)),
            volume: Some(RealParameter::new("vol_audio", "linear", 1.0)),
        }),
        tracks: Vec::new(),
    };
    let clip = Clip {
        name: Some(t.name.clone()),
        color: None,
        time: 0.0,
        duration: Some(t.duration_secs),
        content_time_unit: Some("seconds".into()),
        play_start: Some(0.0),
        loop_start: None,
        loop_end: None,
        reference: None,
        content: Some(ClipContent::Audio(Audio {
            id: Some("audio_1".into()),
            duration: t.duration_secs,
            algorithm: None,
            channels: t.channels,
            sample_rate: t.sample_rate,
            file: FileReference {
                path: t.audio_path.clone(),
                external: Some(false),
            },
        })),
    };
    let project = Project {
        version: DAWPROJECT_VERSION.into(),
        application: Application {
            name: "UltraPads".into(),
            version: t.application_version.clone(),
        },
        transport: Some(transport(t.bpm, [4, 4])),
        structure: Some(Structure {
            items: vec![
                StructureItem::Track(track),
                StructureItem::Track(master_track()),
            ],
        }),
        arrangement: Some(Arrangement {
            id: Some("arr".into()),
            lanes: Some(Lanes {
                id: Some("arr_lanes".into()),
                time_unit: Some("seconds".into()),
                track: None,
                items: vec![LaneItem::Lanes(Lanes {
                    id: Some("lane_audio".into()),
                    time_unit: None,
                    track: Some("trk_audio".into()),
                    items: vec![LaneItem::Clips(Clips {
                        id: Some("clips_audio".into()),
                        track: None,
                        clips: vec![clip],
                    })],
                })],
            }),
        }),
        scenes: None,
    };
    let meta = MetaData {
        title: Some(t.name.clone()),
        ..MetaData::default()
    };
    Ok(DawProjectXml {
        project_xml: project.to_xml()?,
        metadata_xml: meta.to_xml()?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kit::{PadAddr, PadDoc, SampleLayer};

    fn kit() -> KitDoc {
        let mut k = KitDoc::new("id", "808 Street & <Friends>");
        k.authors = vec!["A".into()];
        k.genres = vec!["hip-hop".into()];
        let mut p = PadDoc::new(PadAddr::from_flat(0));
        p.layers.push(SampleLayer::new("samples/kick.wav"));
        k.pads.push(p);
        k
    }

    fn pattern() -> Vec<PatternNote> {
        vec![
            PatternNote {
                beat: 0.0,
                duration: 0.25,
                key: 36,
                velocity: 0.9,
            },
            PatternNote {
                beat: 1.0,
                duration: 0.25,
                key: 42,
                velocity: 0.7,
            },
        ]
    }

    #[test]
    fn kit_project_roundtrips_through_serde() {
        let xml = export_kit_project(
            &kit(),
            &KitExportOptions {
                pattern: pattern(),
                ..KitExportOptions::default()
            },
        )
        .unwrap();
        assert!(xml.project_xml.starts_with("<?xml"));
        assert!(xml.project_xml.contains("<BuiltinDevice"));
        assert!(xml.project_xml.contains("&amp; &lt;Friends&gt;"));
        let p = Project::from_xml(&xml.project_xml).unwrap();
        assert_eq!(p.version, "1.0");
        assert_eq!(p.structure.as_ref().unwrap().items.len(), 2);
        assert_eq!(Project::from_xml(&p.to_xml().unwrap()).unwrap(), p);
        let m = MetaData::from_xml(&xml.metadata_xml).unwrap();
        assert_eq!(m.genre.as_deref(), Some("hip-hop"));
    }

    /// 用官方 XSD（content/schema/dawproject/）校验导出结果。需要 `xmllint`（libxml2-utils）。
    #[test]
    fn exported_xml_validates_against_official_xsd() {
        let schema_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../content/schema/dawproject");
        let project_xsd = schema_dir.join("Project.xsd");
        let meta_xsd = schema_dir.join("MetaData.xsd");
        assert!(
            project_xsd.exists(),
            "缺少官方 XSD：{}",
            project_xsd.display()
        );
        if std::process::Command::new("xmllint")
            .arg("--version")
            .output()
            .is_err()
        {
            eprintln!("跳过：未安装 xmllint，无法做 XSD 校验");
            return;
        }
        let dir = std::env::temp_dir().join(format!("up-format-xsd-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let cases = [
            (
                "kit",
                export_kit_project(
                    &kit(),
                    &KitExportOptions {
                        pattern: pattern(),
                        ..KitExportOptions::default()
                    },
                )
                .unwrap(),
            ),
            (
                "kit_empty",
                export_kit_project(&kit(), &KitExportOptions::default()).unwrap(),
            ),
            (
                "audio",
                export_audio_track_project(&AudioTrackExport {
                    name: "Take 1".into(),
                    audio_path: "audio/take-1.wav".into(),
                    duration_secs: 12.5,
                    sample_rate: 48_000,
                    channels: 2,
                    bpm: 92.0,
                    application_version: "0.0.1".into(),
                })
                .unwrap(),
            ),
        ];
        for (name, xml) in cases {
            for (file, body, xsd) in [
                ("project.xml", &xml.project_xml, &project_xsd),
                ("metadata.xml", &xml.metadata_xml, &meta_xsd),
            ] {
                let path = dir.join(format!("{name}-{file}"));
                std::fs::write(&path, body).unwrap();
                let out = std::process::Command::new("xmllint")
                    .arg("--noout")
                    .arg("--schema")
                    .arg(xsd)
                    .arg(&path)
                    .output()
                    .unwrap();
                assert!(
                    out.status.success(),
                    "{name}/{file} 未通过 XSD 校验：\n{}\n{body}",
                    String::from_utf8_lossy(&out.stderr)
                );
            }
        }
        let _ = std::fs::remove_dir_all(&dir);
    }
}
