//! Process-wide runtime state behind the FFI.

use crate::api::types::UpError;
use arc_swap::ArcSwapOption;
use std::sync::Arc;
use up_host::AppCore;

static CORE: ArcSwapOption<AppCore> = ArcSwapOption::const_empty();
static LIBRARY: ArcSwapOption<up_library::Library> = ArcSwapOption::const_empty();

pub(crate) fn library() -> Result<Arc<up_library::Library>, UpError> {
    LIBRARY.load_full().ok_or_else(|| UpError {
        code: crate::api::types::ErrorCode::NotInitialized,
        message: "library not opened; call init() first".into(),
    })
}

pub(crate) fn install_library(lib: up_library::Library) -> Arc<up_library::Library> {
    let arc = Arc::new(lib);
    LIBRARY.store(Some(Arc::clone(&arc)));
    arc
}

/// Map library errors onto FFI error codes.
pub(crate) fn lib_err(e: up_library::LibraryError) -> UpError {
    use crate::api::types::ErrorCode as C;
    use up_library::LibraryError as L;
    let code = match &e {
        L::Io { source, .. } if source.kind() == std::io::ErrorKind::NotFound => C::NotFound,
        L::Io { source, .. } if source.kind() == std::io::ErrorKind::PermissionDenied => {
            C::PermissionDenied
        }
        L::Io { .. } => C::Io,
        L::Format(_) | L::Zip(_) | L::CorruptIndex(_) => C::Format,
        L::LimitExceeded(_) | L::Unsafe(_) | L::InvalidInput(_) => C::InvalidArgument,
        L::UnsupportedSource(_) => C::NotImplemented,
        L::NotFound { .. } => C::NotFound,
        #[allow(unreachable_patterns)]
        _ => C::Internal,
    };
    UpError {
        code,
        message: e.to_string(),
    }
}

/// Lock-free access to the runtime (hot path).
#[inline]
pub(crate) fn core() -> Result<Arc<AppCore>, UpError> {
    CORE.load_full().ok_or_else(|| UpError {
        code: crate::api::types::ErrorCode::NotInitialized,
        message: "call init() first".into(),
    })
}

pub(crate) fn install(core: AppCore) -> Arc<AppCore> {
    let arc = Arc::new(core);
    CORE.store(Some(Arc::clone(&arc)));
    arc
}

pub(crate) fn installed() -> Option<Arc<AppCore>> {
    CORE.load_full()
}

/// Kit currently loaded from the library (recordings are tagged with it).
static CURRENT_KIT: ArcSwapOption<String> = ArcSwapOption::const_empty();

pub(crate) fn set_current_kit(id: Option<String>) {
    CURRENT_KIT.store(id.map(Arc::new));
}

pub(crate) fn current_kit() -> Option<String> {
    CURRENT_KIT.load_full().map(|s| (*s).clone())
}

/// Waveform overviews of tracks (computed once per track).
pub(crate) fn waveform_cache()
-> &'static std::sync::Mutex<std::collections::HashMap<String, Vec<f32>>> {
    static CACHE: std::sync::OnceLock<
        std::sync::Mutex<std::collections::HashMap<String, Vec<f32>>>,
    > = std::sync::OnceLock::new();
    CACHE.get_or_init(Default::default)
}
