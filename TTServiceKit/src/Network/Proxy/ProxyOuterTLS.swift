//
//  ProxyOuterTLS.swift
//  TTServiceKit
//
//  Outer-layer (client <-> proxy) TLS parameters: decoy hostname SNI + SPKI fingerprint
//  pinning, fully isolated from the chative CA. Shared by LocalTunnelProxy (the live tunnel)
//  and ProxyConnectivityChecker (the settings-page reachability probe) so the pin logic
//  lives in one place.
//

import Foundation
import Network
import Security
import CryptoKit

@available(iOS 13.0, *)
public enum ProxyOuterTLS {

    /// NWParameters for the outer hop: sends `config.outerSni()` and accepts the peer cert
    /// only if its SPKI SHA-256 matches `config.fingerprintBase64`. The verify block runs on
    /// `queue`. Inner (chative-CA) TLS is layered on top by the caller, untouched.
    ///
    /// `onVerify` (optional) fires with the pin result the moment the verify block runs, on
    /// `queue`. `ProxyConnectivityChecker` uses it to report `.pinMismatch` immediately: a rejected
    /// verify block makes `NWConnection` retry/wait rather than surface `.failed(.tls)`, so without
    /// this signal a bad pin would only ever be reported as a timeout.
    static func parameters(for config: ProxyConfig,
                           on queue: DispatchQueue,
                           onVerify: ((Bool) -> Void)? = nil) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let sec = tls.securityProtocolOptions

        sec_protocol_options_set_tls_server_name(sec, config.outerSni())

        let expectedPin = config.fingerprintBase64
        sec_protocol_options_set_verify_block(sec, { _, secTrust, complete in
            let trust = sec_trust_copy_ref(secTrust).takeRetainedValue()

            let leaf: SecCertificate?
            if #available(iOS 15.0, *) {
                leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
            } else {
                leaf = SecTrustGetCertificateAtIndex(trust, 0)
            }
            guard let leaf else {
                onVerify?(false)
                complete(false)
                return
            }
            guard let digest = spkiSha256Base64(leaf) else {
                Logger.error("[Proxy] could not derive SPKI from leaf cert")
                onVerify?(false)
                complete(false)
                return
            }
            let match = (digest == expectedPin)
            if !match {
                Logger.error("[Proxy] outer SPKI pin mismatch")
            }
            onVerify?(match)
            complete(match)
        }, queue)

        return NWParameters(tls: tls)
    }

    // MARK: SPKI pin

    /// SubjectPublicKeyInfo SHA-256, standard base64 — matches the server's openssl pipeline.
    /// `SecKeyCopyExternalRepresentation` returns the bare key (PKCS#1 for RSA), so we prepend
    /// the fixed ASN.1 SPKI header to reconstruct the DER that openssl hashes.
    /// Covers RSA-4096 (the proxy's self-signed key type); add headers for other key types.
    private static let rsa4096SpkiHeader: [UInt8] = [
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
    ]

    /// SPKI SHA-256 (standard base64) from an X.509 DER certificate. Used by the call path's
    /// TURN-TLS `SSLCertificateVerifier` (a22) to pin the coturn leaf with the same logic as
    /// the signaling tunnel. Returns nil if the DER can't be parsed.
    public static func spkiSha256Base64(fromDERCertificate der: Data) -> String? {
        guard let cert = SecCertificateCreateWithData(nil, der as CFData) else { return nil }
        return spkiSha256Base64(cert)
    }

    static func spkiSha256Base64(_ cert: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(cert),
              let raw = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            return nil
        }
        var spki = Data(rsa4096SpkiHeader)
        spki.append(raw)
        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }
}
