//! Tutorial charts (Ref 4.7.0 semantics, see
//! docs/research/compat-ipa-4.7.0-analysis.md §7.2).
//!
//! A chart is a time line of events. **Time unit: song seconds at speed
//! 1.0** (`time_secs`). When the user slows the tutorial down (speed 0.7 /
//! 0.5), the engine's transport runs slower and its song clock
//! (`TransportClock::song_secs`) advances at `speed × real time`, so
//! comparing an event's `time_secs` with the song clock at the moment of
//! the press is speed-independent. Judgement windows are in real-time
//! milliseconds.

use serde::{Deserialize, Serialize};
use up_core::{Bank, ColorRole, PadId};

/// What the user must do.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum TutorialTarget {
    Pad {
        pad: PadId,
    },
    /// Switch to the given bank (Ref codes 100 / 101).
    Page {
        bank: Bank,
    },
}

/// Kind of press (Ref `state`: 0 = start/toggle a loop, 1 = tap).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TutorialAction {
    #[default]
    Tap,
    LoopToggle,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TutorialEvent {
    /// Song time (seconds at speed 1.0) at which the press is expected.
    pub time_secs: f64,
    pub target: TutorialTarget,
    #[serde(default)]
    pub color: Option<ColorRole>,
    #[serde(default)]
    pub action: TutorialAction,
}

/// A lesson: a slice of the song practised on its own.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TutorialLesson {
    /// Event times are relative to the lesson start.
    pub events: Vec<TutorialEvent>,
    pub duration_secs: f64,
    /// Lesson start within the whole song.
    pub song_start_secs: f64,
}

/// Judgement window (real-time milliseconds).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct JudgeWindow {
    /// |error| ≤ this → Perfect.
    pub perfect_ms: f64,
    /// |error| beyond this → Miss (ignored as a hit).
    pub miss_ms: f64,
}

impl Default for JudgeWindow {
    fn default() -> Self {
        Self {
            perfect_ms: 80.0,
            miss_ms: 600.0,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Judgement {
    Perfect,
    /// Pressed too early.
    TooFast,
    /// Pressed too late.
    TooSlow,
    Miss,
}

impl JudgeWindow {
    /// Judge a press at song time `actual` against `expected` (both song
    /// seconds). `speed` converts song time to real time.
    pub fn judge(&self, expected: f64, actual: f64, speed: f64) -> Judgement {
        let err_ms = (actual - expected) / speed.max(1e-6) * 1000.0;
        if err_ms.abs() <= self.perfect_ms {
            Judgement::Perfect
        } else if err_ms.abs() > self.miss_ms {
            Judgement::Miss
        } else if err_ms < 0.0 {
            Judgement::TooFast
        } else {
            Judgement::TooSlow
        }
    }
}

/// Tutorial chart.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TutorialChart {
    /// Sorted by `time_secs`.
    pub events: Vec<TutorialEvent>,
    pub lessons: Vec<TutorialLesson>,
    pub bpm: Option<f64>,
    pub judge: JudgeWindow,
    /// `false` for compat (Ref 3.x) order-only charts: event times
    /// are then just 1 s apart and only the order matters.
    pub timed: bool,
}

fn compat_target(pad: i64) -> Option<TutorialTarget> {
    match pad {
        100 => Some(TutorialTarget::Page { bank: Bank::A }),
        101 => Some(TutorialTarget::Page { bank: Bank::B }),
        1..=24 => PadId::from_flat((pad - 1) as usize).map(|pad| TutorialTarget::Pad { pad }),
        _ => None,
    }
}

fn compat_color(c: &str) -> Option<ColorRole> {
    match c {
        "orange" => Some(ColorRole::Orange),
        "blue" => Some(ColorRole::Blue),
        "pink" => Some(ColorRole::Pink),
        "green" => Some(ColorRole::Green),
        "purple" => Some(ColorRole::Purple),
        _ => ColorRole::from_compat_name(c),
    }
}

#[derive(Deserialize)]
struct SpEvent {
    time: f64,
    pad: i64,
    #[serde(default)]
    color: Option<String>,
    #[serde(default)]
    state: Option<i64>,
}

#[derive(Deserialize)]
struct SpLessonStep {
    pad: i64,
    time: f64,
}

#[derive(Deserialize)]
struct SpLesson {
    #[serde(default)]
    steps: Vec<SpLessonStep>,
    #[serde(default)]
    duration: f64,
    #[serde(default, rename = "midStartTime")]
    mid_start_time: f64,
}

#[derive(Deserialize)]
struct SpLessons {
    #[serde(default)]
    bpm: Option<f64>,
    #[serde(default)]
    lessons: Vec<SpLesson>,
}

/// Ref 3.x note code → flat pad index.
fn compat_code_to_flat(code: i32) -> Option<usize> {
    const A: [i32; 12] = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19];
    if let Some(i) = A.iter().position(|c| *c == code) {
        return Some(i);
    }
    if (23..=34).contains(&code) {
        return Some(12 + (code - 23) as usize);
    }
    None
}

impl TutorialChart {
    pub fn is_empty(&self) -> bool {
        self.events.is_empty() && self.lessons.is_empty()
    }

    /// Total length (last event time).
    pub fn duration_secs(&self) -> f64 {
        self.events.last().map_or(0.0, |e| e.time_secs)
    }

    fn sort(&mut self) {
        self.events
            .sort_by(|a, b| a.time_secs.total_cmp(&b.time_secs));
        for l in &mut self.lessons {
            l.events.sort_by(|a, b| a.time_secs.total_cmp(&b.time_secs));
        }
    }

    /// Parse Ref 4.x `tutorial.json` (`[{time, pad, color, state}]`).
    pub fn from_compat_tutorial(json: &str) -> Result<Self, up_core::UpError> {
        let raw: Vec<SpEvent> =
            serde_json::from_str(json).map_err(|e| up_core::UpError::format(e.to_string()))?;
        let mut chart = Self {
            timed: true,
            ..Default::default()
        };
        for e in raw {
            let Some(target) = compat_target(e.pad) else {
                continue;
            };
            if !e.time.is_finite() {
                continue;
            }
            chart.events.push(TutorialEvent {
                time_secs: e.time.max(0.0),
                target,
                color: e.color.as_deref().and_then(compat_color),
                action: if e.state == Some(0) {
                    TutorialAction::LoopToggle
                } else {
                    TutorialAction::Tap
                },
            });
        }
        chart.sort();
        Ok(chart)
    }

    /// Merge Ref `<id>_lesson.json`
    /// (`{bpm, lessons:[{steps:[{pad,time,type}], duration, midStartTime}]}`).
    pub fn add_compat_lessons(&mut self, json: &str) -> Result<(), up_core::UpError> {
        let raw: SpLessons =
            serde_json::from_str(json).map_err(|e| up_core::UpError::format(e.to_string()))?;
        if raw.bpm.is_some() {
            self.bpm = raw.bpm;
        }
        for l in raw.lessons {
            self.lessons.push(TutorialLesson {
                events: l
                    .steps
                    .iter()
                    .filter_map(|s| {
                        Some(TutorialEvent {
                            time_secs: s.time,
                            target: compat_target(s.pad)?,
                            color: None,
                            action: TutorialAction::Tap,
                        })
                    })
                    .collect(),
                duration_secs: l.duration,
                song_start_secs: l.mid_start_time,
            });
        }
        self.sort();
        Ok(())
    }

    /// Convert Ref 3.x `Kit.sequence` (order-only steps of note
    /// codes; 100/101 = page A/B). Steps are placed 1 s apart and the chart
    /// is marked `timed = false`.
    pub fn from_compat_sequence(seq: &[Vec<i32>]) -> Self {
        let mut chart = Self::default();
        for (i, codes) in seq.iter().enumerate() {
            let t = i as f64;
            for &c in codes {
                let target = match c {
                    100 => Some(TutorialTarget::Page { bank: Bank::A }),
                    101 => Some(TutorialTarget::Page { bank: Bank::B }),
                    _ => compat_code_to_flat(c)
                        .and_then(PadId::from_flat)
                        .map(|pad| TutorialTarget::Pad { pad }),
                };
                if let Some(target) = target {
                    chart.events.push(TutorialEvent {
                        time_secs: t,
                        target,
                        color: None,
                        action: TutorialAction::Tap,
                    });
                }
            }
        }
        chart
    }

    /// Parse either the native format (object) or Ref 4.x (array).
    pub fn from_json_any(json: &str) -> Result<Self, up_core::UpError> {
        let trimmed = json.trim_start();
        if trimmed.starts_with('[') {
            Self::from_compat_tutorial(json)
        } else {
            let mut c: Self =
                serde_json::from_str(json).map_err(|e| up_core::UpError::format(e.to_string()))?;
            c.sort();
            Ok(c)
        }
    }

    /// Events in `[from, to)` song seconds (binary search on sorted events).
    pub fn events_between(&self, from: f64, to: f64) -> &[TutorialEvent] {
        let a = self.events.partition_point(|e| e.time_secs < from);
        let b = self.events.partition_point(|e| e.time_secs < to);
        &self.events[a..b.max(a)]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_compat_4_tutorial() {
        let json = r#"[
            {"time": 3.0, "pad": 8, "color": "blue", "state": 0},
            {"time": 0.0, "pad": 100, "color": "page", "state": 1},
            {"time": 1.5, "pad": 13, "color": "orange", "state": 1},
            {"time": 2.0, "pad": 999, "color": "x", "state": 1}
        ]"#;
        let c = TutorialChart::from_compat_tutorial(json).unwrap();
        assert!(c.timed);
        assert_eq!(c.events.len(), 3);
        assert_eq!(c.events[0].target, TutorialTarget::Page { bank: Bank::A });
        assert_eq!(
            c.events[1].target,
            TutorialTarget::Pad {
                pad: PadId { bank: 1, index: 0 }
            }
        );
        assert_eq!(c.events[1].color, Some(ColorRole::Orange));
        assert_eq!(c.events[2].action, TutorialAction::LoopToggle);
        assert_eq!(c.events_between(1.0, 3.0).len(), 1);
        assert_eq!(c.duration_secs(), 3.0);
        let native = serde_json::to_string(&c).unwrap();
        assert_eq!(TutorialChart::from_json_any(&native).unwrap(), c);
        assert_eq!(TutorialChart::from_json_any(json).unwrap(), c);
    }

    #[test]
    fn lessons_and_compat() {
        let mut c = TutorialChart::default();
        c.add_compat_lessons(
            r#"{"bpm":90,"numberOfLessons":1,"lessons":[{"steps":[{"pad":1,"time":1.333,"type":"beat"},{"pad":2,"time":0.0,"type":"beat"}],"duration":8.0,"midStartTime":16.0}]}"#,
        )
        .unwrap();
        assert_eq!(c.bpm, Some(90.0));
        assert_eq!(c.lessons[0].events[0].time_secs, 0.0);
        assert_eq!(c.lessons[0].song_start_secs, 16.0);
        let compat = TutorialChart::from_compat_sequence(&[vec![100], vec![0, 19], vec![23]]);
        assert!(!compat.timed);
        assert_eq!(compat.events.len(), 4);
        assert_eq!(
            compat.events[2].target,
            TutorialTarget::Pad {
                pad: PadId { bank: 0, index: 11 }
            }
        );
        assert_eq!(compat.events[3].time_secs, 2.0);
    }

    #[test]
    fn judgement_windows_scale_with_speed() {
        let j = JudgeWindow::default();
        assert_eq!(j.judge(10.0, 10.05, 1.0), Judgement::Perfect);
        assert_eq!(j.judge(10.0, 9.85, 1.0), Judgement::TooFast);
        assert_eq!(j.judge(10.0, 10.2, 1.0), Judgement::TooSlow);
        assert_eq!(j.judge(10.0, 12.0, 1.0), Judgement::Miss);
        // At half speed 50 ms of song time = 100 ms real time → too slow.
        assert_eq!(j.judge(10.0, 10.05, 0.5), Judgement::TooSlow);
    }
}
