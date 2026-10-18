//! `LibraryHubStore`（up-hub 的 `LibraryStore` 实现）：两台设备之间按 Hub 客户端的流程同步。
#![cfg(feature = "hub")]

use std::path::Path;
use std::sync::Arc;

use tokio::io::AsyncReadExt;
use up_hub::{BlobStatus, DeviceIdentity, LibraryStore};
use up_library::hub_store::LibraryHubStore;
use up_library::{KitQuery, Library, SampleOrigin};

fn repo_root() -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

/// 模拟 HubClient::sync 的核心步骤：拉取 `from` 的清单 → 把缺失 blob 拷到 `to` → 合并。
async fn push(from: &LibraryHubStore, to: &LibraryHubStore) -> u32 {
    let m = from.manifest().await.unwrap();
    for (h, _) in m.referenced_blobs() {
        if matches!(to.blob_status(&h).await.unwrap(), BlobStatus::Complete(_)) {
            continue;
        }
        let (_, mut r) = from.open_blob(&h, 0).await.unwrap().unwrap();
        let mut buf = Vec::new();
        r.read_to_end(&mut buf).await.unwrap();
        let mut w = to.blob_writer(&h, 0).await.unwrap();
        w.write(&buf).await.unwrap();
        w.finish().await.unwrap();
    }
    to.merge_manifest(&m).await.unwrap().changed
}

fn tone() -> Vec<u8> {
    let s: Vec<f32> = (0..4410).map(|i| (i as f32 * 0.05).sin() * 0.3).collect();
    up_format::wav::encode_pcm16(1, 44_100, &s)
}

#[tokio::test(flavor = "multi_thread")]
async fn two_devices_sync_kits_samples_tracks_and_deletions() {
    let dir = tempfile::tempdir().unwrap();
    let a_lib = Arc::new(Library::open(dir.path().join("a")).unwrap());
    let b_lib = Arc::new(Library::open(dir.path().join("b")).unwrap());
    let a = LibraryHubStore::new(a_lib.clone(), DeviceIdentity::generate().id());
    let b = LibraryHubStore::new(b_lib.clone(), DeviceIdentity::generate().id());

    let kit = a_lib
        .import(repo_root().join("content/kits/ultrapads-night-drive.upkit"))
        .unwrap()
        .kits[0]
        .kit_id
        .clone();
    a_lib.set_favorite(&kit, true).unwrap();
    let sample = a_lib
        .add_sample(&tone(), "Mic", SampleOrigin::Microphone)
        .unwrap();
    let track = a_lib.track_add(&tone(), "Take", Some(&kit), None).unwrap();

    assert!(push(&a, &b).await > 0);
    let s = b_lib.kit_summary(&kit).unwrap();
    assert!(s.favorite);
    assert_eq!(
        s.manifest_blake3,
        a_lib.kit_summary(&kit).unwrap().manifest_blake3
    );
    b_lib.load_kit_assets(&kit).unwrap();
    assert_eq!(b_lib.sample(&sample.id).unwrap().name, "Mic");
    assert_eq!(b_lib.track(&track.id).unwrap().name, "Take");
    assert!(b_lib.track_path(&track.id).unwrap().is_file());

    // 稳定：再同步不会产生变化（没有来回抖动）
    assert_eq!(push(&b, &a).await, 0);
    assert_eq!(push(&a, &b).await, 0);
    assert_eq!(a.manifest().await.unwrap(), b.manifest().await.unwrap());

    // B 上修改 + 删除 → 同步回 A
    let mut doc = b_lib.kit_doc(&kit).unwrap();
    doc.name = "Renamed on B".into();
    b_lib.save_kit(&doc).unwrap();
    b_lib.track_delete(&track.id).unwrap();
    assert!(push(&b, &a).await > 0);
    assert_eq!(a_lib.kit_summary(&kit).unwrap().name, "Renamed on B");
    assert!(a_lib.track(&track.id).is_err());
    assert_eq!(push(&a, &b).await, 0);

    // 删除 Kit 传播
    a_lib.delete_kit(&kit).unwrap();
    push(&a, &b).await;
    assert!(b_lib.list_kits(&KitQuery::default()).is_empty());
    let blobs = b.list_blobs().await.unwrap();
    assert!(!blobs.is_empty());
}
