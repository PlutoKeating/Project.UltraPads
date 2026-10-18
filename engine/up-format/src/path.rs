//! 包内相对路径规范化。
//!
//! 规则（ZIP 条目名、manifest 路径、SFZ `sample=` 都适用）：
//! - 反斜杠视为分隔符（兼容 Windows 写出的 SFZ），统一转成 `/`
//! - 拒绝空路径、绝对路径（`/x`、`\x`、`C:x`）、`..` 组件、NUL 与控制字符
//! - 去掉 `.` 组件和重复分隔符
//! - 结果永远是不含前导 `/` 的相对路径

use crate::{FormatError, Result};

/// 单个路径的最大长度（字节）。
pub const MAX_PATH_LEN: usize = 1024;
/// 最大目录深度。
pub const MAX_PATH_DEPTH: usize = 16;

/// 规范化包内相对路径，拒绝任何可能逃逸出包根目录的写法。
pub fn normalize(raw: &str) -> Result<String> {
    let err = |reason| FormatError::UnsafePath {
        path: raw.to_string(),
        reason,
    };
    if raw.is_empty() {
        return Err(err("路径为空"));
    }
    if raw.len() > MAX_PATH_LEN {
        return Err(err("路径过长"));
    }
    if raw.chars().any(|c| c == '\0' || c.is_control()) {
        return Err(err("包含控制字符"));
    }
    let unified = raw.replace('\\', "/");
    if unified.starts_with('/') {
        return Err(err("绝对路径"));
    }
    let bytes = unified.as_bytes();
    if bytes.len() >= 2 && bytes[1] == b':' && bytes[0].is_ascii_alphabetic() {
        return Err(err("带盘符的路径"));
    }
    let mut parts: Vec<&str> = Vec::new();
    for comp in unified.split('/') {
        match comp {
            "" | "." => {}
            ".." => return Err(err("包含 `..`")),
            c => {
                if c.contains(':') {
                    return Err(err("组件中包含 `:`"));
                }
                parts.push(c);
            }
        }
    }
    if parts.is_empty() {
        return Err(err("路径为空"));
    }
    if parts.len() > MAX_PATH_DEPTH {
        return Err(err("目录层级过深"));
    }
    Ok(parts.join("/"))
}

/// 拼接 `base`（目录，可为空）和相对路径 `rel`，再规范化。用于 SFZ 的 `default_path` + `sample`。
pub fn join(base: &str, rel: &str) -> Result<String> {
    if base.trim().is_empty() {
        return normalize(rel);
    }
    let base = base.replace('\\', "/");
    let base = base.trim_end_matches('/');
    normalize(&format!("{base}/{rel}"))
}

/// 返回路径的文件名部分。
pub fn file_name(path: &str) -> &str {
    path.rsplit(['/', '\\']).next().unwrap_or(path)
}

/// 返回不带扩展名的文件名。
pub fn file_stem(path: &str) -> &str {
    let name = file_name(path);
    match name.rfind('.') {
        Some(0) | None => name,
        Some(i) => &name[..i],
    }
}

/// 返回小写扩展名（不含点）。
pub fn extension_lower(path: &str) -> Option<String> {
    let name = file_name(path);
    name.rfind('.')
        .filter(|&i| i > 0)
        .map(|i| name[i + 1..].to_ascii_lowercase())
}

/// 依据扩展名推断媒体类型。
pub fn media_type_for(path: &str) -> &'static str {
    match extension_lower(path).as_deref() {
        Some("wav") | Some("wave") => "audio/wav",
        Some("flac") => "audio/flac",
        Some("ogg") => "audio/ogg",
        Some("mp3") => "audio/mpeg",
        Some("aif") | Some("aiff") => "audio/aiff",
        Some("sfz") => "text/plain",
        Some("txt") | Some("md") => "text/plain",
        Some("json") => "application/json",
        Some("mid") | Some("midi") => "audio/midi",
        Some("png") => "image/png",
        Some("jpg") | Some("jpeg") => "image/jpeg",
        Some("webp") => "image/webp",
        Some("svg") => "image/svg+xml",
        Some("xml") => "application/xml",
        _ => "application/octet-stream",
    }
}

/// 把任意显示名转换成安全的文件名片段（ASCII 字母数字、`-`、`_`、`.`）。
pub fn slug(name: &str) -> String {
    let mut out = String::with_capacity(name.len());
    let mut last_dash = false;
    for c in name.chars() {
        if c.is_ascii_alphanumeric() || c == '_' || c == '.' {
            out.push(c.to_ascii_lowercase());
            last_dash = false;
        } else if !last_dash && !out.is_empty() {
            out.push('-');
            last_dash = true;
        }
    }
    let trimmed = out.trim_matches(|c| c == '-' || c == '.').to_string();
    if trimmed.is_empty() {
        "untitled".to_string()
    } else {
        trimmed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_normal_paths() {
        assert_eq!(normalize("samples/kick.wav").unwrap(), "samples/kick.wav");
        assert_eq!(
            normalize("./samples//kick.wav").unwrap(),
            "samples/kick.wav"
        );
        assert_eq!(normalize("samples\\kick.wav").unwrap(), "samples/kick.wav");
        assert_eq!(join("samples/", "a b.wav").unwrap(), "samples/a b.wav");
    }

    #[test]
    fn rejects_traversal() {
        for bad in [
            "../evil",
            "a/../../evil",
            "/etc/passwd",
            "\\windows\\x",
            "C:/x",
            "c:x",
            "a\0b",
            "",
            "./",
            "..\\..\\x",
        ] {
            assert!(normalize(bad).is_err(), "{bad:?} 应被拒绝");
        }
    }

    #[test]
    fn helpers() {
        assert_eq!(file_stem("a/b/kick_01.wav"), "kick_01");
        assert_eq!(extension_lower("A.WAV").as_deref(), Some("wav"));
        assert_eq!(slug("808 Street!"), "808-street");
        assert_eq!(slug("鼓"), "untitled");
        assert_eq!(media_type_for("x.flac"), "audio/flac");
    }
}
