//! Linux：安装脚本管理的安装（`website/public/install`）的就地更新。
//!
//! ```text
//! <前缀>/                     默认 ~/.local/opt/ultrapads
//! ├── install.json            {"installer":"install.sh","version":…,"platform":…,"desktop":…}
//! ├── current -> versions/X   符号链接；切换用 rename(2)，原子
//! └── versions/<版本>/        发布包内容（ultrapads、lib/、data/、share/）
//! ```
//! 运行中的进程用的是 `versions/<旧版本>` 下的文件，切换 `current` 不影响它；重启后才用新版本。

use std::ffi::OsStr;
use std::fs::{self, File};
use std::os::unix::fs::{PermissionsExt, symlink};
use std::os::unix::process::CommandExt;
use std::path::{Component, Path, PathBuf};
use std::process::{Command, Stdio};
use up_core::{UpError, UpResult};

const APP_ID: &str = "dev.ultrapads.ultrapads";

/// 安装脚本管理的一处安装。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScriptInstall {
    pub prefix: PathBuf,
    /// 正在运行的版本（`versions/<版本>` 的目录名）。
    pub version: String,
    /// 安装时写了桌面项（更新后同步刷新）。
    pub desktop: bool,
}

/// 当前进程是否运行在安装脚本管理的安装里。
pub fn detect() -> Option<ScriptInstall> {
    detect_from_exe(&std::env::current_exe().ok()?)
}

/// `exe` 必须是 `<前缀>/versions/<X.Y.Z>/ultrapads`（已解析符号链接），且 `<前缀>/install.json` 由安装脚本写入。
pub fn detect_from_exe(exe: &Path) -> Option<ScriptInstall> {
    let version_dir = exe.parent()?;
    let version = version_dir.file_name()?.to_str()?;
    crate::parse_version(version)?;
    let versions = version_dir.parent()?;
    if versions.file_name() != Some(OsStr::new("versions")) {
        return None;
    }
    let prefix = versions.parent()?;
    let marker: serde_json::Value =
        serde_json::from_slice(&fs::read(prefix.join("install.json")).ok()?).ok()?;
    if marker["installer"].as_str() != Some("install.sh") {
        return None;
    }
    Some(ScriptInstall {
        prefix: prefix.to_path_buf(),
        version: version.to_owned(),
        desktop: marker["desktop"].as_bool().unwrap_or(true),
    })
}

fn io_err(ctx: &str, path: &Path, e: impl std::fmt::Display) -> UpError {
    UpError::io(format!("[io] {ctx} {}: {e}", path.display()))
}

/// 把发布包 `archive`（`ultrapads-<版本>-linux-<架构>.tar.gz`）装成 `versions/<version>` 并切换 `current`；
/// 只保留新版本与正在运行的版本。不重启（见 [`relaunch`]）。
pub fn install(si: &ScriptInstall, archive: &Path, version: &str) -> UpResult<()> {
    crate::parse_version(version)
        .ok_or_else(|| UpError::invalid(format!("bad version {version:?}")))?;
    let versions = si.prefix.join("versions");
    let staging = versions.join(format!(".staging-{}", std::process::id()));
    let _ = fs::remove_dir_all(&staging);
    fs::create_dir_all(&staging).map_err(|e| io_err("create", &staging, e))?;
    if let Err(e) = extract(archive, &staging) {
        let _ = fs::remove_dir_all(&staging);
        return Err(e);
    }
    let bin = staging.join("ultrapads");
    let exec_ok =
        fs::metadata(&bin).is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0);
    if !exec_ok {
        let _ = fs::remove_dir_all(&staging);
        return Err(UpError::format(
            "[protocol] package has no executable ultrapads",
        ));
    }

    let target = versions.join(version);
    let replaced = versions.join(format!(".replaced-{version}-{}", std::process::id()));
    if target.exists() {
        fs::rename(&target, &replaced).map_err(|e| io_err("move aside", &target, e))?;
    }
    fs::rename(&staging, &target).map_err(|e| io_err("install", &target, e))?;
    let _ = fs::remove_dir_all(&replaced);

    let tmp_link = si.prefix.join(".current-new");
    let _ = fs::remove_file(&tmp_link);
    symlink(Path::new("versions").join(version), &tmp_link)
        .map_err(|e| io_err("link", &tmp_link, e))?;
    fs::rename(&tmp_link, si.prefix.join("current"))
        .map_err(|e| io_err("switch", &si.prefix, e))?;

    update_marker(&si.prefix, version)?;
    if si.desktop
        && let Err(e) = refresh_desktop(&si.prefix)
    {
        log::warn!("refresh desktop entry: {e}");
    }
    prune(&versions, version, &si.version);
    Ok(())
}

/// 解压并去掉顶层目录；拒绝绝对路径、`..` 与指向包外的符号链接。
fn extract(archive: &Path, dest: &Path) -> UpResult<()> {
    let file = File::open(archive).map_err(|e| io_err("open", archive, e))?;
    let mut tar = tar::Archive::new(flate2::read::GzDecoder::new(file));
    tar.set_preserve_permissions(true);
    let entries = tar.entries().map_err(|e| io_err("read", archive, e))?;
    for entry in entries {
        let mut entry = entry.map_err(|e| io_err("read", archive, e))?;
        let path = entry
            .path()
            .map_err(|e| io_err("read", archive, e))?
            .into_owned();
        let rel: PathBuf = path.components().skip(1).collect();
        if rel.as_os_str().is_empty() {
            continue;
        }
        if rel.components().any(|c| !matches!(c, Component::Normal(_))) {
            return Err(UpError::format(format!(
                "[protocol] unsafe path in package: {}",
                path.display()
            )));
        }
        if let Ok(Some(link)) = entry.link_name() {
            if link.is_absolute()
                || escapes_root(&rel.parent().unwrap_or(Path::new("")).join(&link))
            {
                return Err(UpError::format(format!(
                    "[protocol] unsafe link in package: {}",
                    path.display()
                )));
            }
        }
        let out = dest.join(&rel);
        if let Some(parent) = out.parent() {
            fs::create_dir_all(parent).map_err(|e| io_err("create", parent, e))?;
        }
        entry.unpack(&out).map_err(|e| io_err("unpack", &out, e))?;
    }
    Ok(())
}

/// 相对路径在任何一步越过根目录（`a/../../x`）即为逃逸。
fn escapes_root(path: &Path) -> bool {
    let mut depth = 0i32;
    for c in path.components() {
        match c {
            Component::ParentDir => {
                depth -= 1;
                if depth < 0 {
                    return true;
                }
            }
            Component::Normal(_) => depth += 1,
            Component::CurDir => {}
            _ => return true,
        }
    }
    false
}

fn update_marker(prefix: &Path, version: &str) -> UpResult<()> {
    let path = prefix.join("install.json");
    let mut marker: serde_json::Value = fs::read(&path)
        .ok()
        .and_then(|b| serde_json::from_slice(&b).ok())
        .unwrap_or_else(|| serde_json::json!({ "installer": "install.sh", "schema": 1 }));
    marker["version"] = version.into();
    let tmp = prefix.join("install.json.tmp");
    let body = serde_json::to_vec_pretty(&marker).map_err(|e| UpError::internal(e.to_string()))?;
    fs::write(&tmp, body).map_err(|e| io_err("write", &tmp, e))?;
    fs::rename(&tmp, &path).map_err(|e| io_err("write", &path, e))
}

fn xdg_data_home() -> Option<PathBuf> {
    std::env::var_os("XDG_DATA_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/share")))
}

/// 与安装脚本的 install_desktop 相同：Exec 指向 `<前缀>/current/ultrapads`，图标进 hicolor。
fn refresh_desktop(prefix: &Path) -> UpResult<()> {
    let share = prefix.join("current/share");
    let src = share.join(format!("applications/{APP_ID}.desktop"));
    let Ok(entry) = fs::read_to_string(&src) else {
        return Ok(());
    };
    let Some(data) = xdg_data_home() else {
        return Ok(());
    };
    let exec = format!("Exec=\"{}\"", prefix.join("current/ultrapads").display());
    let body: Vec<&str> = entry
        .lines()
        .map(|l| {
            if l.starts_with("Exec=") {
                exec.as_str()
            } else {
                l
            }
        })
        .collect();
    let apps = data.join("applications");
    fs::create_dir_all(&apps).map_err(|e| io_err("create", &apps, e))?;
    fs::write(
        apps.join(format!("{APP_ID}.desktop")),
        body.join("\n") + "\n",
    )
    .map_err(|e| io_err("write", &apps, e))?;
    let icon = share.join(format!("icons/hicolor/512x512/apps/{APP_ID}.png"));
    if icon.is_file() {
        let dir = data.join("icons/hicolor/512x512/apps");
        fs::create_dir_all(&dir).map_err(|e| io_err("create", &dir, e))?;
        fs::copy(&icon, dir.join(format!("{APP_ID}.png"))).map_err(|e| io_err("copy", &icon, e))?;
    }
    Ok(())
}

/// 删除除 `keep` 与 `previous` 以外的版本目录和遗留的临时目录。
fn prune(versions: &Path, keep: &str, previous: &str) {
    let Ok(rd) = fs::read_dir(versions) else {
        return;
    };
    for e in rd.flatten() {
        let name = e.file_name();
        let name = name.to_string_lossy();
        if name == keep || name == previous {
            continue;
        }
        let _ = fs::remove_dir_all(e.path());
    }
}

/// 稍后（1 s，等本进程退出并释放音频设备）启动 `<前缀>/current/ultrapads`；调用方随后退出本进程。
pub fn relaunch(si: &ScriptInstall) -> UpResult<()> {
    let bin = si.prefix.join("current/ultrapads");
    Command::new("sh")
        .arg("-c")
        .arg("sleep 1; exec \"$0\"")
        .arg(&bin)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
        .map_err(|e| io_err("relaunch", &bin, e))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn package(
        dir: &Path,
        version: &str,
        extra: impl FnOnce(&mut tar::Builder<flate2::write::GzEncoder<File>>),
    ) -> PathBuf {
        let path = dir.join(format!("ultrapads-{version}-linux-x64.tar.gz"));
        let gz = flate2::write::GzEncoder::new(
            File::create(&path).unwrap(),
            flate2::Compression::fast(),
        );
        let mut b = tar::Builder::new(gz);
        let top = format!("ultrapads-{version}-linux-x64");
        let mut add = |name: &str, body: &[u8], mode: u32| {
            let mut h = tar::Header::new_gnu();
            h.set_size(body.len() as u64);
            h.set_mode(mode);
            h.set_cksum();
            b.append_data(&mut h, format!("{top}/{name}"), body)
                .unwrap();
        };
        add(
            "ultrapads",
            format!("#!/bin/sh\necho {version}\n").as_bytes(),
            0o755,
        );
        add("lib/libapp.so", b"so", 0o644);
        add(
            "share/applications/dev.ultrapads.ultrapads.desktop",
            b"[Desktop Entry]\nName=UltraPads\nExec=ultrapads\n",
            0o644,
        );
        extra(&mut b);
        b.into_inner().unwrap().finish().unwrap().flush().unwrap();
        path
    }

    fn layout(root: &Path, versions: &[&str], current: &str) -> PathBuf {
        let prefix = root.join("opt/ultrapads");
        for v in versions {
            let d = prefix.join("versions").join(v);
            fs::create_dir_all(&d).unwrap();
            fs::write(d.join("ultrapads"), "old").unwrap();
        }
        symlink(Path::new("versions").join(current), prefix.join("current")).unwrap();
        fs::write(
            prefix.join("install.json"),
            format!(r#"{{"installer":"install.sh","schema":1,"version":"{current}","platform":"linux-x64","desktop":false}}"#),
        )
        .unwrap();
        prefix
    }

    #[test]
    fn detects_only_script_layout() {
        let t = tempfile::tempdir().unwrap();
        let prefix = layout(t.path(), &["0.1.0"], "0.1.0");
        let si = detect_from_exe(&prefix.join("versions/0.1.0/ultrapads")).unwrap();
        assert_eq!(si.version, "0.1.0");
        assert_eq!(si.prefix, prefix);
        assert!(!si.desktop);
        assert!(detect_from_exe(&t.path().join("bundle/ultrapads")).is_none());
        fs::write(prefix.join("install.json"), r#"{"installer":"other"}"#).unwrap();
        assert!(detect_from_exe(&prefix.join("versions/0.1.0/ultrapads")).is_none());
    }

    #[test]
    fn install_switches_current_keeps_previous_and_prunes_rest() {
        let t = tempfile::tempdir().unwrap();
        let prefix = layout(t.path(), &["0.0.9", "0.1.0"], "0.1.0");
        let si = detect_from_exe(&prefix.join("versions/0.1.0/ultrapads")).unwrap();
        let pkg = package(t.path(), "0.2.0", |_| {});
        install(&si, &pkg, "0.2.0").unwrap();
        assert_eq!(
            fs::read_link(prefix.join("current")).unwrap(),
            Path::new("versions/0.2.0")
        );
        let bin = prefix.join("current/ultrapads");
        assert!(fs::metadata(&bin).unwrap().permissions().mode() & 0o111 != 0);
        let mut left: Vec<_> = fs::read_dir(prefix.join("versions"))
            .unwrap()
            .map(|e| e.unwrap().file_name().into_string().unwrap())
            .collect();
        left.sort();
        assert_eq!(left, ["0.1.0", "0.2.0"]);
        let marker: serde_json::Value =
            serde_json::from_slice(&fs::read(prefix.join("install.json")).unwrap()).unwrap();
        assert_eq!(marker["version"], "0.2.0");
        assert_eq!(marker["platform"], "linux-x64");
    }

    #[test]
    fn rejects_path_traversal_and_leaves_install_untouched() {
        let t = tempfile::tempdir().unwrap();
        let prefix = layout(t.path(), &["0.1.0"], "0.1.0");
        let si = detect_from_exe(&prefix.join("versions/0.1.0/ultrapads")).unwrap();
        let pkg = package(t.path(), "0.2.0", |b| {
            let mut h = tar::Header::new_gnu();
            h.set_entry_type(tar::EntryType::Symlink);
            h.set_size(0);
            h.set_mode(0o777);
            h.set_cksum();
            b.append_link(
                &mut h,
                "ultrapads-0.2.0-linux-x64/lib/evil",
                "../../../../etc/passwd",
            )
            .unwrap();
        });
        let err = install(&si, &pkg, "0.2.0").unwrap_err();
        assert!(err.message.contains("unsafe link"), "{}", err.message);
        assert_eq!(
            fs::read_link(prefix.join("current")).unwrap(),
            Path::new("versions/0.1.0")
        );
        assert!(!prefix.join("versions/0.2.0").exists());
    }
}
