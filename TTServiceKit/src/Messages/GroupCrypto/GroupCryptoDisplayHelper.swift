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

        // Has ciphertext but can't decrypt (e.g. stale R_group after rotation) -> placeholder,
        // not stale cached plaintext, so the "can't read new name" state stays visible.
        if let effectiveEncryptedName, !effectiveEncryptedName.isEmpty {
            return Self.encryptedGroupNamePlaceholder
        }
        // No ciphertext to decrypt (transient, e.g. just joined) -> fall back to last known name.
        return (originalName?.isEmpty == false ? originalName : nil) ?? Self.encryptedGroupNamePlaceholder
    }

    @objc public func decryptedGroupName(rGroup: Data, encryptedName: String) -> String? {
        manager.decryptedGroupName(rGroup: rGroup, encryptedName: encryptedName)
    }

    /// Call-scene name resolver. Trusts caller's E2EE plaintext first;
    /// local DB decrypt may fail when R_group hasn't landed yet (first call into an encrypted group).
    @objc public func resolveGroupCallDisplayName(trustedPlaintextName: String?,
                                                  serverGroupId: String?,
                                                  transaction: SDSAnyReadTransaction) -> String {
        if let name = trustedPlaintextName, !name.isEmpty {
            return name
        }
        if let gid = serverGroupId, !gid.isEmpty {
            let dbName = resolveGroupDisplayName(serverGroupId: gid,
                                                  fallbackName: nil,
                                                  transaction: transaction)
            if !dbName.isEmpty {
                return dbName
            }
        }
        return Self.encryptedGroupNamePlaceholder
    }

    /// 给会议等场景解析群显示名。
    @objc public func resolveGroupDisplayName(serverGroupId: String?,
                                              fallbackName: String?,
                                              transaction: SDSAnyReadTransaction) -> String {
        let fallback = fallbackName ?? ""
        guard let serverGroupId, !serverGroupId.isEmpty,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: serverGroupId) else {
            return fallback
        }
        let threadId = TSGroupThread.threadId(fromGroupId: groupId)
        guard let thread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction) else {
            return fallback
        }

        guard thread.groupModel.isEncryptedGroup else {
            let name = thread.name(with: transaction)
            return name.isEmpty ? fallback : name
        }

        // fallback chain: decrypted -> cached local name -> caller fallback
        let encryptedName = DTGroupBaseInfoEntity.anyFetch(uniqueId: serverGroupId, transaction: transaction)?.encryptedName
        if let decrypted = manager.decryptedGroupName(gid: serverGroupId, encryptedName: encryptedName, transaction: transaction),
           !decrypted.isEmpty {
            return decrypted
        }
        if manager.hasRGroup(gid: serverGroupId, transaction: transaction) {
            Logger.error("[GroupCrypto] resolve unresolved with R_group present, gid: \(serverGroupId)")
        }
        if let localName = thread.groupModel.groupName, !localName.isEmpty {
            return localName
        }
        return fallback
    }

    // MARK: - Avatar Update

    /// 加密群头像的下一步动作决策。
    private enum AvatarDecision {
        case download(url: String)
        /// 清空 groupImage，UI 走 empty-group-avatar
        case clear
        /// 保持现状
        case keep
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
            Logger.info("[GroupCrypto] Avatar will download, gid: \(gid)")
            return url
        case .clear:
            // No real encrypted avatar: clear groupImage and return nil so the UI falls back
            // to empty-group-avatar (like plaintext groups), not the server lock placeholder.
            clearGroupImage(gid: gid, transaction: transaction)
            return nil
        case .keep:
            return nil
        case .pendingDecryption:
            return plainFallback(plainAvatar)
        }
    }

    private func decideEncryptedAvatarAction(encryptedAvatar: String?,
                                              gid: String,
                                              transaction: SDSAnyReadTransaction) -> AvatarDecision {
        let effectiveEncrypted = (encryptedAvatar?.isEmpty == false)
            ? encryptedAvatar
            : loadEncryptedAvatar(gid: gid, transaction: transaction)

        guard let encrypted = effectiveEncrypted else {
            return .clear
        }

        guard manager.hasRGroup(gid: gid, transaction: transaction) else {
            return .pendingDecryption
        }

        guard let decrypted = manager.decryptedGroupAvatar(gid: gid,
                                                             encryptedAvatar: encrypted,
                                                             transaction: transaction) else {
            // Has ciphertext but can't decrypt (e.g. stale R_group) -> lock placeholder, matching the
            // "🔒" name, instead of keeping a stale image. Decryptable avatars take .download instead.
            return .pendingDecryption
        }

        if decrypted.isEmpty {
            return .clear
        }

        return .download(url: decrypted)
    }

    // MARK: - Avatar Download Marker
    // 仅用于 plainFallback 路径避免覆盖已下载的真实头像。
    @objc public func markAvatarDownloaded(gid: String, encryptedAvatar: String) {
        guard !gid.isEmpty, !encryptedAvatar.isEmpty else { return }
        fingerprintQueue.sync {
            self.downloadedAvatarFingerprint[gid] = encryptedAvatar
        }
    }

    @objc public func hasAvatarDownloaded(gid: String) -> Bool {
        guard !gid.isEmpty else { return false }
        return fingerprintQueue.sync {
            downloadedAvatarFingerprint[gid] != nil
        }
    }

    @objc public func clearAvatarFingerprint(gid: String) {
        guard !gid.isEmpty else { return }
        fingerprintQueue.sync {
            downloadedAvatarFingerprint.removeValue(forKey: gid)
        }
    }

    // MARK: - Query

    @objc public func isEncryptedGroup(_ groupCryptoMode: Int) -> Bool {
        manager.isEncryptedGroup(groupCryptoMode: groupCryptoMode)
    }

    @objc public func hasGroupKey(gid: String, transaction: SDSAnyReadTransaction) -> Bool {
        manager.hasRGroup(gid: gid, transaction: transaction)
    }

    /// Whether the current key can decrypt the stored encrypted avatar. If not (no key or wrong R_group),
    /// what shows is the lock placeholder — used to avoid marking it as a "real avatar downloaded".
    @objc public func canDecryptAvatar(gid: String, transaction: SDSAnyReadTransaction) -> Bool {
        guard let encrypted = loadEncryptedAvatar(gid: gid, transaction: transaction), !encrypted.isEmpty else {
            return false
        }
        return manager.decryptedGroupAvatar(gid: gid, encryptedAvatar: encrypted, transaction: transaction) != nil
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
