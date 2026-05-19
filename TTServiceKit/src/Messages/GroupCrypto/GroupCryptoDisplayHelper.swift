//
//  DTGroupCryptoDisplayHelper.swift
//  TTServiceKit
//

import Foundation

@objc public final class DTGroupCryptoDisplayHelper: NSObject {

    @objc public static let shared = DTGroupCryptoDisplayHelper()

    @objc public static var encryptedGroupNamePlaceholder: String {
        Localized("GROUP_CRYPTO_DEFAULT_NAME", comment: "Encrypted Group")
    }

    private let manager: GroupCryptoManaging

    private let fingerprintQueue = DispatchQueue(label: "com.tt.groupcrypto.avatarFingerprint")
    private var downloadedAvatarFingerprint: [String: String] = [:]

    init(manager: GroupCryptoManaging) {
        self.manager = manager
        super.init()

        // 账号切换时清空 per-process fingerprint 缓存，避免跨账号残留导致头像不刷新
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(localNumberDidChange(_:)),
                                               name: NSNotification.Name("NSNotificationNameLocalNumberDidChange"),
                                               object: nil)
    }

    private override convenience init() {
        self.init(manager: DTGroupCryptoManager(
            cryptoService: DTGroupCryptoServiceImpl(),
            keyStore: DTGroupCryptoKeyStoreImpl()
        ))
    }

    @objc private func localNumberDidChange(_ notification: Notification) {
        fingerprintQueue.async { [weak self] in
            self?.downloadedAvatarFingerprint.removeAll()
            Logger.info("[GroupCrypto] Cleared avatar fingerprint cache due to account change")
        }
    }

    // MARK: - Display

    @objc public func displayGroupName(gid: String,
                                       groupCryptoMode: Int,
                                       encryptedName: String?,
                                       originalName: String?,
                                       transaction: SDSAnyReadTransaction) -> String {
        guard isEncryptedGroup(groupCryptoMode) else {
            return originalName ?? ""
        }

        let effectiveEncryptedName = encryptedName ?? loadEncryptedName(gid: gid, transaction: transaction)

        if let decrypted = manager.decryptedGroupName(gid: gid,
                                                       encryptedName: effectiveEncryptedName,
                                                       transaction: transaction),
           !decrypted.isEmpty {
            return decrypted
        }

        if let effective = effectiveEncryptedName, !effective.isEmpty, originalName == effective {
            Logger.info("[GroupCrypto] displayGroupName avoid ciphertext leak, gid: \(gid)")
            return Self.encryptedGroupNamePlaceholder
        }

        return (originalName?.isEmpty == false ? originalName : nil) ?? Self.encryptedGroupNamePlaceholder
    }

    /// 给会议等场景解析群显示名。对加密群走本地解密
    @objc public func resolveGroupDisplayName(serverGroupId: String?,
                                              fallbackName: String?,
                                              transaction: SDSAnyReadTransaction) -> String {
        let fallback = fallbackName ?? ""
        guard let serverGroupId, !serverGroupId.isEmpty,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: serverGroupId) else {
            return fallback
        }

        let threadId = TSGroupThread.threadId(fromGroupId: groupId)
        let placeholder = Self.encryptedGroupNamePlaceholder

        guard let thread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction) else {
            return fallback
        }
        let name = thread.name(with: transaction)
        let resolved = !name.isEmpty && name != placeholder
        let hasKey = manager.hasRGroup(gid: serverGroupId, transaction: transaction)
        Logger.info("[GroupCrypto] resolve gid=\(serverGroupId) hasKey=\(hasKey) resolved=\(resolved)")
        return resolved ? name : fallback
    }

    // MARK: - Avatar Update

    /// 加密群头像的下一步动作决策。
    private enum AvatarDecision {
        case download(url: String)
        /// 清空 groupImage，UI 走 empty-group-avatar
        case clear(reason: String)
        /// 保持现状
        case keep(reason: String)
        /// R_group 未到达，（服务端下发的加锁占位图）
        case pendingDecryption
    }

    @objc public func prepareAvatarUpdate(plainAvatar: String?,
                                          encryptedAvatar: String?,
                                          groupCryptoMode: Int,
                                          gid: String,
                                          transaction: SDSAnyWriteTransaction) -> String? {
        guard isEncryptedGroup(groupCryptoMode) else {
            return plainFallback(plainAvatar)
        }

        switch decideEncryptedAvatarAction(encryptedAvatar: encryptedAvatar,
                                            gid: gid,
                                            transaction: transaction) {
        case .download(let url):
            Logger.info("[GroupCrypto] Avatar decrypted, will download for gid: \(gid)")
            return url
        case .clear(let reason):
            clearGroupImage(gid: gid, transaction: transaction)
            let fallback = plainFallback(plainAvatar)
            Logger.info("[GroupCrypto] Avatar cleared for gid: \(gid) (\(reason)), hasPlainFallback: \(fallback != nil)")
            return fallback
        case .keep(let reason):
            Logger.info("[GroupCrypto] Avatar keep current state for gid: \(gid) (\(reason))")
            return nil
        case .pendingDecryption:
            let fallback = plainFallback(plainAvatar)
            Logger.info("[GroupCrypto] Avatar pending decryption for gid: \(gid), hasPlainFallback: \(fallback != nil)")
            return fallback
        }
    }

    private func decideEncryptedAvatarAction(encryptedAvatar: String?,
                                              gid: String,
                                              transaction: SDSAnyReadTransaction) -> AvatarDecision {
        let effectiveEncrypted = (encryptedAvatar?.isEmpty == false)
            ? encryptedAvatar
            : loadEncryptedAvatar(gid: gid, transaction: transaction)

        guard let encrypted = effectiveEncrypted else {
            return .clear(reason: "no ciphertext")
        }

        if isAvatarFingerprintUnchanged(gid: gid, encryptedAvatar: encrypted) {
            return .keep(reason: "fingerprint unchanged")
        }

        guard manager.hasRGroup(gid: gid, transaction: transaction) else {
            return .pendingDecryption
        }

        guard let decrypted = manager.decryptedGroupAvatar(gid: gid,
                                                             encryptedAvatar: encrypted,
                                                             transaction: transaction) else {
            return .keep(reason: "decrypt failed")
        }

        if decrypted.isEmpty {
            return .clear(reason: "decrypted empty plaintext")
        }

        return .download(url: decrypted)
    }

    // MARK: - Avatar Fingerprint
    @objc public func markAvatarDownloaded(gid: String, encryptedAvatar: String) {
        guard !gid.isEmpty else { return }
        guard !encryptedAvatar.isEmpty else {
            Logger.info("[GroupCrypto] markAvatarDownloaded skip: empty encryptedAvatar, gid: \(gid)")
            return
        }
        fingerprintQueue.sync {
            self.downloadedAvatarFingerprint[gid] = encryptedAvatar
        }
    }

    private func isAvatarFingerprintUnchanged(gid: String, encryptedAvatar: String) -> Bool {
        fingerprintQueue.sync {
            downloadedAvatarFingerprint[gid] == encryptedAvatar
        }
    }

    @objc public func hasAvatarDownloaded(gid: String) -> Bool {
        guard !gid.isEmpty else { return false }
        return fingerprintQueue.sync {
            downloadedAvatarFingerprint[gid] != nil
        }
    }

    // MARK: - Query

    @objc public func isEncryptedGroup(_ groupCryptoMode: Int) -> Bool {
        manager.isEncryptedGroup(groupCryptoMode: groupCryptoMode)
    }

    @objc public func hasGroupKey(gid: String, transaction: SDSAnyReadTransaction) -> Bool {
        manager.hasRGroup(gid: gid, transaction: transaction)
    }

    // MARK: - Private

    private func plainFallback(_ plainAvatar: String?) -> String? {
        (plainAvatar?.isEmpty == false) ? plainAvatar : nil
    }

    private func clearGroupImage(gid: String, transaction: SDSAnyWriteTransaction) {
        guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else { return }
        let threadId = TSGroupThread.threadId(fromGroupId: groupId)
        guard let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction),
              groupThread.groupModel.groupImage != nil else {
            return
        }

        groupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel.groupImage = nil
        }
        transaction.addAsyncCompletionOnMain {
            groupThread.fireAvatarChangedNotification()
        }
    }

    private func loadEncryptedName(gid: String, transaction: SDSAnyReadTransaction) -> String? {
        DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedName
    }

    private func loadEncryptedAvatar(gid: String, transaction: SDSAnyReadTransaction) -> String? {
        DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedAvatar
    }
}
