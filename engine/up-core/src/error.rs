use serde::{Deserialize, Serialize};

/// Stable, machine readable error category. Mirrored in Dart.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ErrorCode {
    /// Invalid argument supplied by the caller.
    InvalidArgument,
    /// Referenced resource (sample, kit, track, device) does not exist.
    NotFound,
    /// Engine / runtime not initialised yet.
    NotInitialized,
    /// Lock-free queue is full; the command was dropped.
    QueueFull,
    /// Audio device / stream failure.
    Audio,
    /// Decoding or encoding failure.
    Codec,
    /// Filesystem or other I/O failure.
    Io,
    /// Serialized data could not be parsed or migrated.
    Format,
    /// Permission denied (e.g. RECORD_AUDIO on Android).
    PermissionDenied,
    /// Operation is invalid in the current state.
    InvalidState,
    /// Feature not implemented yet in this build.
    NotImplemented,
    /// Anything else.
    Internal,
}

/// Error type returned by every fallible API (`Result<T, UpError>`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, thiserror::Error)]
#[error("{code:?}: {message}")]
pub struct UpError {
    pub code: ErrorCode,
    pub message: String,
}

/// Convenience alias.
pub type UpResult<T> = Result<T, UpError>;

impl UpError {
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
    pub fn invalid(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::InvalidArgument, message)
    }
    pub fn not_found(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::NotFound, message)
    }
    pub fn not_implemented(what: impl Into<String>) -> Self {
        Self::new(ErrorCode::NotImplemented, what)
    }
    pub fn io(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Io, message)
    }
    pub fn codec(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Codec, message)
    }
    pub fn audio(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Audio, message)
    }
    pub fn format(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Format, message)
    }
    pub fn state(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::InvalidState, message)
    }
    pub fn internal(message: impl Into<String>) -> Self {
        Self::new(ErrorCode::Internal, message)
    }
}

impl From<std::io::Error> for UpError {
    fn from(e: std::io::Error) -> Self {
        let code = match e.kind() {
            std::io::ErrorKind::NotFound => ErrorCode::NotFound,
            std::io::ErrorKind::PermissionDenied => ErrorCode::PermissionDenied,
            _ => ErrorCode::Io,
        };
        Self::new(code, e.to_string())
    }
}
