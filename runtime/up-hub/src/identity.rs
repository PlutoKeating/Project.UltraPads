//! 设备身份（Ed25519）与受信设备列表。
//!
//! 数据目录布局：
//! - `identity.key`：32 字节 Ed25519 私钥种子（Unix 上权限 0600）
//! - `trusted.json`：已配对（受信）设备列表

use std::collections::{BTreeMap, HashMap};
use std::fmt;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::sync::{Arc, Mutex, OnceLock, Weak};

use ed25519_dalek::SigningKey;
use serde::{Deserialize, Serialize};

use crate::util::{atomic_write_sync, now_ms};
use crate::{HubError, Result};

const IDENTITY_FILE: &str = "identity.key";
const TRUST_FILE: &str = "trusted.json";

/// 设备 ID = Ed25519 公钥（32 字节）。文本形式为小写 RFC 4648 base32（无填充，52 字符）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct DeviceId([u8; 32]);

impl DeviceId {
    /// 由原始公钥字节构造。
    pub const fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// 原始公钥字节。
    pub const fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    /// 52 字符的 base32 文本。
    pub fn to_b32(&self) -> String {
        data_encoding::BASE32_NOPAD
            .encode(&self.0)
            .to_ascii_lowercase()
    }

    /// 前 8 个字符，便于在 UI/日志中显示。
    pub fn short(&self) -> String {
        self.to_b32()[..8].to_string()
    }

    /// 解析 base32 文本（大小写不敏感）。
    pub fn parse(s: &str) -> Result<Self> {
        let up = s.trim().to_ascii_uppercase();
        let raw = data_encoding::BASE32_NOPAD
            .decode(up.as_bytes())
            .map_err(|e| HubError::InvalidInput(format!("device id: {e}")))?;
        let arr: [u8; 32] = raw
            .try_into()
            .map_err(|_| HubError::InvalidInput("device id must be 32 bytes".into()))?;
        // 必须是合法的 Ed25519 公钥点。
        ed25519_dalek::VerifyingKey::from_bytes(&arr)
            .map_err(|_| HubError::InvalidInput("device id is not an ed25519 key".into()))?;
        Ok(Self(arr))
    }
}

impl fmt::Display for DeviceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.to_b32())
    }
}

impl fmt::Debug for DeviceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "DeviceId({})", self.short())
    }
}

impl FromStr for DeviceId {
    type Err = HubError;
    fn from_str(s: &str) -> Result<Self> {
        Self::parse(s)
    }
}

impl Serialize for DeviceId {
    fn serialize<S: serde::Serializer>(&self, s: S) -> std::result::Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_b32())
    }
}

impl<'de> Deserialize<'de> for DeviceId {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> std::result::Result<Self, D::Error> {
        let s = String::deserialize(d)?;
        DeviceId::parse(&s).map_err(serde::de::Error::custom)
    }
}

/// 本机设备身份（私钥只在内存与 `identity.key` 中）。
pub struct DeviceIdentity {
    signing: SigningKey,
    id: DeviceId,
}

impl fmt::Debug for DeviceIdentity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DeviceIdentity")
            .field("id", &self.id)
            .finish_non_exhaustive()
    }
}

impl DeviceIdentity {
    /// 从数据目录加载身份；不存在时生成并持久化。文件损坏时报错，绝不静默覆盖。
    pub fn load_or_create(data_dir: &Path) -> Result<Self> {
        let path = data_dir.join(IDENTITY_FILE);
        match std::fs::read(&path) {
            Ok(bytes) => {
                let seed: [u8; 32] = bytes.as_slice().try_into().map_err(|_| {
                    HubError::Store(format!(
                        "{} is corrupt (expected 32 bytes, got {})",
                        path.display(),
                        bytes.len()
                    ))
                })?;
                Ok(Self::from_seed(seed))
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                let me = Self::generate();
                atomic_write_sync(&path, &me.signing.to_bytes(), true)?;
                tracing::info!(id = %me.id, "generated new device identity");
                Ok(me)
            }
            Err(e) => Err(e.into()),
        }
    }

    /// 生成临时身份（不落盘）。
    pub fn generate() -> Self {
        let signing = SigningKey::generate(&mut rand::rngs::OsRng);
        let id = DeviceId(signing.verifying_key().to_bytes());
        Self { signing, id }
    }

    fn from_seed(seed: [u8; 32]) -> Self {
        let signing = SigningKey::from_bytes(&seed);
        let id = DeviceId(signing.verifying_key().to_bytes());
        Self { signing, id }
    }

    /// 本机设备 ID。
    pub fn id(&self) -> DeviceId {
        self.id
    }

    /// PKCS#8 v2 DER 编码的私钥（用于生成 TLS 证书）。
    pub(crate) fn pkcs8_der(&self) -> Result<Vec<u8>> {
        use ed25519_dalek::pkcs8::EncodePrivateKey;
        let doc = self
            .signing
            .to_pkcs8_der()
            .map_err(|e| HubError::Tls(format!("pkcs8: {e}")))?;
        Ok(doc.as_bytes().to_vec())
    }
}

/// 受信（已配对）设备。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrustedDevice {
    /// 设备 ID（公钥）。
    pub id: DeviceId,
    /// 配对时对端报告的设备名。
    pub name: String,
    /// 配对时间（Unix 毫秒）。
    pub paired_at_ms: i64,
}

#[derive(Serialize, Deserialize, Default)]
struct TrustFile {
    version: u32,
    devices: Vec<TrustedDevice>,
}

/// 受信设备列表，持久化到 `trusted.json`。
pub struct TrustStore {
    path: PathBuf,
    inner: Mutex<BTreeMap<DeviceId, TrustedDevice>>,
}

impl TrustStore {
    /// 加载（不存在时为空）。
    pub fn load(data_dir: &Path) -> Result<Self> {
        let path = data_dir.join(TRUST_FILE);
        let map = match std::fs::read(&path) {
            Ok(bytes) => {
                let f: TrustFile = serde_json::from_slice(&bytes)
                    .map_err(|e| HubError::Store(format!("{}: {e}", path.display())))?;
                f.devices.into_iter().map(|d| (d.id, d)).collect()
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => BTreeMap::new(),
            Err(e) => return Err(e.into()),
        };
        Ok(Self {
            path,
            inner: Mutex::new(map),
        })
    }

    fn persist(&self, map: &BTreeMap<DeviceId, TrustedDevice>) -> Result<()> {
        let f = TrustFile {
            version: 1,
            devices: map.values().cloned().collect(),
        };
        atomic_write_sync(&self.path, &serde_json::to_vec_pretty(&f)?, true)?;
        Ok(())
    }

    /// 查询某设备是否受信。
    pub fn get(&self, id: &DeviceId) -> Option<TrustedDevice> {
        self.inner.lock().expect("trust lock").get(id).cloned()
    }

    /// 所有受信设备。
    pub fn list(&self) -> Vec<TrustedDevice> {
        self.inner
            .lock()
            .expect("trust lock")
            .values()
            .cloned()
            .collect()
    }

    /// 添加或更新受信设备并持久化。
    pub fn insert(&self, id: DeviceId, name: &str) -> Result<TrustedDevice> {
        let mut map = self.inner.lock().expect("trust lock");
        let dev = TrustedDevice {
            id,
            name: name.to_string(),
            paired_at_ms: now_ms(),
        };
        let prev = map.insert(id, dev.clone());
        if let Err(e) = self.persist(&map) {
            // 回滚内存状态，保持与磁盘一致。
            match prev {
                Some(p) => map.insert(id, p),
                None => map.remove(&id),
            };
            return Err(e);
        }
        Ok(dev)
    }

    /// 移除受信设备；返回是否存在。
    pub fn remove(&self, id: &DeviceId) -> Result<bool> {
        let mut map = self.inner.lock().expect("trust lock");
        let Some(prev) = map.remove(id) else {
            return Ok(false);
        };
        if let Err(e) = self.persist(&map) {
            map.insert(*id, prev);
            return Err(e);
        }
        Ok(true)
    }
}

/// 一个数据目录对应的身份 + 信任列表。同一进程内同一目录共享一个实例，
/// 以免 Hub 与 Client 各自写 `trusted.json` 互相覆盖。
pub(crate) struct HubContext {
    pub identity: DeviceIdentity,
    pub trust: TrustStore,
}

pub(crate) fn open_context(data_dir: &Path) -> Result<Arc<HubContext>> {
    static REGISTRY: OnceLock<Mutex<HashMap<PathBuf, Weak<HubContext>>>> = OnceLock::new();
    std::fs::create_dir_all(data_dir)?;
    let key = std::fs::canonicalize(data_dir)?;
    let mut reg = REGISTRY
        .get_or_init(Default::default)
        .lock()
        .expect("context registry");
    if let Some(ctx) = reg.get(&key).and_then(Weak::upgrade) {
        return Ok(ctx);
    }
    let ctx = Arc::new(HubContext {
        identity: DeviceIdentity::load_or_create(&key)?,
        trust: TrustStore::load(&key)?,
    });
    reg.retain(|_, w| w.strong_count() > 0);
    reg.insert(key, Arc::downgrade(&ctx));
    Ok(ctx)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn device_id_roundtrip() {
        let id = DeviceIdentity::generate().id();
        let s = id.to_b32();
        assert_eq!(s.len(), 52);
        assert_eq!(DeviceId::parse(&s).unwrap(), id);
        assert_eq!(DeviceId::parse(&s.to_uppercase()).unwrap(), id);
        let json = serde_json::to_string(&id).unwrap();
        assert_eq!(serde_json::from_str::<DeviceId>(&json).unwrap(), id);
        assert!(DeviceId::parse("abc").is_err());
    }

    #[test]
    fn identity_persists_and_rejects_corruption() {
        let dir = tempfile::tempdir().unwrap();
        let a = DeviceIdentity::load_or_create(dir.path()).unwrap();
        let b = DeviceIdentity::load_or_create(dir.path()).unwrap();
        assert_eq!(a.id(), b.id());
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(dir.path().join(IDENTITY_FILE))
                .unwrap()
                .permissions()
                .mode();
            assert_eq!(mode & 0o777, 0o600);
        }
        std::fs::write(dir.path().join(IDENTITY_FILE), b"short").unwrap();
        assert!(DeviceIdentity::load_or_create(dir.path()).is_err());
    }

    #[test]
    fn trust_store_persists() {
        let dir = tempfile::tempdir().unwrap();
        let id = DeviceIdentity::generate().id();
        {
            let t = TrustStore::load(dir.path()).unwrap();
            t.insert(id, "phone").unwrap();
        }
        let t = TrustStore::load(dir.path()).unwrap();
        assert_eq!(t.get(&id).unwrap().name, "phone");
        assert!(t.remove(&id).unwrap());
        assert!(!t.remove(&id).unwrap());
        assert!(TrustStore::load(dir.path()).unwrap().list().is_empty());
    }

    #[test]
    fn context_is_shared_per_dir() {
        let dir = tempfile::tempdir().unwrap();
        let a = open_context(dir.path()).unwrap();
        let b = open_context(dir.path()).unwrap();
        assert!(Arc::ptr_eq(&a, &b));
    }
}
