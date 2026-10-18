//! 最小 Standard MIDI File（SMF）读写，用于教程谱 `chart.mid`。
//!
//! 写：type 1，track 0 = 速度/拍号/marker，track 1 = 音符。读：任意 type 0/1 中的 note-on/off、
//! 速度和拍号（忽略 sysex 与其它 meta）。

use crate::{FormatError, Result};

fn err(msg: impl Into<String>) -> FormatError {
    FormatError::Midi(msg.into())
}

/// 一个音符事件（时间单位为 tick）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NoteEvent {
    pub tick: u32,
    pub duration: u32,
    pub channel: u8,
    pub key: u8,
    pub velocity: u8,
}

/// marker 元事件。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Marker {
    pub tick: u32,
    pub text: String,
}

/// 教程谱 / pattern。
#[derive(Debug, Clone, PartialEq)]
pub struct Chart {
    pub ticks_per_quarter: u16,
    pub bpm: f64,
    pub time_signature: [u8; 2],
    pub track_name: Option<String>,
    pub markers: Vec<Marker>,
    pub notes: Vec<NoteEvent>,
}

impl Default for Chart {
    fn default() -> Self {
        Self {
            ticks_per_quarter: 480,
            bpm: 120.0,
            time_signature: [4, 4],
            track_name: None,
            markers: Vec::new(),
            notes: Vec::new(),
        }
    }
}

fn vlq(out: &mut Vec<u8>, mut v: u32) {
    let mut buf = [0u8; 5];
    let mut i = 4;
    buf[i] = (v & 0x7F) as u8;
    v >>= 7;
    while v > 0 {
        i -= 1;
        buf[i] = ((v & 0x7F) as u8) | 0x80;
        v >>= 7;
    }
    out.extend_from_slice(&buf[i..]);
}

fn track_chunk(events: &[(u32, Vec<u8>)]) -> Vec<u8> {
    let mut body = Vec::new();
    let mut last = 0u32;
    for (tick, data) in events {
        vlq(&mut body, tick - last);
        body.extend_from_slice(data);
        last = *tick;
    }
    vlq(&mut body, 0);
    body.extend_from_slice(&[0xFF, 0x2F, 0x00]);
    let mut out = b"MTrk".to_vec();
    out.extend_from_slice(&(body.len() as u32).to_be_bytes());
    out.extend_from_slice(&body);
    out
}

fn meta(kind: u8, data: &[u8]) -> Vec<u8> {
    let mut v = vec![0xFF, kind];
    vlq(&mut v, data.len() as u32);
    v.extend_from_slice(data);
    v
}

impl Chart {
    /// 写成 SMF type 1。
    pub fn to_smf(&self) -> Vec<u8> {
        let mut t0: Vec<(u32, Vec<u8>)> = Vec::new();
        let us = (60_000_000.0 / self.bpm.clamp(1.0, 1000.0)).round() as u32;
        t0.push((0, meta(0x51, &us.to_be_bytes()[1..])));
        let denom_pow = u32::from(self.time_signature[1].max(1)).trailing_zeros() as u8;
        t0.push((0, meta(0x58, &[self.time_signature[0], denom_pow, 24, 8])));
        for m in &self.markers {
            t0.push((m.tick, meta(0x06, m.text.as_bytes())));
        }
        t0.sort_by_key(|e| e.0);

        let mut t1: Vec<(u32, u8, Vec<u8>)> = Vec::new();
        if let Some(n) = &self.track_name {
            t1.push((0, 0, meta(0x03, n.as_bytes())));
        }
        for n in &self.notes {
            let ch = n.channel & 0x0F;
            // note-off 排在同 tick 的 note-on 之前
            t1.push((
                n.tick,
                2,
                vec![0x90 | ch, n.key & 0x7F, n.velocity.clamp(1, 127)],
            ));
            t1.push((
                n.tick + n.duration.max(1),
                1,
                vec![0x80 | ch, n.key & 0x7F, 0],
            ));
        }
        t1.sort_by_key(|e| (e.0, e.1));
        let t1: Vec<(u32, Vec<u8>)> = t1.into_iter().map(|(t, _, d)| (t, d)).collect();

        let mut out = b"MThd".to_vec();
        out.extend_from_slice(&6u32.to_be_bytes());
        out.extend_from_slice(&1u16.to_be_bytes());
        out.extend_from_slice(&2u16.to_be_bytes());
        out.extend_from_slice(&self.ticks_per_quarter.to_be_bytes());
        out.extend_from_slice(&track_chunk(&t0));
        out.extend_from_slice(&track_chunk(&t1));
        out
    }

    /// 解析 SMF（PPQ 时基）。
    pub fn from_smf(bytes: &[u8]) -> Result<Self> {
        if bytes.len() < 14 || &bytes[0..4] != b"MThd" {
            return Err(err("不是 SMF 文件"));
        }
        let hlen = u32::from_be_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]) as usize;
        let ntracks = u16::from_be_bytes([bytes[10], bytes[11]]);
        let division = u16::from_be_bytes([bytes[12], bytes[13]]);
        if division & 0x8000 != 0 {
            return Err(err("不支持 SMPTE 时基"));
        }
        let mut chart = Chart {
            ticks_per_quarter: division,
            ..Chart::default()
        };
        let mut pos = 8 + hlen;
        for _ in 0..ntracks {
            if pos + 8 > bytes.len() {
                return Err(err("track 截断"));
            }
            if &bytes[pos..pos + 4] != b"MTrk" {
                return Err(err("缺少 MTrk"));
            }
            let len = u32::from_be_bytes([
                bytes[pos + 4],
                bytes[pos + 5],
                bytes[pos + 6],
                bytes[pos + 7],
            ]) as usize;
            let start = pos + 8;
            let end = start
                .checked_add(len)
                .filter(|e| *e <= bytes.len())
                .ok_or_else(|| err("track 长度越界"))?;
            parse_track(&bytes[start..end], &mut chart)?;
            pos = end;
        }
        chart.notes.sort_by_key(|n| (n.tick, n.key));
        Ok(chart)
    }
}

fn read_vlq(d: &[u8], i: &mut usize) -> Result<u32> {
    let mut v = 0u32;
    for _ in 0..4 {
        let b = *d.get(*i).ok_or_else(|| err("VLQ 截断"))?;
        *i += 1;
        v = (v << 7) | u32::from(b & 0x7F);
        if b & 0x80 == 0 {
            return Ok(v);
        }
    }
    Err(err("VLQ 过长"))
}

fn parse_track(d: &[u8], chart: &mut Chart) -> Result<()> {
    let mut i = 0usize;
    let mut tick = 0u32;
    let mut status = 0u8;
    let mut open: Vec<(u8, u8, u32, u8)> = Vec::new();
    while i < d.len() {
        tick = tick.saturating_add(read_vlq(d, &mut i)?);
        let mut b = *d.get(i).ok_or_else(|| err("事件截断"))?;
        if b & 0x80 != 0 {
            status = b;
            i += 1;
        } else if status == 0 {
            return Err(err("running status 无前导"));
        }
        match status {
            0xFF => {
                let kind = *d.get(i).ok_or_else(|| err("meta 截断"))?;
                i += 1;
                let len = read_vlq(d, &mut i)? as usize;
                let data = d.get(i..i + len).ok_or_else(|| err("meta 越界"))?;
                i += len;
                match kind {
                    0x51 if len == 3 => {
                        let us = u32::from_be_bytes([0, data[0], data[1], data[2]]);
                        if us > 0 {
                            chart.bpm = 60_000_000.0 / f64::from(us);
                        }
                    }
                    0x58 if len >= 2 => {
                        chart.time_signature =
                            [data[0], 1u8.checked_shl(u32::from(data[1])).unwrap_or(4)];
                    }
                    0x06 => chart.markers.push(Marker {
                        tick,
                        text: String::from_utf8_lossy(data).into_owned(),
                    }),
                    0x03 if chart.track_name.is_none() => {
                        chart.track_name = Some(String::from_utf8_lossy(data).into_owned());
                    }
                    0x2F => break,
                    _ => {}
                }
                status = 0;
            }
            0xF0 | 0xF7 => {
                let len = read_vlq(d, &mut i)? as usize;
                i += len;
                status = 0;
            }
            s => {
                let kind = s & 0xF0;
                let ch = s & 0x0F;
                let n = if kind == 0xC0 || kind == 0xD0 { 1 } else { 2 };
                let data = d.get(i..i + n).ok_or_else(|| err("通道事件截断"))?;
                i += n;
                b = data[0];
                let vel = if n == 2 { data[1] } else { 0 };
                if kind == 0x90 && vel > 0 {
                    open.push((ch, b, tick, vel));
                } else if kind == 0x80 || (kind == 0x90 && vel == 0) {
                    if let Some(p) = open.iter().position(|o| o.0 == ch && o.1 == b) {
                        let (ch, key, t0, v) = open.remove(p);
                        chart.notes.push(NoteEvent {
                            tick: t0,
                            duration: tick - t0,
                            channel: ch,
                            key,
                            velocity: v,
                        });
                    }
                }
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip() {
        let chart = Chart {
            ticks_per_quarter: 480,
            bpm: 92.0,
            time_signature: [3, 4],
            track_name: Some("Tutorial".into()),
            markers: vec![Marker {
                tick: 0,
                text: "Intro".into(),
            }],
            notes: vec![
                NoteEvent {
                    tick: 0,
                    duration: 240,
                    channel: 0,
                    key: 36,
                    velocity: 100,
                },
                NoteEvent {
                    tick: 240,
                    duration: 240,
                    channel: 0,
                    key: 36,
                    velocity: 90,
                },
                NoteEvent {
                    tick: 480,
                    duration: 100_000,
                    channel: 9,
                    key: 42,
                    velocity: 64,
                },
            ],
        };
        let bytes = chart.to_smf();
        let back = Chart::from_smf(&bytes).unwrap();
        assert_eq!(back.notes, chart.notes);
        assert_eq!(back.time_signature, [3, 4]);
        assert!((back.bpm - 92.0).abs() < 0.01);
        assert_eq!(back.markers, chart.markers);
        assert_eq!(back.track_name.as_deref(), Some("Tutorial"));
        assert!(Chart::from_smf(b"garbage").is_err());
    }
}
