//! up-library 集成测试：.upkit 往返、恶意 ZIP、WAV 文件夹、SFZ、示例 Kit、私有素材包（假数据）、
//! 收藏/搜索、保存编辑、样本与录音作品、导出。

use std::io::Write;
use std::path::{Path, PathBuf};

use up_format::kit::{ColorRole, LaunchMode, PadAddr, PadColor, PadKind, SampleLayer};
use up_format::wav;
use up_library::archive::zip_to_vec;
use up_library::{
    CatalogStatus, ExportFormat, ImportKind, ImportLimits, KitQuery, KitSort, Library,
    LibraryError, LibraryOptions, SampleOrigin, TrackExportFormat,
};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn tone(secs: f32, hz: f32) -> Vec<u8> {
    let n = (secs * 44_100.0) as usize;
    let s: Vec<f32> = (0..n)
        .map(|i| (i as f32 * hz * std::f32::consts::TAU / 44_100.0).sin() * 0.5)
        .collect();
    wav::encode_pcm16(1, 44_100, &s)
}

fn lib() -> (tempfile::TempDir, Library) {
    let dir = tempfile::tempdir().unwrap();
    let lib = Library::open(dir.path().join("data")).unwrap();
    (dir, lib)
}

#[test]
fn example_kits_import_load_and_roundtrip() {
    let (dir, lib) = lib();
    let mut ids = Vec::new();
    for name in ["ultrapads-starter.upkit", "ultrapads-night-drive.upkit"] {
        let r = lib
            .import(repo_root().join("content/kits").join(name))
            .unwrap();
        assert_eq!(r.kind, ImportKind::Upkit);
        assert!(r.warnings.is_empty(), "{:?}", r.warnings);
        assert!(!r.kits[0].duplicate);
        ids.push(r.kits[0].kit_id.clone());
    }
    // 提交的示例与生成器输出一致（生成器是确定性的）
    for (file, pkg) in up_library::kitgen::example_packages().unwrap() {
        let committed = std::fs::read(repo_root().join("content/kits").join(&file)).unwrap();
        assert_eq!(
            committed,
            zip_to_vec(&pkg.zip_entries()).unwrap(),
            "{file} 与 kitgen 输出不一致，请重新运行 `cargo run -p up-library --example kitgen -- content/kits`"
        );
    }
    let starter = &ids[0];
    let loaded = lib.load_kit_assets(starter).unwrap();
    assert_eq!(loaded.doc.name, "UltraPads Starter");
    assert_eq!(loaded.doc.pads.len(), 12);
    assert_eq!(loaded.samples.len(), 12);
    for s in loaded.samples.values() {
        assert!(s.file.is_file());
        let pcm = s.pcm.as_ref().unwrap();
        assert_eq!(pcm.sample_rate, 44_100);
        assert_eq!(pcm.frames() as u64, s.frames);
    }
    let lp = loaded.doc.pad(PadAddr::from_flat(8)).unwrap();
    assert_eq!(lp.kind, PadKind::Loop);
    assert_eq!(lp.tempo.unwrap().bpm, 120.0);
    assert!(lib.kit_summary(starter).unwrap().last_used_at_ms.is_some());
    assert!(lib.kit_summary(starter).unwrap().has_tutorial);

    // 导出 ZIP → 重新导入 = 重复
    let out = dir.path().join("out.upkit");
    lib.export_kit(starter, &out, ExportFormat::Upkit).unwrap();
    let r = lib.import(&out).unwrap();
    assert!(r.kits[0].duplicate);
    assert_eq!(&r.kits[0].kit_id, starter);
    // 导出文件夹 → 导入到另一个库，文档一致
    let folder = dir.path().join("folder.upkit");
    lib.export_kit(starter, &folder, ExportFormat::UpkitFolder)
        .unwrap();
    assert!(folder.join("kit.sfz").is_file() && folder.join("mimetype").is_file());
    let other = Library::open(dir.path().join("other")).unwrap();
    let r = other.import(&folder).unwrap();
    let mut a = lib.kit_doc(starter).unwrap();
    let mut b = other.kit_doc(&r.kits[0].kit_id).unwrap();
    a.id.clear();
    b.id.clear();
    assert_eq!(a, b);
    // SFZ 文件夹导出：loop 采样带 acid/smpl
    let sfz = dir.path().join("sfz");
    lib.export_kit(starter, &sfz, ExportFormat::SfzFolder)
        .unwrap();
    let bytes = std::fs::read(sfz.join("samples/loop-drums-120bpm-1bar.wav")).unwrap();
    let meta = wav::read_metadata(&bytes).unwrap();
    assert_eq!(meta.acid.unwrap().tempo, 120.0);
    assert!(!meta.smpl.unwrap().loops.is_empty());
    // 导出 SFZ 能被重新导入
    let r = other.import(sfz.join("kit.sfz")).unwrap();
    assert_eq!(r.kind, ImportKind::Sfz);
    assert_eq!(other.kit_doc(&r.kits[0].kit_id).unwrap().pads.len(), 12);
}

#[test]
fn dawproject_export_validates_against_xsd() {
    let (dir, lib) = lib();
    let r = lib
        .import(repo_root().join("content/kits/ultrapads-starter.upkit"))
        .unwrap();
    let out = dir.path().join("starter.dawproject");
    lib.export_kit(&r.kits[0].kit_id, &out, ExportFormat::DawProject)
        .unwrap();
    let fs = up_library::archive::read_zip_file(&out, &ImportLimits::default()).unwrap();
    assert!(
        fs.files
            .contains_key("kits/ultrapads-starter.upkit/kit.sfz")
    );
    if std::process::Command::new("xmllint")
        .arg("--version")
        .output()
        .is_err()
    {
        eprintln!("跳过 XSD 校验：未安装 xmllint");
        return;
    }
    let schema = repo_root().join("content/schema/dawproject");
    for (file, xsd) in [
        ("project.xml", "Project.xsd"),
        ("metadata.xml", "MetaData.xsd"),
    ] {
        let p = dir.path().join(file);
        std::fs::write(&p, &fs.files[file]).unwrap();
        let o = std::process::Command::new("xmllint")
            .args(["--noout", "--schema"])
            .arg(schema.join(xsd))
            .arg(&p)
            .output()
            .unwrap();
        assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stderr));
    }
}

fn raw_zip(entries: &[(&str, &[u8])], method: zip::CompressionMethod) -> Vec<u8> {
    let mut w = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    for (name, data) in entries {
        w.start_file(
            *name,
            zip::write::SimpleFileOptions::DEFAULT.compression_method(method),
        )
        .unwrap();
        w.write_all(data).unwrap();
    }
    w.finish().unwrap().into_inner()
}

#[test]
fn malicious_zips_are_rejected() {
    let (dir, lib) = lib();
    let stored = zip::CompressionMethod::Stored;
    for (label, name) in [
        ("traversal", "../../evil.txt"),
        ("nested traversal", "samples/../../evil.txt"),
        ("absolute", "/etc/evil.txt"),
        ("windows", "..\\..\\evil.txt"),
        ("drive", "C:/evil.txt"),
    ] {
        let z = raw_zip(
            &[("kit.sfz", b"<region> key=36 sample=a.wav"), (name, b"x")],
            stored,
        );
        let err = lib.import_zip_bytes("bad.upkit", &z).unwrap_err();
        assert!(
            matches!(err, LibraryError::Unsafe(_)),
            "{label}: 期望 Unsafe，得到 {err:?}"
        );
    }
    assert!(!dir.path().join("evil.txt").exists());

    // 符号链接条目
    let mut w = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    w.add_symlink(
        "link",
        "/etc/passwd",
        zip::write::SimpleFileOptions::DEFAULT,
    )
    .unwrap();
    let z = w.finish().unwrap().into_inner();
    assert!(matches!(
        lib.import_zip_bytes("sym.upkit", &z),
        Err(LibraryError::Unsafe(_))
    ));

    // 超大：用小限额的库
    let small = Library::open_with(
        dir.path().join("small"),
        LibraryOptions {
            limits: ImportLimits {
                max_entry_bytes: 1024,
                max_total_bytes: 4096,
                max_entries: 8,
                ..ImportLimits::default()
            },
            ..LibraryOptions::default()
        },
    )
    .unwrap();
    let big = vec![7u8; 4096];
    let z = raw_zip(&[("kit.sfz", b""), ("samples/a.wav", &big)], stored);
    assert!(matches!(
        small.import_zip_bytes("big.upkit", &z),
        Err(LibraryError::LimitExceeded(_))
    ));
    // 总量超限（每个条目都不超）
    let chunk = vec![1u8; 1000];
    let entries: Vec<(String, Vec<u8>)> = (0..6)
        .map(|i| (format!("f{i}.bin"), chunk.clone()))
        .collect();
    let refs: Vec<(&str, &[u8])> = entries
        .iter()
        .map(|(n, d)| (n.as_str(), d.as_slice()))
        .collect();
    let z = raw_zip(&refs, stored);
    assert!(matches!(
        small.import_zip_bytes("total.zip", &z),
        Err(LibraryError::LimitExceeded(_))
    ));
    // 条目数超限
    let entries: Vec<(String, Vec<u8>)> = (0..9).map(|i| (format!("e{i}"), vec![0u8])).collect();
    let refs: Vec<(&str, &[u8])> = entries
        .iter()
        .map(|(n, d)| (n.as_str(), d.as_slice()))
        .collect();
    let z = raw_zip(&refs, stored);
    assert!(matches!(
        small.import_zip_bytes("many.zip", &z),
        Err(LibraryError::LimitExceeded(_))
    ));
    // zip bomb：64 MiB 的 0 压缩到几十 KB
    let zeros = vec![0u8; 64 * 1024 * 1024];
    let z = raw_zip(
        &[("kit.sfz", b""), ("samples/bomb.wav", &zeros)],
        zip::CompressionMethod::Deflated,
    );
    assert!(z.len() < 1024 * 1024);
    match lib.import_zip_bytes("bomb.upkit", &z) {
        Err(LibraryError::LimitExceeded(m)) => assert!(m.contains("压缩比"), "{m}"),
        other => panic!("期望 zip bomb 被拒绝，得到 {other:?}"),
    }
    // 篡改的包（哈希不符）
    let good = std::fs::read(repo_root().join("content/kits/ultrapads-night-drive.upkit")).unwrap();
    let fs =
        up_library::archive::read_zip(std::io::Cursor::new(good), "x", &ImportLimits::default())
            .unwrap();
    let mut files = fs.files.clone();
    files.get_mut("samples/kick.wav").unwrap()[100] ^= 0x55;
    let entries: Vec<(&str, &[u8], bool)> = files
        .iter()
        .map(|(p, b)| (p.as_str(), b.as_slice(), true))
        .collect();
    let z = zip_to_vec(&entries).unwrap();
    assert!(matches!(
        lib.import_zip_bytes("tampered.upkit", &z),
        Err(LibraryError::Format(
            up_format::FormatError::HashMismatch { .. }
        ))
    ));
    assert!(lib.list_kits(&KitQuery::default()).is_empty());
}

#[test]
fn wav_folder_import_orders_and_detects_loops() {
    let (dir, lib) = lib();
    let src = dir.path().join("My Beats");
    std::fs::create_dir_all(src.join("sub")).unwrap();
    std::fs::write(src.join("10 snare.wav"), tone(0.2, 200.0)).unwrap();
    std::fs::write(src.join("2 kick.wav"), tone(0.2, 60.0)).unwrap();
    std::fs::write(src.join("1 hat.wav"), tone(0.1, 8000.0)).unwrap();
    std::fs::write(src.join("groove_92bpm_4bar.wav"), tone(1.0, 100.0)).unwrap();
    // acid 声明的 loop
    let meta = wav::WavMetadata {
        acid: Some(wav::AcidChunk::looped(128.0, 8, 60, [4, 4])),
        ..Default::default()
    };
    let acid = wav::write_metadata(&tone(1.0, 300.0), &meta).unwrap();
    std::fs::write(src.join("sub/zz acid.wav"), acid).unwrap();
    std::fs::write(src.join("notes.txt"), b"ignore me").unwrap();
    std::fs::write(src.join(".DS_Store"), b"junk").unwrap();

    let r = lib.import(&src).unwrap();
    assert_eq!(r.kind, ImportKind::WavFolder);
    let doc = lib.kit_doc(&r.kits[0].kit_id).unwrap();
    assert_eq!(doc.name, "My Beats");
    let names: Vec<_> = doc.pads.iter().map(|p| p.name.clone().unwrap()).collect();
    assert_eq!(
        names,
        vec![
            "1 hat",
            "2 kick",
            "10 snare",
            "groove_92bpm_4bar",
            "zz acid"
        ]
    );
    let groove = &doc.pads[3];
    assert_eq!(groove.kind, PadKind::Loop);
    assert_eq!(groove.launch.mode, LaunchMode::Toggle);
    assert_eq!(groove.tempo.unwrap().bpm, 92.0);
    assert_eq!(groove.tempo.unwrap().beats, Some(16.0));
    assert_eq!(groove.color, PadColor::Role(ColorRole::Blue));
    let acid = &doc.pads[4];
    assert_eq!(acid.tempo.unwrap().bpm, 128.0);
    assert_eq!(acid.tempo.unwrap().beats, Some(8.0));
    assert_eq!(doc.pads[0].kind, PadKind::OneShot);
    assert_eq!(doc.tempo.unwrap().bpm, 92.0);
    // 再导一次是重复
    assert!(lib.import(&src).unwrap().kits[0].duplicate);
}

#[test]
fn sfz_import_resolves_relative_paths_and_includes() {
    let (dir, lib) = lib();
    let root = dir.path().join("Drums");
    std::fs::create_dir_all(root.join("Samples/Kick")).unwrap();
    std::fs::create_dir_all(root.join("inc")).unwrap();
    std::fs::write(root.join("Samples/Kick/Kick_01.wav"), tone(0.2, 60.0)).unwrap();
    std::fs::write(root.join("Samples/snare.wav"), tone(0.2, 200.0)).unwrap();
    std::fs::write(root.join("Samples/hat closed.wav"), tone(0.05, 8000.0)).unwrap();
    std::fs::write(
        root.join("inc/common.sfz"),
        "<global> loop_mode=one_shot amp_veltrack=100\n",
    )
    .unwrap();
    std::fs::write(
        root.join("drums.sfz"),
        "#define $KICK 36\n#include \"inc/common.sfz\"\n<control> default_path=Samples/ label_key36=Big Kick\n\
         <group> key=$KICK\n<region> sample=kick\\kick_01.wav\n\
         <group> key=38 group=1 off_by=2 cutoff=1000\n<region> sample=snare.wav\n\
         <region> key=42 sample=hat closed.wav\n<region> key=44 sample=missing.wav\n",
    )
    .unwrap();
    let r = lib.import(root.join("drums.sfz")).unwrap();
    assert_eq!(r.kind, ImportKind::Sfz);
    let codes: Vec<_> = r.warnings.iter().map(|w| w.code.as_str()).collect();
    assert!(codes.contains(&"sfz.unknown_opcode"), "{codes:?}");
    assert!(codes.contains(&"import.missing_sample"), "{codes:?}");
    let doc = lib.kit_doc(&r.kits[0].kit_id).unwrap();
    assert_eq!(doc.name, "drums");
    let kick = doc.pad_by_note(36).unwrap();
    assert_eq!(kick.name.as_deref(), Some("Big Kick"));
    assert_eq!(kick.layers[0].sample, "samples/Kick_01.wav");
    let snare = doc.pad_by_note(38).unwrap();
    assert_eq!(snare.choke_group, Some(1));
    assert_eq!(snare.choked_by, Some(2));
    assert_eq!(
        doc.pad_by_note(42).unwrap().layers[0].sample,
        "samples/hat closed.wav"
    );
    assert!(doc.pad_by_note(44).is_none());
    // 文件夹导入时也会识别 SFZ
    let other = Library::open(dir.path().join("o")).unwrap();
    let r = other.import(&root).unwrap();
    assert_eq!(r.kind, ImportKind::Sfz);
    // inc/common.sfz 没有 region：导入失败只记警告，不影响 drums.sfz
    assert_eq!(r.kits.len(), 1);
    assert!(r.warnings.iter().any(|w| w.code == "import.sfz_failed"));
}

#[test]
fn search_filter_favorites_recent() {
    let (_dir, lib) = lib();
    let a = lib
        .import(repo_root().join("content/kits/ultrapads-starter.upkit"))
        .unwrap()
        .kits[0]
        .kit_id
        .clone();
    let b = lib
        .import(repo_root().join("content/kits/ultrapads-night-drive.upkit"))
        .unwrap()
        .kits[0]
        .kit_id
        .clone();
    let names = |q: &KitQuery| {
        lib.list_kits(q)
            .into_iter()
            .map(|k| k.name)
            .collect::<Vec<_>>()
    };
    assert_eq!(
        names(&KitQuery::default()),
        vec!["UltraPads Night Drive", "UltraPads Starter"]
    );
    assert_eq!(
        names(&KitQuery {
            text: Some("starter synth".into()),
            ..Default::default()
        }),
        vec!["UltraPads Starter"]
    );
    assert_eq!(
        names(&KitQuery {
            genre: Some("lo-fi".into()),
            ..Default::default()
        }),
        vec!["UltraPads Night Drive"]
    );
    assert!(
        names(&KitQuery {
            genre: Some("rock".into()),
            ..Default::default()
        })
        .is_empty()
    );
    let genres: Vec<String> = lib.genres().into_iter().map(|(g, _)| g).collect();
    assert_eq!(genres, vec!["Electronic", "Hip Hop", "Lo-Fi"]);
    lib.set_favorite(&b, true).unwrap();
    assert_eq!(
        names(&KitQuery {
            favorites_only: true,
            ..Default::default()
        }),
        vec!["UltraPads Night Drive"]
    );
    assert!(lib.recent_kits(10).is_empty());
    lib.mark_used(&b).unwrap();
    lib.mark_used(&a).unwrap();
    let recent: Vec<_> = lib.recent_kits(10).into_iter().map(|k| k.id).collect();
    assert_eq!(recent, vec![a.clone(), b.clone()]);
    assert_eq!(
        lib.list_kits(&KitQuery {
            sort: KitSort::RecentlyUsed,
            limit: Some(1),
            ..Default::default()
        })[0]
            .id,
        a
    );
    // 状态持久化
    let root = lib.root().to_path_buf();
    drop(lib);
    let lib = Library::open(&root).unwrap();
    assert!(lib.kit_summary(&b).unwrap().favorite);
    lib.delete_kit(&a).unwrap();
    assert!(lib.kit_summary(&a).is_err());
    assert!(lib.gc_blobs().unwrap() > 0);
    lib.load_kit_assets(&b).unwrap();
}

#[test]
fn save_kit_with_mic_sample_and_tracks() {
    let (dir, lib) = lib();
    let id = lib
        .import(repo_root().join("content/kits/ultrapads-night-drive.upkit"))
        .unwrap()
        .kits[0]
        .kit_id
        .clone();
    // 麦克风录音入库
    let mic = lib
        .add_sample(&tone(0.3, 440.0), "My Voice", SampleOrigin::Microphone)
        .unwrap();
    assert_eq!(lib.list_samples().len(), 1);
    assert_eq!(lib.sample_waveform(&mic.id, 16).unwrap().len(), 16);
    let mut doc = lib.kit_doc(&id).unwrap();
    doc.name = "Night Drive (edited)".into();
    let mut pad = up_format::kit::PadDoc::new(PadAddr::from_flat(9));
    pad.name = Some("Voice".into());
    let mut layer = SampleLayer::new("samples/voice.wav");
    layer.sample_id = Some(mic.id.clone());
    pad.layers.push(layer);
    doc.pads.push(pad);
    doc.pads.retain(|p| p.addr.flat() != 7);
    let s = lib.save_kit(&doc).unwrap();
    assert_eq!(s.id, id);
    assert_eq!(s.name, "Night Drive (edited)");
    let back = lib.kit_doc(&id).unwrap();
    let voice = back.pad(PadAddr::from_flat(9)).unwrap();
    assert_eq!(voice.layers[0].sample_id.as_deref(), Some(mic.id.as_str()));
    assert!(back.pad(PadAddr::from_flat(7)).is_none());
    assert!(
        lib.kit_manifest(&id).unwrap().find("LICENSE.txt").is_some(),
        "非采样文件被保留"
    );
    // 新建 Kit
    let mut fresh = up_format::kit::KitDoc::new("", "Fresh");
    let mut p = up_format::kit::PadDoc::new(PadAddr::from_flat(0));
    let mut l = SampleLayer::new("whatever.wav");
    l.sample_id = Some(mic.id.clone());
    p.layers.push(l);
    fresh.pads.push(p);
    let f = lib.save_kit(&fresh).unwrap();
    assert_ne!(f.id, id);
    assert_eq!(lib.list_kits(&KitQuery::default()).len(), 2);

    // 录音作品
    let t = lib
        .track_add(&tone(1.0, 220.0), "Take 1", Some(&id), Some(90.0))
        .unwrap();
    assert_eq!(lib.tracks_list().len(), 1);
    assert!(lib.track_path(&t.id).unwrap().is_file());
    let wav_out = dir.path().join("take.wav");
    lib.track_export(&t.id, &wav_out, TrackExportFormat::Wav)
        .unwrap();
    let meta = wav::read_metadata(&std::fs::read(&wav_out).unwrap()).unwrap();
    assert_eq!(meta.bext.unwrap().description, "Take 1");
    let dp = dir.path().join("take.dawproject");
    lib.track_export(&t.id, &dp, TrackExportFormat::DawProject)
        .unwrap();
    let fs = up_library::archive::read_zip_file(&dp, &ImportLimits::default()).unwrap();
    assert!(fs.files.contains_key("audio/take-1.wav"));
    let s = lib.track_to_sample(&t.id).unwrap();
    assert_eq!(s.origin, SampleOrigin::Track);
    lib.track_rename(&t.id, "Best take").unwrap();
    lib.track_delete(&t.id).unwrap();
    assert!(lib.tracks_list().is_empty());
}

// ---------------------------------------------------------------------------
// 私有素材包（测试用代码构造的同结构假数据；不复制任何私有素材）
// ---------------------------------------------------------------------------

fn fake_config() -> Vec<u8> {
    br#"{"behaviour":{"pad1":200,"pad2":100,"pad3":300,"pad13":200},
        "colors":{"pad1":"amarelo","pad2":"azul_loop","pad3":"rosa","pad13":"verde"},
        "groups":{"pad1":1,"pad2":2,"pad3":1,"pad13":3},"preset":"fake kit"}"#
        .to_vec()
}

fn fake_sounds_zip() -> Vec<u8> {
    let a = tone(0.2, 100.0);
    let b = tone(0.5, 200.0);
    let c = tone(0.2, 300.0);
    let d = tone(0.2, 400.0);
    let cfg = fake_config();
    raw_zip(
        &[
            ("Sounds/", b""),
            ("Sounds/Fake Kit.txt", &cfg),
            ("Sounds/pad1_fake kit.wav", &a),
            ("Sounds/pad2_fake kit.wav", &b),
            ("Sounds/pad3_fake kit.wav", &c),
            ("Sounds/pad13_fake kit.wav", &d),
            ("Sounds/fake kit.aupreset", b"<plist/>"),
            ("Sounds/.DS_Store", b"junk"),
        ],
        zip::CompressionMethod::Deflated,
    )
}

fn fake_catalog() -> serde_json::Value {
    serde_json::json!({
        "kits": [
            {"id": 7, "name": "Fake Kit", "url": "https://example.invalid/v", "authorName": "Nobody",
             "musicName": "Nothing", "shouldShowRealNames": true, "colorBackground": "10;20;30",
             "isTop": true, "orderTop": 3, "difficulty": "Easy", "createdAt": "2020-01-01T00:00:00.000Z", "isMP3": false,
             "sequence": [[100], [0], [2, 4], [101], [23], [999]]},
            {"id": 8, "name": "Remote Only", "shouldShowRealNames": false, "orderTop": 1}
        ],
        "categories": [
            {"id": "g", "name": "GENRES", "type": 3, "order": 0},
            {"id": "hh", "name": "HIP HOP", "type": 1, "order": 1},
            {"id": "art", "name": "Some Artist", "type": 1, "order": 2},
            {"id": "feat", "name": "FEATURED", "type": 100, "order": 3}
        ],
        "kitCategories": [
            {"kitId": 7, "categoryId": "hh", "order": 0},
            {"kitId": 7, "categoryId": "art", "order": 1},
            {"kitId": 7, "categoryId": "feat", "order": 2},
            {"kitId": 8, "categoryId": "hh", "order": 0}
        ],
        "groupCategories": [{"categoryId": "hh", "groupId": "g"}],
        "detailTimestamp": 0
    })
}

#[test]
fn compat_android_fake_sounds_zip_and_catalog() {
    let (dir, lib) = lib();
    // 1. 单独的 Sounds.zip
    let zip_path = dir.path().join("Sounds.zip");
    std::fs::write(&zip_path, fake_sounds_zip()).unwrap();
    let r = lib.import(&zip_path).unwrap();
    assert_eq!(r.kind, ImportKind::Compat("compat-android".into()));
    assert_eq!(r.kits.len(), 1);
    let doc = lib.kit_doc(&r.kits[0].kit_id).unwrap();
    assert_eq!(doc.name, "Fake Kit");
    assert_eq!(doc.pad_count, 24);
    assert_eq!(doc.license.as_deref(), Some("LicenseRef-Private-Assets"));
    let p1 = doc.pad(PadAddr::from_flat(0)).unwrap();
    assert_eq!(
        (p1.kind, p1.launch.mode),
        (PadKind::OneShot, LaunchMode::Trigger)
    );
    assert_eq!(p1.color, PadColor::Role(ColorRole::Orange));
    assert_eq!((p1.choke_group, p1.choked_by), (Some(1), Some(1)));
    let p2 = doc.pad(PadAddr::from_flat(1)).unwrap();
    assert_eq!(
        (p2.kind, p2.launch.mode),
        (PadKind::Loop, LaunchMode::Toggle)
    );
    assert_eq!(p2.color, PadColor::Role(ColorRole::Blue));
    let p3 = doc.pad(PadAddr::from_flat(2)).unwrap();
    assert_eq!(p3.launch.mode, LaunchMode::Gate);
    let p13 = doc.pad(PadAddr { bank: 1, index: 0 }).unwrap();
    assert_eq!(p13.color, PadColor::Role(ColorRole::Green));
    assert_eq!(p13.note, 48);

    // 2. 素材目录：解包后的 Sounds/ + 目录 list.json → 曲库目录与教程
    let root = dir.path().join("compat-android");
    std::fs::create_dir_all(root.join("audio/kits/fake/Sounds")).unwrap();
    std::fs::create_dir_all(root.join("data")).unwrap();
    let fs = up_library::archive::read_zip(
        std::io::Cursor::new(fake_sounds_zip()),
        "s",
        &ImportLimits::default(),
    )
    .unwrap();
    for (p, b) in &fs.files {
        std::fs::write(root.join("audio/kits/fake").join(p), b).unwrap();
    }
    std::fs::write(
        root.join("data/list.json"),
        serde_json::to_vec(&fake_catalog()).unwrap(),
    )
    .unwrap();
    let other = Library::open(dir.path().join("lib2")).unwrap();
    let r = other.import(&root).unwrap();
    assert_eq!(r.kind, ImportKind::Compat("compat-android".into()));
    assert_eq!(r.catalog_entries, 2);
    let codes: Vec<_> = r.warnings.iter().map(|w| w.code.as_str()).collect();
    assert!(codes.contains(&"compat.tutorial_code"), "{codes:?}");
    let kid = r.kits[0].kit_id.clone();
    let entries = other.catalog_entries(Some("compat-android"));
    assert_eq!(entries.len(), 2);
    let fake = entries.iter().find(|e| e.name == "Fake Kit").unwrap();
    assert_eq!(
        fake.status,
        CatalogStatus::Downloaded {
            kit_id: kid.clone()
        }
    );
    assert_eq!(fake.genres, vec!["Hip Hop"]);
    assert_eq!(fake.tags, vec!["Some Artist"]);
    assert_eq!(fake.theme_color.as_deref(), Some("#0A141E"));
    assert_eq!(fake.difficulty.as_deref(), Some("easy"));
    assert_eq!(fake.inspired_by.as_deref(), Some("Nobody — Nothing"));
    let remote = entries.iter().find(|e| e.name == "Remote Only").unwrap();
    assert_eq!(remote.status, CatalogStatus::NotDownloaded);
    assert!(
        other
            .catalog_categories(None)
            .iter()
            .any(|c| c.name == "HIP HOP" && c.entries.len() == 2)
    );
    let s = other.kit_summary(&kid).unwrap();
    assert_eq!(s.genres, vec!["Hip Hop"]);
    assert_eq!(s.source_kind, "compat-android");
    assert!(s.has_tutorial);
    // 教程：sequence 模式 + chart.mid
    let pkg = other.kit_package(&kid).unwrap();
    let t =
        up_format::tutorial::TutorialDoc::from_slice(&pkg.files["tutorials/compat/tutorial.json"])
            .unwrap();
    assert_eq!(t.mode, up_format::tutorial::TutorialMode::Sequence);
    assert_eq!(t.steps[0].bank.as_deref(), Some("A"));
    assert_eq!(t.steps[1].pads, vec![36]);
    assert_eq!(t.steps[2].pads, vec![37, 38]);
    assert_eq!(t.steps[4].pads, vec![48]);
    let chart = up_format::smf::Chart::from_smf(&pkg.files["tutorials/compat/chart.mid"]).unwrap();
    assert_eq!(chart.notes.len(), 4);
    // 删除后目录条目回到“未下载”，再导入恢复
    other.delete_kit(&kid).unwrap();
    assert_eq!(
        other
            .catalog_entries(None)
            .iter()
            .find(|e| e.name == "Fake Kit")
            .unwrap()
            .status,
        CatalogStatus::NotDownloaded
    );
}

#[test]
fn compat_ios_fake_catalog_lessons_and_timed_tutorial_parsing() {
    // 无法在测试中合成 Ogg Vorbis；这里验证 iOS 来源的探测、目录（fetch.json + difficulty）和
    // “音频解码失败时跳过 pad”的行为。真实 Ogg 转码见 #[ignore] 的私有素材测试。
    let (dir, lib) = lib();
    let root = dir.path().join("ios");
    std::fs::create_dir_all(root.join("initial/sp")).unwrap();
    std::fs::write(
        root.join("initial/sp/fetch.json"),
        serde_json::to_vec(&fake_catalog()).unwrap(),
    )
    .unwrap();
    let z = raw_zip(
        &[
            ("Sounds/Fake Kit.txt", &fake_config()),
            ("Sounds/pad1_fake kit.ogg", b"not really ogg"),
        ],
        zip::CompressionMethod::Deflated,
    );
    std::fs::write(root.join("initial/sp/7.zip"), z).unwrap();
    std::fs::write(
        root.join("initial/sp/7_lesson.json"),
        br#"{"bpm":90,"numberOfLessons":1,"lessons":[{"steps":[{"pad":100,"time":0,"type":"beat"},{"pad":2,"time":0.6666,"type":"beat"}],"duration":2,"midStartTime":0}]}"#,
    )
    .unwrap();
    let r = lib.import(&root).unwrap();
    assert_eq!(r.kind, ImportKind::Compat("compat-ios".into()));
    assert!(r.kits.is_empty());
    assert_eq!(r.catalog_entries, 2);
    let codes: Vec<_> = r.warnings.iter().map(|w| w.code.as_str()).collect();
    assert!(codes.contains(&"compat.decode"), "{codes:?}");
    let e = lib.catalog_entries(Some("compat-ios"));
    assert!(e.iter().all(|e| e.status == CatalogStatus::NotDownloaded));
    assert_eq!(
        e.iter().find(|x| x.name == "Fake Kit").unwrap().extra["isMP3"],
        false
    );
}

/// 用真实的私有素材包跑一次（私有素材不在仓库中；存在时手动运行：
/// `cargo test -p up-library -- --ignored real_`）。
#[test]
#[ignore = "需要 private-assets/compat-android（不入库的私有素材）"]
fn real_compat_android_assets() {
    let root = repo_root().join("private-assets/compat-android");
    if !root.exists() {
        eprintln!("跳过：没有 {}", root.display());
        return;
    }
    let (_dir, lib) = lib();
    // 真实的 initialpack.zip（res/raw）
    let pack = root.join("raw/apk/res/raw/initialpack.zip");
    if pack.exists() {
        let r = lib.import(&pack).unwrap();
        assert_eq!(r.kits[0].name, "Sunset");
        assert_eq!(r.kits[0].pads_used, 12);
    }
    let r = lib.import(&root).unwrap();
    println!(
        "{} 个 Kit，{} 个目录条目，{} 条警告",
        r.kits.len(),
        r.catalog_entries,
        r.warnings.len()
    );
    assert!(r.catalog_entries >= 400);
    // 取本次目录导入的 Sunset（上面 initialpack.zip 单独导入的那份没有目录 ID，也没有教程）。
    let sunset_id = &r.kits.iter().find(|k| k.name == "Sunset").unwrap().kit_id;
    let sunset = lib.kit_summary(sunset_id).unwrap();
    assert!(sunset.has_tutorial);
    let loaded = lib.load_kit_assets(&sunset.id).unwrap();
    assert_eq!(loaded.samples.len(), 12);
    let loops = loaded
        .doc
        .pads
        .iter()
        .filter(|p| p.kind == PadKind::Loop)
        .count();
    assert_eq!(loops, 4);
}

#[test]
#[ignore = "需要 private-assets/compat-ios（不入库的私有素材）"]
fn real_compat_ios_assets() {
    let root = repo_root().join("private-assets/compat-ios");
    if !root.exists() {
        eprintln!("跳过：没有 {}", root.display());
        return;
    }
    let (_dir, lib) = lib();
    let r = lib.import(&root).unwrap();
    println!(
        "{} 个 Kit，{} 个目录条目，警告：{:?}",
        r.kits.len(),
        r.catalog_entries,
        r.warnings
    );
    assert_eq!(r.kind, ImportKind::Compat("compat-ios".into()));
    assert_eq!(r.kits.len(), 6, "内置 6 个 Kit 应全部导入");
    assert!(r.catalog_entries >= 1000);
    for k in &r.kits {
        let loaded = lib.load_kit_assets(&k.kit_id).unwrap();
        assert!(
            loaded.samples.values().all(|s| s.pcm.is_some()),
            "{}",
            k.name
        );
        let s = lib.kit_summary(&k.kit_id).unwrap();
        assert!(s.has_tutorial, "{} 应带教程", k.name);
        let t = loaded.model.tutorial.as_ref().unwrap();
        println!(
            "{}: 曲风 {:?} 标签 {:?} 教程事件 {} 分课 {}",
            k.name,
            s.genres,
            s.tags,
            t.events.len(),
            t.lessons.len()
        );
    }
    let easy: Vec<_> = lib
        .catalog_entries(Some("compat-ios"))
        .into_iter()
        .filter(|e| matches!(e.status, CatalogStatus::Downloaded { .. }))
        .collect();
    assert_eq!(easy.len(), 6);
    let medium = easy
        .iter()
        .filter(|e| e.difficulty.as_deref() == Some("medium"))
        .count();
    println!("已下载目录条目中 difficulty=medium 的有 {medium} 个");
}

#[test]
fn import_rejects_unknown_sources() {
    let (dir, lib) = lib();
    let empty = dir.path().join("empty");
    std::fs::create_dir_all(&empty).unwrap();
    std::fs::write(empty.join("readme.md"), b"x").unwrap();
    assert!(matches!(
        lib.import(&empty),
        Err(LibraryError::UnsupportedSource(_))
    ));
    let f = dir.path().join("x.mp4");
    std::fs::write(&f, b"x").unwrap();
    assert!(matches!(
        lib.import(&f),
        Err(LibraryError::UnsupportedSource(_))
    ));
}

#[test]
fn library_index_matches_schema() {
    let (dir, lib) = lib();
    let id = lib
        .import(repo_root().join("content/kits/ultrapads-starter.upkit"))
        .unwrap()
        .kits[0]
        .kit_id
        .clone();
    lib.set_favorite(&id, true).unwrap();
    lib.mark_used(&id).unwrap();
    lib.add_sample(&tone(0.1, 440.0), "s", SampleOrigin::Microphone)
        .unwrap();
    lib.track_add(&tone(0.1, 220.0), "t", Some(&id), None)
        .unwrap();
    let zip_path = dir.path().join("Sounds.zip");
    std::fs::write(&zip_path, fake_sounds_zip()).unwrap();
    let root = dir.path().join("sp");
    std::fs::create_dir_all(&root).unwrap();
    std::fs::copy(&zip_path, root.join("initialpack.zip")).unwrap();
    std::fs::write(
        root.join("list.json"),
        serde_json::to_vec(&fake_catalog()).unwrap(),
    )
    .unwrap();
    lib.import(&root).unwrap();
    lib.delete_kit(&id).unwrap();
    let schema: serde_json::Value = serde_json::from_slice(
        &std::fs::read(repo_root().join("content/schema/library-1.schema.json")).unwrap(),
    )
    .unwrap();
    let v = jsonschema::validator_for(&schema).unwrap();
    let index: serde_json::Value =
        serde_json::from_slice(&std::fs::read(lib.root().join("library.json")).unwrap()).unwrap();
    let errors: Vec<String> = v.iter_errors(&index).map(|e| e.to_string()).collect();
    assert!(errors.is_empty(), "{errors:#?}");
}

#[test]
fn model_roundtrip_through_library() {
    let (_dir, lib) = lib();
    let id = lib
        .import(repo_root().join("content/kits/ultrapads-starter.upkit"))
        .unwrap()
        .kits[0]
        .kit_id
        .clone();
    let loaded = lib.load_kit_assets(&id).unwrap();
    let m = &loaded.model;
    assert_eq!(m.pads.len(), 12);
    let tut = m
        .tutorial
        .as_ref()
        .expect("first-beat 教程转成 TutorialChart");
    assert!(tut.timed && !tut.events.is_empty());
    for p in &m.pads {
        let s = p.sample.as_ref().unwrap();
        assert!(
            loaded
                .samples
                .values()
                .any(|ls| ls.sample_id == s.id.as_str())
        );
        assert!(s.frames.is_some());
    }
    assert!(m.validate().is_ok());
    // 原样保存不改变内容
    let before = lib.kit_summary(&id).unwrap().content_blake3;
    lib.save_kit_model(m).unwrap();
    assert_eq!(lib.kit_summary(&id).unwrap().content_blake3, before);
    // 编辑：换采样、改模式
    let mic = lib
        .add_sample(&tone(0.2, 330.0), "mic", SampleOrigin::Microphone)
        .unwrap();
    let mut edited = lib.kit_model(&id).unwrap();
    edited.pads[0].sample = Some(up_model::SampleRef {
        id: up_core::SampleId::new(mic.id.clone()),
        name: "mic".into(),
        blake3: Some(mic.id.clone()),
        ..Default::default()
    });
    edited.pads[0].mode = up_core::PadMode::Gate;
    lib.save_kit_model(&edited).unwrap();
    let doc = lib.kit_doc(&id).unwrap();
    let p = doc.pad(PadAddr::from_flat(0)).unwrap();
    assert_eq!(p.launch.mode, LaunchMode::Gate);
    assert_eq!(p.layers[0].sample_id.as_deref(), Some(mic.id.as_str()));
    assert_eq!(lib.kit_summary(&id).unwrap().to_protocol().pad_count, 12);
}

/// 同一个包在两台设备（两个曲库）上导入得到同一个 ID 和同样的 manifest，
/// 多设备同步时不会被当成并发修改而产生冲突副本。
#[test]
fn same_package_imports_identically_on_two_devices() {
    let (_a_dir, a) = lib();
    let (_b_dir, b) = lib();
    let pkg = repo_root().join("content/kits/ultrapads-starter.upkit");
    let ra = a.import(&pkg).unwrap();
    std::thread::sleep(std::time::Duration::from_millis(1100));
    let rb = b.import(&pkg).unwrap();
    let (ia, ib) = (&ra.kits[0].kit_id, &rb.kits[0].kit_id);
    assert_eq!(ia, ib);
    assert_eq!(a.kit_manifest(ia).unwrap(), b.kit_manifest(ib).unwrap());
}
