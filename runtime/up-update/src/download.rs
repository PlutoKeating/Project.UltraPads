//! 发布包下载：先镜像、后 GitHub 直链；边下边算 SHA-256，核对通过才把 `.part` 改名为正式文件。

use crate::manifest::Asset;
use crate::{agent, net_err};
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};
use up_core::{ErrorCode, UpError, UpResult};

/// 下载进度（`total` 未知时为 `None`）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DownloadProgress {
    pub done: u64,
    pub total: Option<u64>,
    /// 正在使用镜像（`false` = 已回退 GitHub 直链）。
    pub mirror: bool,
}

const PROGRESS_EVERY: Duration = Duration::from_millis(100);

fn cancelled() -> UpError {
    UpError::new(ErrorCode::InvalidState, "[cancelled] download cancelled")
}

/// 下载 `asset` 到 `dir/<asset.name>` 并核对 SHA-256，返回文件路径。
/// 已存在且哈希相符的文件直接复用；`cancel` 置位后尽快返回 `[cancelled]` 错误。
pub fn download(
    asset: &Asset,
    dir: &Path,
    cancel: &AtomicBool,
    mut progress: impl FnMut(DownloadProgress),
) -> UpResult<PathBuf> {
    if asset.name.contains('/') || asset.name.contains("..") {
        return Err(UpError::invalid(format!("bad asset name {:?}", asset.name)));
    }
    fs::create_dir_all(dir).map_err(|e| UpError::io(format!("create {}: {e}", dir.display())))?;
    let dest = dir.join(&asset.name);
    if dest.is_file() && sha256_file(&dest).is_ok_and(|h| h == asset.sha256) {
        let size = fs::metadata(&dest).map(|m| m.len()).unwrap_or(0);
        progress(DownloadProgress {
            done: size,
            total: Some(size),
            mirror: true,
        });
        return Ok(dest);
    }
    let part = dir.join(format!("{}.part", asset.name));
    let mut last_err = None;
    for (url, mirror) in [(&asset.url, true), (&asset.fallback_url, false)] {
        if cancel.load(Ordering::Relaxed) {
            break;
        }
        match fetch(url, &part, asset, mirror, cancel, &mut progress) {
            Ok(()) => {
                fs::rename(&part, &dest)
                    .map_err(|e| UpError::io(format!("rename {}: {e}", part.display())))?;
                return Ok(dest);
            }
            Err(e) => {
                let _ = fs::remove_file(&part);
                log::warn!("download {url} failed: {e}");
                last_err = Some(e);
            }
        }
    }
    if cancel.load(Ordering::Relaxed) {
        return Err(cancelled());
    }
    Err(last_err.unwrap_or_else(cancelled))
}

fn fetch(
    url: &str,
    part: &Path,
    asset: &Asset,
    mirror: bool,
    cancel: &AtomicBool,
    progress: &mut impl FnMut(DownloadProgress),
) -> UpResult<()> {
    let mut res = agent(Duration::from_secs(30 * 60))
        .get(url)
        .call()
        .map_err(|e| net_err(url, e))?;
    let total = asset.size.or_else(|| {
        res.headers()
            .get("content-length")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.parse().ok())
    });
    // 已知大小时多读 1 字节即判定不符，防止无限下载
    let limit = asset.size.map_or(u64::MAX, |s| s + 1);
    let mut reader = res.body_mut().with_config().limit(limit).reader();
    let file =
        File::create(part).map_err(|e| UpError::io(format!("create {}: {e}", part.display())))?;
    let mut out = BufWriter::new(file);
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    let mut done = 0u64;
    let mut last = Instant::now();
    progress(DownloadProgress {
        done,
        total,
        mirror,
    });
    loop {
        if cancel.load(Ordering::Relaxed) {
            return Err(cancelled());
        }
        let n = reader.read(&mut buf).map_err(|e| net_err(url, e))?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
        out.write_all(&buf[..n])
            .map_err(|e| UpError::io(format!("write {}: {e}", part.display())))?;
        done += n as u64;
        if last.elapsed() >= PROGRESS_EVERY {
            last = Instant::now();
            progress(DownloadProgress {
                done,
                total,
                mirror,
            });
        }
    }
    out.into_inner()
        .map_err(|e| UpError::io(format!("flush {}: {e}", part.display())))?
        .sync_all()
        .map_err(|e| UpError::io(format!("sync {}: {e}", part.display())))?;
    progress(DownloadProgress {
        done,
        total,
        mirror,
    });
    if let Some(size) = asset.size
        && size != done
    {
        return Err(UpError::format(format!(
            "[hash_mismatch] {url}: expected {size} bytes, got {done}"
        )));
    }
    let actual = hex(&hasher.finalize());
    if actual != asset.sha256 {
        return Err(UpError::format(format!(
            "[hash_mismatch] {url}: sha256 {actual} != {}",
            asset.sha256
        )));
    }
    Ok(())
}

pub(crate) fn sha256_file(path: &Path) -> std::io::Result<String> {
    let mut f = File::open(path)?;
    let mut h = Sha256::new();
    std::io::copy(&mut f, &mut h)?;
    Ok(hex(&h.finalize()))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
