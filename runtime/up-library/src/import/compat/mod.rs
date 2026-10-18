//! 私有素材包导入器（可插拔、多来源）。
//!
//! 每个来源实现 [`CompatSource`]：探测输入是否属于该来源，然后把其中的 Kit 逐个交给回调入库，
//! 并返回外部目录（分类/曲目元数据，没有音频的条目标记为“未下载”）。
//!
//! 内置来源：
//! - [`mobile::AndroidSource`]（`compat-android`）：Android 格式 —— `Sounds/pad{N}_{preset}.wav`、
//!   `<Kit>.txt`（JSON）、`initialpack.zip`/`Sounds.zip`、`list.json`、按顺序的教程 `sequence`
//! - [`mobile::IosSource`]（`compat-ios`）：iOS 格式 —— `Sounds/pad{N}_{preset}.ogg`（入库时转 WAV）、
//!   同结构 JSON、`initial/sp/<id>.zip`/`kit.zip`/`Sounds_OGG.zip`、`fetch.json`/`fetch_next.json`、
//!   计时教程 `tutorial.json` 与分课 `<id>_lesson.json`

pub mod mobile;

use std::collections::BTreeMap;

use up_format::Warning;
use up_format::kit::KitDoc;

use crate::archive::{ImportLimits, SourceFs};
use crate::error::Result;
use crate::index::Catalog;

/// 来源交给曲库入库的一个 Kit。
#[derive(Debug, Clone)]
pub struct CompatKit {
    pub doc: KitDoc,
    /// 包内路径 → 字节（采样、教程等）。
    pub assets: BTreeMap<String, Vec<u8>>,
    /// 对应的外部目录条目 ID（`<source>:<原 ID>`），用于把目录条目标记为“已下载”。
    pub catalog_id: Option<String>,
}

/// 扫描结果。
#[derive(Debug, Clone, Default)]
pub struct CompatScan {
    pub catalog: Option<Catalog>,
    pub warnings: Vec<Warning>,
}

/// 私有素材包来源。
pub trait CompatSource: Send + Sync {
    /// 来源 ID（同时是 KitSource.kind 与目录条目的 source）。
    fn id(&self) -> &'static str;
    /// 输入是否属于该来源（应当便宜：只看文件名，必要时读小文件）。
    fn detect(&self, fs: &dyn SourceFs) -> bool;
    /// 导入：每找到一个 Kit 调一次 `emit`。
    fn import(
        &self,
        fs: &dyn SourceFs,
        limits: &ImportLimits,
        emit: &mut dyn FnMut(CompatKit) -> Result<()>,
    ) -> Result<CompatScan>;
}

/// 内置来源（按探测顺序）。
pub fn builtin_sources() -> Vec<Box<dyn CompatSource>> {
    vec![Box::new(mobile::IosSource), Box::new(mobile::AndroidSource)]
}
