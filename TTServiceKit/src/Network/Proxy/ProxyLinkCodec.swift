//
//  ProxyLinkCodec.swift
//  TTServiceKit
//
//  Codec for the `ytp://config?d=<base64url envelope>` proxy share link (format v1).
//  Byte layout matches the server and the other clients exactly, so all interoperate.
//
//  Envelope = version(1B=0x01) | mode(1B) | body
//    mode 0x00 (plain)     : body = jsonBytes
//    mode 0x01 (encrypted) : body = salt(16) | iv(12) | AES-256-GCM(jsonBytes, aad = envelope[0..<2])
//                            key = PBKDF2-HMAC-SHA256(passphrase, salt, 600000, 32B)
//  link = "ytp://config?d=" + base64url-nopad(envelope)
//
//  Plain mode is base64 only (NOT confidential). Encrypted mode protects the payload
//  with a passphrase distributed out-of-band; the GCM tag implicitly verifies it.
//

import Foundation
import CryptoKit
import CommonCrypto

public enum ProxyLinkCodec {

    public enum Mode: UInt8 {
        case plain = 0x00
        case encrypted = 0x01
    }

    private static let version: UInt8 = 0x01
    private static let saltLen = 16
    private static let ivLen = 12
    private static let tagLen = 16
    private static let keyLen = 32
    private static let pbkdf2Iterations: UInt32 = 600_000

    /// Decoded envelope: the parsed mode, the body after the 2-byte header, and the
    /// 2-byte header itself (version|mode), which is the AAD for encrypted payloads.
    public struct Envelope {
        public let mode: Mode
        public let header: Data
        public let body: Data
    }

    // MARK: Inspect / decode

    public static func inspect(_ link: String) -> Envelope? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              comps.scheme?.lowercased() == "ytp",
              comps.host?.lowercased() == "config" else {
            return nil
        }

        var d: String?
        for item in comps.queryItems ?? [] where item.name.lowercased() == "d" {
            d = item.value
        }
        guard let d, let raw = base64urlDecode(d), raw.count >= 2 else { return nil }

        guard raw[raw.startIndex] == version,
              let mode = Mode(rawValue: raw[raw.index(after: raw.startIndex)]) else {
            return nil
        }
        let header = Data(raw.prefix(2))
        let body = Data(raw.dropFirst(2))
        return Envelope(mode: mode, header: header, body: body)
    }

    /// True when the link is a well-formed `ytp://config?d=` envelope whose version byte is
    /// present but not the one this build supports — i.e. a valid proxy address from a newer
    /// scheme this app is too old to parse. Lets the caller show "unsupported version" instead
    /// of the generic "invalid address" (both otherwise collapse to `inspect` returning nil).
    public static func isUnsupportedVersion(_ link: String) -> Bool {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              comps.scheme?.lowercased() == "ytp",
              comps.host?.lowercased() == "config" else {
            return false
        }
        var d: String?
        for item in comps.queryItems ?? [] where item.name.lowercased() == "d" {
            d = item.value
        }
        guard let d, let raw = base64urlDecode(d), raw.count >= 2 else { return false }
        return raw[raw.startIndex] != version
    }

    /// Plain (unencrypted) share link -> raw JSON bytes, or nil if not a plain `ytp` link.
    public static func decodePlain(_ link: String) -> Data? {
        guard let env = inspect(link), env.mode == .plain else { return nil }
        return env.body
    }

    /// Encrypted share link -> raw JSON bytes, or nil on wrong passphrase / malformed input.
    public static func decodeEncrypted(_ link: String, passphrase: String) -> Data? {
        guard !passphrase.isEmpty,
              let env = inspect(link), env.mode == .encrypted,
              env.body.count >= saltLen + ivLen + tagLen else {
            return nil
        }

        let salt = Data(env.body.prefix(saltLen))
        let iv = Data(env.body.dropFirst(saltLen).prefix(ivLen))
        let sealed = env.body.dropFirst(saltLen + ivLen)   // ciphertext || tag
        let cipherText = Data(sealed.prefix(sealed.count - tagLen))
        let tag = Data(sealed.suffix(tagLen))

        guard let key = pbkdf2SHA256(passphrase: passphrase, salt: salt) else { return nil }

        do {
            let box = try AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: iv),
                                            ciphertext: cipherText,
                                            tag: tag)
            return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: env.header)
        } catch {
            Logger.warn("[Proxy] encrypted share link decode failed (wrong passphrase?): \(error)")
            return nil
        }
    }

    // MARK: Encode (plain only — clients never emit encrypted links)

    /// Encode raw JSON bytes into a plain `ytp://config?d=...` link. Used to re-persist a
    /// decrypted (passphrase) link as plain text so restarts don't re-prompt for the passphrase.
    public static func encodePlain(json: Data) -> String {
        var envelope = Data([version, Mode.plain.rawValue])
        envelope.append(json)
        return "ytp://config?d=" + base64urlEncode(envelope)
    }

    // MARK: base64url (no padding)

    static func base64urlEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64urlDecode(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        let remainder = t.count % 4
        if remainder > 0 { t += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: t)
    }

    // MARK: PBKDF2-HMAC-SHA256 (CryptoKit has no PBKDF2 -> CommonCrypto)

    private static func pbkdf2SHA256(passphrase: String, salt: Data) -> Data? {
        let pwData = Data(passphrase.utf8)
        var derived = Data(count: keyLen)

        let status = derived.withUnsafeMutableBytes { derivedPtr -> Int32 in
            salt.withUnsafeBytes { saltPtr -> Int32 in
                pwData.withUnsafeBytes { pwPtr -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr.baseAddress?.assumingMemoryBound(to: Int8.self), pwData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Iterations,
                        derivedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self), keyLen
                    )
                }
            }
        }
        return status == kCCSuccess ? derived : nil
    }
}
