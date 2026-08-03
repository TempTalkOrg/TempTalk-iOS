//
//  DTGroupCryptoAPI.swift
//  TTServiceKit
//

import Foundation

// MARK: - Request Models

public struct UpgradeGroupCryptoRequest {
    public let groupCryptoMode: Int
    public let encryptedName: String
    public let encryptedAvatar: String?
    public let groupMemberVerifyPublicKey: String
    public let memberBindings: [[String: String]]

    public init(groupCryptoMode: Int,
                encryptedName: String,
                encryptedAvatar: String?,
                groupMemberVerifyPublicKey: String,
                memberBindings: [[String: String]]) {
        self.groupCryptoMode = groupCryptoMode
        self.encryptedName = encryptedName
        self.encryptedAvatar = encryptedAvatar
        self.groupMemberVerifyPublicKey = groupMemberVerifyPublicKey
        self.memberBindings = memberBindings
    }
}

public struct CryptoDisposeRequest {
    public let members: [String]

    public init(members: [String]) {
        self.members = members
    }
}

public struct CryptoDisposeResponse {
    public let removed: [String]
    public let rejected: [String]
}

// MARK: - Protocol

public protocol GroupCryptoAPI {
    func upgradeToEncrypted(groupId: String, request: UpgradeGroupCryptoRequest) async throws
    /// Rotate an already-encrypted group's crypto key. `baseKeyVersion` is the CAS baseline
    /// (the current groupCryptoKeyVersion known before rotating). Returns the new keyVersion.
    func rotateCrypto(groupId: String, request: UpgradeGroupCryptoRequest, baseKeyVersion: Int) async throws -> Int
    func cryptoDispose(groupId: String, request: CryptoDisposeRequest) async throws -> CryptoDisposeResponse
}

// MARK: - Implementation

public final class DTGroupCryptoAPIImpl: GroupCryptoAPI {

    private let networkManager: NetworkManager

    public init(networkManager: NetworkManager = .sharedInstance) {
        self.networkManager = networkManager
    }

    public func upgradeToEncrypted(groupId: String, request: UpgradeGroupCryptoRequest) async throws {
        let path = String(format: "/v1/groups/%@/upgrade-to-encrypted", groupId)

        var parameters: [String: Any] = [
            "groupCryptoMode": request.groupCryptoMode,
            "encryptedName": request.encryptedName,
            "groupMemberVerifyPublicKey": request.groupMemberVerifyPublicKey,
            "memberBindings": request.memberBindings
        ]
        if let encryptedAvatar = request.encryptedAvatar {
            parameters["encryptedAvatar"] = encryptedAvatar
        }

        guard let url = URL(string: path) else {
            throw OWSGenericError("[GroupCrypto] Invalid URL for upgrade-to-encrypted: \(path)")
        }
        let tsRequest = TSRequest(url: url, method: "PUT", parameters: parameters)
        _ = try await networkManager.asyncRequest(tsRequest)
        Logger.info("[GroupCrypto] Upgrade to encrypted succeeded for gid: \(groupId)")
    }

    public func rotateCrypto(groupId: String, request: UpgradeGroupCryptoRequest, baseKeyVersion: Int) async throws -> Int {
        let path = String(format: "/v1/groups/%@/rotate-crypto", groupId)

        var parameters: [String: Any] = [
            "groupCryptoMode": request.groupCryptoMode,
            "encryptedName": request.encryptedName,
            "groupMemberVerifyPublicKey": request.groupMemberVerifyPublicKey,
            "memberBindings": request.memberBindings,
            "baseGroupCryptoKeyVersion": baseKeyVersion
        ]
        if let encryptedAvatar = request.encryptedAvatar {
            parameters["encryptedAvatar"] = encryptedAvatar
        }

        guard let url = URL(string: path) else {
            throw OWSGenericError("[GroupCrypto] Invalid URL for rotate-crypto: \(path)")
        }
        let tsRequest = TSRequest(url: url, method: "PUT", parameters: parameters)
        let httpResponse = try await networkManager.asyncRequest(tsRequest)

        // The server's returned new keyVersion IS the proof that it actually committed the rotate. We
        // require it (and that it advanced past the CAS base) and use it verbatim — the server is the
        // sole authority. If it's missing/invalid we throw rather than fabricate base+1: a version-less
        // 200 means the rotate is unconfirmed (e.g. a proxy/cache 200, server didn't really rotate), and
        // distributing a key the server may not recognize is exactly the silent client/server mismatch
        // that breaks decryption + add-member. Failing loudly is recoverable (retry re-GETs a fresh base).
        var parsedVersion: Int?
        if let json = httpResponse.responseBodyJson as? [String: Any],
           let data = json["data"] as? [String: Any] {
            parsedVersion = (data["groupCryptoKeyVersion"] as? Int) ?? (data["keyVersion"] as? Int)
        }
        guard let newKeyVersion = parsedVersion, newKeyVersion > baseKeyVersion else {
            throw OWSGenericError("[GroupCrypto] rotate-crypto returned no valid new keyVersion (base: \(baseKeyVersion), parsed: \(parsedVersion.map(String.init) ?? "nil"))")
        }
        Logger.info("[GroupCrypto] rotate-crypto succeeded for gid: \(groupId), base: \(baseKeyVersion), newKeyVersion: \(newKeyVersion)")
        return newKeyVersion
    }

    @discardableResult
    public func cryptoDispose(groupId: String, request: CryptoDisposeRequest) async throws -> CryptoDisposeResponse {
        let path = String(format: "/v1/groups/%@/members/crypto-dispose", groupId)
        let parameters: [String: Any] = ["uids": request.members]

        guard let url = URL(string: path) else {
            throw OWSGenericError("[GroupCrypto] Invalid URL for crypto-dispose: \(path)")
        }
        let tsRequest = TSRequest(url: url, method: "POST", parameters: parameters)
        let httpResponse = try await networkManager.asyncRequest(tsRequest)

        var removed: [String] = []
        var rejected: [String] = []
        if let json = httpResponse.responseBodyJson as? [String: Any],
           let data = json["data"] as? [String: Any] {
            removed = data["removed"] as? [String] ?? []
            rejected = data["rejected"] as? [String] ?? []
        }
        
        return CryptoDisposeResponse(removed: removed, rejected: rejected)
    }
}
