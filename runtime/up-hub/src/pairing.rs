//! 配对：6 位一次性配对码 + SPAKE2（口令认证密钥交换）+ 绑定双方 TLS 公钥的确认 MAC。
//!
//! 流程（均在双向 TLS 内，客户端证书即设备公钥 D，服务端证书即 Hub 公钥 H）：
//! 1. 客户端 `POST /v1/pair/start {name, spake=msgA}`；
//! 2. Hub 用当前配对码做 SPAKE2(B)，返回 `{pair_id, spake=msgB, confirm=HMAC(K, "hub"‖T)}`；
//! 3. 客户端校验 Hub 的 confirm（T 中的 H 取自 TLS 证书），再 `POST /v1/pair/finish {pair_id, confirm=HMAC(K,"device"‖T)}`；
//! 4. Hub 校验后把 D 写入受信列表并作废配对码；客户端把 H 写入受信列表。
//!
//! `T = "ultrapads/pair/v1" ‖ H ‖ D ‖ msgA ‖ msgB`。中间人即使替换了 TLS 公钥，
//! 不知道配对码也无法让两侧的 T 与 K 同时一致；每次尝试只是一次在线猜测（1/10^6），
//! 并且失败次数受 `max_attempts` 限制。

use hmac::{Hmac, Mac};
use rand::Rng;
use sha2::Sha256;

use crate::identity::DeviceId;
use crate::{HubError, Result};

pub(crate) const SPAKE_ID_DEVICE: &[u8] = b"ultrapads/pair/device";
pub(crate) const SPAKE_ID_HUB: &[u8] = b"ultrapads/pair/hub";
pub(crate) const ROLE_HUB: &[u8] = b"hub";
pub(crate) const ROLE_DEVICE: &[u8] = b"device";

/// 配对码长度。
pub const PAIRING_CODE_LEN: usize = 6;

/// 生成 6 位数字配对码。
pub(crate) fn generate_code() -> String {
    let n: u32 = rand::rngs::OsRng.gen_range(0..1_000_000);
    format!("{n:06}")
}

/// 规范化用户输入（去掉空格和连字符），必须为 6 位数字。
pub(crate) fn normalize_code(input: &str) -> Result<String> {
    let s: String = input
        .chars()
        .filter(|c| !c.is_whitespace() && *c != '-')
        .collect();
    if s.len() != PAIRING_CODE_LEN || !s.chars().all(|c| c.is_ascii_digit()) {
        return Err(HubError::InvalidInput(
            "pairing code must be 6 digits".into(),
        ));
    }
    Ok(s)
}

pub(crate) fn transcript(hub: &DeviceId, device: &DeviceId, msg_a: &[u8], msg_b: &[u8]) -> Vec<u8> {
    let mut t = Vec::with_capacity(17 + 64 + msg_a.len() + msg_b.len() + 8);
    t.extend_from_slice(b"ultrapads/pair/v1");
    t.extend_from_slice(hub.as_bytes());
    t.extend_from_slice(device.as_bytes());
    t.extend_from_slice(&(msg_a.len() as u32).to_be_bytes());
    t.extend_from_slice(msg_a);
    t.extend_from_slice(&(msg_b.len() as u32).to_be_bytes());
    t.extend_from_slice(msg_b);
    t
}

pub(crate) fn confirm(key: &[u8], role: &[u8], transcript: &[u8]) -> [u8; 32] {
    let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(key).expect("hmac accepts any key length");
    mac.update(role);
    mac.update(transcript);
    mac.finalize().into_bytes().into()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::identity::DeviceIdentity;
    use spake2::{Ed25519Group, Identity, Password, Spake2};

    #[test]
    fn code_format() {
        for _ in 0..100 {
            let c = generate_code();
            assert_eq!(normalize_code(&c).unwrap(), c);
        }
        assert_eq!(normalize_code(" 123-456 ").unwrap(), "123456");
        assert!(normalize_code("12345").is_err());
        assert!(normalize_code("12345a").is_err());
    }

    fn run(code_a: &str, code_b: &str) -> bool {
        let (h, d) = (
            DeviceIdentity::generate().id(),
            DeviceIdentity::generate().id(),
        );
        let ids = (Identity::new(SPAKE_ID_DEVICE), Identity::new(SPAKE_ID_HUB));
        let (sa, ma) = Spake2::<Ed25519Group>::start_a(&Password::new(code_a), &ids.0, &ids.1);
        let (sb, mb) = Spake2::<Ed25519Group>::start_b(&Password::new(code_b), &ids.0, &ids.1);
        let ka = sa.finish(&mb).unwrap();
        let kb = sb.finish(&ma).unwrap();
        let t = transcript(&h, &d, &ma, &mb);
        confirm(&ka, ROLE_HUB, &t) == confirm(&kb, ROLE_HUB, &t)
    }

    #[test]
    fn spake_confirm_matches_only_with_same_code() {
        assert!(run("123456", "123456"));
        assert!(!run("123456", "123457"));
    }
}
