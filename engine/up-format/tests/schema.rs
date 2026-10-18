//! 用 content/schema/ 中的 JSON Schema 校验 up-format 的 serde 输出，确保 Schema 与代码一致。

use std::collections::BTreeMap;

use serde_json::Value;
use up_format::kit::{
    ColorRole, KitDoc, KitTempo, Launch, LaunchMode, LoopTempo, PadAddr, PadColor, PadDoc, PadKind,
    Quantize, SampleLayer, Stretch, TutorialRef,
};
use up_format::tutorial::{TutorialDoc, TutorialMode, TutorialStep};
use up_format::upkit::{BuildOptions, UpkitPackage};
use up_format::{kit_json, manifest, wav};

fn schema(name: &str) -> jsonschema::Validator {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../content/schema")
        .join(name);
    let text = std::fs::read_to_string(&path).unwrap();
    let value: Value = serde_json::from_str(&text).unwrap();
    jsonschema::validator_for(&value).unwrap()
}

fn assert_valid(v: &jsonschema::Validator, instance: &Value) {
    let errors: Vec<String> = v.iter_errors(instance).map(|e| e.to_string()).collect();
    assert!(errors.is_empty(), "{errors:#?}\n{instance:#}");
}

fn doc() -> (KitDoc, BTreeMap<String, Vec<u8>>) {
    let mut d = KitDoc::new(
        "urn:uuid:0192f0c0-0000-7000-8000-000000000002",
        "Schema Kit",
    );
    d.pad_count = 24;
    d.genres = vec!["electronic".into()];
    d.license = Some("CC0-1.0".into());
    d.tempo = Some(KitTempo {
        bpm: 120.0,
        time_signature: [4, 4],
    });
    d.tutorials = vec![TutorialRef {
        id: "t".into(),
        path: "tutorials/t/tutorial.json".into(),
    }];
    let mut p = PadDoc::new(PadAddr::from_flat(0));
    p.name = Some("Kick".into());
    p.layers.push(SampleLayer::new("samples/kick.wav"));
    let mut l = PadDoc::new(PadAddr::from_flat(12));
    l.kind = PadKind::Loop;
    l.color = PadColor::Hex("#3FA7FF".into());
    l.launch = Launch {
        mode: LaunchMode::Toggle,
        quantize: Quantize::Bar,
        ..Launch::default()
    };
    l.tempo = Some(LoopTempo {
        bpm: 120.0,
        beats: Some(8.0),
        time_signature: [4, 4],
        stretch: Stretch::Beats,
    });
    l.layers.push(SampleLayer::new("samples/loop.wav"));
    let mut g = PadDoc::new(PadAddr::from_flat(1));
    g.color = PadColor::Role(ColorRole::Green);
    d.pads = vec![p, l, g];
    let mut assets = BTreeMap::new();
    let w = wav::encode_pcm16(1, 44_100, &[0.0; 100]);
    assets.insert("samples/kick.wav".to_string(), w.clone());
    assets.insert("samples/loop.wav".to_string(), w);
    assets.insert(
        "tutorials/t/tutorial.json".to_string(),
        b"{\"id\":\"t\"}".to_vec(),
    );
    (d, assets)
}

#[test]
fn generated_kit_json_and_manifest_match_schema() {
    let (d, assets) = doc();
    let pkg = UpkitPackage::build(&d, assets, &BuildOptions::default()).unwrap();
    let kit: Value = serde_json::from_slice(&pkg.files[kit_json::FILE_NAME]).unwrap();
    assert_valid(&schema("ultrapads-kit-1.schema.json"), &kit);
    let m: Value = serde_json::from_slice(&pkg.files[manifest::FILE_NAME]).unwrap();
    assert_valid(&schema("manifest-1.schema.json"), &m);
}

#[test]
fn spec_examples_match_schema() {
    let kit = serde_json::json!({
      "$schema": "https://ultrapads.dev/schema/kit-1.json",
      "formatVersion": "1.0.0",
      "sfz": "kit.sfz",
      "layout": { "padCount": 24, "grid": [4, 3], "banks": ["A", "B"] },
      "pads": [
        { "note": 36, "bank": "A", "index": 0, "name": "Kick", "color": "#FF5A36", "icon": "kick" },
        { "note": 48, "bank": "B", "index": 0, "name": "Groove", "color": "#3FA7FF", "kind": "loop",
          "launch": { "mode": "toggle", "quantize": "1bar", "retrigger": "restart" },
          "tempo": { "bpm": 92.0, "beats": 16, "timeSignature": [4, 4], "stretch": "beats" },
          "exclusive": "loops-B" }
      ],
      "defaults": { "oneShot": { "launch": { "mode": "trigger", "quantize": "none" } } },
      "tutorials": [ { "id": "first-beat", "path": "tutorials/first-beat/tutorial.json" } ],
      "skin": "skin/theme.json"
    });
    let v = schema("ultrapads-kit-1.schema.json");
    assert_valid(&v, &kit);
    // 路径穿越与非法颜色必须被 Schema 拒绝
    let mut bad = kit.clone();
    bad["skin"] = Value::String("../../etc/passwd".into());
    assert!(!v.is_valid(&bad));
    let mut bad = kit;
    bad["pads"][0]["color"] = Value::String("magenta-ish".into());
    assert!(!v.is_valid(&bad));
}

#[test]
fn tutorial_matches_schema() {
    let t = TutorialDoc {
        id: "seq".into(),
        title: BTreeMap::from([("en".into(), "Sequence".into())]),
        mode: TutorialMode::Sequence,
        chart: Some("chart.mid".into()),
        tempo: None,
        judge: None,
        video_url: None,
        steps: vec![
            TutorialStep {
                from_bar: None,
                to_bar: None,
                hint: BTreeMap::new(),
                pads: vec![],
                bank: Some("A".into()),
                loop_: false,
            },
            TutorialStep {
                from_bar: Some(1),
                to_bar: Some(2),
                hint: BTreeMap::from([("zh-CN".into(), "按 Kick".into())]),
                pads: vec![36, 42],
                bank: None,
                loop_: true,
            },
        ],
        extra: Default::default(),
    };
    let v: Value = serde_json::from_slice(&t.to_vec_pretty()).unwrap();
    assert_valid(&schema("tutorial-1.schema.json"), &v);
}
