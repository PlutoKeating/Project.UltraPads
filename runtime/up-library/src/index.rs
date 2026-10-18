//! `library.json`：曲库索引（Kit/样本/录音作品摘要、收藏、最近使用、外部目录、删除墓碑）。
//!
//! JSON Schema 见 `content/schema/library-1.schema.json`。Kit 的完整内容在 `kits/<id>/manifest.json`
//! 与内容寻址存储中；索引只是可重建的缓存加用户状态（收藏/最近使用）。

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

pub const INDEX_FILE: &str = "library.json";
pub const INDEX_FORMAT_VERSION: &str = "1.0.0";

/// Kit 摘要（列表/搜索用，也是 FFI 的 `KitSummary`）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KitSummary {
    pub id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(default)]
    pub authors: Vec<String>,
    #[serde(default)]
    pub license: String,
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    pub pad_count: u8,
    /// 有声音的 pad 数。
    pub pads_used: u8,
    pub sample_count: u32,
    pub total_bytes: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub bpm: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub theme_color: Option<String>,
    /// 封面在内容寻址存储中的哈希。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cover_blob: Option<String>,
    pub has_tutorial: bool,
    /// 来源类别：`upkit` | `sfz` | `wav-folder` | `compat-android` | `generated` | `user` …
    pub source_kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub inspired_by: Option<String>,
    #[serde(default)]
    pub favorite: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub favorited_at_ms: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_used_at_ms: Option<i64>,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
    /// `kits/<id>/manifest.json` 的 BLAKE3（内容版本）。
    pub manifest_blake3: String,
    /// 除 manifest 外所有文件 (路径, 哈希) 的摘要，用于识别重复导入。
    pub content_blake3: String,
}

/// 样本来源。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SampleOrigin {
    /// 随 Kit 导入。
    Kit,
    /// 用户导入的单个文件。
    Import,
    /// 麦克风录音。
    Microphone,
    /// 由录音作品转成的样本。
    Track,
    /// 合成生成。
    Generated,
}

/// 独立样本记录（可被编辑器分配给 pad）。随 Kit 导入的采样不单独登记。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SampleRecord {
    /// BLAKE3 十六进制。
    pub id: String,
    pub name: String,
    pub origin: SampleOrigin,
    pub size: u64,
    pub media_type: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub frames: u64,
    pub created_at_ms: i64,
}

impl SampleRecord {
    pub fn duration_secs(&self) -> f64 {
        if self.sample_rate == 0 {
            0.0
        } else {
            self.frames as f64 / f64::from(self.sample_rate)
        }
    }
}

/// 录音作品（FFI 的 `TrackInfo`）。音频在 `tracks/<id>.wav`。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrackInfo {
    pub id: String,
    pub name: String,
    /// 音频的 BLAKE3。
    pub blob: String,
    pub size: u64,
    pub sample_rate: u32,
    pub channels: u16,
    pub duration_secs: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kit_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub bpm: Option<f64>,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

/// 外部目录条目的下载状态。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    tag = "state"
)]
pub enum CatalogStatus {
    /// 只有元数据，没有音频。
    NotDownloaded,
    /// 已导入为本地 Kit。
    Downloaded { kit_id: String },
}

/// 外部目录（如私有素材包的 `list.json`）中的一个 Kit 条目。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CatalogEntry {
    /// 全局唯一：`<source>:<原 ID>`。
    pub id: String,
    pub source: String,
    pub original_id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub inspired_by: Option<String>,
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub category_ids: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub theme_color: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub video_url: Option<String>,
    pub has_tutorial: bool,
    #[serde(default)]
    pub is_new: bool,
    #[serde(default)]
    pub is_top: bool,
    #[serde(default)]
    pub order: i64,
    /// 难度（新版目录的 `difficulty`，如 `easy`；空表示未标注）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub difficulty: Option<String>,
    /// 原目录的创建时间（RFC 3339）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    /// 原目录中其余字段（如 `isMP3`、`tutorialUpdateTime`、`lessonsUpdateTime`、`isAuthorial`），原样保留。
    #[serde(default, skip_serializing_if = "serde_json::Map::is_empty")]
    pub extra: serde_json::Map<String, serde_json::Value>,
    pub status: CatalogStatus,
}

/// 外部目录的分类。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CatalogCategory {
    pub id: String,
    pub source: String,
    pub name: String,
    pub order: i64,
    /// 原始类型码（私有素材包：100 = 大卡片，1/2/3 = feed 样式…）。
    pub kind: i64,
    /// 父分组（如 GENRES）。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub group_id: Option<String>,
    /// 该分类下的目录条目 ID（有序）。
    #[serde(default)]
    pub entries: Vec<String>,
}

/// 外部目录。
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Catalog {
    #[serde(default)]
    pub entries: BTreeMap<String, CatalogEntry>,
    #[serde(default)]
    pub categories: BTreeMap<String, CatalogCategory>,
}

/// `library.json` 根对象。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryIndex {
    pub format_version: String,
    #[serde(default)]
    pub kits: BTreeMap<String, KitSummary>,
    #[serde(default)]
    pub samples: BTreeMap<String, SampleRecord>,
    #[serde(default)]
    pub tracks: BTreeMap<String, TrackInfo>,
    #[serde(default)]
    pub catalog: Catalog,
    /// 本地删除的条目 ID → 删除时间（供同步传播删除）。
    #[serde(default)]
    pub tombstones: BTreeMap<String, i64>,
}

impl Default for LibraryIndex {
    fn default() -> Self {
        Self {
            format_version: INDEX_FORMAT_VERSION.into(),
            kits: BTreeMap::new(),
            samples: BTreeMap::new(),
            tracks: BTreeMap::new(),
            catalog: Catalog::default(),
            tombstones: BTreeMap::new(),
        }
    }
}

/// Kit 列表排序。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum KitSort {
    #[default]
    Name,
    RecentlyUsed,
    RecentlyAdded,
    Favorited,
}

/// Kit 列表查询。
#[derive(Debug, Clone, Default)]
pub struct KitQuery {
    /// 在名称/作者/曲风/标签/灵感来源中做大小写不敏感的子串匹配（空格分隔的词全部命中）。
    pub text: Option<String>,
    /// 曲风（大小写不敏感，精确匹配其一）。
    pub genre: Option<String>,
    pub favorites_only: bool,
    /// 只返回用过的 Kit（最近使用列表）。
    pub used_only: bool,
    pub sort: KitSort,
    pub limit: Option<usize>,
}

impl KitSummary {
    pub(crate) fn matches(&self, q: &KitQuery) -> bool {
        if q.favorites_only && !self.favorite {
            return false;
        }
        if q.used_only && self.last_used_at_ms.is_none() {
            return false;
        }
        if let Some(g) = &q.genre {
            if !self.genres.iter().any(|x| x.eq_ignore_ascii_case(g)) {
                return false;
            }
        }
        if let Some(t) = &q.text {
            let hay = format!(
                "{} {} {} {} {} {}",
                self.name,
                self.authors.join(" "),
                self.genres.join(" "),
                self.tags.join(" "),
                self.inspired_by.as_deref().unwrap_or(""),
                self.description.as_deref().unwrap_or("")
            )
            .to_lowercase();
            if !t
                .split_whitespace()
                .all(|w| hay.contains(&w.to_lowercase()))
            {
                return false;
            }
        }
        true
    }
}
