//! 联网检查真实站点（默认忽略）：cargo test -p up-update --test live -- --ignored

use std::sync::atomic::AtomicBool;
use up_update::{DEFAULT_SITE, Platform, check, download};

#[test]
#[ignore = "network"]
fn live_check_and_download_linux_x64() {
    let c = check(DEFAULT_SITE, "0.0.0", Platform::LinuxX64).unwrap();
    assert_eq!(c.source, "site");
    assert!(c.available, "{c:?}");
    let asset = c.asset.unwrap();
    let dir = tempfile::tempdir().unwrap();
    let mut last = None;
    let path = download(&asset, dir.path(), &AtomicBool::new(false), |p| last = Some(p)).unwrap();
    assert_eq!(std::fs::metadata(&path).unwrap().len(), asset.size.unwrap());
    let p = last.unwrap();
    assert!(p.mirror);
    assert_eq!(Some(p.done), p.total);
}

#[test]
#[ignore = "network"]
fn live_github_fallback_when_site_is_down() {
    let c = check("https://127.0.0.1:9", "0.0.0", Platform::AndroidArm64).unwrap();
    assert_eq!(c.source, "github");
    assert!(c.asset.is_some());
}
