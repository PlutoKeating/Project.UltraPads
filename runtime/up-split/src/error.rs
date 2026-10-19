//! 拆分过程的错误类型。

#[derive(Debug, thiserror::Error)]
pub enum SplitError {
    #[error("无法读取音频：{0}")]
    Decode(String),
    #[error("音频太短：至少需要 {need_secs:.0} 秒才能切出一个 4 小节段落，实际 {got_secs:.1} 秒")]
    TooShort { need_secs: f64, got_secs: f64 },
    #[error("没有找到可用的节拍网格（速度估计不可靠，置信度 {confidence:.1}）")]
    NoGrid { confidence: f64 },
    #[error("可用内存不足：分轨需要约 {need_mb} MB，当前可用约 {have_mb} MB")]
    InsufficientMemory { need_mb: u64, have_mb: u64 },
    #[error("分轨模型加载失败：{0}")]
    Model(String),
    #[error("分轨失败：{0}")]
    Separate(String),
    #[error("已取消")]
    Cancelled,
    #[error("生成 Kit 失败：{0}")]
    Kit(String),
}

pub type Result<T> = std::result::Result<T, SplitError>;
