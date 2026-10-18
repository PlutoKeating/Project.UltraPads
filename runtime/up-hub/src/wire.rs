//! 控制面 HTTP JSON 报文（见 docs/API.md 第 4 节）。

use serde::{Deserialize, Serialize};

use crate::identity::DeviceId;
use crate::model::{BlobHash, LibraryManifest};

/// 自定义请求头：PUT blob 的续传起始偏移。
pub const HEADER_OFFSET: &str = "x-up-offset";
/// 自定义响应头：blob 总长度。
pub const HEADER_BLOB_SIZE: &str = "x-up-blob-size";

/// `GET /v1/info`
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct InfoResponse {
    /// 协议版本（= 1）。
    pub v: u32,
    /// Hub 设备 ID。客户端必须与 TLS 证书公钥核对。
    pub id: DeviceId,
    /// Hub 设备名。
    pub name: String,
    /// up-hub 版本。
    pub version: String,
    /// 调用者是否已被 Hub 信任。
    pub paired: bool,
    /// 当前是否有有效配对码（可配对）。
    pub pairing_open: bool,
}

/// `POST /v1/pair/start`
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PairStartRequest {
    /// 客户端设备名。
    pub name: String,
    /// SPAKE2 A 侧消息（base64）。
    pub spake: String,
}

/// `POST /v1/pair/start` 响应
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PairStartResponse {
    /// 本次配对会话 ID。
    pub pair_id: String,
    /// SPAKE2 B 侧消息（base64）。
    pub spake: String,
    /// `HMAC(K, "hub" ‖ T)`（base64）。
    pub confirm: String,
}

/// `POST /v1/pair/finish`
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PairFinishRequest {
    /// 会话 ID。
    pub pair_id: String,
    /// `HMAC(K, "device" ‖ T)`（base64）。
    pub confirm: String,
}

/// `POST /v1/pair/finish` 响应
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PairFinishResponse {
    /// Hub 设备 ID。
    pub hub_id: DeviceId,
    /// Hub 设备名。
    pub hub_name: String,
}

/// `POST /v1/manifest/merge`
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MergeRequest {
    /// 客户端（已与 Hub 清单预合并的）清单。
    pub manifest: LibraryManifest,
}

/// `POST /v1/manifest/merge` 响应
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MergeResponse {
    /// Hub 合并后的清单。
    pub manifest: LibraryManifest,
    /// Hub 侧新产生的冲突副本 ID。
    pub conflicts: Vec<String>,
    /// Hub 清单新增/改变的条目数。
    pub changed: u32,
}

/// `POST /v1/blobs/missing`
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MissingRequest {
    /// 待查询的 blob。
    pub hashes: Vec<BlobHash>,
}

/// 缺失的 blob。
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct MissingBlob {
    /// 地址。
    pub hash: BlobHash,
    /// 已有部分数据长度（续传偏移），0 表示完全没有。
    pub offset: u64,
}

/// `POST /v1/blobs/missing` 响应
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MissingResponse {
    /// 不完整的 blob。
    pub missing: Vec<MissingBlob>,
}

/// `PUT /v1/blob/{hash}` 响应
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PutBlobResponse {
    /// 地址。
    pub hash: BlobHash,
    /// 总字节数。
    pub size: u64,
    /// `stored`（本次写入完成）或 `exists`（之前已存在）。
    pub status: String,
}

/// `POST /v1/controller/open` 响应
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ControllerOpenResponse {
    /// 会话 ID（UDP 报文中携带）。
    pub session_id: u32,
    /// 32 字节 HMAC-SHA256 会话密钥（base64）。仅经 TLS 下发。
    pub key: String,
    /// Hub 的 UDP 端口。
    pub udp_port: u16,
    /// 建议的 ping/保活间隔（毫秒）。
    pub ping_interval_ms: u64,
    /// 无报文多久后 Hub 关闭会话（毫秒）。
    pub idle_timeout_ms: u64,
}

/// `POST /v1/controller/close`
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ControllerCloseRequest {
    /// 会话 ID。
    pub session_id: u32,
}

/// 错误响应体。
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct ErrorBody {
    /// 机器可读错误码。
    pub error: String,
    /// 可读描述。
    #[serde(default)]
    pub message: String,
    /// `offset_mismatch` 时：Hub 已有的部分数据长度。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expected_offset: Option<u64>,
    /// `missing_blobs` 时：清单引用但 Hub 缺失的 blob。
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub missing: Vec<BlobHash>,
}
