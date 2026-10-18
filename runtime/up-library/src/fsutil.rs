//! 文件系统小工具：原子写、时间、自然排序。

use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::error::{IoContext, Result};

/// 原子写入：同目录临时文件 → fsync → rename。`keep_backup` 时把旧文件保留为 `.bak`。
pub fn atomic_write(path: &Path, bytes: &[u8], keep_backup: bool) -> Result<()> {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    std::fs::create_dir_all(dir).ctx(|| format!("创建目录 {}", dir.display()))?;
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "file".into());
    let tmp = dir.join(format!(".{name}.{}.tmp", uuid::Uuid::now_v7().simple()));
    {
        let mut f = std::fs::File::create(&tmp).ctx(|| format!("创建 {}", tmp.display()))?;
        f.write_all(bytes)
            .ctx(|| format!("写入 {}", tmp.display()))?;
        f.sync_all().ctx(|| format!("fsync {}", tmp.display()))?;
    }
    if keep_backup && path.exists() {
        let bak = path.with_file_name(format!("{name}.bak"));
        let _ = std::fs::remove_file(&bak);
        std::fs::copy(path, &bak).ctx(|| format!("备份 {}", path.display()))?;
    }
    std::fs::rename(&tmp, path).ctx(|| format!("重命名到 {}", path.display()))?;
    Ok(())
}

/// 当前 Unix 毫秒。
pub fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// Unix 毫秒 → RFC 3339（UTC，秒精度）。
pub fn rfc3339(ms: i64) -> String {
    let secs = ms.div_euclid(1000);
    let days = secs.div_euclid(86_400);
    let tod = secs.rem_euclid(86_400);
    // Howard Hinnant 的 civil_from_days
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        tod / 3600,
        (tod / 60) % 60,
        tod % 60
    )
}

/// 新的 UUIDv7 字符串（资源 ID）。
pub fn new_id() -> String {
    uuid::Uuid::now_v7().to_string()
}

/// 资源 ID 只能包含 `[A-Za-z0-9_~-]`（会被用作目录名；`~` 用于同步冲突副本 `<id>~conflict~<hash>`）。
pub fn is_safe_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 160
        && !id.starts_with('~')
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'~')
}

/// 自然排序键：`pad2` < `pad10`，大小写不敏感。
pub fn natural_key(s: &str) -> Vec<(u8, u64, String)> {
    let mut out = Vec::new();
    let mut chars = s.chars().peekable();
    while let Some(&c) = chars.peek() {
        if c.is_ascii_digit() {
            let mut n: u64 = 0;
            let mut raw = String::new();
            while let Some(&d) = chars.peek() {
                if !d.is_ascii_digit() {
                    break;
                }
                n = n
                    .saturating_mul(10)
                    .saturating_add(u64::from(d as u8 - b'0'));
                raw.push(d);
                chars.next();
            }
            out.push((0, n, raw));
        } else {
            let mut t = String::new();
            while let Some(&d) = chars.peek() {
                if d.is_ascii_digit() {
                    break;
                }
                t.extend(d.to_lowercase());
                chars.next();
            }
            out.push((1, 0, t));
        }
    }
    out
}

/// 系统垃圾文件（`.DS_Store`、`Thumbs.db`、`._*`）。
pub fn is_junk(path: &str) -> bool {
    let name = up_format::path::file_name(path);
    name == ".DS_Store" || name.eq_ignore_ascii_case("thumbs.db") || name.starts_with("._")
}

/// 把 `rel`（已规范化的包内路径）拼到 `root` 下。
pub fn join_rel(root: &Path, rel: &str) -> PathBuf {
    let mut p = root.to_path_buf();
    for c in rel.split('/') {
        p.push(c);
    }
    p
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn time_format() {
        assert_eq!(rfc3339(0), "1970-01-01T00:00:00Z");
        assert_eq!(rfc3339(1_791_936_000_000), "2026-10-14T00:00:00Z");
        assert_eq!(rfc3339(951_782_400_000), "2000-02-29T00:00:00Z");
    }

    #[test]
    fn natural_sort() {
        let mut v = vec!["pad10.wav", "pad2.wav", "Pad1.wav", "kick.wav"];
        v.sort_by_key(|s| natural_key(s));
        assert_eq!(v, vec!["kick.wav", "Pad1.wav", "pad2.wav", "pad10.wav"]);
    }

    #[test]
    fn ids() {
        assert!(is_safe_id(&new_id()));
        assert!(!is_safe_id("../x"));
        assert!(!is_safe_id(""));
    }
}
