use crate::AudioBuffer;
use rubato::audioadapter_buffers::direct::InterleavedSlice;
use rubato::{Fft, FixedSync, Resampler};
use up_core::{UpError, UpResult};

/// High-quality offline sample-rate conversion (FFT-based, rubato).
/// Returns the input unchanged (cloned) when the rates already match.
pub fn resample(input: &AudioBuffer, target_rate: u32) -> UpResult<AudioBuffer> {
    if target_rate == 0 {
        return Err(UpError::invalid("target sample rate must be > 0"));
    }
    if input.sample_rate == target_rate || input.is_empty() {
        return Ok(AudioBuffer::new(
            target_rate,
            input.channels,
            input.data.clone(),
        ));
    }
    let channels = input.channels.max(1) as usize;
    let frames = input.frames();
    let mut rs = Fft::<f32>::new(
        input.sample_rate as usize,
        target_rate as usize,
        1024,
        channels,
        FixedSync::Input,
    )
    .map_err(|e| UpError::codec(format!("resampler init: {e}")))?;
    let adapter = InterleavedSlice::new(&input.data[..frames * channels], channels, frames)
        .map_err(|e| UpError::codec(format!("resampler buffer: {e}")))?;
    let out = rs
        .process_all(&adapter, frames, None)
        .map_err(|e| UpError::codec(format!("resample: {e}")))?;
    Ok(AudioBuffer::new(
        target_rate,
        input.channels,
        out.take_data(),
    ))
}

/// Resample planar channels.
pub fn resample_planar(
    planar: &[Vec<f32>],
    from_rate: u32,
    to_rate: u32,
) -> UpResult<Vec<Vec<f32>>> {
    let buf = AudioBuffer::from_planar(from_rate, planar);
    Ok(resample(&buf, to_rate)?.to_planar())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sine(rate: u32, secs: f64, hz: f64) -> AudioBuffer {
        let n = (rate as f64 * secs) as usize;
        let data = (0..n)
            .map(|i| (2.0 * std::f64::consts::PI * hz * i as f64 / rate as f64).sin() as f32 * 0.5)
            .collect();
        AudioBuffer::new(rate, 1, data)
    }

    #[test]
    fn length_and_level_preserved() {
        let src = sine(44_100, 1.0, 440.0);
        let out = resample(&src, 48_000).unwrap();
        assert_eq!(out.sample_rate, 48_000);
        let expected = 48_000i64;
        assert!(
            (out.frames() as i64 - expected).abs() < 64,
            "frames {}",
            out.frames()
        );
        // Steady-state peak close to 0.5.
        let mid = &out.data[4_800..43_200];
        let peak = mid.iter().fold(0.0f32, |m, s| m.max(s.abs()));
        assert!((peak - 0.5).abs() < 0.02, "peak {peak}");
    }

    #[test]
    fn identity_when_rates_match() {
        let src = sine(48_000, 0.1, 440.0);
        assert_eq!(resample(&src, 48_000).unwrap(), src);
    }
}
