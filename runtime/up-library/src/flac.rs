//! 录音作品导出为 FLAC：16-bit 无损压缩，并写入 Vorbis 注释（标题、署名）。
//!
//! 编码用纯 Rust 的 `flacenc`；它不写注释块，所以编码后在 STREAMINFO 之后插入一个 VORBIS_COMMENT 块。

use up_format::wav::DecodedPcm;

use crate::error::{LibraryError, Result};

fn invalid(msg: impl std::fmt::Display) -> LibraryError {
    LibraryError::InvalidInput(format!("FLAC 编码：{msg}"))
}

/// Vorbis 注释块的正文（不含块头）。
fn vorbis_comment(comments: &[(&str, &str)]) -> Vec<u8> {
    let vendor = b"UltraPads";
    let mut body = Vec::new();
    body.extend_from_slice(&(vendor.len() as u32).to_le_bytes());
    body.extend_from_slice(vendor);
    body.extend_from_slice(&(comments.len() as u32).to_le_bytes());
    for (k, v) in comments {
        let entry = format!("{k}={v}");
        body.extend_from_slice(&(entry.len() as u32).to_le_bytes());
        body.extend_from_slice(entry.as_bytes());
    }
    body
}

/// 把 `pcm` 编码成 FLAC。`comments` 是 `(字段名, 值)`，如 `("TITLE", "My take")`。
pub fn encode(pcm: &DecodedPcm, comments: &[(&str, &str)]) -> Result<Vec<u8>> {
    use flacenc::component::BitRepr;
    use flacenc::error::Verify;

    if pcm.channels == 0 || pcm.channels > 8 || pcm.samples.is_empty() {
        return Err(invalid("没有可编码的音频"));
    }
    let samples: Vec<i32> = pcm
        .samples
        .iter()
        .map(|s| (s.clamp(-1.0, 1.0) * 32767.0).round() as i32)
        .collect();
    let config = flacenc::config::Encoder::default()
        .into_verified()
        .map_err(|e| invalid(format!("{e:?}")))?;
    let source = flacenc::source::MemSource::from_samples(
        &samples,
        usize::from(pcm.channels),
        16,
        pcm.sample_rate as usize,
    );
    let stream = flacenc::encode_with_fixed_block_size(&config, source, config.block_size)
        .map_err(|e| invalid(format!("{e:?}")))?;
    let mut sink = flacenc::bitsink::ByteSink::new();
    stream
        .write(&mut sink)
        .map_err(|e| invalid(format!("{e:?}")))?;
    let raw = sink.as_slice();
    if raw.len() < 42 || &raw[..4] != b"fLaC" {
        return Err(invalid("编码结果不是合法的 FLAC"));
    }
    // flacenc 的 STREAMINFO 里最小块长是（较短的）最后一块，symphonia 会拒绝；
    // 按 libFLAC 的惯例把最小块长对齐到最大块长（固定块长流，最后一块允许更短）。
    let mut fixed = raw.to_vec();
    let (hi, lo) = (fixed[10], fixed[11]);
    fixed[8] = hi;
    fixed[9] = lo;
    let raw = fixed.as_slice();
    if comments.is_empty() {
        return Ok(raw.to_vec());
    }
    // 布局：'fLaC' + STREAMINFO 块（4 字节块头 + 34 字节）+ 其后的帧。给 STREAMINFO 清掉 last 标志，
    // 再接上 VORBIS_COMMENT（type 4，last = 1）。
    let body = vorbis_comment(comments);
    if body.len() >= 1 << 24 {
        return Err(invalid("注释过长"));
    }
    let mut out = Vec::with_capacity(raw.len() + body.len() + 4);
    out.extend_from_slice(&raw[..4]);
    let mut streaminfo = raw[4..42].to_vec();
    streaminfo[0] &= 0x7F;
    out.extend_from_slice(&streaminfo);
    out.push(0x80 | 4);
    out.extend_from_slice(&(body.len() as u32).to_be_bytes()[1..]);
    out.extend_from_slice(&body);
    out.extend_from_slice(&raw[42..]);
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tone(frames: usize, ch: u16) -> DecodedPcm {
        let mut samples = Vec::new();
        for i in 0..frames {
            let v = (i as f32 * 0.05).sin() * 0.5;
            for c in 0..ch {
                samples.push(v * if c == 0 { 1.0 } else { 0.7 });
            }
        }
        DecodedPcm {
            channels: ch,
            sample_rate: 44_100,
            samples,
        }
    }

    #[test]
    fn roundtrips_with_and_without_comments() {
        for ch in [1u16, 2] {
            let pcm = tone(20_000, ch);
            for comments in [vec![], vec![("TITLE", "t"), ("COMMENT", "by x")]] {
                let bytes = encode(&pcm, &comments).unwrap();
                assert_eq!(&bytes[..4], b"fLaC");
                let back = up_codec::decode_bytes(bytes, Some("flac")).unwrap();
                assert_eq!(back.channels, ch);
                assert_eq!(back.frames(), 20_000);
                let err = back
                    .data
                    .iter()
                    .zip(&pcm.samples)
                    .map(|(a, b)| (a - b).abs())
                    .fold(0.0f32, f32::max);
                assert!(err < 1.0 / 16_000.0, "最大误差 {err}");
            }
        }
    }
}
