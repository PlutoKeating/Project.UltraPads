use std::path::PathBuf;
use up_codec::{AudioBuffer, WavFormat, decode, decode_bytes, encode_wav, resample, waveform};

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

fn check_sine(buf: &AudioBuffer, label: &str) {
    assert_eq!(buf.sample_rate, 44_100, "{label} rate");
    assert_eq!(buf.channels, 2, "{label} channels");
    let secs = buf.duration_secs();
    assert!((0.45..0.6).contains(&secs), "{label} duration {secs}");
    let peak = buf.peak();
    assert!(peak > 0.05, "{label} should not be silent (peak {peak})");
}

#[test]
fn decodes_mp3_ogg_flac_m4a() {
    for ext in ["mp3", "ogg", "flac", "m4a"] {
        let f = std::fs::File::open(fixture(&format!("sine440.{ext}"))).unwrap();
        let buf = decode(f, Some(ext)).unwrap_or_else(|e| panic!("{ext}: {e}"));
        check_sine(&buf, ext);
    }
}

#[test]
fn wav_roundtrip_all_formats() {
    let n = 4410;
    let data: Vec<f32> = (0..n * 2)
        .map(|i| ((i / 2) as f32 * 0.0627).sin() * 0.8)
        .collect();
    let src = AudioBuffer::new(44_100, 2, data);
    for fmt in [WavFormat::Pcm16, WavFormat::Pcm24, WavFormat::Float32] {
        let bytes = encode_wav(&src, fmt).unwrap();
        let back = decode_bytes(bytes, Some("wav")).unwrap();
        assert_eq!(back.frames(), n);
        assert_eq!(back.channels, 2);
        let max_err = src
            .data
            .iter()
            .zip(&back.data)
            .fold(0.0f32, |m, (a, b)| m.max((a - b).abs()));
        assert!(max_err < 1e-3, "{fmt:?} error {max_err}");
    }
}

#[test]
fn corrupt_input_is_an_error() {
    let err = decode_bytes(vec![0u8; 1000], Some("wav")).unwrap_err();
    assert_eq!(err.code, up_core::ErrorCode::Codec);
}

#[test]
fn decode_resample_waveform_pipeline() {
    let f = std::fs::File::open(fixture("sine440.flac")).unwrap();
    let buf = decode(f, Some("flac")).unwrap();
    let rs = resample(&buf, 48_000).unwrap();
    assert_eq!(rs.sample_rate, 48_000);
    let w = waveform(&rs.data, rs.channels, 64);
    assert_eq!(w.len(), 64);
    assert!(w.iter().skip(4).take(56).all(|v| *v > 0.05));
}
