//! Audio decoding, resampling, WAV encoding and waveform overviews.
//!
//! Engine crates do no I/O: every function here works on readers/writers or
//! in-memory buffers. Opening files is the job of `runtime/*`.

#![forbid(unsafe_code)]

mod buffer;
mod decode;
mod resample;
mod wav;
mod waveform;

pub use buffer::AudioBuffer;
pub use decode::{decode, decode_bytes, decode_source};
pub use resample::{resample, resample_planar};
pub use wav::{WavFormat, encode_wav, write_wav};
pub use waveform::{waveform, waveform_planar};

/// Re-export so runtime crates can pass files without depending on symphonia.
pub use symphonia::core::io::MediaSource;
