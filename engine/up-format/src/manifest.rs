//! `manifest.json`：包元数据 + 每个文件的 BLAKE3 和大小。
//!
//! JSON Schema 见 `content/schema/manifest-1.schema.json`。

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

use crate::kit::KitSource;
use crate::{FormatError, Result};

pub const FILE_NAME: &str = "manifest.json";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileEntry {
    pub path: String,
    pub size: u64,
    pub blake3: String,
    #[serde(default = "default_media")]
    pub media_type: String,
}

fn default_media() -> String {
    "application/octet-stream".into()
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Manifest {
    pub media_type: String,
    pub format_version: String,
    pub id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(default)]
    pub authors: Vec<String>,
    /// SPDX 许可证标识（内容许可，与代码许可分离）。
    #[serde(default = "default_license")]
    pub license: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub generator: Option<String>,
    /// RFC 3339 时间。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub created: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub updated: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub genres: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source: Option<KitSource>,
    #[serde(default)]
    pub files: Vec<FileEntry>,
    #[serde(flatten)]
    pub extra: Map<String, Value>,
}

fn default_license() -> String {
    "NOASSERTION".into()
}

impl Manifest {
    pub fn new(id: impl Into<String>, name: impl Into<String>) -> Self {
        Self {
            media_type: crate::UPKIT_MEDIA_TYPE.into(),
            format_version: crate::FORMAT_VERSION.into(),
            id: id.into(),
            name: name.into(),
            description: None,
            authors: Vec::new(),
            license: default_license(),
            generator: Some(concat!("UltraPads up-format ", env!("CARGO_PKG_VERSION")).into()),
            created: None,
            updated: None,
            genres: Vec::new(),
            tags: Vec::new(),
            source: None,
            files: Vec::new(),
            extra: Map::new(),
        }
    }

    pub fn from_slice(bytes: &[u8]) -> Result<Self> {
        let m: Self = serde_json::from_slice(bytes).map_err(|e| FormatError::json(FILE_NAME, e))?;
        crate::check_format_version(&m.format_version)?;
        for f in &m.files {
            crate::path::normalize(&f.path)?;
            if f.blake3.len() != 64 || !f.blake3.bytes().all(|b| b.is_ascii_hexdigit()) {
                return Err(FormatError::InvalidKit(format!(
                    "manifest 中 `{}` 的 blake3 格式无效",
                    f.path
                )));
            }
        }
        Ok(m)
    }

    pub fn to_vec_pretty(&self) -> Vec<u8> {
        let mut v = serde_json::to_vec_pretty(self).expect("Manifest 序列化不会失败");
        v.push(b'\n');
        v
    }

    pub fn find(&self, path: &str) -> Option<&FileEntry> {
        self.files.iter().find(|f| f.path == path)
    }

    /// 由文件内容构造条目（路径会被规范化）。
    pub fn entry_for(path: &str, bytes: &[u8]) -> Result<FileEntry> {
        let path = crate::path::normalize(path)?;
        Ok(FileEntry {
            media_type: crate::path::media_type_for(&path).into(),
            size: bytes.len() as u64,
            blake3: crate::blake3_hex(bytes),
            path,
        })
    }

    /// 插入或替换条目，并按路径排序。
    pub fn upsert(&mut self, entry: FileEntry) {
        self.files.retain(|f| f.path != entry.path);
        self.files.push(entry);
        self.files.sort_by(|a, b| a.path.cmp(&b.path));
    }

    /// 校验文件内容与 manifest 记录一致。未登记的文件返回 `Ok(false)`。
    pub fn verify(&self, path: &str, bytes: &[u8]) -> Result<bool> {
        let Some(entry) = self.find(path) else {
            return Ok(false);
        };
        if entry.size != bytes.len() as u64 {
            return Err(FormatError::SizeMismatch {
                path: path.into(),
                expected: entry.size,
                actual: bytes.len() as u64,
            });
        }
        let actual = crate::blake3_hex(bytes);
        if !actual.eq_ignore_ascii_case(&entry.blake3) {
            return Err(FormatError::HashMismatch {
                path: path.into(),
                expected: entry.blake3.clone(),
                actual,
            });
        }
        Ok(true)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verify_detects_tampering() {
        let mut m = Manifest::new("urn:uuid:x", "Kit");
        m.upsert(Manifest::entry_for("samples/a.wav", b"abc").unwrap());
        assert!(m.verify("samples/a.wav", b"abc").unwrap());
        assert!(!m.verify("samples/b.wav", b"abc").unwrap());
        assert!(matches!(
            m.verify("samples/a.wav", b"abd"),
            Err(FormatError::HashMismatch { .. })
        ));
        assert!(matches!(
            m.verify("samples/a.wav", b"abcd"),
            Err(FormatError::SizeMismatch { .. })
        ));
        let back = Manifest::from_slice(&m.to_vec_pretty()).unwrap();
        assert_eq!(back, m);
    }

    #[test]
    fn rejects_unsafe_paths_in_manifest() {
        let src = format!(
            r#"{{"mediaType":"x","formatVersion":"1.0.0","id":"a","name":"b","files":[{{"path":"../x","size":1,"blake3":"{}"}}]}}"#,
            "0".repeat(64)
        );
        assert!(Manifest::from_slice(src.as_bytes()).is_err());
    }
}
