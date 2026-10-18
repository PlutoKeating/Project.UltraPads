//! 应用内更新（`runtime/up-update`，docs/API.md §6）。
//!
//! 流程：`update_check` → `update_download`（进度流，结束于 `Ready { path }`）→
//! Linux：`update_apply(path)` + `update_relaunch()`（应用随即退出）；
//! Android：应用把 `path` 交给系统安装器（MethodChannel `dev.ultrapads/update`）。

use crate::api::types::{ErrorCode, UpError};
use crate::frb_generated::StreamSink;
use crate::state;
use arc_swap::ArcSwapOption;
use flutter_rust_bridge::frb;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

type R<T> = Result<T, UpError>;

/// 本平台怎样完成安装。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdateInstallMode {
    /// Linux，由安装脚本安装：应用内下载、切换版本并重启。
    SelfUpdate,
    /// Android：下载 APK 后交给系统安装器。
    ApkInstaller,
    /// 其它（手动解压的 Linux 包、开发构建、没有发布包的平台）：只提示，打开下载页。
    Manual,
}

#[derive(Debug, Clone, PartialEq)]
pub struct UpdateInfo {
    pub current: String,
    pub latest: String,
    /// 有更新且本平台有发布包。
    pub available: bool,
    pub notes_url: String,
    pub asset_name: Option<String>,
    pub asset_size: Option<u64>,
    /// `site` 或 `github`（站点不可用时的回退）。
    pub source: String,
    pub install_mode: UpdateInstallMode,
}

#[derive(Debug, Clone, PartialEq)]
pub enum UpdateProgress {
    Downloading {
        done: u64,
        total: Option<u64>,
        mirror: bool,
    },
    /// 已下载并通过 SHA-256 校验。
    Ready {
        path: String,
    },
    Failed {
        error: UpError,
    },
}

static LAST_ASSET: ArcSwapOption<up_update::Asset> = ArcSwapOption::const_empty();
static CANCEL: AtomicBool = AtomicBool::new(false);
static DOWNLOADING: AtomicBool = AtomicBool::new(false);

/// 当前应用版本（Cargo workspace 版本，与 pubspec 一致，`just bump` 同时修改两处）。
#[frb(sync)]
pub fn app_version() -> String {
    env!("CARGO_PKG_VERSION").to_owned()
}

fn install_mode(platform: Option<up_update::Platform>) -> UpdateInstallMode {
    match platform {
        Some(p) if p.is_android() => UpdateInstallMode::ApkInstaller,
        #[cfg(target_os = "linux")]
        Some(_) if up_update::linux::detect().is_some() => UpdateInstallMode::SelfUpdate,
        _ => UpdateInstallMode::Manual,
    }
}

/// 查询最新正式版（阻塞，FRB 线程池执行）。`site` 为空时用正式站点。
pub fn update_check(site: Option<String>) -> R<UpdateInfo> {
    let site = site
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| up_update::DEFAULT_SITE.to_owned());
    let platform = up_update::Platform::current();
    let current = app_version();
    let check = match platform {
        Some(p) => up_update::check(&site, &current, p)?,
        None => {
            // 没有发布包的平台：只报告最新版本号
            let c = up_update::check(&site, &current, up_update::Platform::LinuxX64)?;
            up_update::UpdateCheck {
                available: false,
                asset: None,
                ..c
            }
        }
    };
    LAST_ASSET.store(
        check
            .asset
            .clone()
            .filter(|_| check.available)
            .map(Arc::new),
    );
    Ok(UpdateInfo {
        current: check.current,
        latest: check.latest,
        available: check.available,
        notes_url: check.notes_url,
        asset_name: check.asset.as_ref().map(|a| a.name.clone()),
        asset_size: check.asset.as_ref().and_then(|a| a.size),
        source: check.source.to_owned(),
        install_mode: install_mode(platform),
    })
}

/// 下载最近一次 `update_check` 找到的发布包到 `<cache_dir>/updates/`，经 `sink` 推送进度。
/// 立即返回；同一时刻只有一个下载。
pub fn update_download(sink: StreamSink<UpdateProgress>) -> R<()> {
    let asset = LAST_ASSET.load_full().ok_or_else(|| UpError {
        code: ErrorCode::InvalidState,
        message: "[no_update] call update_check first".into(),
    })?;
    let core = state::core()?;
    let dir = std::path::Path::new(&core.dirs().cache_dir).join("updates");
    if DOWNLOADING.swap(true, Ordering::AcqRel) {
        return Err(UpError {
            code: ErrorCode::InvalidState,
            message: "[busy] a download is already running".into(),
        });
    }
    CANCEL.store(false, Ordering::Relaxed);
    std::thread::Builder::new()
        .name("up-update".into())
        .spawn(move || {
            // 只留本次的包：旧版本残留的下载一并清掉
            if let Ok(rd) = std::fs::read_dir(&dir) {
                for e in rd.flatten() {
                    let n = e.file_name();
                    if n != std::ffi::OsStr::new(&asset.name)
                        && n.to_string_lossy() != format!("{}.part", asset.name)
                    {
                        let _ = std::fs::remove_file(e.path());
                    }
                }
            }
            let res = up_update::download(&asset, &dir, &CANCEL, |p| {
                let _ = sink.add(UpdateProgress::Downloading {
                    done: p.done,
                    total: p.total,
                    mirror: p.mirror,
                });
            });
            let _ = sink.add(match res {
                Ok(path) => UpdateProgress::Ready {
                    path: path.to_string_lossy().into_owned(),
                },
                Err(e) => UpdateProgress::Failed { error: e.into() },
            });
            DOWNLOADING.store(false, Ordering::Release);
        })
        .map_err(|e| {
            DOWNLOADING.store(false, Ordering::Release);
            UpError {
                code: ErrorCode::Internal,
                message: format!("spawn download: {e}"),
            }
        })?;
    Ok(())
}

/// 取消正在进行的下载（流以 `Failed { [cancelled] }` 结束）。
#[frb(sync)]
pub fn update_cancel() {
    CANCEL.store(true, Ordering::Relaxed);
}

/// Linux（安装脚本管理的安装）：把下载好的包装为新版本并切换 `current`。之后调用 `update_relaunch`。
pub fn update_apply(path: String) -> R<()> {
    #[cfg(target_os = "linux")]
    {
        let si = up_update::linux::detect().ok_or_else(|| UpError {
            code: ErrorCode::InvalidState,
            message: "[unmanaged] not installed by the install script; update manually".into(),
        })?;
        let asset = LAST_ASSET.load_full().ok_or_else(|| UpError {
            code: ErrorCode::InvalidState,
            message: "[no_update] call update_check first".into(),
        })?;
        let version = asset
            .name
            .strip_prefix("ultrapads-")
            .and_then(|s| s.split('-').next())
            .unwrap_or_default()
            .to_owned();
        Ok(up_update::linux::install(
            &si,
            std::path::Path::new(&path),
            &version,
        )?)
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = path;
        Err(UpError {
            code: ErrorCode::NotImplemented,
            message: "update_apply is Linux only".into(),
        })
    }
}

/// Linux：约 1 s 后启动新版本；调用方应随即停止音频并退出应用。
pub fn update_relaunch() -> R<()> {
    #[cfg(target_os = "linux")]
    {
        let si = up_update::linux::detect().ok_or_else(|| UpError {
            code: ErrorCode::InvalidState,
            message: "[unmanaged] not installed by the install script".into(),
        })?;
        Ok(up_update::linux::relaunch(&si)?)
    }
    #[cfg(not(target_os = "linux"))]
    {
        Err(UpError {
            code: ErrorCode::NotImplemented,
            message: "update_relaunch is Linux only".into(),
        })
    }
}
