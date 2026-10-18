use crate::AudioBuffer;
use std::io::{Seek, Write};
use up_core::{UpError, UpResult};

/// WAV sample encoding.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum WavFormat {
    /// 16-bit PCM with TPDF-free rounding (fine for exports/recordings).
    #[default]
    Pcm16,
    /// 24-bit PCM.
    Pcm24,
    /// 32-bit IEEE float.
    Float32,
}

/// Write `buf` as a WAV stream into `writer`.
pub fn write_wav<W: Write + Seek>(writer: W, buf: &AudioBuffer, fmt: WavFormat) -> UpResult<()> {
    if buf.channels == 0 || buf.sample_rate == 0 {
        return Err(UpError::invalid(
            "invalid audio buffer (0 channels or 0 Hz)",
        ));
    }
    let (bits, sample_format) = match fmt {
        WavFormat::Pcm16 => (16, hound::SampleFormat::Int),
        WavFormat::Pcm24 => (24, hound::SampleFormat::Int),
        WavFormat::Float32 => (32, hound::SampleFormat::Float),
    };
    let spec = hound::WavSpec {
        channels: buf.channels,
        sample_rate: buf.sample_rate,
        bits_per_sample: bits,
        sample_format,
    };
    let map = |e: hound::Error| UpError::codec(format!("wav write: {e}"));
    let mut w = hound::WavWriter::new(writer, spec).map_err(map)?;
    match fmt {
        WavFormat::Pcm16 => {
            for &s in &buf.data {
                w.write_sample((s.clamp(-1.0, 1.0) * i16::MAX as f32).round() as i16)
                    .map_err(map)?;
            }
        }
        WavFormat::Pcm24 => {
            const MAX24: f32 = 8_388_607.0;
            for &s in &buf.data {
                w.write_sample((s.clamp(-1.0, 1.0) * MAX24).round() as i32)
                    .map_err(map)?;
            }
        }
        WavFormat::Float32 => {
            for &s in &buf.data {
                w.write_sample(s).map_err(map)?;
            }
        }
    }
    w.finalize().map_err(map)
}

/// Encode to an in-memory WAV file.
pub fn encode_wav(buf: &AudioBuffer, fmt: WavFormat) -> UpResult<Vec<u8>> {
    let mut cur = std::io::Cursor::new(Vec::new());
    write_wav(&mut cur, buf, fmt)?;
    Ok(cur.into_inner())
}
