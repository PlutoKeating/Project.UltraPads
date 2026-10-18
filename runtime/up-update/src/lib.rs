//! 应用内更新（docs/ARCHITECTURE.md §10，接口 docs/API.md §6）。
//!
//! * [`check`]：查询 `<站点>/api/version`（失败时回退 GitHub Releases API），得到最新正式版清单，
//!   与当前版本比较，挑出本平台的发布包；
//! * [`download`]：先走 `/dl/` 镜像、失败回退 GitHub 直链，边下边算 SHA-256，核对通过才落盘；
//! * [`linux`]：识别安装脚本管理的安装（`<前缀>/versions/<版本>` + `current` 链接 + `install.json`），
//!   解压新版本、原子切换 `current`、保留上一版、重启。Android 的安装由应用经系统安装器完成。
//!
//! 只做 HTTPS GET，不上报任何设备信息。所有函数都是阻塞的，调用方放到后台线程。

mod download;
#[cfg(target_os = "linux")]
pub mod linux;
mod manifest;

pub use download::{DownloadProgress, download};
pub use manifest::{Asset, Manifest, Platform, is_newer, manifest_from_github, parse_version};

use std::time::Duration;
use up_core::{ErrorCode, UpError, UpResult};

/// 正式站点（`/api/version`、`/dl/`）。
pub const DEFAULT_SITE: &str = "https://ultrapads.plutokeating.beer";
/// GitHub 仓库（站点不可用时的回退）。
pub const REPO: &str = "PlutoKeating/Project.UltraPads";

/// 一次检查的结果。
#[derive(Debug, Clone, PartialEq)]
pub struct UpdateCheck {
    pub current: String,
    pub latest: String,
    /// `latest` 比 `current` 新，且有本平台的发布包。
    pub available: bool,
    pub notes_url: String,
    /// 本平台的发布包（没有时为 `None`，例如该平台还没有发布）。
    pub asset: Option<Asset>,
    /// 清单来自站点还是 GitHub 回退。
    pub source: &'static str,
}

pub(crate) fn agent(timeout: Duration) -> ureq::Agent {
    ureq::Agent::config_builder()
        .timeout_connect(Some(Duration::from_secs(10)))
        .timeout_global(Some(timeout))
        .user_agent(concat!("UltraPads/", env!("CARGO_PKG_VERSION")))
        .http_status_as_error(true)
        .build()
        .into()
}

pub(crate) fn net_err(ctx: &str, e: impl std::fmt::Display) -> UpError {
    UpError::new(ErrorCode::Io, format!("[network] {ctx}: {e}"))
}

/// 查询最新正式版。`site` 为站点根地址（无尾斜杠），`current` 为当前版本（`X.Y.Z`）。
pub fn check(site: &str, current: &str, platform: Platform) -> UpResult<UpdateCheck> {
    let (manifest, source) = match fetch_site(site) {
        Ok(m) => (m, "site"),
        Err(site_err) => {
            log::warn!("update check via {site} failed: {site_err}; trying GitHub");
            match fetch_github() {
                Ok(m) => (m, "github"),
                // 两边都失败时报告站点的错误（更常见的情况是整体离线）
                Err(_) => return Err(site_err),
            }
        }
    };
    Ok(evaluate(&manifest, current, platform, source))
}

/// 比较版本并挑出平台资产（纯函数，便于测试）。
pub fn evaluate(
    manifest: &Manifest,
    current: &str,
    platform: Platform,
    source: &'static str,
) -> UpdateCheck {
    let asset = manifest.assets.get(platform.key()).cloned();
    UpdateCheck {
        current: current.to_owned(),
        latest: manifest.version.clone(),
        available: asset.is_some() && is_newer(&manifest.version, current),
        notes_url: manifest.notes_url.clone(),
        asset,
        source,
    }
}

fn fetch_site(site: &str) -> UpResult<Manifest> {
    let url = format!("{}/api/version", site.trim_end_matches('/'));
    let mut res = agent(Duration::from_secs(20))
        .get(&url)
        .call()
        .map_err(|e| net_err(&url, e))?;
    let m: Manifest = res
        .body_mut()
        .read_json()
        .map_err(|e| UpError::format(format!("[protocol] {url}: {e}")))?;
    m.validate()?;
    Ok(m)
}

fn fetch_github() -> UpResult<Manifest> {
    let url = format!("https://api.github.com/repos/{REPO}/releases/latest");
    let mut res = agent(Duration::from_secs(20))
        .get(&url)
        .header("Accept", "application/vnd.github+json")
        .call()
        .map_err(|e| net_err(&url, e))?;
    let v: serde_json::Value = res
        .body_mut()
        .read_json()
        .map_err(|e| UpError::format(format!("[protocol] {url}: {e}")))?;
    manifest_from_github(&v, DEFAULT_SITE).ok_or_else(|| {
        UpError::format("[protocol] latest GitHub release is not a stable vX.Y.Z release")
    })
}
