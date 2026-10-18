//! 曲库错误类型。

use up_format::FormatError;

#[derive(Debug, thiserror::Error)]
pub enum LibraryError {
    #[error("I/O 错误（{context}）：{source}")]
    Io {
        context: String,
        #[source]
        source: std::io::Error,
    },
    #[error(transparent)]
    Format(#[from] FormatError),
    #[error("ZIP 错误：{0}")]
    Zip(String),
    #[error("超出导入限制：{0}")]
    LimitExceeded(String),
    #[error("不安全的包内容：{0}")]
    Unsafe(String),
    #[error("不支持的导入源：{0}")]
    UnsupportedSource(String),
    #[error("找不到 {kind} `{id}`")]
    NotFound { kind: &'static str, id: String },
    #[error("曲库索引损坏：{0}")]
    CorruptIndex(String),
    #[error("参数无效：{0}")]
    InvalidInput(String),
}

pub type Result<T, E = LibraryError> = std::result::Result<T, E>;

impl LibraryError {
    pub(crate) fn io(context: impl Into<String>, source: std::io::Error) -> Self {
        Self::Io {
            context: context.into(),
            source,
        }
    }
    pub(crate) fn not_found(kind: &'static str, id: impl Into<String>) -> Self {
        Self::NotFound {
            kind,
            id: id.into(),
        }
    }
}

impl From<zip::result::ZipError> for LibraryError {
    fn from(e: zip::result::ZipError) -> Self {
        Self::Zip(e.to_string())
    }
}

/// 给 `std::io::Result` 补上下文。
pub(crate) trait IoContext<T> {
    fn ctx(self, context: impl FnOnce() -> String) -> Result<T>;
}

impl<T> IoContext<T> for std::io::Result<T> {
    fn ctx(self, context: impl FnOnce() -> String) -> Result<T> {
        self.map_err(|e| LibraryError::io(context(), e))
    }
}
