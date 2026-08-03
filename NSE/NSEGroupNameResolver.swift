//
//  NSEGroupNameResolver.swift
//  NSE
//

import Foundation
import TTServiceKit

internal enum GroupNameResolution {
    case useServerProvided
    case replace(String)
}

internal struct NSEGroupNameResolver {
    func resolve(aps: [String: Any],
                 lockey: String,
                 transaction: SDSAnyReadTransaction) -> GroupNameResolution {
        guard let passthroughString = aps["passthrough"] as? String,
              let passthroughData = passthroughString.data(using: .utf8),
              let passthroughDict = try? JSONSerialization.jsonObject(with: passthroughData) as? [String: Any],
              let rawConversationId = passthroughDict["conversationId"] as? String else {
            return .useServerProvided
        }

        let conversationId = Self.normalizeConversationId(rawConversationId)

        guard let groupIdData = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) else {
            return .useServerProvided
        }

        let threadId = TSGroupThread.threadId(fromGroupId: groupIdData)
        if let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction) {
            return resolveWithThread(groupThread, transaction: transaction)
        }
        return resolveWithoutThread(serverGid: conversationId, transaction: transaction)
    }

    private func resolveWithThread(_ groupThread: TSGroupThread,
                                    transaction: SDSAnyReadTransaction) -> GroupNameResolution {
        guard groupThread.groupModel.isEncryptedGroup else {
            return .useServerProvided
        }

        let serverGid = groupThread.serverThreadId
        guard !serverGid.isEmpty else {
            Logger.error("[NSE] encrypted group thread has empty serverThreadId")
            return .useServerProvided
        }

        // Receiving a notification implies membership; missing R_group is an anomaly.
        if !DTGroupCryptoDisplayHelper.shared.hasGroupKey(gid: serverGid, transaction: transaction) {
            Logger.error("[NSE] encrypted group missing R_group locally, gid: \(serverGid)")
        }

        let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: serverGid, transaction: transaction)
        // Prefer baseInfo.name; it outlives the thread.
        let originalName: String? = baseInfo?.name ?? groupThread.groupModel.groupName
        let displayName = DTGroupCryptoDisplayHelper.shared.displayGroupName(
            gid: serverGid,
            groupCryptoMode: groupThread.groupModel.groupCryptoMode,
            encryptedName: baseInfo?.encryptedName,
            originalName: originalName,
            transaction: transaction
        )

        let placeholder = DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder
        if displayName.isEmpty || displayName == placeholder {
            return .useServerProvided
        }
        return .replace(displayName)
    }

    private func resolveWithoutThread(serverGid: String,
                                       transaction: SDSAnyReadTransaction) -> GroupNameResolution {
        let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: serverGid, transaction: transaction)
        let cryptoMode = baseInfo?.groupCryptoMode ?? 0

        guard DTGroupCryptoDisplayHelper.shared.isEncryptedGroup(Int(cryptoMode)) else {
            return .useServerProvided
        }

        // Encrypted group without a local thread; gid-direct decrypt path.
        Logger.error("[NSE] encrypted group thread missing, falling back to gid-direct decrypt, gid: \(serverGid)")

        if !DTGroupCryptoDisplayHelper.shared.hasGroupKey(gid: serverGid, transaction: transaction) {
            Logger.error("[NSE] encrypted group missing R_group locally, gid: \(serverGid)")
        }

        let displayName = DTGroupCryptoDisplayHelper.shared.displayGroupName(
            gid: serverGid,
            groupCryptoMode: Int(cryptoMode),
            encryptedName: baseInfo?.encryptedName,
            originalName: baseInfo?.name,
            transaction: transaction
        )
        let placeholder = DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder
        if displayName.isEmpty || displayName == placeholder {
            return .useServerProvided
        }
        return .replace(displayName)
    }

    private static func normalizeConversationId(_ raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        if isGid(raw) { return raw }

        guard raw.count % 4 == 0,
              let decodedData = Data(base64Encoded: raw),
              let decoded = String(data: decodedData, encoding: .utf8),
              isGid(decoded) else {
            return raw
        }
        return decoded
    }

    private static func isGid(_ s: String) -> Bool {
        return s.count == 32 &&
               s.range(of: "^[a-zA-Z0-9]{32}$", options: .regularExpression) != nil
    }
}

// MARK: - Payload-direct decrypt (Path A)

/// First-push path: decrypt groupInfo.encryptedName using dataMessage.groupRootKey.
/// Returns nil to let the caller fall back to NSEGroupNameResolver.resolve(...).
internal enum NSEPayloadGroupNameDecryptor {
    /// Decrypt closure: (rGroup, cipher) -> plainName. Injected for tests.
    typealias Decryptor = (Data, String) -> String?

    static var defaultDecryptor: Decryptor = { rGroup, cipher in
        DTGroupCryptoDisplayHelper.shared.decryptedGroupName(rGroup: rGroup, encryptedName: cipher)
    }

    /// Pure-data variant — testable without constructing protobuf messages.
    static func tryDecrypt(aps: [String: Any],
                           rGroup: Data?,
                           decryptor: Decryptor = defaultDecryptor) -> (gid: String, plainName: String)? {
        guard let groupInfo = aps["groupInfo"] as? [String: Any],
              (groupInfo["groupCryptoMode"] as? Int) == 1,
              let cipher = groupInfo["encryptedName"] as? String, !cipher.isEmpty,
              let gid = groupInfo["gid"] as? String, !gid.isEmpty else {
            return nil
        }
        guard let rGroup, !rGroup.isEmpty else {
            Logger.info("[NSE][groupInfo] missing rGroup gid=...\(gid.suffix(6))")
            return nil
        }
        guard let plain = decryptor(rGroup, cipher), !plain.isEmpty else {
            Logger.error("[NSE][groupInfo] decrypt failed gid=...\(gid.suffix(6))")
            return nil
        }
        Logger.info("[NSE][groupInfo] decrypt ok gid=...\(gid.suffix(6))")
        return (gid, plain)
    }

    /// Convenience for NotificationService — unwraps rGroup from groupContext.
    static func tryDecrypt(aps: [String: Any],
                           dataMessage: DSKProtoDataMessage?,
                           decryptor: Decryptor = defaultDecryptor) -> (gid: String, plainName: String)? {
        let rGroup: Data? = {
            guard let groupContext = dataMessage?.group,
                  groupContext.hasGroupRootKey else { return nil }
            return groupContext.groupRootKey
        }()
        return tryDecrypt(aps: aps, rGroup: rGroup, decryptor: decryptor)
    }
}

// MARK: - 🔒 Lock fallback (Path C)

internal enum NSELockFallback {
    /// Returns "🔒 ${title}" when aps is from an encrypted group push with non-empty title.
    static func lockedTitle(aps: [String: Any]) -> String? {
        guard isEncryptedGroupAlert(aps: aps),
              let alert = aps["alert"] as? [String: Any],
              let pushTitle = alert["title"] as? String, !pushTitle.isEmpty else {
            return nil
        }
        return "🔒 " + pushTitle
    }

    /// Encrypted group iff aps.groupInfo.groupCryptoMode == 1.
    static func isEncryptedGroupAlert(aps: [String: Any]) -> Bool {
        guard let info = aps["groupInfo"] as? [String: Any] else { return false }
        return (info["groupCryptoMode"] as? Int) == 1
    }
}

// MARK: - Encrypted name persistence helper

internal enum NSEEncryptedNamePersister {
    /// Decide whether to write cipher into baseInfo. Only update when:
    ///   - existing baseInfo is non-nil (do NOT create)
    ///   - existing.encryptedName differs from cipher
    static func shouldUpsert(existing: DTGroupBaseInfoEntity?, cipher: String) -> Bool {
        guard let existing else { return false }
        return existing.encryptedName != cipher
    }
}
