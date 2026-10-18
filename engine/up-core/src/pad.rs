use crate::{PAD_COUNT, PADS_PER_BANK, UpError};
use serde::{Deserialize, Serialize};
use std::fmt;

/// Pad bank (page).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Bank {
    A,
    B,
}

impl Bank {
    pub fn index(self) -> u8 {
        match self {
            Bank::A => 0,
            Bank::B => 1,
        }
    }
    pub fn from_index(i: u8) -> Option<Self> {
        match i {
            0 => Some(Bank::A),
            1 => Some(Bank::B),
            _ => None,
        }
    }
}

/// Pad address. `bank`: sound group 0 = A, 1 = B … 6 = G; `index`: 0..12.
/// Flat index = `bank * 12 + index`.
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Default, Serialize, Deserialize,
)]
pub struct PadId {
    pub bank: u8,
    pub index: u8,
}

impl PadId {
    /// Construct a validated pad id.
    pub fn new(bank: u8, index: u8) -> Result<Self, UpError> {
        if bank as usize >= crate::BANK_COUNT || index as usize >= PADS_PER_BANK {
            return Err(UpError::invalid(format!(
                "pad out of range: bank={bank} index={index}"
            )));
        }
        Ok(Self { bank, index })
    }

    /// Flat index `0..PAD_COUNT`.
    #[inline]
    pub const fn flat(self) -> usize {
        self.bank as usize * PADS_PER_BANK + self.index as usize
    }

    /// Inverse of [`PadId::flat`]. Returns `None` when out of range.
    #[inline]
    pub const fn from_flat(flat: usize) -> Option<Self> {
        if flat >= PAD_COUNT {
            return None;
        }
        Some(Self {
            bank: (flat / PADS_PER_BANK) as u8,
            index: (flat % PADS_PER_BANK) as u8,
        })
    }

    /// True if bank/index are in range.
    #[inline]
    pub const fn is_valid(self) -> bool {
        (self.bank as usize) < crate::BANK_COUNT && (self.index as usize) < PADS_PER_BANK
    }

    /// Iterate all [`PAD_COUNT`] pads in flat order.
    pub fn all() -> impl Iterator<Item = PadId> {
        (0..PAD_COUNT).filter_map(PadId::from_flat)
    }

    /// Default MIDI note mapping (`36 + flat`, capped at 127), see
    /// docs/research/kit-and-project-formats.md.
    pub const fn default_note(self) -> u8 {
        let n = 36 + self.flat();
        if n > 127 { 127 } else { n as u8 }
    }

    /// Group letter: 0 → `A` … 6 → `G`.
    pub const fn bank_letter(self) -> char {
        (b'A' + self.bank) as char
    }

    /// Parse labels such as `A0`, `b11`, `C3`, or a flat number.
    pub fn parse(s: &str) -> Result<Self, UpError> {
        let s = s.trim();
        let bad = || UpError::invalid(format!("invalid pad label: {s:?}"));
        let mut chars = s.chars();
        match chars.next() {
            Some(c) if c.is_ascii_alphabetic() => {
                let bank = c.to_ascii_uppercase() as u8 - b'A';
                let index: u8 = chars.as_str().parse().map_err(|_| bad())?;
                PadId::new(bank, index)
            }
            Some(_) => {
                let flat: usize = s.parse().map_err(|_| bad())?;
                PadId::from_flat(flat).ok_or_else(bad)
            }
            None => Err(bad()),
        }
    }
}

impl fmt::Display for PadId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}{}", self.bank_letter(), self.index)
    }
}

/// Pad playback behaviour. Matches the compat kit config `behaviour` codes 100/200/300.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
pub enum PadMode {
    /// Press plays the sample once from the start; re-press retriggers (code 200).
    #[default]
    OneShot,
    /// Press toggles a looping playback on/off (code 100).
    Loop,
    /// Plays while held, stops on release (code 300).
    Gate,
}

impl PadMode {
    /// Map a compat kit config `behaviour` code.
    pub fn from_compat_code(code: i32) -> Option<Self> {
        match code {
            100 => Some(PadMode::Loop),
            200 => Some(PadMode::OneShot),
            300 => Some(PadMode::Gate),
            _ => None,
        }
    }
}

/// Launch quantization grid. A beat is a quarter note.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
pub enum Quantize {
    /// Start immediately (default).
    #[default]
    None,
    /// Next 1/16 note.
    Sixteenth,
    /// Next 1/8 note.
    Eighth,
    /// Next beat (quarter note).
    Beat,
    /// Next bar boundary.
    Bar,
    /// Next 2-bar boundary.
    TwoBars,
    /// Next 4-bar boundary.
    FourBars,
}

impl Quantize {
    /// Grid length in beats for a bar of `bar_len_beats`; `None` = no grid.
    pub fn grid_beats(self, bar_len_beats: f64) -> Option<f64> {
        match self {
            Quantize::None => None,
            Quantize::Sixteenth => Some(0.25),
            Quantize::Eighth => Some(0.5),
            Quantize::Beat => Some(1.0),
            Quantize::Bar => Some(bar_len_beats),
            Quantize::TwoBars => Some(2.0 * bar_len_beats),
            Quantize::FourBars => Some(4.0 * bar_len_beats),
        }
    }
}

/// What a re-press of a playing one-shot/gate pad does.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
pub enum Retrigger {
    /// Restart from the start (default).
    #[default]
    Restart,
    /// Ignore the press while the pad is still playing.
    Continue,
}

/// Pad playback state machine as observed by the UI.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
pub enum PadPlayState {
    #[default]
    Idle,
    /// Armed and waiting for the next quantize boundary.
    Pending,
    Playing,
    /// Scheduled to stop (waiting for boundary) or fading out.
    Stopping,
}

/// Semantic color role of a pad. Resolved to an actual color by the design
/// tokens (`design/tokens`), never an RGB value.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize)]
pub enum ColorRole {
    #[default]
    Blue,
    Orange,
    Pink,
    Green,
    Purple,
    Yellow,
    Red,
    Cyan,
    Lime,
    Grey,
    /// Empty / unassigned pad.
    Neutral,
}

impl ColorRole {
    /// Map the compat kit config's Portuguese color names (`azul`, `amarelo`, `rosa`, `verde`).
    pub fn from_compat_name(name: &str) -> Option<Self> {
        match name {
            "azul" | "azul_loop" => Some(ColorRole::Blue),
            "amarelo" => Some(ColorRole::Orange),
            "rosa" => Some(ColorRole::Pink),
            "verde" => Some(ColorRole::Green),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flat_roundtrip() {
        for f in 0..PAD_COUNT {
            let p = PadId::from_flat(f).unwrap();
            assert_eq!(p.flat(), f);
            assert!(p.is_valid());
        }
        assert!(PadId::from_flat(PAD_COUNT).is_none());
        assert_eq!(PadId::all().count(), PAD_COUNT);
    }

    #[test]
    fn parse_labels() {
        assert_eq!(PadId::parse("A0").unwrap(), PadId { bank: 0, index: 0 });
        assert_eq!(PadId::parse("b11").unwrap(), PadId { bank: 1, index: 11 });
        assert_eq!(PadId::parse("13").unwrap(), PadId { bank: 1, index: 1 });
        assert!(PadId::parse("A12").is_err());
        assert_eq!(PadId::parse("C1").unwrap(), PadId { bank: 2, index: 1 });
        assert_eq!(PadId::parse("g11").unwrap().to_string(), "G11");
        assert!(PadId::parse("H0").is_err());
        assert_eq!(PadId { bank: 6, index: 11 }.default_note(), 119);
        assert!(PadId::parse("").is_err());
        assert_eq!(PadId::parse("B3").unwrap().to_string(), "B3");
    }

    #[test]
    fn compat_codes() {
        assert_eq!(PadMode::from_compat_code(100), Some(PadMode::Loop));
        assert_eq!(PadMode::from_compat_code(200), Some(PadMode::OneShot));
        assert_eq!(PadMode::from_compat_code(300), Some(PadMode::Gate));
        assert_eq!(PadMode::from_compat_code(-1), None);
        assert_eq!(ColorRole::from_compat_name("rosa"), Some(ColorRole::Pink));
    }

    #[test]
    fn serde_shapes() {
        let p = PadId { bank: 1, index: 3 };
        let s = serde_json::to_string(&p).unwrap();
        assert_eq!(s, r#"{"bank":1,"index":3}"#);
        assert_eq!(serde_json::to_string(&Quantize::Bar).unwrap(), r#""Bar""#);
        assert_eq!(Quantize::default(), Quantize::None);
        let id: crate::SampleId = serde_json::from_str(r#""abc""#).unwrap();
        assert_eq!(id.as_str(), "abc");
    }
}
