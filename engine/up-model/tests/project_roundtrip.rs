use up_core::{Bank, KitId, PadId, SampleId};
use up_model::arrangement::*;
use up_model::blob::Blob;
use up_model::link::LinkSettings;
use up_model::midi::*;
use up_model::mixer::*;
use up_model::pattern::*;
use up_model::project::*;
use up_model::session::*;
use up_model::*;

fn full_project() -> Project {
    let kit = KitDoc {
        id: KitId::new("kit-1"),
        name: "Demo".into(),
        pads: vec![PadDoc::new(PadId { bank: 0, index: 0 })],
        tutorial: Some(TutorialChart {
            events: vec![
                TutorialEvent {
                    time_secs: 0.0,
                    target: TutorialTarget::Page { bank: Bank::A },
                    color: None,
                    action: TutorialAction::Tap,
                },
                TutorialEvent {
                    time_secs: 1.5,
                    target: TutorialTarget::Pad {
                        pad: PadId { bank: 0, index: 0 },
                    },
                    color: Some(up_core::ColorRole::Blue),
                    action: TutorialAction::LoopToggle,
                },
            ],
            timed: true,
            ..Default::default()
        }),
        ..Default::default()
    };
    Project {
        id: "proj-1".into(),
        name: "Song".into(),
        kits: vec![
            KitRef::Embedded { kit: Box::new(kit) },
            KitRef::Library {
                id: KitId::new("lib"),
            },
        ],
        session: Session {
            tracks: vec![SessionTrack {
                id: "t1".into(),
                name: "Pads".into(),
                kind: TrackKind::Pads,
                channel: Some("ch1".into()),
                kit: Some(KitId::new("kit-1")),
                slots: vec![
                    ClipSlot {
                        clip: Some(Clip {
                            id: "c1".into(),
                            name: "Beat".into(),
                            content: ClipContent::Pattern {
                                pattern: "p1".into(),
                            },
                            length_beats: 4.0,
                            looping: true,
                            launch: LaunchSettings {
                                mode: LaunchMode::Toggle,
                                quantize: LaunchQuantize::Bar,
                                follow_action: Some(FollowAction {
                                    after_beats: 16.0,
                                    action: FollowActionKind::Next,
                                    chance: 1.0,
                                }),
                            },
                            color: None,
                        }),
                        has_stop: true,
                    },
                    ClipSlot::default(),
                ],
            }],
            scenes: vec![Scene {
                id: "s1".into(),
                name: "Intro".into(),
                tempo: None,
            }],
            ..Default::default()
        },
        patterns: vec![Pattern {
            id: "p1".into(),
            name: "P1".into(),
            lanes: vec![PatternLane {
                pad: PadId { bank: 0, index: 0 },
                steps: vec![Step::on(1.0), Step::default(), Step::on(0.5)],
                muted: false,
            }],
            ..Default::default()
        }],
        arrangement: Arrangement {
            tracks: vec![ArrangementTrack {
                id: "at1".into(),
                name: "Audio".into(),
                channel: Some("ch1".into()),
                clips: vec![ArrangementClip {
                    id: "ac1".into(),
                    start_beats: 0.0,
                    length_beats: 8.0,
                    offset_beats: 0.0,
                    content: ClipContent::Audio {
                        sample: SampleId::new("smp"),
                        warp: false,
                    },
                    muted: false,
                    gain: None,
                }],
                automation: vec![AutomationLane {
                    id: "l1".into(),
                    target: ParamTarget::ChannelGain {
                        channel: "ch1".into(),
                    },
                    points: vec![AutomationPoint {
                        beat: 0.0,
                        value: 0.5,
                        curve: CurveKind::Linear,
                        tension: 0.0,
                    }],
                    enabled: true,
                }],
            }],
            loop_region: Some((0.0, 16.0)),
            ..Default::default()
        },
        mixer: Mixer {
            channels: vec![Channel {
                id: "ch1".into(),
                name: "Pads".into(),
                input: ChannelInput::Kit {
                    kit: KitId::new("kit-1"),
                },
                sends: vec![SendDoc {
                    id: "s1".into(),
                    bus: "rev".into(),
                    level_db: -12.0,
                    pre_fader: false,
                }],
                effects: EffectChain {
                    slots: vec![
                        PluginSlot {
                            id: "eq".into(),
                            kind: PluginKind::Builtin { name: "eq3".into() },
                            enabled: true,
                            mix: 1.0,
                            params: vec![],
                            state: None,
                            display_name: None,
                        },
                        PluginSlot {
                            id: "comp".into(),
                            kind: PluginKind::Clap {
                                id: "com.vendor.comp".into(),
                                version: Some("1.2".into()),
                            },
                            enabled: true,
                            mix: 0.8,
                            params: vec![ParamValue { id: 1, value: 0.25 }],
                            state: Some(Blob(b"clap-state".to_vec())),
                            display_name: Some("Comp".into()),
                        },
                    ],
                },
                ..Default::default()
            }],
            buses: vec![Bus {
                id: "rev".into(),
                name: "Reverb".into(),
                ..Default::default()
            }],
            master: MasterChannel::default(),
        },
        midi: MidiSettings {
            bindings: vec![MidiBinding {
                source: MidiSource {
                    device: None,
                    channel: None,
                    message: MidiMessageKind::ControlChange { cc: 7 },
                },
                target: MidiTarget::Param {
                    target: ParamTarget::MasterGain,
                    min: 0.0,
                    max: 1.0,
                },
                velocity_curve: VelocityCurve::Linear,
            }],
            ..Default::default()
        },
        link: LinkSettings {
            enabled: true,
            ..Default::default()
        },
        ..Default::default()
    }
}

#[test]
fn project_json_roundtrip() {
    let p = full_project();
    p.mixer.validate().unwrap();
    let json = p.to_json().unwrap();
    assert!(json.contains("\"schemaVersion\": 1"));
    let back = Project::from_json(&json).unwrap();
    assert_eq!(back, p);
}

#[test]
fn minimal_project_uses_defaults() {
    let p = Project::from_json(r#"{"name":"Empty"}"#).unwrap();
    assert_eq!(p.schema_version, PROJECT_SCHEMA_VERSION);
    assert_eq!(p.tempo.bpm, 120.0);
    assert!(!p.link.enabled);
    assert_eq!(p.session.global_quantize, LaunchQuantize::Bar);
}
