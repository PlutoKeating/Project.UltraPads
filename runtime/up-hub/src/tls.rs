//! TLS 1.3（rustls + ring）：证书由设备 Ed25519 密钥自签，双方按公钥钉扎（不使用 CA）。
//!
//! - 服务端证书公钥 = Hub 设备 ID；客户端按预期的 Hub ID 校验（不匹配即握手失败）。
//! - 客户端必须出示证书（公钥 = 设备 ID）；服务端接受任意 Ed25519 证书，
//!   再在应用层按受信列表授权（未配对设备只能访问 `/v1/info` 与 `/v1/pair/*`）。
//! - 证书中的名称、有效期与签发者都不参与校验；身份只由 TLS 握手中的
//!   CertificateVerify 签名（证明持有私钥）+ 公钥钉扎确定。

use std::sync::Arc;

use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::{CryptoProvider, WebPkiSupportedAlgorithms};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer, ServerName, UnixTime};
use rustls::server::danger::{ClientCertVerified, ClientCertVerifier};
use rustls::{CertificateError, DigitallySignedStruct, DistinguishedName, SignatureScheme};

use crate::identity::{DeviceId, DeviceIdentity};
use crate::{HubError, Result};

/// TLS SNI 中使用的固定名称（不参与校验）。
pub(crate) const TLS_SERVER_NAME: &str = "hub.ultrapads.local";

const ED25519_SPKI_PREFIX: [u8; 12] = [
    0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00,
];

/// 本机证书与私钥。
#[derive(Clone)]
pub(crate) struct TlsMaterial {
    cert: CertificateDer<'static>,
    key_pkcs8: Vec<u8>,
}

impl TlsMaterial {
    pub(crate) fn new(identity: &DeviceIdentity) -> Result<Self> {
        let der = identity.pkcs8_der()?;
        let kp = rcgen::KeyPair::from_pkcs8_der_and_sign_algo(
            &PrivatePkcs8KeyDer::from(der.as_slice()),
            &rcgen::PKCS_ED25519,
        )
        .map_err(|e| HubError::Tls(format!("keypair: {e}")))?;
        let mut params = rcgen::CertificateParams::new(vec![TLS_SERVER_NAME.to_string()])
            .map_err(|e| HubError::Tls(format!("cert params: {e}")))?;
        params.distinguished_name.push(
            rcgen::DnType::CommonName,
            format!("UltraPads {}", identity.id()),
        );
        let cert = params
            .self_signed(&kp)
            .map_err(|e| HubError::Tls(format!("self-sign: {e}")))?;
        Ok(Self {
            cert: cert.der().clone(),
            key_pkcs8: der,
        })
    }

    fn key(&self) -> PrivateKeyDer<'static> {
        PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(self.key_pkcs8.clone()))
    }
}

fn provider() -> Arc<CryptoProvider> {
    Arc::new(rustls::crypto::ring::default_provider())
}

/// 从证书中取出 Ed25519 公钥作为设备 ID。
pub(crate) fn device_id_from_cert(
    cert: &CertificateDer<'_>,
) -> std::result::Result<DeviceId, rustls::Error> {
    let ee = webpki::EndEntityCert::try_from(cert)
        .map_err(|_| rustls::Error::InvalidCertificate(CertificateError::BadEncoding))?;
    let spki = ee.subject_public_key_info();
    let b: &[u8] = spki.as_ref();
    if b.len() != 44 || b[..12] != ED25519_SPKI_PREFIX {
        return Err(rustls::Error::InvalidCertificate(
            CertificateError::ApplicationVerificationFailure,
        ));
    }
    let mut key = [0u8; 32];
    key.copy_from_slice(&b[12..]);
    Ok(DeviceId::from_bytes(key))
}

/// 从已完成握手的连接中取对端设备 ID。
pub(crate) fn peer_id(certs: Option<&[CertificateDer<'_>]>) -> Result<DeviceId> {
    let cert = certs
        .and_then(|c| c.first())
        .ok_or_else(|| HubError::Tls("peer presented no certificate".into()))?;
    device_id_from_cert(cert).map_err(HubError::from)
}

fn verify13(
    algs: &WebPkiSupportedAlgorithms,
    message: &[u8],
    cert: &CertificateDer<'_>,
    dss: &DigitallySignedStruct,
) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
    if dss.scheme != SignatureScheme::ED25519 {
        return Err(rustls::Error::PeerMisbehaved(
            rustls::PeerMisbehaved::SignedHandshakeWithUnadvertisedSigScheme,
        ));
    }
    rustls::crypto::verify_tls13_signature(message, cert, dss, algs)
}

#[derive(Debug)]
struct PinnedServerVerifier {
    expected: DeviceId,
    algs: WebPkiSupportedAlgorithms,
}

impl ServerCertVerifier for PinnedServerVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> std::result::Result<ServerCertVerified, rustls::Error> {
        let id = device_id_from_cert(end_entity)?;
        if id != self.expected {
            return Err(rustls::Error::InvalidCertificate(
                CertificateError::ApplicationVerificationFailure,
            ));
        }
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        Err(rustls::Error::General("TLS 1.2 is not supported".into()))
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        verify13(&self.algs, message, cert, dss)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![SignatureScheme::ED25519]
    }
}

/// 接受任意 Ed25519 客户端证书（授权在应用层完成）。
#[derive(Debug)]
struct AnyDeviceClientVerifier {
    algs: WebPkiSupportedAlgorithms,
}

impl ClientCertVerifier for AnyDeviceClientVerifier {
    fn root_hint_subjects(&self) -> &[DistinguishedName] {
        &[]
    }

    fn verify_client_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _now: UnixTime,
    ) -> std::result::Result<ClientCertVerified, rustls::Error> {
        device_id_from_cert(end_entity)?;
        Ok(ClientCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        Err(rustls::Error::General("TLS 1.2 is not supported".into()))
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        verify13(&self.algs, message, cert, dss)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![SignatureScheme::ED25519]
    }
}

pub(crate) fn server_config(m: &TlsMaterial) -> Result<Arc<rustls::ServerConfig>> {
    let p = provider();
    let verifier = Arc::new(AnyDeviceClientVerifier {
        algs: p.signature_verification_algorithms,
    });
    let mut cfg = rustls::ServerConfig::builder_with_provider(p)
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .with_client_cert_verifier(verifier)
        .with_single_cert(vec![m.cert.clone()], m.key())?;
    cfg.alpn_protocols = vec![b"http/1.1".to_vec()];
    Ok(Arc::new(cfg))
}

pub(crate) fn client_config(
    m: &TlsMaterial,
    expected_hub: DeviceId,
) -> Result<Arc<rustls::ClientConfig>> {
    let p = provider();
    let verifier = Arc::new(PinnedServerVerifier {
        expected: expected_hub,
        algs: p.signature_verification_algorithms,
    });
    let mut cfg = rustls::ClientConfig::builder_with_provider(p)
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .dangerous()
        .with_custom_certificate_verifier(verifier)
        .with_client_auth_cert(vec![m.cert.clone()], m.key())?;
    cfg.alpn_protocols = vec![b"http/1.1".to_vec()];
    Ok(Arc::new(cfg))
}

/// 探测用：接受任意 Ed25519 服务端证书（只用于 `GET /v1/info` 读取对端 ID，绝不传输数据）。
pub(crate) fn probe_client_config(m: &TlsMaterial) -> Result<Arc<rustls::ClientConfig>> {
    #[derive(Debug)]
    struct AnyServer(WebPkiSupportedAlgorithms);
    impl ServerCertVerifier for AnyServer {
        fn verify_server_cert(
            &self,
            end_entity: &CertificateDer<'_>,
            _: &[CertificateDer<'_>],
            _: &ServerName<'_>,
            _: &[u8],
            _: UnixTime,
        ) -> std::result::Result<ServerCertVerified, rustls::Error> {
            device_id_from_cert(end_entity)?;
            Ok(ServerCertVerified::assertion())
        }
        fn verify_tls12_signature(
            &self,
            _: &[u8],
            _: &CertificateDer<'_>,
            _: &DigitallySignedStruct,
        ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
            Err(rustls::Error::General("TLS 1.2 is not supported".into()))
        }
        fn verify_tls13_signature(
            &self,
            message: &[u8],
            cert: &CertificateDer<'_>,
            dss: &DigitallySignedStruct,
        ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
            verify13(&self.0, message, cert, dss)
        }
        fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
            vec![SignatureScheme::ED25519]
        }
    }
    let p = provider();
    let v = Arc::new(AnyServer(p.signature_verification_algorithms));
    let mut cfg = rustls::ClientConfig::builder_with_provider(p)
        .with_protocol_versions(&[&rustls::version::TLS13])?
        .dangerous()
        .with_custom_certificate_verifier(v)
        .with_client_auth_cert(vec![m.cert.clone()], m.key())?;
    cfg.alpn_protocols = vec![b"http/1.1".to_vec()];
    Ok(Arc::new(cfg))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cert_carries_device_key() {
        let id = DeviceIdentity::generate();
        let m = TlsMaterial::new(&id).unwrap();
        assert_eq!(device_id_from_cert(&m.cert).unwrap(), id.id());
        server_config(&m).unwrap();
        client_config(&m, id.id()).unwrap();
    }
}
