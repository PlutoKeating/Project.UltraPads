//! UltraPads 纯格式层。
//!
//! 本 crate 不做任何文件系统、网络或设备 I/O：所有输入输出都是字节、字符串或调用方提供的回调。
//! 文件读写、ZIP 解包、内容寻址存储由 `runtime/up-library` 负责。
//!
//! 模块一览：
//! - [`sfz`]：SFZ 解析（`#define`/`#include` 由调用方解析）、opcode 白名单（UltraPads SFZ Profile）、序列化
//! - [`kit_json`]：`ultrapads-kit.json` 的 serde 模型
//! - [`manifest`]：`manifest.json` 的 serde 模型与 BLAKE3 校验
//! - [`tutorial`]：`tutorials/<id>/tutorial.json` 的 serde 模型
//! - [`wav`]：WAV/RIFF 解析、`smpl`/`acid`/`inst`/`cue `/`bext` 元数据 chunk 读写、PCM 编解码
//! - [`smf`]：最小 Standard MIDI File 读写（教程谱 `chart.mid`）
//! - [`kit`]：Kit 的逻辑文档 [`kit::KitDoc`]（`up-model` 尚未提供 Kit 类型前的适配层）
//! - [`upkit`]：`.upkit` 包的逻辑模型，以及 `KitDoc` ↔ `kit.sfz` + `ultrapads-kit.json` + `manifest.json` 的映射
//! - [`dawproject`]：DAWproject 1.0 `project.xml` / `metadata.xml` 的 serde 模型骨架与最小导出
//! - [`path`]：包内相对路径规范化（防路径穿越）

pub mod dawproject;
pub mod kit;
pub mod kit_json;
pub mod manifest;
pub mod model;
pub mod path;
pub mod sfz;
pub mod smf;
pub mod tutorial;
pub mod upkit;
pub mod wav;

/// `.upkit` 首条目 `mimetype` 的内容。
pub const UPKIT_MEDIA_TYPE: &str = "application/vnd.ultrapads.kit+zip";
/// `.ultrapads` 项目包的 mimetype。
pub const PROJECT_MEDIA_TYPE: &str = "application/vnd.ultrapads.project+zip";
/// 本 crate 写出的格式版本（`formatVersion`）。
pub const FORMAT_VERSION: &str = "1.0.0";
/// 本 crate 支持读取的最高 major 版本。
pub const SUPPORTED_FORMAT_MAJOR: u64 = 1;

/// 格式层统一错误。
#[derive(Debug, thiserror::Error)]
pub enum FormatError {
    #[error("SFZ 解析错误（第 {line} 行）：{message}")]
    Sfz { line: usize, message: String },
    #[error("SFZ #include 失败：{0}")]
    Include(String),
    #[error("JSON 错误（{context}）：{source}")]
    Json {
        context: String,
        #[source]
        source: serde_json::Error,
    },
    #[error("XML 错误：{0}")]
    Xml(String),
    #[error("WAV 错误：{0}")]
    Wav(String),
    #[error("MIDI 错误：{0}")]
    Midi(String),
    #[error("非法包内路径 `{path}`：{reason}")]
    UnsafePath { path: String, reason: &'static str },
    #[error("文件 `{path}` 哈希不匹配：期望 {expected}，实际 {actual}")]
    HashMismatch {
        path: String,
        expected: String,
        actual: String,
    },
    #[error("文件 `{path}` 大小不匹配：期望 {expected}，实际 {actual}")]
    SizeMismatch {
        path: String,
        expected: u64,
        actual: u64,
    },
    #[error("缺少必需文件：{0}")]
    MissingFile(String),
    #[error("不支持的格式版本 {found}（支持的最高 major 为 {supported}）")]
    UnsupportedVersion { found: String, supported: u64 },
    #[error("Kit 数据无效：{0}")]
    InvalidKit(String),
}

pub type Result<T, E = FormatError> = std::result::Result<T, E>;

impl FormatError {
    pub(crate) fn json(context: impl Into<String>, source: serde_json::Error) -> Self {
        Self::Json {
            context: context.into(),
            source,
        }
    }
}

/// 计算字节的 BLAKE3 十六进制摘要（小写，64 字符）。
pub fn blake3_hex(bytes: &[u8]) -> String {
    blake3::hash(bytes).to_hex().to_string()
}

/// 检查 `formatVersion` 的 major 是否受支持。缺省或无法解析的版本视为 1.x。
pub fn check_format_version(version: &str) -> Result<()> {
    let major = version
        .split('.')
        .next()
        .and_then(|m| m.trim().parse::<u64>().ok())
        .unwrap_or(1);
    if major > SUPPORTED_FORMAT_MAJOR {
        return Err(FormatError::UnsupportedVersion {
            found: version.to_string(),
            supported: SUPPORTED_FORMAT_MAJOR,
        });
    }
    Ok(())
}

/// 加载/转换过程中的非致命问题。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct Warning {
    /// 机器可读的类别，例如 `sfz.unknown_opcode`。
    pub code: String,
    pub message: String,
}

impl Warning {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
        }
    }
}

impl std::fmt::Display for Warning {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{}] {}", self.code, self.message)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_gate() {
        assert!(check_format_version("1.0.0").is_ok());
        assert!(check_format_version("1.9").is_ok());
        assert!(check_format_version("").is_ok());
        assert!(check_format_version("2.0.0").is_err());
    }
}
