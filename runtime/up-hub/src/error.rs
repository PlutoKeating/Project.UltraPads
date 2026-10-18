//! 统一错误类型。

use crate::model::BlobHash;

/// up-hub 的所有公开 API 返回的错误。
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum HubError {
    /// 本地 I/O 失败（文件、套接字）。
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    /// TLS 握手或配置失败（包括对端公钥与预期不符）。
    #[error("tls: {0}")]
    Tls(String),
    /// 对端发来了不符合协议的数据。
    #[error("protocol: {0}")]
    Protocol(String),
    /// 设备未配对（本地未信任对端，或对端未信任本机）。
    #[error("device not paired: {0}")]
    NotPaired(String),
    /// 配对失败（配对码错误/过期/用尽，或检测到中间人）。
    #[error("pairing failed: {0}")]
    Pairing(String),
    /// 对端返回的 HTTP 错误。
    #[error("remote error {status} {code}: {message}")]
    Remote {
        /// HTTP 状态码。
        status: u16,
        /// 机器可读错误码（见 docs/API.md 第 4 节）。
        code: String,
        /// 可读描述。
        message: String,
    },
    /// blob 内容与其 BLAKE3 地址不符。
    #[error("blob hash mismatch: expected {expected}, got {actual}")]
    HashMismatch {
        /// 期望的哈希（地址）。
        expected: BlobHash,
        /// 实际内容的哈希。
        actual: BlobHash,
    },
    /// blob 不存在。
    #[error("blob not found: {0}")]
    BlobNotFound(BlobHash),
    /// 续传偏移量与已有的部分数据长度不一致。
    #[error("resume offset mismatch, expected {expected}")]
    OffsetMismatch {
        /// 存储中已有的部分数据长度。
        expected: u64,
    },
    /// 同一 blob 正在被另一个写入者写入。
    #[error("blob busy: {0}")]
    Busy(BlobHash),
    /// LibraryStore 实现报告的错误。
    #[error("store: {0}")]
    Store(String),
    /// mDNS 发现/广播失败。
    #[error("discovery: {0}")]
    Discovery(String),
    /// 操作超时。
    #[error("timed out: {0}")]
    Timeout(&'static str),
    /// 参数不合法。
    #[error("invalid input: {0}")]
    InvalidInput(String),
    /// 句柄/服务已关闭。
    #[error("closed")]
    Closed,
}

impl From<serde_json::Error> for HubError {
    fn from(e: serde_json::Error) -> Self {
        HubError::Protocol(format!("json: {e}"))
    }
}

impl From<rustls::Error> for HubError {
    fn from(e: rustls::Error) -> Self {
        HubError::Tls(e.to_string())
    }
}

impl From<hyper::Error> for HubError {
    fn from(e: hyper::Error) -> Self {
        HubError::Protocol(format!("http: {e}"))
    }
}

/// `Result` 别名。
pub type Result<T, E = HubError> = std::result::Result<T, E>;
