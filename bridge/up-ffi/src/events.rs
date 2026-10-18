//! `events()` plumbing: engine bus (`AppCore::subscribe`) merged with the
//! hub event bus (`hub_rt::subscribe_events`) on one forwarding thread.

use crate::api::types::{EngineEvent, ErrorCode, UpError};
use crate::{hub_rt, state};

/// Forward merged events to `f` until it returns `false`.
pub(crate) fn pump(mut f: impl FnMut(EngineEvent) -> bool + Send + 'static) -> Result<(), UpError> {
    let engine = state::core()?.subscribe();
    let hub = hub_rt::subscribe_events();
    std::thread::Builder::new()
        .name("up-ffi-events".into())
        .spawn(move || {
            loop {
                let ev = crossbeam_channel::select! {
                    recv(engine) -> ev => match ev {
                        Ok(ev) => EngineEvent::from(ev),
                        Err(_) => break,
                    },
                    recv(hub) -> ev => match ev {
                        Ok(ev) => EngineEvent::Hub(ev),
                        Err(_) => break,
                    },
                };
                if !f(ev) {
                    break; // Dart side closed the stream.
                }
            }
        })
        .map_err(|e| UpError {
            code: ErrorCode::Internal,
            message: e.to_string(),
        })?;
    Ok(())
}
