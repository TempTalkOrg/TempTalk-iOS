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

// MARK: - Protocol

public protocol GroupCryptoAPI {
    func upgradeToEncrypted(groupId: String, request: UpgradeGroupCryptoRequest) async throws
    func cryptoDispose(groupId: String, request: CryptoDisposeRequest) async throws
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

    public func cryptoDispose(groupId: String, request: CryptoDisposeRequest) async throws {
        let path = String(format: "/v1/groups/%@/members/crypto-dispose", groupId)
        let parameters: [String: Any] = ["members": request.members]

        guard let url = URL(string: path) else {
            throw OWSGenericError("[GroupCrypto] Invalid URL for crypto-dispose: \(path)")
        }
        let tsRequest = TSRequest(url: url, method: "POST", parameters: parameters)
        _ = try await networkManager.asyncRequest(tsRequest)
        Logger.info("[GroupCrypto] Crypto dispose succeeded for gid: \(groupId)")
    }
}
