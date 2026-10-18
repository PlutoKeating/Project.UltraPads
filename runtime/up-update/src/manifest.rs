//! 版本清单（`/api/version` 的 JSON，见 docs/API.md §6）与版本比较。
//! [`manifest_from_github`] 与 `website/worker/release.js` 的 `manifestFromRelease` 同一规则。

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use up_core::{UpError, UpResult};

/// 一个平台的发布包。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Asset {
    pub name: String,
    pub size: Option<u64>,
    /// 小写十六进制 SHA-256。
    pub sha256: String,
    /// 镜像地址（站点 `/dl/`）。
    pub url: String,
    /// GitHub Release 直链。
    pub fallback_url: String,
}

/// 一个正式版本。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Manifest {
    pub version: String,
    pub tag: String,
    #[serde(default)]
    pub published_at: Option<String>,
    pub notes_url: String,
    /// 平台键（`linux-x64` …）→ 发布包。
    #[serde(default)]
    pub assets: BTreeMap<String, Asset>,
}

impl Manifest {
    /// 拒绝格式不对的清单（版本号、SHA-256、https 地址）。
    pub fn validate(&self) -> UpResult<()> {
        parse_version(&self.version)
            .ok_or_else(|| UpError::format(format!("[protocol] bad version {:?}", self.version)))?;
        for (k, a) in &self.assets {
            let hex_ok = a.sha256.len() == 64 && a.sha256.bytes().all(|b| b.is_ascii_hexdigit());
            let https = |u: &str| u.starts_with("https://");
            if !hex_ok || !https(&a.url) || !https(&a.fallback_url) {
                return Err(UpError::format(format!(
                    "[protocol] bad asset entry for {k}"
                )));
            }
        }
        Ok(())
    }
}

/// 发布包对应的平台（编译目标决定，见 [`Platform::current`]）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Platform {
    LinuxX64,
    LinuxArm64,
    AndroidArm64,
    AndroidArmV7,
    AndroidX64,
}

impl Platform {
    pub const ALL: [Platform; 5] = [
        Platform::LinuxX64,
        Platform::LinuxArm64,
        Platform::AndroidArm64,
        Platform::AndroidArmV7,
        Platform::AndroidX64,
    ];

    /// 清单中的键（也是发布包文件名的平台段）。
    pub fn key(self) -> &'static str {
        match self {
            Platform::LinuxX64 => "linux-x64",
            Platform::LinuxArm64 => "linux-arm64",
            Platform::AndroidArm64 => "android-arm64-v8a",
            Platform::AndroidArmV7 => "android-armeabi-v7a",
            Platform::AndroidX64 => "android-x86_64",
        }
    }

    pub fn from_key(key: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|p| p.key() == key)
    }

    pub fn is_android(self) -> bool {
        matches!(
            self,
            Platform::AndroidArm64 | Platform::AndroidArmV7 | Platform::AndroidX64
        )
    }

    /// 本次编译的目标平台；没有发布包的平台（Windows、macOS…）返回 `None`。
    pub fn current() -> Option<Self> {
        if cfg!(all(target_os = "linux", target_arch = "x86_64")) {
            Some(Platform::LinuxX64)
        } else if cfg!(all(target_os = "linux", target_arch = "aarch64")) {
            Some(Platform::LinuxArm64)
        } else if cfg!(all(target_os = "android", target_arch = "aarch64")) {
            Some(Platform::AndroidArm64)
        } else if cfg!(all(target_os = "android", target_arch = "arm")) {
            Some(Platform::AndroidArmV7)
        } else if cfg!(all(target_os = "android", target_arch = "x86_64")) {
            Some(Platform::AndroidX64)
        } else {
            None
        }
    }

    fn extension(self) -> &'static str {
        if self.is_android() { "apk" } else { "tar.gz" }
    }
}

/// `X.Y.Z`（可带前缀 `v`）→ 三元组；预发布 / 其它格式返回 `None`。
pub fn parse_version(v: &str) -> Option<(u64, u64, u64)> {
    let mut it = v.strip_prefix('v').unwrap_or(v).split('.');
    let mut next = || -> Option<u64> {
        let s = it.next()?;
        if s.is_empty() || !s.bytes().all(|b| b.is_ascii_digit()) {
            return None;
        }
        s.parse().ok()
    };
    let out = (next()?, next()?, next()?);
    if it.next().is_some() {
        return None;
    }
    Some(out)
}

/// `candidate` 是否严格新于 `current`（任一无法解析时为 `false`）。
pub fn is_newer(candidate: &str, current: &str) -> bool {
    match (parse_version(candidate), parse_version(current)) {
        (Some(a), Some(b)) => a > b,
        _ => false,
    }
}

/// GitHub release JSON → 清单（站点不可用时的回退；资产地址仍指向 `site` 的 `/dl/`，下载时会再回退直链）。
/// 预发布、草稿、非 `vX.Y.Z` 的 tag 返回 `None`；没有 `digest` 的资产不收录。
pub fn manifest_from_github(release: &serde_json::Value, site: &str) -> Option<Manifest> {
    if release["draft"].as_bool().unwrap_or(false)
        || release["prerelease"].as_bool().unwrap_or(false)
    {
        return None;
    }
    let tag = release["tag_name"].as_str()?;
    parse_version(tag)?;
    if !tag.starts_with('v') {
        return None;
    }
    let version = &tag[1..];
    let mut assets = BTreeMap::new();
    for a in release["assets"].as_array().into_iter().flatten() {
        let Some(name) = a["name"].as_str() else {
            continue;
        };
        let Some(platform) = Platform::ALL
            .into_iter()
            .find(|p| name == format!("ultrapads-{version}-{}.{}", p.key(), p.extension()))
        else {
            continue;
        };
        let Some(sha256) = a["digest"]
            .as_str()
            .and_then(|d| d.strip_prefix("sha256:"))
            .map(str::to_ascii_lowercase)
            .filter(|h| h.len() == 64 && h.bytes().all(|b| b.is_ascii_hexdigit()))
        else {
            continue;
        };
        assets.insert(
            platform.key().to_owned(),
            Asset {
                name: name.to_owned(),
                size: a["size"].as_u64(),
                sha256,
                url: format!("{}/dl/{tag}/{name}", site.trim_end_matches('/')),
                fallback_url: format!(
                    "https://github.com/{}/releases/download/{tag}/{name}",
                    crate::REPO
                ),
            },
        );
    }
    Some(Manifest {
        version: version.to_owned(),
        tag: tag.to_owned(),
        published_at: release["published_at"].as_str().map(str::to_owned),
        notes_url: format!("https://github.com/{}/releases/tag/{tag}", crate::REPO),
        assets,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::evaluate;

    const SHA: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    #[test]
    fn versions_compare_numerically() {
        assert_eq!(parse_version("v1.2.3"), Some((1, 2, 3)));
        assert_eq!(parse_version("0.10.0"), Some((0, 10, 0)));
        assert_eq!(parse_version("1.2"), None);
        assert_eq!(parse_version("1.2.3-rc1"), None);
        assert_eq!(parse_version("1.2.3.4"), None);
        assert!(is_newer("0.10.0", "0.9.9"));
        assert!(is_newer("0.1.0", "0.0.1"));
        assert!(!is_newer("0.1.0", "0.1.0"));
        assert!(!is_newer("garbage", "0.1.0"));
    }

    #[test]
    fn github_release_maps_like_the_worker() {
        let rel = serde_json::json!({
            "tag_name": "v0.1.0", "draft": false, "prerelease": false,
            "published_at": "2026-10-18T00:00:00Z",
            "assets": [
                {"name": "ultrapads-0.1.0-linux-x64.tar.gz", "size": 10, "digest": format!("sha256:{SHA}")},
                {"name": "ultrapads-0.1.0-android-arm64-v8a.apk", "size": 20, "digest": format!("sha256:{}", SHA.to_uppercase())},
                {"name": "ultrapads-0.1.0-linux-arm64.tar.gz", "size": 30, "digest": null},
                {"name": "ultrapads-0.1.0-linux-x64.apk", "size": 1, "digest": format!("sha256:{SHA}")},
                {"name": "SHA256SUMS.txt", "size": 1, "digest": format!("sha256:{SHA}")}
            ]
        });
        let m = manifest_from_github(&rel, "https://site.example/").unwrap();
        assert_eq!(m.version, "0.1.0");
        assert_eq!(
            m.assets.keys().collect::<Vec<_>>(),
            ["android-arm64-v8a", "linux-x64"]
        );
        let a = &m.assets["linux-x64"];
        assert_eq!(
            a.url,
            "https://site.example/dl/v0.1.0/ultrapads-0.1.0-linux-x64.tar.gz"
        );
        assert_eq!(a.sha256, SHA);
        assert_eq!(m.assets["android-arm64-v8a"].sha256, SHA);
        m.validate().unwrap();

        let mut pre = rel.clone();
        pre["prerelease"] = true.into();
        assert!(manifest_from_github(&pre, "x").is_none());
    }

    #[test]
    fn evaluate_needs_newer_version_and_platform_asset() {
        let rel = serde_json::json!({
            "tag_name": "v0.2.0",
            "assets": [{"name": "ultrapads-0.2.0-linux-x64.tar.gz", "size": 1, "digest": format!("sha256:{SHA}")}]
        });
        let m = manifest_from_github(&rel, "https://s").unwrap();
        assert!(evaluate(&m, "0.1.0", Platform::LinuxX64, "site").available);
        assert!(!evaluate(&m, "0.2.0", Platform::LinuxX64, "site").available);
        let arm = evaluate(&m, "0.1.0", Platform::LinuxArm64, "site");
        assert!(!arm.available);
        assert!(arm.asset.is_none());
    }

    #[test]
    fn validate_rejects_non_https_and_bad_hashes() {
        let mut m = manifest_from_github(
            &serde_json::json!({"tag_name": "v1.0.0", "assets": [
                {"name": "ultrapads-1.0.0-linux-x64.tar.gz", "digest": format!("sha256:{SHA}")}]}),
            "https://s",
        )
        .unwrap();
        m.assets.get_mut("linux-x64").unwrap().url = "http://evil/x".into();
        assert!(m.validate().is_err());
    }
}
