use crate::{AudioProcessor, EngineHandle};
use up_core::{UpError, UpResult};
use up_protocol::RenderScript;

/// Longest offline render accepted (1 hour).
const MAX_RENDER_SECS: f64 = 3600.0;

/// Render `script` through `processor`, sending each command exactly at its
/// frame (blocks are split at command times, so timing is sample accurate).
/// Returns interleaved stereo.
pub fn render_offline(
    handle: &EngineHandle,
    processor: &mut AudioProcessor,
    script: &RenderScript,
) -> UpResult<Vec<f32>> {
    if !script.duration_secs.is_finite()
        || script.duration_secs < 0.0
        || script.duration_secs > MAX_RENDER_SECS
    {
        return Err(UpError::invalid("duration_secs must be within 0..=3600"));
    }
    let sr = processor.sample_rate() as f64;
    let total = (script.duration_secs * sr).round() as usize;
    let mut events: Vec<_> = script
        .events
        .iter()
        .map(|e| {
            if !e.at_secs.is_finite() || e.at_secs < 0.0 {
                return Err(UpError::invalid(
                    "event time must be a finite, non-negative number",
                ));
            }
            Ok(((e.at_secs * sr).round() as usize, e.cmd.clone()))
        })
        .collect::<UpResult<_>>()?;
    events.sort_by_key(|(f, _)| *f);

    let mut out = vec![0.0f32; total * 2];
    let mut pos = 0usize;
    let mut i = 0usize;
    while pos < total {
        while i < events.len() && events[i].0 <= pos {
            handle.send(events[i].1.clone())?;
            i += 1;
        }
        let next = events.get(i).map_or(total, |(f, _)| (*f).min(total));
        let end = next.max(pos + 1).min(total);
        processor.process(&mut out[pos * 2..end * 2], 2);
        pos = end;
    }
    Ok(out)
}
