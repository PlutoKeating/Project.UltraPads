use crate::AudioBuffer;
use symphonia::core::codecs::audio::AudioDecoderOptions;
use symphonia::core::errors::Error as SymError;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, TrackType};
use symphonia::core::io::{MediaSource, MediaSourceStream};
use symphonia::core::meta::MetadataOptions;
use up_core::{UpError, UpResult};

/// Maximum decoded length accepted (protects against pathological files):
/// 30 minutes of 8-channel audio at 192 kHz.
const MAX_SAMPLES: usize = 30 * 60 * 192_000 * 8;

/// Decode an in-memory encoded file. `ext_hint` is the file extension
/// (e.g. `"mp3"`) and improves format detection.
pub fn decode_bytes(bytes: Vec<u8>, ext_hint: Option<&str>) -> UpResult<AudioBuffer> {
    decode_source(Box::new(std::io::Cursor::new(bytes)), ext_hint)
}

/// Decode from any seekable reader (e.g. `std::fs::File` opened by the runtime).
pub fn decode<R>(reader: R, ext_hint: Option<&str>) -> UpResult<AudioBuffer>
where
    R: MediaSource + 'static,
{
    decode_source(Box::new(reader), ext_hint)
}

/// Decode from a boxed symphonia media source. Supports WAV/AIFF/CAF (PCM,
/// ADPCM), MP3, Ogg Vorbis, FLAC, AAC/ALAC in MP4/M4A.
pub fn decode_source(
    source: Box<dyn MediaSource>,
    ext_hint: Option<&str>,
) -> UpResult<AudioBuffer> {
    let mss = MediaSourceStream::new(source, Default::default());
    let mut hint = Hint::new();
    if let Some(ext) = ext_hint {
        hint.with_extension(&ext.to_ascii_lowercase());
    }
    let mut format = symphonia::default::get_probe()
        .probe(
            &hint,
            mss,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|e| UpError::codec(format!("unsupported or corrupt audio: {e}")))?;

    let track = format
        .default_track(TrackType::Audio)
        .ok_or_else(|| UpError::codec("no audio track"))?;
    let track_id = track.id;
    let params = track
        .codec_params
        .as_ref()
        .and_then(|p| p.audio())
        .ok_or_else(|| UpError::codec("track has no audio codec parameters"))?
        .clone();

    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(&params, &AudioDecoderOptions::default())
        .map_err(|e| UpError::codec(format!("no decoder: {e}")))?;

    let mut sample_rate = params.sample_rate.unwrap_or(0);
    let mut channels = params
        .channels
        .as_ref()
        .map(|c| c.count() as u16)
        .unwrap_or(0);
    let mut data: Vec<f32> = Vec::new();
    let mut scratch: Vec<f32> = Vec::new();

    loop {
        let packet = match format.next_packet() {
            Ok(Some(p)) => p,
            Ok(None) => break,
            Err(SymError::IoError(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => break,
            Err(SymError::ResetRequired) => {
                // Stream parameters changed mid-file; not supported for samples.
                break;
            }
            Err(e) => return Err(UpError::codec(format!("read error: {e}"))),
        };
        if packet.track_id != track_id {
            continue;
        }
        match decoder.decode(&packet) {
            Ok(buf) => {
                let spec = buf.spec();
                if sample_rate == 0 {
                    sample_rate = spec.rate();
                }
                let ch = spec.channels().count() as u16;
                if channels == 0 {
                    channels = ch;
                }
                if ch != channels {
                    return Err(UpError::codec("channel count changed mid-stream"));
                }
                scratch.resize(buf.samples_interleaved(), 0.0);
                buf.copy_to_slice_interleaved(&mut scratch[..]);
                if data.len() + scratch.len() > MAX_SAMPLES {
                    return Err(UpError::codec("audio file too long"));
                }
                data.extend_from_slice(&scratch);
            }
            // Recoverable: skip the corrupt packet.
            Err(SymError::DecodeError(_)) => continue,
            Err(e) => return Err(UpError::codec(format!("decode error: {e}"))),
        }
    }

    if sample_rate == 0 || channels == 0 {
        return Err(UpError::codec("could not determine sample rate / channels"));
    }
    Ok(AudioBuffer::new(sample_rate, channels, data))
}
