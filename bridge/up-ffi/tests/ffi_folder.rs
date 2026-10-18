//! Folder-path fallback of `library_load_kit` (own process: FFI state is global).

use up_ffi::api::{engine, library, types::*};

#[test]
fn folder_path_fallback() {
    let tmp = std::env::temp_dir().join(format!("up-ffi-folder-{}", std::process::id()));
    let kit = tmp.join("kit");
    std::fs::create_dir_all(&kit).unwrap();
    let data: Vec<f32> = (0..4800).map(|i| (i as f32 * 0.05).sin() * 0.5).collect();
    let bytes = up_codec::encode_wav(
        &up_codec::AudioBuffer::new(48_000, 1, data),
        up_codec::WavFormat::Pcm16,
    )
    .unwrap();
    std::fs::write(kit.join("a.wav"), bytes).unwrap();
    engine::init(AppDirs {
        data_dir: tmp.join("data").to_string_lossy().into(),
        cache_dir: String::new(),
    })
    .unwrap();
    let s = library::library_load_kit(kit.to_string_lossy().into()).unwrap();
    assert_eq!(s.pad_count, 1);
    assert_eq!(
        library::library_load_kit("no-such-kit".into())
            .unwrap_err()
            .code,
        ErrorCode::NotFound
    );
}
