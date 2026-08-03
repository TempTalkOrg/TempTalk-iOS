//
//  DTGifFavoriteCryptoService.swift
//  TTServiceKit
//
//  AES-256-GCM encryption of the whole GIF favorites list with favKey.
//  Cross-platform byte format (must match Android/Mac exactly):
//    blob = Base64( nonce(12B) ‖ ciphertext ‖ tag(16B) ), AAD = "tt-fav-v1|gcm|list".
//  CryptoKit's SealedBox.combined yields exactly nonce‖ciphertext‖tag.
//

import Foundation
import CryptoKit

public protocol GifFavoriteCryptoService {
    /// Generate a random 32-byte favKey.
    func generateFavKey() -> Data
    /// Encrypt the whole list (JSON) → Base64 blob. Returns nil on failure.
    func encryptList(favKey: Data, plaintext: Data) -> String?
    /// Decrypt a Base64 blob → list JSON. Returns nil on failure.
    func decryptList(favKey: Data, blob: String) -> Data?
    /// Wrap favKey with the account-derived KEK → self-describing envelope string (v2 §3.2).
    func wrapFavKey(_ favKey: Data, kek: Data) -> String?
    /// Unwrap the envelope with the KEK → favKey. Returns nil on failure (stale masterKey / bad data).
    func unwrapFavKey(_ envelope: String, kek: Data) -> Data?
}

@objc
public final class DTGifFavoriteCryptoServiceImpl: NSObject, GifFavoriteCryptoService {

    /// GCM additional authenticated data, identical across all clients.
    private static let aad = Data("tt-fav-v1|gcm|list".utf8)
    /// AAD for wrapping favKey with the KEK (v2 §6). Distinct from the list AAD.
    private static let wrapAad = Data("tt-fav-wrap-v1".utf8)

    public func generateFavKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes)
    }

    public func encryptList(favKey: Data, plaintext: Data) -> String? {
        do {
            let key = SymmetricKey(data: favKey)
            // seal() uses a fresh random 12-byte nonce; .combined = nonce ‖ ciphertext ‖ tag.
            let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: Self.aad)
            guard let combined = sealed.combined else {
                Logger.error("[GifFav] encryptList: nil combined box")
                return nil
            }
            return combined.base64EncodedString()
        } catch {
            Logger.error("[GifFav] encryptList failed: \(error)")
            return nil
        }
    }

    public func decryptList(favKey: Data, blob: String) -> Data? {
        guard let combined = Data(base64Encoded: blob) else {
            Logger.error("[GifFav] decryptList failed: invalid base64, blobLen: \(blob.count)")
            return nil
        }
        do {
            let key = SymmetricKey(data: favKey)
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key, authenticating: Self.aad)
        } catch {
            Logger.error("[GifFav] decryptList failed: \(error), blobDataLen: \(combined.count)")
            return nil
        }
    }

    // MARK: - favKey wrap / unwrap (v2 §3.2)

    public func wrapFavKey(_ favKey: Data, kek: Data) -> String? {
        do {
            let sealed = try AES.GCM.seal(favKey, using: SymmetricKey(data: kek), authenticating: Self.wrapAad)
            guard let combined = sealed.combined else { return nil }  // nonce ‖ ct ‖ tag
            // Self-describing envelope; only `ct` must be byte-identical across clients.
            let envelope: [String: Any] = [
                "v": 1,
                "kdf": "hkdf-sha256",
                "root": "master",
                "cipher": "aes-256-gcm",
                "ct": combined.base64EncodedString()
            ]
            let data = try JSONSerialization.data(withJSONObject: envelope)
            return String(data: data, encoding: .utf8)
        } catch {
            Logger.error("[GifFav] wrapFavKey failed: \(error)")
            return nil
        }
    }

    public func unwrapFavKey(_ envelope: String, kek: Data) -> Data? {
        guard let data = envelope.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ct = obj["ct"] as? String,
              let combined = Data(base64Encoded: ct) else {
            Logger.error("[GifFav] unwrapFavKey: malformed envelope")
            return nil
        }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: SymmetricKey(data: kek), authenticating: Self.wrapAad)
        } catch {
            Logger.error("[GifFav] unwrapFavKey failed (stale masterKey?): \(error)")
            return nil
        }
    }
}
