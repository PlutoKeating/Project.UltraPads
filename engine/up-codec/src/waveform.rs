/// Peak overview of interleaved audio: `buckets` values in `0..=1`, each the
/// maximum absolute sample (over all channels) within its time slice.
pub fn waveform(interleaved: &[f32], channels: u16, buckets: u32) -> Vec<f32> {
    let ch = channels.max(1) as usize;
    let frames = interleaved.len() / ch;
    overview(frames, buckets, |f| {
        interleaved[f * ch..f * ch + ch]
            .iter()
            .fold(0.0f32, |m, s| m.max(s.abs()))
    })
}

/// Peak overview of planar audio.
pub fn waveform_planar(planar: &[&[f32]], buckets: u32) -> Vec<f32> {
    let frames = planar.iter().map(|c| c.len()).min().unwrap_or(0);
    overview(frames, buckets, |f| {
        planar.iter().fold(0.0f32, |m, c| m.max(c[f].abs()))
    })
}

fn overview(frames: usize, buckets: u32, peak_at: impl Fn(usize) -> f32) -> Vec<f32> {
    let b = buckets as usize;
    if b == 0 {
        return Vec::new();
    }
    let mut out = vec![0.0f32; b];
    if frames == 0 {
        return out;
    }
    for (i, slot) in out.iter_mut().enumerate() {
        let start = i * frames / b;
        let end = (((i + 1) * frames) / b).max(start + 1).min(frames);
        let mut m = 0.0f32;
        for f in start..end {
            m = m.max(peak_at(f));
        }
        *slot = m.min(1.0);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buckets_and_peaks() {
        let data = [0.1, -0.2, 0.9, 0.0, -0.5, 0.3, 0.0, 0.0];
        let w = waveform(&data, 2, 2);
        assert_eq!(w, vec![0.9, 0.5]);
        assert_eq!(waveform(&data, 2, 0), Vec::<f32>::new());
        assert_eq!(waveform(&[], 2, 4), vec![0.0; 4]);
        // More buckets than frames still yields `buckets` entries.
        assert_eq!(waveform(&data, 2, 8).len(), 8);
        let l = [0.1f32, 0.7];
        let r = [-0.4f32, 0.2];
        assert_eq!(waveform_planar(&[&l, &r], 2), vec![0.4, 0.7]);
    }
}
