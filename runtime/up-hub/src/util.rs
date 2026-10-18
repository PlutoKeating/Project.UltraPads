//! 内部小工具：时间、原子写文件、常量时间比较。

use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

/// 当前 Unix 毫秒时间戳。
pub fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// 原子写文件：写临时文件 → fsync → rename。`private` 为 true 时在 Unix 上设置 0600。
pub(crate) fn atomic_write_sync(path: &Path, bytes: &[u8], private: bool) -> std::io::Result<()> {
    use std::io::Write;
    let dir = path
        .parent()
        .ok_or_else(|| std::io::Error::other("path has no parent"))?;
    std::fs::create_dir_all(dir)?;
    let tmp = dir.join(format!(
        ".{}.tmp-{}",
        path.file_name().and_then(|n| n.to_str()).unwrap_or("file"),
        rand::random::<u32>()
    ));
    {
        let mut opts = std::fs::OpenOptions::new();
        opts.write(true).create_new(true);
        #[cfg(unix)]
        if private {
            use std::os::unix::fs::OpenOptionsExt;
            opts.mode(0o600);
        }
        #[cfg(not(unix))]
        let _ = private;
        let mut f = opts.open(&tmp)?;
        f.write_all(bytes)?;
        f.sync_all()?;
    }
    if let Err(e) = std::fs::rename(&tmp, path) {
        let _ = std::fs::remove_file(&tmp);
        return Err(e);
    }
    Ok(())
}

/// 常量时间字节比较。
pub(crate) fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

pub(crate) fn b64(bytes: &[u8]) -> String {
    data_encoding::BASE64.encode(bytes)
}

pub(crate) fn unb64(s: &str) -> crate::Result<Vec<u8>> {
    data_encoding::BASE64
        .decode(s.as_bytes())
        .map_err(|e| crate::HubError::Protocol(format!("base64: {e}")))
}
