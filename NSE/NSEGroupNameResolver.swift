//
//  NSEGroupNameResolver.swift
//  NSE
//

import Foundation
import TTServiceKit

internal enum GroupNameResolution {
    case useServerProvided
    case replace(String)
    case encryptedPlaceholder
}

internal struct NSEGroupNameResolver {
    func resolve(aps: [String: Any],
                 isCritical: Bool,
                 lockey: String,
                 transaction: SDSAnyReadTransaction) -> GroupNameResolution {
        guard let passthroughString = aps["passthrough"] as? String else {
            Logger.info("resolveGroupName: no passthrough in aps, skip (isCritical=\(isCritical))")
            return .useServerProvided
        }
        
        guard let passthroughData = passthroughString.data(using: .utf8),
              let passthroughDict = try? JSONSerialization.jsonObject(with: passthroughData) as? [String: Any] else {
            Logger.info("resolveGroupName: passthrough JSON parse failed (isCritical=\(isCritical))")
            return .useServerProvided
        }
        
        guard let rawConversationId = passthroughDict["conversationId"] as? String else {
            Logger.info("resolveGroupName: no conversationId in passthrough, isCritical=\(isCritical)")
            return .useServerProvided
        }
        
        let conversationId = Self.normalizeConversationId(rawConversationId)
        if conversationId != rawConversationId {
            Logger.info("[NSE] conversationId normalized via base64 decode, len: \(rawConversationId.count) -> \(conversationId.count)")
        }
        
        guard let groupIdData = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) else {
            Logger.info("resolveGroupName: cannot decode conversationId, prefix=\(rawConversationId.prefix(8)), isCritical=\(isCritical)")
            return .useServerProvided
        }

        let threadId = TSGroupThread.threadId(fromGroupId: groupIdData)
        if let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction) {
            return resolveWithThread(groupThread, threadId: threadId, isCritical: isCritical, transaction: transaction)
        }
        Logger.info("resolveGroupName: thread missing, attempt gid-direct decrypt, isCritical=\(isCritical), lockey=\(lockey)")
        return resolveWithoutThread(serverGid: conversationId, transaction: transaction)
    }

    private func resolveWithThread(_ groupThread: TSGroupThread,
                                    threadId: String,
                                    isCritical: Bool,
                                    transaction: SDSAnyReadTransaction) -> GroupNameResolution {
        guard groupThread.groupModel.isEncryptedGroup else {
            return .useServerProvided
        }

        // 以下分支已确认是加密群上下文
        let encryptedGroupFallback: GroupNameResolution = isCritical ? .encryptedPlaceholder : .useServerProvided

        let serverGid = groupThread.serverThreadId
        guard !serverGid.isEmpty else {
            Logger.info("resolveGroupName: serverThreadId empty, threadId=\(threadId), isCritical=\(isCritical)")
            return encryptedGroupFallback
        }

        let displayName = DTGroupCryptoDisplayHelper.shared.displayGroupName(
            gid: serverGid,
            groupCryptoMode: groupThread.groupModel.groupCryptoMode,
            encryptedName: nil,
            originalName: groupThread.groupModel.groupName,
            transaction: transaction
        )

        let placeholder = DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder
        if displayName.isEmpty || displayName == placeholder {
            Logger.info("resolveGroupName: helper returned placeholder/empty, kind=placeholder")
            return .encryptedPlaceholder
        }
        Logger.info("resolveGroupName: helper resolved, kind=replace")
        return .replace(displayName)
    }

    private func resolveWithoutThread(serverGid: String,
                                       transaction: SDSAnyReadTransaction) -> GroupNameResolution {
        let displayName = DTGroupCryptoDisplayHelper.shared.displayGroupName(
            gid: serverGid,
            groupCryptoMode: 1,
            encryptedName: nil,
            originalName: nil,
            transaction: transaction
        )
        let placeholder = DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder
        if displayName.isEmpty || displayName == placeholder {
            Logger.info("resolveGroupName: thread missing, gid-direct decrypt produced placeholder, kind=encryptedPlaceholder")
            return .encryptedPlaceholder
        }
        Logger.info("resolveGroupName: thread missing, gid-direct decrypt succeeded, kind=replace")
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
