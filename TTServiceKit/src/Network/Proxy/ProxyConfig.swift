//
//  ProxyConfig.swift
//  TTServiceKit
//
//  Self-hosted proxy (TLS-in-TLS) — share-link parsing + tunnel whitelist.
//  Mirrors the ProxyConfig contract shared with the other clients.
//

import Foundation
import CryptoKit

/// Parsed proxy config decoded from a `ytp://config?d=<base64url envelope>` share link
/// (format v1, see `ProxyLinkCodec`). JSON payload: `{v,h,p,f,t,sni}`.
public struct ProxyConfig: Equatable {

    public let host: String
    public let port: Int
    /// Outer-layer cert pin from the share link (`f`). Base64 of the SPKI SHA-256
    /// (see `LocalTunnelProxy` verify block). Normalized.
    public let fingerprintBase64: String
    /// Optional disguise SNI for the outer handshake (`sni`). Falls back to a decoy
    /// hostname via `outerSni()` so the 443 demux routes us to the signaling terminator.
    public let sni: String?
    /// coturn `static-auth-secret` (`t`). Media relays via `turns:<host>:<port>` (turns:443).
    public let turnSecret: String?
    /// Optional plaintext TURN/UDP port (`tu`, typically 3478) for the dual media path.
    /// When present, an extra `turn:<host>:<tu>?transport=udp` candidate is offered
    /// alongside `turns:<host>:<port>` so ICE can pick it — the plaintext path drops the DPI
    /// camouflage but still relays media through coturn (IP stays hidden from the SFU).
    public let turnUdpPort: Int?
    /// Whether the proxy runs a QUIC MASQUE CONNECT-UDP relay (`q`). On iOS the LiveKit a22
    /// SDK can only tunnel *signaling* over QUIC-over-proxy (WSS has no proxy hook), so calls
    /// can hide the signaling IP only when this is true.
    public let quicEnabled: Bool

    // MARK: Parse

    /// Parse a plain (unencrypted) `ytp://config?d=...` share link.
    public static func parse(_ link: String) -> ProxyConfig? {
        guard let json = ProxyLinkCodec.decodePlain(link) else { return nil }
        return fromJSON(json)
    }

    /// Parse a passphrase-encrypted `ytp://config?d=...` share link. Returns nil on wrong
    /// passphrase or malformed input.
    public static func parse(_ link: String, passphrase: String) -> ProxyConfig? {
        guard let json = ProxyLinkCodec.decodeEncrypted(link, passphrase: passphrase) else { return nil }
        return fromJSON(json)
    }

    private static func fromJSON(_ data: Data) -> ProxyConfig? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let host = (obj["h"] as? String)?.trimmingCharacters(in: .whitespaces), !host.isEmpty,
              let fpRaw = obj["f"] as? String, !fpRaw.isEmpty else {
            return nil
        }
        // `tp` (legacy plain-TURN port) is intentionally ignored — the dual media path uses the
        // new `tu` key instead; never reuse the retired `tp`.
        // Clamp out-of-range ports to the default: an unvalidated `p` like 70000 would
        // otherwise trap the non-clamping `UInt16(config.port)` in ProxyConnectivityChecker.
        let portRaw = (obj["p"] as? Int) ?? 443
        let port = (1...65535).contains(portRaw) ? portRaw : 443
        let sni = (obj["sni"] as? String)?.trimmingCharacters(in: .whitespaces)
        let turnSecret = (obj["t"] as? String)?.trimmingCharacters(in: .whitespaces)
        let quicEnabled = ((obj["q"] as? Int) ?? 0) == 1 || (obj["q"] as? Bool) == true
        // `tu` only makes sense with a TURN secret; drop out-of-range ports.
        let turnUdpPort: Int? = {
            guard let tu = obj["tu"] as? Int, (1...65535).contains(tu) else { return nil }
            return tu
        }()

        return ProxyConfig(
            host: host,
            port: port,
            fingerprintBase64: normalizeBase64Pin(fpRaw),
            sni: (sni?.isEmpty ?? true) ? nil : sni,
            turnSecret: (turnSecret?.isEmpty ?? true) ? nil : turnSecret,
            turnUdpPort: turnUdpPort,
            quicEnabled: quicEnabled
        )
    }

    /// Re-encode as a plain `ytp://config?d=...` link. Used to persist a decrypted (passphrase)
    /// link as plain text so restarts don't re-prompt. `f` keeps the normalized pin (parse
    /// re-normalizes idempotently).
    public func toShareLink() -> String {
        var obj: [String: Any] = ["v": 1, "h": host, "p": port, "f": fingerprintBase64]
        if let turnSecret, !turnSecret.isEmpty { obj["t"] = turnSecret }
        if let turnUdpPort { obj["tu"] = turnUdpPort }
        if let sni, !sni.isEmpty { obj["sni"] = sni }
        if quicEnabled { obj["q"] = 1 }
        guard let json = try? JSONSerialization.data(withJSONObject: obj) else { return "" }
        return ProxyLinkCodec.encodePlain(json: json)
    }

    // MARK: Routing

    /// True if `host` must be tunneled (official source); false -> direct (3rd-party CDN).
    /// The whitelist comes from `ProxyTunnelConfig.effectiveTunnelDomains()` (server
    /// `proxy.tunnelDomains`, else IM + call domains derived from GlobalConfig). Match is exact:
    /// connection paths only ever dial domains taken straight from that config, so a suffix
    /// match would only risk tunneling (or leaking) hosts the config never listed.
    public func shouldTunnel(host: String) -> Bool {
        return ProxyTunnelConfig.effectiveTunnelDomains().contains(host.lowercased())
    }

    /// Outer-handshake SNI: a non-empty hostname so the proxy's 443 SNI demux routes us to
    /// the signaling terminator (hostname SNI), not coturn (IP/empty SNI). Defaults to a
    /// common decoy when the share link omits `sni`.
    public func outerSni() -> String {
        if let sni, !sni.isEmpty { return sni }
        return "www.bing.com"
    }

    // MARK: TURN (call media relay)

    public func turnEnabled() -> Bool {
        guard let secret = turnSecret, !secret.isEmpty else { return false }
        return true
    }

    /// coturn TURN REST credential: username = expiry timestamp, password = base64(HMAC-SHA1(secret, username)).
    /// TTL default 24h; coturn only checks expiry at allocation time.
    public func turnCredentials(ttl: TimeInterval = 24 * 3600,
                                now: Date = Date()) -> (username: String, password: String)? {
        guard turnEnabled(), let secret = turnSecret else { return nil }
        let expiry = Int(now.addingTimeInterval(ttl).timeIntervalSince1970)
        let username = String(expiry)
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data(username.utf8), using: key)
        let password = Data(mac).base64EncodedString()
        return (username, password)
    }

    // MARK: Pin normalization

    /// Standard base64 contains `+` and `/`. URL/share paths often decode `+` to a space and
    /// some emitters output url-safe base64 (`-`/`_`). Map all back to standard base64, losslessly.
    static func normalizeBase64Pin(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: " ", with: "+")
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
    }
}
