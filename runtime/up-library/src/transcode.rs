//! 导入时的音频转码：Ogg Vorbis / MP3 / FLAC / AIFF … → 16-bit PCM WAV。
//!
//! 解码用 `up-codec`（symphonia）。库内采样统一存成 WAV：`.upkit` 中的 SFZ 可被任何采样器直接播放，
//! 引擎加载时也只需要解析 WAV。

use crate::error::{LibraryError, Result};

/// 支持转码的扩展名（小写）。
pub const TRANSCODE_EXTS: &[&str] = &["ogg", "oga", "mp3", "flac", "aif", "aiff", "m4a", "caf"];

pub fn is_transcodable(ext: &str) -> bool {
    TRANSCODE_EXTS.contains(&ext)
}

/// 解码任意支持的格式并编码为 16-bit WAV。`max_frames` 限制解码长度。
pub fn to_wav(bytes: &[u8], ext: &str, max_frames: u64) -> Result<Vec<u8>> {
    let buf = up_codec::decode_bytes(bytes.to_vec(), Some(ext))
        .map_err(|e| LibraryError::InvalidInput(format!("解码 .{ext}：{e}")))?;
    if buf.channels == 0 || buf.sample_rate == 0 {
        return Err(LibraryError::InvalidInput(format!(
            ".{ext}：声道或采样率为 0"
        )));
    }
    if (buf.data.len() as u64) / u64::from(buf.channels) > max_frames {
        return Err(LibraryError::LimitExceeded(format!(".{ext} 解码后过长")));
    }
    Ok(up_format::wav::encode_pcm16(
        buf.channels,
        buf.sample_rate,
        &buf.data,
    ))
}

/// 已是 WAV 则原样返回，否则转码。
pub fn ensure_wav(bytes: Vec<u8>, ext: &str, max_frames: u64) -> Result<Vec<u8>> {
    if ext == "wav" || ext == "wave" {
        up_format::wav::info(&bytes)?;
        Ok(bytes)
    } else {
        to_wav(&bytes, ext, max_frames)
    }
}
