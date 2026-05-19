//
//  GroupCryptoService.swift
//  TTServiceKit
//

import Foundation
import DTProto

// MARK: - Key Set

public struct GroupKeySet {
    public let kGroup: Data    // AES-256-GCM key for encrypting group name/avatar
    public let skBind: Data    // Ed25519 private key for signing member UIDs
    public let pkBind: Data    // Ed25519 public key (raw 32 bytes)
    public let pkBindSPKI: String // pk_bind in X.509 SPKI DER Base64 (for server upload)

    public init(kGroup: Data, skBind: Data, pkBind: Data, pkBindSPKI: String) {
        self.kGroup = kGroup
        self.skBind = skBind
        self.pkBind = pkBind
        self.pkBindSPKI = pkBindSPKI
    }
}

// MARK: - Member Binding

public struct GroupMemberBinding {
    public let uid: String
    public let uidSignature: String

    public init(uid: String, uidSignature: String) {
        self.uid = uid
        self.uidSignature = uidSignature
    }

    public var asDictionary: [String: String] {
        ["uid": uid, "uidSignature": uidSignature]
    }
}

// MARK: - Protocol

public protocol GroupCryptoService {

    /// Generate a random 32-byte R_group
    func generateRGroup() -> Data

    /// Derive K_group, sk_bind, pk_bind from R_group via HKDF. Returns nil on FFI failure.
    func deriveKeys(rGroup: Data) -> GroupKeySet?

    /// Encrypt group name with K_group (AES-256-GCM) → Base64 blob
    func encryptGroupName(kGroup: Data, plainName: String) -> String?

    /// Decrypt group name from Base64 blob → plaintext
    func decryptGroupName(kGroup: Data, encryptedName: String) -> String?

    /// Encrypt group avatar JSON with K_group → Base64 blob
    func encryptGroupAvatar(kGroup: Data, plainAvatar: String) -> String?

    /// Decrypt group avatar JSON from Base64 blob → plaintext
    func decryptGroupAvatar(kGroup: Data, encryptedAvatar: String) -> String?

    /// Sign a member UID with sk_bind (Ed25519) → Base64 signature
    func signUid(skBind: Data, uid: String) -> String?

    /// Verify a member UID signature with pk_bind → Bool
    func verifyUid(pkBind: Data, uid: String, uidSignature: String) -> Bool
}

// MARK: - Convenience

public extension GroupCryptoService {

    func signMembers(skBind: Data, uids: [String]) -> [GroupMemberBinding]? {
        var bindings: [GroupMemberBinding] = []
        for uid in uids {
            guard let sig = signUid(skBind: skBind, uid: uid) else { return nil }
            bindings.append(GroupMemberBinding(uid: uid, uidSignature: sig))
        }
        return bindings
    }
}

// MARK: - Implementation

@objc
public final class DTGroupCryptoServiceImpl: NSObject, GroupCryptoService {

    private static let groupCryptoVersion: UInt8 = 1

    private static let aadGroupName = "tt-grp-v1|gcm|name"
    private static let aadGroupAvatar = "tt-grp-v1|gcm|avatar"

    // Ed25519 X.509 SPKI DER header (OID 1.3.101.112)
    private static let ed25519SPKIHeader: [UInt8] = [
        0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00
    ]

    private let adapter: DTProtoAdapter

    @objc
    public init(adapter: DTProtoAdapter = DTProtoAdapter()) {
        self.adapter = adapter
        super.init()
    }

    public func generateRGroup() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes)
    }

    public func deriveKeys(rGroup: Data) -> GroupKeySet? {
        do {
            let result = try adapter.groupCryptoDeriveKeys(version: Self.groupCryptoVersion, rGroup: rGroup)
            let pkBindSPKI = Self.wrapEd25519SPKI(rawPublicKey: result.pkBind)
            return GroupKeySet(kGroup: result.kGroup,
                               skBind: result.skBind,
                               pkBind: result.pkBind,
                               pkBindSPKI: pkBindSPKI)
        } catch {
            Logger.error("[GroupCrypto] deriveKeys failed: \(error)")
            return nil
        }
    }

    public func encryptGroupName(kGroup: Data, plainName: String) -> String? {
        encrypt(kGroup: kGroup, plaintext: plainName, aad: Self.aadGroupName)
    }

    public func decryptGroupName(kGroup: Data, encryptedName: String) -> String? {
        decrypt(kGroup: kGroup, blob: encryptedName, aad: Self.aadGroupName)
    }

    public func encryptGroupAvatar(kGroup: Data, plainAvatar: String) -> String? {
        encrypt(kGroup: kGroup, plaintext: plainAvatar, aad: Self.aadGroupAvatar)
    }

    public func decryptGroupAvatar(kGroup: Data, encryptedAvatar: String) -> String? {
        decrypt(kGroup: kGroup, blob: encryptedAvatar, aad: Self.aadGroupAvatar)
    }

    public func signUid(skBind: Data, uid: String) -> String? {
        do {
            let signature = try adapter.groupCryptoSignUid(version: Self.groupCryptoVersion,
                                                           skBind: skBind,
                                                           uid: uid)
            return signature.base64EncodedString()
        } catch {
            Logger.error("[GroupCrypto] signUid failed: \(error)")
            return nil
        }
    }

    public func verifyUid(pkBind: Data, uid: String, uidSignature: String) -> Bool {
        guard let signatureData = Data(base64Encoded: uidSignature) else {
            Logger.error("[GroupCrypto] verifyUid: invalid base64 signature")
            return false
        }
        do {
            let result = try adapter.groupCryptoVerifyUid(version: Self.groupCryptoVersion,
                                                          pkBind: pkBind,
                                                          uid: uid,
                                                          signature: signatureData)
            return result.boolValue
        } catch {
            Logger.error("[GroupCrypto] verifyUid failed: \(error)")
            return false
        }
    }

    // MARK: - Private

    private func encrypt(kGroup: Data, plaintext: String, aad: String) -> String? {
        guard let plaintextData = plaintext.data(using: .utf8),
              let aadData = aad.data(using: .utf8) else { return nil }
        do {
            let blob = try adapter.groupCryptoEncrypt(version: Self.groupCryptoVersion,
                                                      kGroup: kGroup,
                                                      plaintext: plaintextData,
                                                      aad: aadData)
            return blob.base64EncodedString()
        } catch {
            Logger.error("[GroupCrypto] encrypt failed: \(error)")
            return nil
        }
    }

    private func decrypt(kGroup: Data, blob: String, aad: String) -> String? {
        guard let blobData = Data(base64Encoded: blob) else {
            Logger.error("[GroupCrypto] decrypt failed: invalid base64, aad: \(aad), blobLen: \(blob.count)")
            return nil
        }
        guard let aadData = aad.data(using: .utf8) else {
            Logger.error("[GroupCrypto] decrypt failed: aad utf8 encode, aad: \(aad)")
            return nil
        }
        do {
            let plaintext = try adapter.groupCryptoDecrypt(version: Self.groupCryptoVersion,
                                                           kGroup: kGroup,
                                                           blob: blobData,
                                                           aad: aadData)
            guard let result = String(data: plaintext, encoding: .utf8) else {
                Logger.error("[GroupCrypto] decrypt failed: plaintext utf8 decode, aad: \(aad), plainLen: \(plaintext.count)")
                return nil
            }
            return result
        } catch {
            Logger.error("[GroupCrypto] decrypt failed: adapter error, aad: \(aad), kGroupLen: \(kGroup.count), blobDataLen: \(blobData.count), error: \(error)")
            return nil
        }
    }

    static func wrapEd25519SPKI(rawPublicKey: Data) -> String {
        var spki = Data(ed25519SPKIHeader)
        spki.append(rawPublicKey)
        return spki.base64EncodedString()
    }
}
