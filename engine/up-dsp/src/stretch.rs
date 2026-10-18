//! Offline pitch / tempo processing interface.
//!
//! Kit editing only changes pitch (±12 semitones) and time (0.5×–2.0×) offline
//! while editing a kit. This module defines the interface; the default
//! implementation is a high-quality varispeed (pitch and time coupled). A
//! true time-stretcher (Signalsmith Stretch, C++ binding) will implement
//! [`OfflineStretcher`] later and handle independent pitch/time.

use crate::interp::read_hermite;
use up_core::{UpError, UpResult};

/// Requested offline transformation.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct StretchParams {
    /// Pitch shift in semitones, `-12.0..=12.0`.
    pub semitones: f32,
    /// Duration ratio: `2.0` = twice as long (half speed), `0.5..=2.0`.
    pub time_ratio: f32,
}

impl StretchParams {
    pub const IDENTITY: Self = Self {
        semitones: 0.0,
        time_ratio: 1.0,
    };

    pub fn validate(&self) -> UpResult<()> {
        if !(-12.0..=12.0).contains(&self.semitones) {
            return Err(UpError::invalid("semitones must be within -12..=12"));
        }
        if !(0.5..=2.0).contains(&self.time_ratio) {
            return Err(UpError::invalid("time_ratio must be within 0.5..=2.0"));
        }
        Ok(())
    }
}

/// Offline (non-realtime) pitch/tempo processor working on planar audio.
pub trait OfflineStretcher {
    fn process(&mut self, planar: &[Vec<f32>], params: StretchParams) -> UpResult<Vec<Vec<f32>>>;
}

/// Tape-style varispeed. Supports `semitones == 0` with any `time_ratio`
/// (speed change with pitch change) or coupled pitch/time.
/// Independent pitch/time returns `NotImplemented` until Signalsmith Stretch
/// is integrated.
#[derive(Debug, Default, Clone, Copy)]
pub struct Varispeed;

impl OfflineStretcher for Varispeed {
    fn process(&mut self, planar: &[Vec<f32>], params: StretchParams) -> UpResult<Vec<Vec<f32>>> {
        params.validate()?;
        let rate = if params.semitones != 0.0 {
            let coupled = 2f32.powf(-params.semitones / 12.0);
            if (coupled - params.time_ratio).abs() > 1e-4 && params.time_ratio != 1.0 {
                return Err(UpError::not_implemented(
                    "independent pitch/time stretch requires Signalsmith Stretch (planned)",
                ));
            }
            2f64.powf(params.semitones as f64 / 12.0)
        } else {
            1.0 / params.time_ratio as f64
        };
        Ok(planar
            .iter()
            .map(|ch| {
                let out_len = ((ch.len() as f64) / rate).floor() as usize;
                (0..out_len)
                    .map(|i| read_hermite(ch, i as f64 * rate, None))
                    .collect()
            })
            .collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn varispeed_lengths() {
        let ch = vec![
            (0..1000)
                .map(|i| (i as f32 * 0.01).sin())
                .collect::<Vec<_>>(),
        ];
        let mut v = Varispeed;
        let slow = v
            .process(
                &ch,
                StretchParams {
                    semitones: 0.0,
                    time_ratio: 2.0,
                },
            )
            .unwrap();
        assert_eq!(slow[0].len(), 2000);
        let up = v
            .process(
                &ch,
                StretchParams {
                    semitones: 12.0,
                    time_ratio: 0.5,
                },
            )
            .unwrap();
        assert_eq!(up[0].len(), 500);
        let err = v
            .process(
                &ch,
                StretchParams {
                    semitones: 12.0,
                    time_ratio: 1.5,
                },
            )
            .unwrap_err();
        assert_eq!(err.code, up_core::ErrorCode::NotImplemented);
        assert!(
            StretchParams {
                semitones: 13.0,
                time_ratio: 1.0
            }
            .validate()
            .is_err()
        );
    }
}
