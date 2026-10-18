//! # up-hub：UltraPads 个人多设备协同
//!
//! 不是面向公众的云服务，而是"一个人的多台设备"之间的协同：
//! 桌面端兼任个人 Hub（局域网自动发现），手机采样、电脑编曲，曲库双向增量同步，
//! 手机还能作为电脑的实时打击垫控制器。
//!
//! - **发现**：mDNS `_ultrapads._tcp.local.`（[`discover`]）
//! - **身份与配对**：每台设备一对 Ed25519 密钥；6 位一次性配对码 + SPAKE2；
//!   之后所有连接都是按公钥钉扎的双向 TLS 1.3（[`HubClient::pair`]）
//! - **控制面**：HTTPS/1.1 JSON（axum），见 docs/API.md 第 4 节（[`HubServer`]）
//! - **同步**：BLAKE3 内容寻址 blob + 清单合并（版本向量 + LWW + 冲突副本），可续传（[`HubClient::sync`]）
//! - **控制器**：UDP + 会话 HMAC，双发、去重、乱序处理（[`HubClient::controller_connect`]）
//! - **解耦**：曲库通过 [`LibraryStore`]、引擎通过 [`PadSink`] 接入；传输通过 [`HubTransport`] 抽象
//!
//! 设计决策见 docs/adr/0004-personal-hub.md。

#![warn(missing_docs)]

mod client;
mod controller;
mod discovery;
mod error;
mod identity;
mod model;
mod pairing;
mod server;
mod sink;
mod store;
mod tls;
mod transport;
mod util;
pub mod wire;

pub use client::{ClientConfig, HubClient, HubPeer};
pub use controller::{
    ControllerHandle, ControllerSessionStats, EVENT_COPIES, LatencyStats, RemotePadEvent,
};
pub use discovery::{Discovery, DiscoveryEvent, SERVICE_TYPE, discover};
pub use error::{HubError, Result};
pub use identity::{DeviceId, DeviceIdentity, TrustedDevice};
pub use model::{
    BlobHash, BlobRef, Causality, EntryKind, LibraryManifest, MANIFEST_SCHEMA, ManifestEntry,
    MergeOutcome, SyncReport, VersionVector, merge,
};
pub use pairing::PAIRING_CODE_LEN;
pub use server::{HubConfig, HubServer, PairingCode};
pub use sink::{NullPadSink, PadSink};
pub use store::{BlobReader, BlobStatus, BlobWriter, FsLibraryStore, LibraryStore};
pub use transport::{
    AsyncStream, BoxedStream, Connected, DatagramChannel, HubTransport, LanTransport, PeerAddr,
};
pub use util::now_ms;

/// Hub 协议版本（mDNS TXT `v`、`/v1/info` 的 `v`、UDP 报文 `ver`）。
pub const PROTOCOL_VERSION: u32 = 1;
