//! Test hooks for `tests/*.rs` (not part of the FFI surface; FRB only scans
//! `crate::api`).

use crate::api::types::{EngineEvent, UpError};
use crate::state;

/// The merged `events()` stream as a channel.
pub fn event_receiver() -> Result<crossbeam_channel::Receiver<EngineEvent>, UpError> {
    let (tx, rx) = crossbeam_channel::unbounded();
    crate::events::pump(move |ev| tx.send(ev).is_ok())?;
    Ok(rx)
}

/// Render `blocks` × 256 frames with the parked audio processor (no audio
/// device), so queued commands are consumed and pad states advance.
pub fn pump_audio(blocks: usize) -> Result<(), UpError> {
    let core = state::core()?;
    let Some(mut p) = core.take_processor()? else {
        return Ok(());
    };
    let mut buf = vec![0.0f32; 256 * 2];
    for _ in 0..blocks {
        p.process(&mut buf, 2);
    }
    core.return_processor(p)?;
    Ok(())
}
